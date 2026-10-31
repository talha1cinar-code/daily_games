import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_run_service.dart';
import 'avatar_service.dart';

/// Sıralama verisi için model.
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String avatar;
  final String banner;
  final double score;
  final int attempts;
  final int maxAttempts;
  final int? durationMs;
  final bool isWin;

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.avatar,
    this.banner = 'none',
    required this.score,
    this.attempts = 0,
    this.maxAttempts = 0,
    this.durationMs,
    this.isWin = true,
  });

  factory LeaderboardEntry.fromMap(String id, Map<String, dynamic> map) {
    return LeaderboardEntry(
      userId: id,
      displayName: map['name'] as String? ?? 'Anonim',
      avatar: map['avatar'] as String? ?? '👤',
      banner: map['banner'] as String? ?? 'none',
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      attempts: map['attempts'] as int? ?? 0,
      maxAttempts: map['maxAttempts'] as int? ?? 0,
      durationMs: map['durationMs'] as int?,
      isWin: map['isWin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': displayName,
        'avatar': avatar,
        'banner': banner,
        'score': score,
        'attempts': attempts,
        'maxAttempts': maxAttempts,
        'durationMs': durationMs,
        'isWin': isWin,
      };
}

class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  _CacheEntry(this.data, this.timestamp);

  bool get isValid => DateTime.now().difference(timestamp).inMinutes < 5;
}

/// Haftalık sıralama için birleştirilmiş giriş.
class WeeklyLeaderboardEntry {
  final String userId;
  final String displayName;
  final String avatar;
  final String banner;
  final double totalScore;
  final int daysPlayed;

  WeeklyLeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.avatar,
    this.banner = 'none',
    required this.totalScore,
    required this.daysPlayed,
  });
}

