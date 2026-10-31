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

  /// Puanı değişen seviye oyunları
  static const List<String> levelGames = ['huedle', 'memorle'];

  /// Eski puanlamada bir seviyenin değeri
  static int _oldLevelPoints(String gameId, int level) {
    if (gameId == 'huedle') return level <= 5 ? level * 10 : 50 + (level - 5) * 15;
    final digits = level <= 3 ? 3 : (level <= 6 ? 4 : (level <= 9 ? 5 : (level <= 12 ? 6 : 7)));
    final showMs = (650 - (level - 1) * 35).clamp(200, 650);
    return digits * 10 + (650 - showMs) ~/ 10;
  }

  /// Eski puanı yeni ölçeğe çevirir: bitirilen seviye x 10
  static double migrateLevelScore(String gameId, double oldScore) {
    var levels = 0;
    var total = 0;
    while (true) {
      total += _oldLevelPoints(gameId, levels + 1);
      if (total > oldScore) return levels * 10.0;
      levels++;
    }
  }

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
