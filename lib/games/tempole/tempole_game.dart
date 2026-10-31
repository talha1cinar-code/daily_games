import 'dart:math';

enum TempoRoundType {
  /// Duyduğun ritmi aynen tekrar et
  repeat,

  /// Duyduğun sabit tempoyu, sesi kesildikten sonra sen sürdür
  keep,
}

class TempoRound {
  final TempoRoundType type;

  /// Dinlenen vuruşların ms cinsinden zamanları (ilki 0)
  final List<int> listen;

  /// Oyuncunun dokunması gereken zamanlar (ilki 0)
  final List<int> target;

  const TempoRound(this.type, this.listen, this.target);
}

/// Tempole: ritmi dinle, dokunarak tekrar et. Süre ilk dokunuştan başlar; böylece
/// tepki süresi ve ses gecikmesi puanı etkilemez, yalnızca vuruşlar arası zamanlama sayılır.
/// 5 tur, tur başına en fazla 20 puan.
class TempoleGame {
  static const int totalRounds = 5;
  static const double maxRoundScore = 20;

  /// Bu sapmaya kadar tam puan (insan dokunuşu da kusursuz değildir)
  static const int perfectMs = 60;

  /// Bu sapmada puan biter. Tempo korurken hata birikir, o yüzden daha toleranslı.
  static int zeroMs(TempoRoundType type) => type == TempoRoundType.keep ? 360 : 260;

  static const int _keepListenBeats = 4;
  static const int _keepTapBeats = 8;

  final List<TempoRound> rounds;

  TempoleGame(Random rng)
    : rounds = [
        _keep(600),
        _repeat(rng, beats: 5, stepMs: 300),
        _keep(450),
        _repeat(rng, beats: 6, stepMs: 260),
        _repeat(rng, beats: 7, stepMs: 240),
      ];

  static TempoRound _keep(int intervalMs) => TempoRound(
    TempoRoundType.keep,
    [for (var i = 0; i < _keepListenBeats; i++) i * intervalMs],
    [for (var i = 0; i < _keepTapBeats; i++) i * intervalMs],
  );

  /// Aralıklar 1-3 adım; en az iki farklı aralık olur ki sabit tempo gibi duyulmasın
  static TempoRound _repeat(Random rng, {required int beats, required int stepMs}) {
    late List<int> gaps;
    do {
      gaps = [for (var i = 0; i < beats - 1; i++) 1 + rng.nextInt(3)];
    } while (gaps.toSet().length < 2);
    final offsets = <int>[0];
    for (final g in gaps) {
      offsets.add(offsets.last + g * stepMs);
    }
    return TempoRound(TempoRoundType.repeat, offsets, offsets);
  }

  /// Dokunuşların ilk dokunuşa göre zamanları
  static List<int> relative(List<int> taps) => taps.isEmpty ? const [] : [for (final t in taps) t - taps.first];

  /// Ortalama sapma (ms). İlk vuruş referans olduğu için sayılmaz; eksik vuruşlar
  /// en büyük sapma kadar ceza alır. Hiç dokunulmadıysa null.
  static double? averageError(TempoRound round, List<int> taps) {
    if (taps.isEmpty) return null;
    final rel = relative(taps);
    final zero = zeroMs(round.type);
    var sum = 0.0;
    for (var i = 1; i < round.target.length; i++) {
      sum += i < rel.length ? (rel[i] - round.target[i]).abs() : zero;
    }
    return sum / (round.target.length - 1);
  }

  static double roundScore(TempoRound round, List<int> taps) {
    final error = averageError(round, taps);
    if (error == null) return 0;
    final zero = zeroMs(round.type);
    if (error <= perfectMs) return maxRoundScore;
    if (error >= zero) return 0;
    return maxRoundScore * (zero - error) / (zero - perfectMs);
  }
}