/// Firestore'a skor yazma ve sıralama okuma işlemlerini yöneten servis.
///
/// Veri yapısı: leaderboards/{gameId}_{YYYY-MM-DD}
///   scores: { userId: { name, score, attempts, ... } }
///
/// Maliyet optimizasyonu:
///   - Tüm skorlar tek dokümanda (aggregated)
///   - SharedPreferences cache ile tekrar okuma yok
class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._();
  factory LeaderboardService() => _instance;
  LeaderboardService._();

  // İlk kullanımda alınır (Firebase başlatılmadan da servis oluşturulabilsin)
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  SharedPreferences? _prefs;
  final Map<String, _CacheEntry<dynamic>> _cache = {};

  // ─── Cache Keys ──────────────────────────────────────────────────
  static const String _userIdKey = 'leaderboard_user_id';
  static const String _displayNameKey = 'leaderboard_display_name';
  static const String _avatarKey = 'leaderboard_avatar';
  static const String _bannerKey = 'leaderboard_banner';
  // ─── Anonim İsim Havuzları ───────────────────────────────────────
  static const List<String> _adjectives = [
    'Crazy', 'Sleepy', 'Happy', 'Angry', 'Brave',
    'Sneaky', 'Lucky', 'Epic', 'Fast', 'Clever',
    'Wild', 'Chill', 'Funky', 'Cosmic', 'Magic',
    'Shiny', 'Dark', 'Golden', 'Hyper', 'Super',
  ];

  static const List<String> _nouns = [
    'Potato', 'Ninja', 'Panda', 'Dragon', 'Wizard',
    'Goblin', 'Cyborg', 'Pirate', 'Alien', 'Ghost',
    'Robot', 'Monkey', 'Unicorn', 'Vampire', 'Zombie',
    'Raccoon', 'Cactus', 'Banana', 'Tiger', 'Penguin',
  ];

  static const List<String> _avatars = [
    '🦊', '🐼', '🐨', '🐸', '🐱', '🐶', '🐰', '🐯', '🦁', '🐮', '🐷', '🐵', '🦉', '🦄', '🐙', '🐻', '🐧', '🐢', '🦖', '🐝'
  ];

  // ─── Init ────────────────────────────────────────────────────────
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _ensureUserIdentity();
  }

  /// Kullanıcı ID ve anonim isim oluşturulmuş mu kontrol et, yoksa oluştur.
  void _ensureUserIdentity() {
    if (_prefs == null) return;

    // User ID
    String? userId = _prefs!.getString(_userIdKey);
    if (userId == null) {
      userId = _generateUUID();
      _prefs!.setString(_userIdKey, userId);
    }

    // Display Name
    String? name = _prefs!.getString(_displayNameKey);
    // Eğer eski formattaysa (içinde # varsa) veya null ise yenisini üret.
    if (name == null || name.contains('#')) {
      name = _generateAnonymousName();
      _prefs!.setString(_displayNameKey, name);
    }

    // Avatar
    String? currentAvatar = _prefs!.getString(_avatarKey);
    if (currentAvatar == null) {
      final free = AvatarService.freeCharacters;
      currentAvatar = AvatarService.character(free[Random().nextInt(free.length)]);
      _prefs!.setString(_avatarKey, currentAvatar);
    }
  }

  /// Rastgele UUID oluştur.
  String _generateUUID() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    // RFC 4122 v4 UUID formatı
    values[6] = (values[6] & 0x0F) | 0x40;
    values[8] = (values[8] & 0x3F) | 0x80;
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Komik İngilizce isim oluştur (örn: "SleepyPotato").
  String _generateAnonymousName() {
    final random = Random();
    final adjective = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    return '$adjective$noun';
  }

  /// Mevcut kullanıcının ID'si.
  String get userId => _prefs?.getString(_userIdKey) ?? 'unknown';

  /// Mevcut kullanıcının görüntülenecek adı.
  String get displayName => _prefs?.getString(_displayNameKey) ?? 'Anonim';

  /// Mevcut kullanıcının avatarı.
  String get avatar => _prefs?.getString(_avatarKey) ?? '👤';

  /// Seçili profil banner'ı (BannerStyle.id)
  String get banner => _prefs?.getString(_bannerKey) ?? 'none';

  /// Banner değişir; sıralamaya bir sonraki skor gönderiminde yansır.
  Future<void> setBanner(String id) async {
    await _prefs?.setString(_bannerKey, id);
  }

  /// Coin ile açılan emoji avatarlar
  static List<String> get emojiAvatars => _avatars;

  /// Avatar değişir; sıralamaya bir sonraki skor gönderiminde yansır.
  Future<void> setAvatar(String value) async {
    await _prefs?.setString(_avatarKey, value);
  }

  // ─── Tarih Yardımcıları ──────────────────────────────────────────
  static String _dateKey([DateTime? date]) {
    final d = date ?? DailyRunService.turkeyNow;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ─── Skor Gönderme ──────────────────────────────────────────────
  /// Günlük oyun skorunu Firestore'a gönderir.
  /// Sadece daily mode'da çağrılmalı.
  Future<void> submitScore({
    required String gameId,
    required double score,
    int attempts = 0,
    int maxAttempts = 0,
    int? durationMs,
    bool isWin = true,
    String? dateKeyOverride,
  }) async {
    try {
      final dateKey = dateKeyOverride ?? _dateKey();
      final docId = '${gameId}_$dateKey';

      final entry = LeaderboardEntry(
        userId: userId,
        displayName: displayName,
        avatar: avatar,
        banner: banner,
        score: score,
        attempts: attempts,
        maxAttempts: maxAttempts,
        durationMs: durationMs,
        isWin: isWin,
      );

      // Günlük kayıt reddedilirse (o gün zaten yazılmışsa) haftalık puan da eklenmez
      final weekId = weekIdFor(gameId, dateKeyOverride == null ? DailyRunService.turkeyNow : DateTime.parse(dateKey));
      _commit([
        ('leaderboards/$docId/entries/$userId', entry.toMap()),
        ('weekly_leaderboards/$weekId/entries/$userId', _weeklyData(score)),
      ]);

      // Invalidate memory cache so new score shows up immediately
      _cache.remove('daily_leaderboard_${gameId}_$dateKey');
      final now = DailyRunService.turkeyNow;
      final weekNum = _isoWeekNumber(now);
      _cache.remove('weekly_leaderboard_${gameId}_${now.year}_w$weekNum');
      _cache.remove('rank_cache_${gameId}_$dateKey');

      debugPrint('LeaderboardService: Score submitted for $gameId');
    } catch (e) {
      debugPrint('LeaderboardService submitScore Error: $e');
    }
  }

  // ─── Sıralama Okuma ──────────────────────────────────────────────

  /// Günlük sıralama listesini getirir (yüksek skordan düşüğe).
  Future<List<LeaderboardEntry>> getDailyLeaderboard(String gameId, [String? date]) async {
    final dateKey = date ?? _dateKey();
    final cacheKey = 'daily_leaderboard_${gameId}_$dateKey';

    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return _cache[cacheKey]!.data as List<LeaderboardEntry>;
    }

    try {
      // Firestore'dan çek (Subcollection limit 50)
      final docId = '${gameId}_$dateKey';
      final querySnapshot = await _firestore
          .collection('leaderboards')
          .doc(docId)
          .collection('entries')
          .orderBy('score', descending: true)
          .orderBy('durationMs', descending: false)
          .limit(50)
          .get();

      if (querySnapshot.docs.isEmpty) return [];

      final list = querySnapshot.docs.map((doc) => 
        LeaderboardEntry.fromMap(doc.id, doc.data())
      ).toList();
      
      _cache[cacheKey] = _CacheEntry(list, DateTime.now());
      return list;
    } catch (e) {
      debugPrint('LeaderboardService getDailyLeaderboard Error: $e');
      return [];
    }
  }

  /// Kullanıcının sıralamasını bulur (Kendi skorundan yüksek olanların sayısı + aynı skorda olup daha hızlı olanların sayısı + 1).
  Future<int?> getUserRank(String gameId, double myScore, int? myDurationMs, [String? date]) async {
    final dateKey = date ?? _dateKey();
    try {
      final docId = '${gameId}_$dateKey';
      final entriesRef = _firestore
          .collection('leaderboards')
          .doc(docId)
          .collection('entries');
          
      // Benden yüksek skorlu olanlar
      final higherCount = await entriesRef
          .where('score', isGreaterThan: myScore)
          .count()
          .get();
          
      // Aynı puanda benden hızlı olanlar (tie-breaker)
      int sameScoreFaster = 0;
      if (myDurationMs != null) {
        final sameScoreFasterCount = await entriesRef
            .where('score', isEqualTo: myScore)
            .where('durationMs', isLessThan: myDurationMs)
            .count()
            .get();
        sameScoreFaster = sameScoreFasterCount.count ?? 0;
      }
      
      return (higherCount.count ?? 0) + sameScoreFaster + 1;
    } catch (e) {
      debugPrint('LeaderboardService getUserRank Error: $e');
      return null;
    }
  }

  /// Sıra ve toplam oyuncu sayısı (yüzdelik dilim için). Hata olursa null.
  Future<({int rank, int total})?> getStanding(String gameId, double myScore, int? myDurationMs, [String? date]) async {
    final dateKey = date ?? _dateKey();
    try {
      final rank = await getUserRank(gameId, myScore, myDurationMs, dateKey);
      if (rank == null) return null;
      final count = await _firestore
          .collection('leaderboards')
          .doc('${gameId}_$dateKey')
          .collection('entries')
          .count()
          .get();
      final total = count.count ?? 0;
      return (rank: rank, total: total < rank ? rank : total);
    } catch (e) {
      debugPrint('LeaderboardService getStanding Error: $e');
      return null;
    }
  }

  /// Belirli kullanıcıların günlük kayıtları (arkadaş sıralaması). Firestore
  /// `whereIn` sınırı nedeniyle 30'arlı gruplar halinde sorgulanır.
  Future<List<LeaderboardEntry>> getDailyEntriesForUsers(String gameId, List<String> userIds, [String? date]) async {
    final dateKey = date ?? _dateKey();
    final result = <LeaderboardEntry>[];
    try {
      final ref = _firestore.collection('leaderboards').doc('${gameId}_$dateKey').collection('entries');
      for (var i = 0; i < userIds.length; i += 30) {
        final chunk = userIds.sublist(i, min(i + 30, userIds.length));
        final snap = await ref.where(FieldPath.documentId, whereIn: chunk).get();
        result.addAll(snap.docs.map((d) => LeaderboardEntry.fromMap(d.id, d.data())));
      }
    } catch (e) {
      debugPrint('LeaderboardService getDailyEntriesForUsers Error: $e');
    }
    result.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : (a.durationMs ?? 0).compareTo(b.durationMs ?? 0);
    });
    return result;
  }

  /// Kullanıcının sırasını getirir (Cache kullanır).
  /// Geçmiş tarihler için SharedPreferences'a kalıcı olarak yazar.
  Future<int?> getCachedUserRank(String gameId, double myScore, int? myDurationMs, String date) async {
    if (_prefs == null) return null;
    
    final nowStr = _dateKey();
    final isPast = date != nowStr;
    final cacheKey = 'rank_cache_${gameId}_$date';

    // 1. Check SharedPreferences for past dates (kalıcı önbellek)
    if (isPast && _prefs!.containsKey(cacheKey)) {
      final cachedRank = _prefs!.getInt(cacheKey);
      if (cachedRank != null && cachedRank != -1) {
        return cachedRank;
      }
    }

    // 2. Check memory cache for today (geçici önbellek)
    if (!isPast && _cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return _cache[cacheKey]!.data as int?;
    }

    // 3. Fetch from Firestore (Sadece benden iyileri sayar = 1 read)
    final rank = await getUserRank(gameId, myScore, myDurationMs, date);

    if (rank != null && rank != -1) {
      if (isPast) {
        // Save permanently for past dates
        await _prefs!.setInt(cacheKey, rank);
      } else {
        // Save in memory for 5 minutes for today
        _cache[cacheKey] = _CacheEntry(rank, DateTime.now());
      }
    }
    return rank;
  }

  /// Mevcut kullanıcının günlük leaderboard kaydını getirir.
  Future<LeaderboardEntry?> getUserEntry(String gameId, [String? date]) async {
    final dateKey = date ?? _dateKey();
    try {
      final docId = '${gameId}_$dateKey';
      final doc = await _firestore
          .collection('leaderboards')
          .doc(docId)
          .collection('entries')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return LeaderboardEntry.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('LeaderboardService getUserEntry Error: $e');
      return null;
    }
  }

  /// Haftalık kullanıcının kendi skor bilgisini getirir.
  Future<WeeklyLeaderboardEntry?> getWeeklyUserEntry(String gameId) async {
    final now = DailyRunService.turkeyNow;
    final weekNum = _isoWeekNumber(now);
    final weekId = '${gameId}_${now.year}_w$weekNum';

    try {
      final doc = await _firestore
          .collection('weekly_leaderboards')
          .doc(weekId)
          .collection('entries')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return WeeklyLeaderboardEntry(
          userId: doc.id,
          displayName: data['name'] as String? ?? 'Anonim',
          avatar: data['avatar'] as String? ?? '👤',
          banner: data['banner'] as String? ?? 'none',
          totalScore: (data['totalScore'] as num?)?.toDouble() ?? 0.0,
          daysPlayed: data['daysPlayed'] as int? ?? 0,
        );
      }
      return null;
    } catch (e) {
      debugPrint('LeaderboardService getWeeklyUserEntry Error: $e');
      return null;
    }
  }

  /// Haftalık kullanıcının sırasını Firestore count() ile hesaplar.
  Future<int> getWeeklyUserRank(String gameId, double myTotalScore) async {
    final now = DailyRunService.turkeyNow;
    final weekNum = _isoWeekNumber(now);
    final weekId = '${gameId}_${now.year}_w$weekNum';

    try {
      final entriesRef = _firestore
          .collection('weekly_leaderboards')
          .doc(weekId)
          .collection('entries');

      // Benden yüksek skorlu olanlar
      final higherCount = await entriesRef
          .where('totalScore', isGreaterThan: myTotalScore)
          .count()
          .get();

      return (higherCount.count ?? 0) + 1;
    } catch (e) {
      debugPrint('LeaderboardService getWeeklyUserRank Error: $e');
      return -1;
    }
  }

  /// Haftalık sıralama listesini getirir.
  Future<List<WeeklyLeaderboardEntry>> getWeeklyLeaderboard(String gameId) async {
    final now = DailyRunService.turkeyNow;
    final weekNum = _isoWeekNumber(now);
    final weekId = '${gameId}_${now.year}_w$weekNum';
    final cacheKey = 'weekly_leaderboard_$weekId';

    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return _cache[cacheKey]!.data as List<WeeklyLeaderboardEntry>;
    }

    try {
      final snapshot = await _firestore
          .collection('weekly_leaderboards')
          .doc(weekId)
          .collection('entries')
          .orderBy('totalScore', descending: true)
          .limit(50)
          .get();

      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return WeeklyLeaderboardEntry(
          userId: doc.id,
          displayName: data['name'] as String? ?? 'Anonim',
          avatar: data['avatar'] as String? ?? '👤',
          banner: data['banner'] as String? ?? 'none',
          totalScore: (data['totalScore'] as num?)?.toDouble() ?? 0.0,
          daysPlayed: data['daysPlayed'] as int? ?? 0,
        );
      }).toList();
      
      _cache[cacheKey] = _CacheEntry(list, DateTime.now());
      return list;
    } catch (e) {
      debugPrint('LeaderboardService getWeeklyLeaderboard Error: $e');
      return [];
    }
  }

  // ─── Yardımcılar ─────────────────────────────────────────────────

  /// Testlerde internetsiz Firestore'u taklit eder
  @visibleForTesting
  static Future<void> Function(List<(String, Map<String, dynamic>)> writes)? commitOverride;

  /// Yazmaları tek işlemde gönderir ve onayı beklemez: internet yokken onay gelmez,
  /// bekleyen kod da takılır. Firestore işlemi telefonda kalıcı kuyruğa alır ve
  /// uygulama kapansa bile internet gelince bir kez gönderir.
  Future<void> _commit(List<(String, Map<String, dynamic>)> writes) {
    final override = commitOverride;
    if (override != null) return override(writes);
    final batch = _firestore.batch();
    for (final (path, data) in writes) {
      batch.set(_firestore.doc(path), data, SetOptions(merge: true));
    }
    return batch.commit().catchError((Object e) {
      debugPrint('LeaderboardService commit Error: $e');
    });
  }

  /// Haftalık kaydın FieldValue.increment ile güncellenen alanları
  Map<String, dynamic> _weeklyData(double score) => {
        'name': displayName,
        'avatar': avatar,
        'banner': banner,
        'totalScore': FieldValue.increment(score),
        'daysPlayed': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

  static String weekIdFor(String gameId, DateTime date) => '${gameId}_${date.year}_w${_isoWeekNumber(date)}';

  /// ISO-8601 hafta numarası hesaplama
  static int _isoWeekNumber(DateTime date) {
    final startOfYear = DateTime.utc(date.year, 1, 1);
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    final dayOfYear = utcDate.difference(startOfYear).inDays + 1;
    
    final woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (woy < 1) {
      final numOfDays = DateTime.utc(date.year - 1, 12, 31).difference(DateTime.utc(date.year - 1, 1, 1)).inDays + 1;
      return ((numOfDays - DateTime.utc(date.year - 1, 12, 31).weekday + 10) / 7).floor();
    } else if (woy > 52) {
      if (DateTime.utc(date.year, 12, 31).weekday < 4) {
        return 1;
      }
    }
    return woy;
  }

  /// Oyun tipine göre sıralama için birleşik skor hesaplar.
  ///
  /// Wordle/Nerdle: Az deneme + kısa süre = yüksek skor
  /// Skor oyunları: yüksek skor + kısa süre
  /// RGBle/Sound/Timele: Doğrudan score değeri
  static double calculateLeaderboardScore({
    required String gameId,
    required bool isWin,
    int attempts = 0,
    int maxAttempts = 0,
    double score = 0.0,
    int? durationMs,
  }) {
    if (!isWin && (gameId == 'wordle' || gameId == 'nerdle')) {
      return 0.0; // Kazanmayanlar 0 puan
    }

    switch (gameId) {
      case 'wordle':
      case 'nerdle':
        // Puan = (maxAttempts - attempts + 1) * 100 - süre bonusu
        // Böylece az denemede bilen daha yüksek puan alır
        final attemptScore = ((maxAttempts - attempts + 1) / maxAttempts) * 100;
        final timeBonus = durationMs != null ? (300000 - durationMs.clamp(0, 300000)) / 300000 * 10 : 0.0;
        return attemptScore + timeBonus;

      case 'rgble':
      case 'sound':
      case 'timele':
      case 'huedle':
      case 'memorle':
      case 'reactle':
      case 'quickle':
      case 'slicele':
      case 'stackle':
      case 'mirrorle':
      case 'anglele':
      case 'dropple':
      case 'icele':
      case 'countle':
      case 'balancele':
      case 'centerle':
      case 'mazele':
      case 'echole':
      case 'shadowle':
      case 'rotatle':
      case 'tempole':
      case 'fitle':
        // Doğrudan score değeri (0-100 arası)
        return score;

      default:
        return score;
    }
  }
}

