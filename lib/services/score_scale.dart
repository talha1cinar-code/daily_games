/// Oyunların sıralama puanlarını (calculateLeaderboardScore) 0-100 aralığına çeker.
///
/// Oyunların ham ölçekleri çok farklı (Wikitrivia ~12, RGBle 50, Huedle sınırsız);
/// Daily Run toplamında her oyunun eşit ağırlıkta olması için kullanılır.
class ScoreScale {
  static const Map<String, double> _fullScore = {
    'wordle': 110,
    'nerdle': 110,
    'worldle': 110,
    'wikitrivia': 12,
    'rgble': 30, // 3 tur × 10
    'sound': 40, // 4 tur × 10
    'timele': 40,
    'huedle': 700, // ~10. seviye
    'memorle': 600, // ~10. seviye
  };

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
