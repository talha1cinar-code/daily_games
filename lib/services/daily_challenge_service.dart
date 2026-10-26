import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_run_service.dart';
import 'language_service.dart';

/// Firestore'dan günlük oyun verilerini çeken ve cache'leyen servis.
///
/// Tüm oyunların günlük verileri tek bir Firestore dokümanında tutulur:
///   daily_challenges/{YYYY-MM-DD}
///
/// Aynı gün içinde tekrar Firestore'a gitmemek için SharedPreferences cache
/// kullanılır. Firebase'den veri çekilemezse null döner ve oyunlar kendi
/// fallback mekanizmalarını kullanır.
class DailyChallengeService {
  static final DailyChallengeService _instance = DailyChallengeService._();
  factory DailyChallengeService() => _instance;
  DailyChallengeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cache key prefix
  static const String _cacheKeyPrefix = 'daily_challenge_';

  /// Bugünün tarih string'i (TSİ — Türkiye Saati)
  static String _todayKey() {
    final now = DailyRunService.turkeyNow;
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Bugünün tüm challenge verisini çek (cache + Firestore)
  Future<Map<String, dynamic>?> _getTodayData() async {
    final dateKey = _todayKey();
    final cacheKey = '$_cacheKeyPrefix$dateKey';

    try {
      // 1. Önce cache'e bak
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        return json.decode(cached) as Map<String, dynamic>;
      }

      // 2. Cache'de yoksa Firestore'dan çek
      final doc = await _firestore
          .collection('daily_challenges')
          .doc(dateKey)
          .get()
          .timeout(const Duration(seconds: 3));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        // Cache'e yaz
        await prefs.setString(cacheKey, json.encode(data));
        // Eski günlerin cache'ini temizle
        await _cleanOldCache(prefs, dateKey);
        return data;
      }

      return null;
    } catch (e) {
      debugPrint('DailyChallengeService Error: $e');
      return null;
    }
  }

  /// Eski günlerin cache verilerini temizle
  Future<void> _cleanOldCache(SharedPreferences prefs, String currentKey) async {
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) && key != '$_cacheKeyPrefix$currentKey') {
        await prefs.remove(key);
      }
    }
  }

  // ─── Oyun Bazlı Getter Metodları ──────────────────────────────────

  /// Wordle: Günün kelimesi
  /// Returns: String? (örn: "KALEM")
  Future<String?> getWordleChallenge() async {
    final data = await _getTodayData();
    if (data == null) return null;
    final wordle = data['wordle'] as Map<String, dynamic>?;
    return wordle?['targetWord'] as String?;
  }

  /// Nerdle: Günün denklemi
  /// Returns: String? (örn: "48-36=12")
  Future<String?> getNerdleChallenge() async {
    final data = await _getTodayData();
    if (data == null) return null;
    final nerdle = data['nerdle'] as Map<String, dynamic>?;
    return nerdle?['equation'] as String?;
  }

  /// RGBle: Günün 5 hedef rengi
  /// Returns: `List<Color>?` (5 renk)
  Future<List<Color>?> getRgbleChallenge() async {
    final data = await _getTodayData();
    if (data == null) return null;
    final rgble = data['rgble'] as Map<String, dynamic>?;
    final colorHexList = rgble?['targetColors'] as List<dynamic>?;
    if (colorHexList == null || colorHexList.length != 5) return null;

    return colorHexList.map((hex) {
      final hexStr = (hex as String).replaceFirst('#', '');
      return Color(int.parse('FF$hexStr', radix: 16));
    }).toList();
  }

  /// Timele: Günün 5 hedef süresi (milisaniye)
  /// Returns: `List<int>?` (5 süre)
  Future<List<int>?> getTimeleChallenge() async {
    final data = await _getTodayData();
    if (data == null) return null;
    final timele = data['timele'] as Map<String, dynamic>?;
    final durations = timele?['targetDurations'] as List<dynamic>?;
    if (durations == null || durations.length != 5) return null;

    return durations.map((d) => (d as num).toInt()).toList();
  }

  /// Sound: Günün 5 hedef frekansı (Hz)
  /// Returns: `List<double>?` (5 frekans)
  Future<List<double>?> getSoundChallenge() async {
    final data = await _getTodayData();
    if (data == null) return null;
    final sound = data['sound'] as Map<String, dynamic>?;
    final frequencies = sound?['targetFrequencies'] as List<dynamic>?;
    if (frequencies == null || frequencies.length != 5) return null;

    return frequencies.map((f) => (f as num).toDouble()).toList();
  }

  /// Wikitrivia: Günün tarihi olayları
  /// Returns: `List<Map<String, dynamic>>?` (her biri {title: String, year: int})
  Future<List<Map<String, dynamic>>?> getWikitriviaChallenge() async {
    final data = await _getTodayData();
    if (data == null) return null;
    final wikitrivia = data['wikitrivia'] as Map<String, dynamic>?;
    final events = wikitrivia?['events'] as List<dynamic>?;
    if (events == null || events.isEmpty) return null;

    return events.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Worldle: Günün hedef ülke ISO kodu
  /// Returns: String? (örn: "TR")
  Future<String?> getWorldleChallenge() async {
    final data = await _getTodayData();
    if (data == null) return null;
    final worldle = data['worldle'] as Map<String, dynamic>?;
    return worldle?['targetCountryCode'] as String?;
  }

  // ═══════════════════════════════════════════════════════════════════
  // ─── Deterministik Seed Motoru ────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════

  /// Ayarlıysa tüm seed'ler tarih yerine buradan türetilir (düello turları).
  static int? seedOverride;

  /// Merkezi seed üreteci.
  /// Tarih (TSİ) + Slot (1/2) + GameId girdileriyle
  /// tüm kullanıcılara %100 aynı seed üretir.
  static int getDailyRunSeed(String gameId) {
    // Düello turu: iki rakip de aynı (düelloya özel) bulmacayı oynar
    final override = seedOverride;
    if (override != null) return override ^ stableHash(gameId);
    final t = DailyRunService.turkeyNow;
    final slot = DailyRunService.currentRunSlot();
    final dateInt = t.year * 10000 + t.month * 100 + t.day;
    return dateInt ^ (slot * 99991) ^ stableHash(gameId);
  }

  /// FNV-1a (32 bit). String.hashCode Dart sürümleri ve platformlar arasında
  /// aynı kalmayabilir; herkesin aynı bulmacayı görmesi için sabit hash şart.
  static int stableHash(String s) {
    var h = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  // ─── Oyun Bazlı Seed Tabanlı İçerik Üretimi ─────────────────────

  /// Wordle: Seed tabanlı kelime seçimi.
  /// [allWords] kelime listesi dışarıdan geçilir (WordleGame.allWords — dile göre).
  /// Seed dile göre de farklılaşır, böylece aynı dili oynayan kullanıcılar aynı kelimeyi görür.
  static String getSeededWordleWord(List<String> allWords) {
    if (allWords.isEmpty) return 'KELME';
    final lang = LanguageService().currentLanguage;
    final seed = getDailyRunSeed('wordle_$lang');
    final rng = Random(seed);
    return allWords[rng.nextInt(allWords.length)];
  }

  /// Nerdle: Seed tabanlı denklem seçimi.
  /// [allEquations] denklem listesi dışarıdan geçilir.
  static String getSeededNerdleEquation(List<String> allEquations) {
    if (allEquations.isEmpty) return '15+9*3=42';
    final seed = getDailyRunSeed('nerdle');
    final rng = Random(seed);
    return allEquations[rng.nextInt(allEquations.length)];
  }

  /// RGBle: Seed tabanlı 5 renk üretimi (HSV).
  static List<Color> getSeededRgbleColors() {
    final seed = getDailyRunSeed('rgble');
    final rng = Random(seed);
    return List.generate(5, (_) {
      return HSVColor.fromAHSV(
        1.0,
        rng.nextDouble() * 360,
        0.4 + rng.nextDouble() * 0.6,
        0.4 + rng.nextDouble() * 0.6,
      ).toColor();
    });
  }

  /// Timele: Seed tabanlı 5 süre üretimi (ms).
  static List<int> getSeededTimeleDurations() {
    final seed = getDailyRunSeed('timele');
    final rng = Random(seed);
    return List.generate(5, (_) {
      return 300 + rng.nextInt(6701); // 300 - 7000 ms
    });
  }

  /// Sound: Seed tabanlı 5 frekans üretimi (Hz).
  static List<double> getSeededSoundFrequencies() {
    final seed = getDailyRunSeed('sound');
    final rng = Random(seed);
    return List.generate(5, (_) {
      return 80.0 + rng.nextDouble() * 1120.0; // 80 - 1200 Hz
    });
  }

  /// Worldle: Seed tabanlı ülke seçimi.
  /// [allCountries] ülke listesi dışarıdan geçilir.
  static int getSeededWorldleIndex(int countryCount) {
    final seed = getDailyRunSeed('worldle');
    final rng = Random(seed);
    return rng.nextInt(countryCount);
  }

  /// Memorle: Seed döndürür (Random(seed) ile tüm seviyeler deterministik).
  static int getSeededMemorleSeed() {
    return getDailyRunSeed('memorle');
  }

  /// Huedle: Seed döndürür (Random(seed) ile tüm seviyeler deterministik).
  static int getSeededHuedleSeed() {
    return getDailyRunSeed('huedle');
  }

  /// Reactle: Seed tabanlı 5 gecikme süresi (1000-4000 ms).
  static List<int> getSeededReactleDelays() {
    final seed = getDailyRunSeed('reactle');
    final rng = Random(seed);
    return List.generate(5, (_) {
      return 1000 + rng.nextInt(3001); // 1000 - 4000 ms
    });
  }

  /// Quickle: Seed döndürür (soru dizisi bu seed'den üretilir).
  static int getSeededQuickleSeed() {
    return getDailyRunSeed('quickle');
  }

  /// Genel seed: yeni oyunlar oyun başına metod yerine bunu kullanır
  static int getSeededSeed(String gameId) => getDailyRunSeed(gameId);

  static int getSeededSliceleSeed() => getDailyRunSeed('slicele');
  static int getSeededStackleSeed() => getDailyRunSeed('stackle');
  static int getSeededMirrorleSeed() => getDailyRunSeed('mirrorle');

  /// Wikitrivia: Seed tabanlı olay shuffle.
  /// [allEvents] olay listesi dışarıdan geçilir.
  static List<T> getSeededWikitriviaEvents<T>(List<T> allEvents, {int take = 15}) {
    final seed = getDailyRunSeed('wikitrivia');
    final rng = Random(seed);
    final pool = List<T>.from(allEvents)..shuffle(rng);
    return pool.take(take).toList();
  }
}
