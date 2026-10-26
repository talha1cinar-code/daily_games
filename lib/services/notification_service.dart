import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'dart:io';
import 'app_strings.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Sabit ID'ler (aynı ID ile zamanlanan bildirim önceki kaydı ezer/günceller)
  static const int _morningRunStartId = 101; // Sabah 12:00
  static const int _eveningRunStartId = 102; // Akşam 17:00
  static const int _morningRunReminderId = 201; // Kaldırılan sabah hatırlatması (16:00)
  static const int _eveningRunReminderId = 202; // Kaldırılan akşam hatırlatması (23:00)

  // Seri bildirimleri 300-330 aralığını kullanır (bkz. scheduleStreakNotifications)

  Future<void> init() async {
    // Zaman dilimi verilerini yükle (timezone)
    tz.initializeTimeZones();
    // Türkiye saat dilimini ayarla
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Android için init
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_stat_flame');

    // iOS için init (Darwin)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android bildirim kanallarını oluştur
    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'daily_run_channel',
            'Daily Run Bildirimleri',
            description: 'Daily Run başlangıç bildirimleri',
            importance: Importance.high,
          ),
        );
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'streak_channel',
            'Seri Bildirimleri',
            description: 'Seri durumu ve dondurma hakkı bildirimleri',
            importance: Importance.high,
          ),
        );
      }
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Bildirime tıklandı: ${response.payload}');
  }

  Future<void> requestPermissions() async {
    try {
      if (Platform.isIOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      } else if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        await androidImplementation?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Bildirim izni istenirken hata oluştu: $e');
    }
  }

  /// Daily Run başlangıç bildirimlerini planlar (12:00 ve 17:00).
  /// 1 saat kala olan bitiş bildirimleri kaldırıldı ve mevcut olanlar iptal edildi.
  Future<void> scheduleDailyNotifications() async {
    // 1 saat önceden gönderilen eski hatırlatıcıları iptal et
    await flutterLocalNotificationsPlugin.cancel(id: _morningRunReminderId);
    await flutterLocalNotificationsPlugin.cancel(id: _eveningRunReminderId);

    // Sabah turu gece yarısı başlar; 12:00 bildirimi yanıltıcıydı, kaldırıldı
    await flutterLocalNotificationsPlugin.cancel(id: _morningRunStartId);

    // Akşam Daily Run başlangıç (17:00)
    await _scheduleDailyNotification(
      id: _eveningRunStartId,
      title: AppStrings.eveningRunStartedTitle,
      body: AppStrings.runStartedBody,
      hour: 17,
      minute: 0,
    );
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOfTime(hour, minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_run_channel',
            'Daily Run Bildirimleri',
            channelDescription: 'Daily Run başlangıç bildirimleri',
            importance: Importance.max,
            priority: Priority.high,
            icon: 'ic_stat_flame',
            color: Color(0xFFFF7A2F),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Her gün aynı saatte tekrarla
      );
    } catch (e) {
      debugPrint('Günlük bildirim zamanlanırken hata ($id): $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Eski hatırlatıcı iptal metodları (geriye dönük uyumluluk için)
  Future<void> cancelMorningReminder() async {
    await flutterLocalNotificationsPlugin.cancel(id: _morningRunReminderId);
  }

  Future<void> cancelEveningReminder() async {
    await flutterLocalNotificationsPlugin.cancel(id: _eveningRunReminderId);
  }

  /// Tüm bildirimleri iptal eder
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Tüm seri bildirimlerini temizler
  Future<void> cancelAllStreakNotifications() async {
    for (int id = 300; id <= 330; id++) {
      try {
        await flutterLocalNotificationsPlugin.cancel(id: id);
      } catch (_) {}
    }
  }

  /// Duolingo tarzı seri bildirimleri. Bugün ve sonraki [_planDays] gün için
  /// "kullanıcı hiç oynamazsa" senaryosuna göre önceden planlanır; oyun
  /// bitince yeniden hesaplanır ve o günün hatırlatmaları iptal olur.
  ///
  /// Gün başına en fazla 3 bildirim: kişinin genelde oynadığı saatte
  /// hatırlatma, 22:00 "tehlikede", 23:15 "son şans".
  static const int _planDays = 3;

  Future<void> scheduleStreakNotifications({
    required int currentStreak,
    required int freezeCount,
    required bool isPlayedToday,
    required int preferredHour,
    required bool canRestore,
    required int lostStreak,
  }) async {
    await cancelAllStreakNotifications();
    final now = tz.TZDateTime.now(tz.local);

    Future<void> at(int dayOffset, int slot, int hour, int minute, String title, String body) async {
      final when = tz.TZDateTime(tz.local, now.year, now.month, now.day + dayOffset, hour, minute);
      if (!when.isAfter(now)) return;
      await _scheduleOneTimeNotification(id: 300 + dayOffset * 3 + slot, title: title, body: body, scheduledDate: when);
    }

    // Seri yoksa: yalnızca nazik bir günlük davet (kayıp seri geri getirilebiliyorsa onu hatırlat)
    if (currentStreak <= 0) {
      for (var d = 0; d <= _planDays; d++) {
        if (d == 0 && isPlayedToday) continue;
        if (canRestore && d <= 1 && lostStreak > 0) {
          await at(d, 0, preferredHour, 0, AppStrings.streakRestoreNotifTitle(lostStreak),
              AppStrings.streakRestoreNotifBody);
        } else {
          final (t, b) = AppStrings.comeBackNotif(d);
          await at(d, 0, preferredHour, 0, t, b);
        }
      }
      return;
    }

    for (var d = 0; d <= _planDays; d++) {
      if (d == 0 && isPlayedToday) continue;
      // Bu güne kadar tamamen kaçırılmış gün sayısı (bugün dahil değil)
      final missedBefore = isPlayedToday ? d - 1 : d;
      final freezesLeft = freezeCount - missedBefore;

      if (missedBefore == 0) {
        // Seri sağlam: bugün oynarsa uzar
        final (t, b) = AppStrings.streakReminderNotif(currentStreak, d);
        await at(d, 0, preferredHour, 0, t, b);
      } else if (freezesLeft >= 0) {
        // Dün kaçırıldı, donma hakkı seriyi kurtardı
        await at(d, 0, preferredHour, 0, AppStrings.streakFrozenNotifTitle, AppStrings.streakFrozenNotifBody(currentStreak));
      } else {
        // Hak yetmedi: seri bitti. Bir kez haber ver, sonra sus.
        await at(d, 0, preferredHour, 0, AppStrings.streakRestoreNotifTitle(currentStreak), AppStrings.streakRestoreNotifBody);
        break;
      }

      await at(d, 1, 22, 0, AppStrings.streakAtRiskTitle, AppStrings.streakAtRiskBody(currentStreak));
      await at(
        d,
        2,
        23,
        15,
        AppStrings.streakLastChanceTitle,
        freezesLeft > 0 ? AppStrings.streakFreezeWillSave : AppStrings.streakWillReset(currentStreak),
      );
    }
  }

  static const int _duelReminderId = 400;

  /// Sırası gelen düello varsa 3 saat sonra (gece ise ertesi gün 12:00) bir
  /// hatırlatma kurar. Sunucu olmadığından rakibin hamlesini anında bildiremeyiz.
  Future<void> scheduleDuelReminder({required int pending}) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id: _duelReminderId);
    } catch (_) {}
    if (pending <= 0) return;
    final now = tz.TZDateTime.now(tz.local);
    var when = now.add(const Duration(hours: 3));
    if (when.hour >= 22 || when.hour < 10) {
      final base = now.hour >= 10 ? now.add(const Duration(days: 1)) : now;
      when = tz.TZDateTime(tz.local, base.year, base.month, base.day, 12);
    }
    await _scheduleOneTimeNotification(
      id: _duelReminderId,
      title: AppStrings.duelReminderTitle,
      body: AppStrings.duelReminderBody(pending),
      scheduledDate: when,
    );
  }

  Future<void> _scheduleOneTimeNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak_channel',
            'Seri Bildirimleri',
            channelDescription: 'Seri durumu ve dondurma hakkı bildirimleri',
            importance: Importance.max,
            priority: Priority.high,
            icon: 'ic_stat_flame',
            color: Color(0xFFFF7A2F),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: null, // Tek seferlik
      );
    } catch (e) {
      debugPrint('Streak bildirim planlama hatası ($id): $e');
    }
  }
}
