import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../firebase_options.dart';
import '../models/duel.dart';
import 'app_strings.dart';
import 'language_service.dart';
import 'notification_service.dart';

/// Düello ve arkadaş olaylarını bildirime çevirir. Sunucu (Cloud Functions) olmadan çalışır:
///   - uygulama açıkken/arka plandayken Firestore dinleyicilerinden anında,
///   - uygulama kapalıyken WorkManager ile ~60 dakikada bir kontrol ederek.
/// İki yol da aynı "son görülen durum"u kullanır; aynı olay iki kez bildirilmez.
class SocialWatcher {
  static const String _duelStateKey = 'social_duel_state'; // {duelId: "rakipTur|bitti"}
  static const String _friendSeenKey = 'social_friend_seen';
  static const String _lastCheckKey = 'social_last_check_ms';
  static const String _taskName = 'social_check';
  static const Duration _every = Duration(minutes: 60);

  /// Uygulama bu süre içinde açıksa canlı dinleyiciler değişiklikleri zaten almıştır;
  /// arka plan kontrolü boşuna okuma yapmaz
  static const Duration _skipIfSeenWithin = Duration(minutes: 50);

  /// Uygulama ön plandaysa bildirim yerine uygulama içi gösterim yeterli
  static bool get _appVisible => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  // ─── Düello ──────────────────────────────────────────────────────
  /// [duels] tam liste ya da yalnızca değişenler olabilir; listede olmayanların durumu korunur.
  static Future<void> handleDuels(
    SharedPreferences prefs,
    String me,
    List<Duel> duels, {
    bool notify = true,
  }) async {
    await prefs.reload();
    final raw = prefs.getString(_duelStateKey);
    final firstRun = raw == null;
    final state = firstRun ? <String, String>{} : Map<String, String>.from(jsonDecode(raw) as Map);
    final show = notify && !firstRun && !_appVisible;

    for (final d in duels) {
      final opp = d.opponentOf(me);
      final oppPlayed = d.playedBy(opp);
      final now = '$oppPlayed|${d.isDone ? 1 : 0}';
      final before = state[d.id];
      state[d.id] = now;
      if (!show || before == now) continue;
      final name = d.names[opp] ?? '?';

      if (before == null) {
        if (!d.isDone && d.playedBy(me) == 0) {
          await NotificationService().showSocial(
            key: 'duel_new_${d.id}',
            title: AppStrings.notifDuelNewTitle,
            body: AppStrings.notifDuelNewBody(name),
          );
        }
        continue;
      }
      final wasDone = before.endsWith('|1');
      if (d.isDone && !wasDone) {
        final r = d.resultFor(me);
        if (r != null) {
          await NotificationService().showSocial(
            key: 'duel_done_${d.id}',
            title: AppStrings.notifDuelDoneTitle(r),
            body: AppStrings.notifDuelDoneBody(r, name),
          );
        }
      } else if (!d.isDone && oppPlayed > (int.tryParse(before.split('|').first) ?? 0) && !d.finishedBy(me)) {
        await NotificationService().showSocial(
          key: 'duel_turn_${d.id}',
          title: AppStrings.notifDuelTurnTitle,
          body: AppStrings.notifDuelTurnBody(name, oppPlayed),
        );
      }
    }
    // Eski kayıtlar şişmesin
    if (state.length > 80) {
      final keep = {for (final d in duels) d.id};
      state.removeWhere((k, _) => !keep.contains(k));
    }
    await prefs.setString(_duelStateKey, jsonEncode(state));
  }

  // ─── Arkadaş ─────────────────────────────────────────────────────
  /// Henüz bildirilmemiş arkadaş eklemelerini bildirir. (requestId, ad) listesi alır.
  static Future<void> handleFriendRequests(
    SharedPreferences prefs,
    List<(String, String)> requests, {
    bool forceNotify = false,
  }) async {
    await prefs.reload();
    final seen = (prefs.getStringList(_friendSeenKey) ?? []).toSet();
    for (final (id, name) in requests) {
      if (!seen.add(id)) continue;
      if (forceNotify || !_appVisible) {
        await NotificationService().showSocial(
          key: 'friend_$id',
          title: AppStrings.notifFriendTitle,
          body: AppStrings.notifFriendBody(name),
        );
      }
    }
    final list = seen.toList();
    await prefs.setStringList(_friendSeenKey, list.length > 100 ? list.sublist(list.length - 100) : list);
  }

  // ─── Arka plan kontrolü ─────────────────────────────────────────
  static Future<void> registerBackgroundCheck() async {
    try {
      await Workmanager().initialize(socialCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: _every,
        constraints: Constraints(networkType: NetworkType.connected),
        // Eski 30 dakikalık görev 60 dakikalıkla değişsin
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } catch (e) {
      debugPrint('SocialWatcher register error: $e');
    }
  }

  /// Uygulama kapalıyken çalışan kontrol. Okuma maliyeti düşük tutulur:
  /// yalnızca son kontrolden beri değişen düellolar ve bana gelen arkadaş istekleri okunur.
  static Future<void> runBackgroundCheck() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final me = prefs.getString('leaderboard_user_id');
    if (me == null) return;
    await LanguageService().init();
    await NotificationService().init();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(_lastCheckKey);
    if (last != null && nowMs - last < _skipIfSeenWithin.inMilliseconds) return;
    final since = last ?? nowMs - const Duration(hours: 1).inMilliseconds;
    final db = FirebaseFirestore.instance;

    final changed = await db
        .collection('duels')
        .where('players', arrayContains: me)
        .where('updatedAt', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(since))
        .limit(20)
        .get();
    await handleDuels(prefs, me, [for (final d in changed.docs) Duel.fromMap(d.id, d.data())], notify: true);

    final requests = await db.collection('friend_requests').where('to', isEqualTo: me).limit(20).get();
    await handleFriendRequests(
      prefs,
      [for (final r in requests.docs) (r.id, (r.data()['name'] as String?) ?? '?')],
      forceNotify: true,
    );

    await prefs.setInt(_lastCheckKey, nowMs);
  }

  /// Uygulama açıldığında: arka plan kontrolü kaldığı yerden devam etsin
  static Future<void> markChecked(SharedPreferences prefs) =>
      prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
}

@pragma('vm:entry-point')
void socialCallbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      await SocialWatcher.runBackgroundCheck();
    } catch (e) {
      debugPrint('SocialWatcher background error: $e');
    }
    return true;
  });
}
