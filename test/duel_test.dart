import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/models/duel.dart';
import 'package:daily_games/models/game_model.dart';

Duel _duel(Map<String, Map<int, double>> scores, {String status = 'active', String? winner, DateTime? updated}) {
  return Duel(
    id: 'd1',
    players: const ['a', 'b'],
    games: const ['reactle', 'quickle', 'slicele'],
    seed: 42,
    names: const {'a': 'A', 'b': 'B'},
    avatars: const {},
    banners: const {},
    scores: scores,
    status: status,
    winner: winner,
    updatedAt: updated ?? DateTime.now(),
  );
}

void main() {
  test('düello oyunları havuzdan, tekrarsız ve oyun listesinde var', () {
    final ids = games.map((g) => g.id).toSet();
    for (var seed = 0; seed < 30; seed++) {
      final picked = Duel.pickGames(Random(seed));
      expect(picked.toSet().length, Duel.rounds);
      expect(ids, containsAll(picked));
    }
  });

  test('tur sayısı fazla olan kazanır', () {
    final d = _duel({
      'a': {0: 90, 1: 10, 2: 80},
      'b': {0: 50, 1: 99, 2: 70},
    });
    expect(Duel.decideWinner(d), 'a');
  });

  test('turlar eşitse toplam skor belirler, o da eşitse berabere', () {
    final d = _duel({
      'a': {0: 90, 1: 50, 2: 60},
      'b': {0: 50, 1: 90, 2: 60},
    });
    expect(Duel.decideWinner(d), 'draw');
    final e = _duel({
      'a': {0: 90, 1: 50, 2: 61},
      'b': {0: 50, 1: 95, 2: 61},
    });
    expect(Duel.decideWinner(e), 'b');
  });

  test('ikisi de bitirmeden kazanan yok', () {
    expect(Duel.decideWinner(_duel({'a': {0: 1, 1: 2, 2: 3}, 'b': {0: 1}})), isNull);
  });

  test('rakip skoru, ben o turu oynayana kadar gizli', () {
    final d = _duel({'b': {0: 70}});
    expect(d.visibleOpponentScore('a', 0), isNull);
    final e = _duel({'a': {0: 40}, 'b': {0: 70}});
    expect(e.visibleOpponentScore('a', 0), 70);
  });

  test('süresi dolan düelloda turlarını bitiren kazanır', () {
    final d = _duel({'a': {0: 1, 1: 1, 2: 1}, 'b': {0: 99}}, updated: DateTime.now().subtract(const Duration(hours: 49)));
    expect(d.isExpired, isTrue);
    expect(Duel.decideExpired(d), 'a');
  });

  test('lig eşikleri ve ödüller', () {
    expect(DuelLeague.of(0).nameTr, 'Bronz');
    expect(DuelLeague.of(150).nameTr, 'Gümüş');
    expect(DuelLeague.of(5000).nameTr, 'Usta');
    expect(DuelLeague.next(5000), isNull);
    expect(DuelRewards.of(DuelResult.win), (30, 40));
    expect(DuelRewards.of(DuelResult.loss).$1, lessThan(0));
  });

  test('sonuç oyuncuya göre yorumlanır', () {
    final d = _duel({}, status: 'done', winner: 'b');
    expect(d.resultFor('a'), DuelResult.loss);
    expect(d.resultFor('b'), DuelResult.win);
    expect(_duel({}, status: 'done', winner: 'draw').resultFor('a'), DuelResult.draw);
  });
}
