import 'dart:math';
import '../common/grid_shape.dart';

typedef Voxel = (int, int, int);

/// Hangi yönden bakılıyor: üstten (z), önden (+y tarafından), yandan (+x tarafından)
enum ShadowView { top, front, side }

class ShadowRound {
  final Set<Voxel> voxels;
  final ShadowView view;
  final List<Cells> options;
  final int answer;

  const ShadowRound(this.voxels, this.view, this.options, this.answer);
}

/// Shadowle: küplerden oluşan bir cisme ok yönünden bakınca görülen silüeti seç.
/// 5 tur, doğru cevap 20 puan.
class ShadowleGame {
  static const int totalRounds = 5;
  static const double roundScore = 20;
  static const int n = 3;

  static const _plan = [
    (ShadowView.top, 5),
    (ShadowView.front, 6),
    (ShadowView.side, 6),
    (ShadowView.front, 8),
    (ShadowView.side, 9),
  ];

  final List<ShadowRound> rounds;

  ShadowleGame(Random rng) : rounds = [for (final (v, k) in _plan) _make(rng, v, k)];

  /// Bakılan yönden görülen silüet; sütun izleyicinin sağına, satır aşağıya doğru artar
  static Cells project(Set<Voxel> vox, ShadowView view) {
    switch (view) {
      case ShadowView.top:
        return {for (final (x, y, _) in vox) (x, y)};
      case ShadowView.front:
        // +y'den -y'ye bakan göz: sağ taraf -x
        return {for (final (x, _, z) in vox) (n - 1 - x, n - 1 - z)};
      case ShadowView.side:
        // +x'ten -x'e bakan göz: sağ taraf +y
        return {for (final (_, y, z) in vox) (y, n - 1 - z)};
    }
  }

  /// Ekrandaki izometrik çizimde (göz +x,+y,+z yönünde) her küpün en az bir yüzünün
  /// ortası görünür mü? Arkada tamamen gizli kalan bir küp silüeti değiştirebilir ama
  /// oyuncu onu göremez; o zaman yanlış görünen şık doğru çıkar.
  static bool allVisible(Set<Voxel> vox) {
    bool seen(double px, double py, double pz, Voxel self) {
      for (final v in vox) {
        if (v == self) continue;
        // Işın p + t(1,1,1) küpü [v, v+1] keser mi?
        final lo = [v.$1 - px, v.$2 - py, v.$3 - pz];
        final tMin = lo.reduce(max);
        final tMax = lo.map((e) => e + 1).reduce(min);
        if (tMax > 1e-6 && tMin < tMax - 1e-6) return false;
      }
      return true;
    }

    for (final v in vox) {
      final (x, y, z) = v;
      final visible = seen(x + 0.5, y + 0.5, z + 1.0, v) || // üst yüz
          seen(x + 1.0, y + 0.5, z + 0.5, v) || // +x yüzü
          seen(x + 0.5, y + 1.0, z + 0.5, v); // +y yüzü
      if (!visible) return false;
    }
    return true;
  }

  /// Her küp yere ya da başka bir küpün üstüne oturur ve cisim bütündür
  static Set<Voxel> _shape(Random rng, int count) {
    final vox = <Voxel>{(1, 1, 0)};
    var guard = 0;
    while (vox.length < count && guard++ < 1000) {
      final (x, y, z) = vox.elementAt(rng.nextInt(vox.length));
      final d = const [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1)][rng.nextInt(5)];
      final v = (x + d.$1, y + d.$2, z + d.$3);
      if ([v.$1, v.$2, v.$3].any((c) => c < 0 || c >= n)) continue;
      if (v.$3 > 0 && !vox.contains((v.$1, v.$2, v.$3 - 1))) continue;
      vox.add(v);
    }
    return vox;
  }

  static ShadowRound _make(Random rng, ShadowView view, int count) {
    while (true) {
      final vox = _shape(rng, count);
      if (!allVisible(vox)) continue;
      final correct = project(vox, view);
      // Silüet tek kare ya da düz bir şerit olmasın; biraz düşündürsün
      if (correct.length < 3) continue;
      final wrong = <Cells>[];
      final seen = {GridShape.canonical(correct)};
      // Önce diğer yönlerin silüetleri, sonra bir hücresi eklenmiş/çıkarılmış halleri
      for (final other in ShadowView.values.where((v) => v != view)) {
        final p = project(vox, other);
        if (seen.add(GridShape.canonical(p))) wrong.add(p);
      }
      var guard = 0;
      while (wrong.length < 3 && guard++ < 200) {
        final c = rng.nextInt(n), r = rng.nextInt(n);
        final m = Set.of(correct);
        m.contains((c, r)) ? m.remove((c, r)) : m.add((c, r));
        if (m.length < 2 || !GridShape.isConnected(m)) continue;
        if (seen.add(GridShape.canonical(m))) wrong.add(m);
      }
      if (wrong.length < 3) continue;
      final options = [correct, ...wrong.take(3)]..shuffle(rng);
      return ShadowRound(vox, view, options, options.indexOf(correct));
    }
  }
}
