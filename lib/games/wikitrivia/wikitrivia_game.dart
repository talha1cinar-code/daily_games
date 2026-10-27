import 'dart:math';

/// Wikitrivia oyununun veri modeli ve mantığı
class HistoricalEvent {
  final String title;
  final int year;

  const HistoricalEvent({required this.title, required this.year});
}

enum PlacementResult { correct, incorrect }

class PlacementInfo {
  final PlacementResult result;

  /// Kartın zaman çizelgesine eklendiği (doğru) konum
  final int index;
  final HistoricalEvent event;

  const PlacementInfo({required this.result, required this.index, required this.event});

  bool get isCorrect => result == PlacementResult.correct;
}

/// Bir başlangıç kartı ve [deckSize] kartlık deste. Her kart zaman çizelgesindeki
/// iki olayın arasına konur; aynı yıllı olaylar hangi yandan konursa konsun doğrudur.
/// Yanlış konan kart da doğru yerine eklenir, can gider.
class WikitriviaGame {
  static const int deckSize = 10;
  static const int maxLives = 3;
  static const int pointsPerCard = 10; // 10 kart × 10 = 100

  /// Destedeki iki olay arasında en az bu kadar yıl olur (eşitlik ve aşırı yakın yıllar olmasın)
  static const int minGapYears = 3;

  final List<HistoricalEvent> timeline = [];
  final List<HistoricalEvent> _deck = [];
  int _next = 0;

  int correct = 0;
  int wrong = 0;

  WikitriviaGame(List<HistoricalEvent> pool, Random rng) {
    final picked = pickDeck(pool, rng, deckSize + 1);
    timeline.add(picked.first);
    _deck.addAll(picked.skip(1));
  }

  /// Havuzdan birbirine çok yakın olmayan yıllarda [count] olay seçer.
  static List<HistoricalEvent> pickDeck(List<HistoricalEvent> pool, Random rng, int count) {
    final shuffled = List<HistoricalEvent>.from(pool)..shuffle(rng);
    final out = <HistoricalEvent>[];
    bool fits(HistoricalEvent e) => out.every((o) => (o.year - e.year).abs() >= minGapYears);
    for (final e in shuffled) {
      if (out.length >= count) break;
      if (fits(e)) out.add(e);
    }
    // Havuz küçükse aralık şartı olmadan tamamla
    for (final e in shuffled) {
      if (out.length >= count) break;
      if (!out.contains(e)) out.add(e);
    }
    return out;
  }

  int get remainingLives => maxLives - wrong;
  int get placed => correct + wrong;
  int get deckTotal => _deck.length;
  int get score => correct * pointsPerCard;

  HistoricalEvent? get currentCard => isGameOver ? null : _deck[_next];

  bool get isGameOver => wrong >= maxLives || _next >= _deck.length;
  bool get isPerfect => correct == _deck.length;

  /// [slot] = 0 en eskinin önü, timeline.length en yeninin arkası
  bool fitsSlot(HistoricalEvent e, int slot) {
    final left = slot > 0 ? timeline[slot - 1].year : null;
    final right = slot < timeline.length ? timeline[slot].year : null;
    return (left == null || left <= e.year) && (right == null || e.year <= right);
  }

  int correctSlotFor(HistoricalEvent e) {
    var i = 0;
    while (i < timeline.length && timeline[i].year <= e.year) {
      i++;
    }
    return i;
  }

  PlacementInfo place(int slot) {
    final card = currentCard!;
    final ok = fitsSlot(card, slot);
    final index = ok ? slot : correctSlotFor(card);
    timeline.insert(index, card);
    ok ? correct++ : wrong++;
    _next++;
    return PlacementInfo(result: ok ? PlacementResult.correct : PlacementResult.incorrect, index: index, event: card);
  }

  static String formatYear(int year, bool tr) {
    if (year < 0) return tr ? 'MÖ ${-year}' : '${-year} BC';
    return '$year';
  }
}
