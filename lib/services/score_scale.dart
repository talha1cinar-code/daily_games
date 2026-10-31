/// Oyunların sıralama puanlarını (calculateLeaderboardScore) 0-100 aralığına çeker.
///
/// Oyunların ham ölçekleri farklı (Wordle 110, RGBle 30);
/// Daily Run toplamında her oyunun eşit ağırlıkta olması için kullanılır.
class ScoreScale {
  static const Map<String, double> _fullScore = {
    'wordle': 110,
    'nerdle': 110,
    'rgble': 30, // 3 tur × 10
    'sound': 40, // 4 tur × 10
    'timele': 40,
  };

  /// Eski puanlamada 1-10. seviyeyi bitirince ulaşılan toplamlar
  static const Map<String, List<int>> _oldLevelTotals = {
    'huedle': [10, 30, 60, 100, 150, 215, 295, 390, 500, 625],
    'memorle': [30, 63, 100, 150, 204, 261, 332, 406, 484, 575],
  };

  /// Puanı değişen seviye oyunları
  static Iterable<String> get levelGames => _oldLevelTotals.keys;

  /// Eski puanı yeni ölçeğe çevirir: bitirilen seviye x 10
  static double migrateLevelScore(String gameId, double oldScore) =>
      _oldLevelTotals[gameId]!.where((total) => oldScore >= total).length * 10.0;

  static double normalize(String gameId, double rawScore) {
    final full = _fullScore[gameId] ?? 100;
    return (rawScore / full * 100).clamp(0.0, 100.0);
  }

  /// Paylaşım kartı için tek karakterlik derece
  static String emoji(double normalized) {
    if (normalized >= 85) return '🟩';
    if (normalized >= 60) return '🟨';
    if (normalized >= 30) return '🟧';
    if (normalized > 0) return '🟥';
    return '⬛';
  }
}
