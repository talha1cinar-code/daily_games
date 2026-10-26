import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'achievement_service.dart';
import 'streak_service.dart';
import 'coin_service.dart';
import 'score_scale.dart';

class PersonalBestResult {
  final String gameId;
  final double score;
  final double? previousBest;
  final int coins;

  const PersonalBestResult(this.gameId, this.score, this.previousBest, this.coins);

  bool get isFirst => previousBest == null;
  bool get isNewBest => previousBest != null && score > previousBest!;
}

/// Oyun başına en iyi skoru (sıralama puanı cinsinden) tutar.
/// Hem bilet modu hem Daily Run skorları sayılır.
class PersonalBestService extends ChangeNotifier {
  static final PersonalBestService _instance = PersonalBestService._internal();
  factory PersonalBestService() => _instance;
  PersonalBestService._internal();

  static const String _prefix = 'pb_';
  SharedPreferences? _prefs;
  PersonalBestResult? _lastResult;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  double? best(String gameId) => _prefs?.getDouble('$_prefix$gameId');

  Set<String> get playedGames => {
        for (final k in _prefs?.getKeys() ?? <String>{})
          if (k.startsWith(_prefix)) k.substring(_prefix.length),
      };

  /// Skoru kaydeder. [announce] true ise oyunlar ekranı dönüşte sonucu gösterir.
  PersonalBestResult submit(String gameId, double score, {bool announce = true}) {
    final prev = best(gameId);
    // Her bitirilen oyun skora göre 5-10 coin kazandırır
    final coins = CoinService.gameReward(ScoreScale.normalize(gameId, score));
    CoinService().earn(coins, 'game');
    final result = PersonalBestResult(gameId, score, prev, coins);
    if (prev == null || score > prev) {
      _prefs?.setDouble('$_prefix$gameId', score);
      notifyListeners();
    }
    if (announce) _lastResult = result;
    AchievementService().onGameScore(gameId, score, playedGames);
    // Günde bir oyun bitirmek seriyi uzatır (Daily Run ya da biletli)
    StreakService().recordActivity();
    return result;
  }

  /// Son bilet modu sonucunu bir kez döndürür.
  PersonalBestResult? takeLastResult() {
    final r = _lastResult;
    _lastResult = null;
    return r;
  }
}
