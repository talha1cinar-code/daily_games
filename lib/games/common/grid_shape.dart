/// Izgara üzerindeki 2B şekil yardımcıları (Shadowle, Rotatle).
/// Şekil: (sütun, satır) hücre kümesi.
typedef Cells = Set<(int, int)>;

class GridShape {
  /// Sol üst köşeye kaydırır
  static Cells normalize(Cells s) {
    final minC = s.map((e) => e.$1).reduce((a, b) => a < b ? a : b);
    final minR = s.map((e) => e.$2).reduce((a, b) => a < b ? a : b);
    return {for (final (c, r) in s) (c - minC, r - minR)};
  }

  /// 90° saat yönünde döndürür
  static Cells rotate(Cells s) => normalize({for (final (c, r) in s) (-r, c)});

  /// Yatay ayna
  static Cells mirror(Cells s) => normalize({for (final (c, r) in s) (-c, r)});

  static Cells rotateTimes(Cells s, int k) {
    var out = normalize(s);
    for (var i = 0; i < k % 4; i++) {
      out = rotate(out);
    }
    return out;
  }

  static String key(Cells s) {
    final l = normalize(s).toList()..sort((a, b) => a.$2 != b.$2 ? a.$2 - b.$2 : a.$1 - b.$1);
    return l.map((e) => '${e.$1},${e.$2}').join(';');
  }

  /// Dönme ve aynalamadan bağımsız kimlik (8 simetrinin en küçüğü)
  static String canonical(Cells s) {
    final keys = <String>[
      for (var k = 0; k < 4; k++) key(rotateTimes(s, k)),
      for (var k = 0; k < 4; k++) key(rotateTimes(mirror(s), k)),
    ]..sort();
    return keys.first;
  }

  /// Yalnızca dönmeden bağımsız kimlik
  static String rotationCanonical(Cells s) {
    final keys = [for (var k = 0; k < 4; k++) key(rotateTimes(s, k))]..sort();
    return keys.first;
  }

  static bool isConnected(Cells s) {
    if (s.isEmpty) return false;
    final seen = <(int, int)>{s.first};
    final stack = [s.first];
    while (stack.isNotEmpty) {
      final (c, r) = stack.removeLast();
      for (final n in [(c + 1, r), (c - 1, r), (c, r + 1), (c, r - 1)]) {
        if (s.contains(n) && seen.add(n)) stack.add(n);
      }
    }
    return seen.length == s.length;
  }
}
