import 'dart:math';

enum DuelResult { win, loss, draw }

/// Düello: iki oyuncu aynı 3 oyunu aynı seed ile, birbirini beklemeden oynar.
/// Skorlar 0-100'e normalize edilmiştir. Firestore: `duels/{id}`.
class Duel {
  static const int rounds = 3;
  static const Duration timeout = Duration(hours: 24);

  /// Düelloda çıkabilecek kısa, seed'li oyunlar
  static const List<String> gamePool = [
    'reactle', 'quickle', 'slicele', 'stackle', 'mirrorle', 'anglele',
    'dropple', 'icele', 'huedle', 'timele', 'rgble', 'memorle', 'countle', 'balancele',
    'centerle', 'mazele', 'echole', 'shadowle', 'rotatle',
  ];

  final String id;
  final List<String> players;
  final List<String> games;
  final int seed;
  final Map<String, String> names;
  final Map<String, String> avatars;
  final Map<String, String> banners;

  /// oyuncu → (tur → skor)
  final Map<String, Map<int, double>> scores;
  final String status; // active | done
  final String? winner; // oyuncu id'si; beraberlikte 'draw'
  final DateTime updatedAt;

  const Duel({
    required this.id,
    required this.players,
    required this.games,
    required this.seed,
    required this.names,
    required this.avatars,
    required this.banners,
    required this.scores,
    required this.status,
    required this.winner,
    required this.updatedAt,
  });

  static List<String> pickGames(Random rng) => (List<String>.from(gamePool)..shuffle(rng)).take(rounds).toList();

  /// Sunucuya henüz ulaşmamış kendi skorlarımı ekleyerek kopya üretir
  Duel withMyScores(String me, Map<int, double> extra) => Duel(
        id: id,
        players: players,
        games: games,
        seed: seed,
        names: names,
        avatars: avatars,
        banners: banners,
        scores: {...scores, me: {...?scores[me], ...extra}},
        status: status,
        winner: winner,
        updatedAt: updatedAt,
      );

  /// Bir turun seed'i: düelloya özgü, iki oyuncuda aynı
  int roundSeed(int round) => seed + round * 7919;

  bool get isDone => status == 'done';
  String opponentOf(String me) => players.firstWhere((p) => p != me, orElse: () => '');
  int playedBy(String id) => scores[id]?.length ?? 0;
  bool finishedBy(String id) => playedBy(id) >= rounds;
  bool get bothFinished => players.every(finishedBy);
  bool isMyTurn(String me) => !isDone && !finishedBy(me);
  bool get isExpired => !isDone && DateTime.now().difference(updatedAt) > timeout;

  /// Rakibin bir turdaki skoru, ben o turu oynayana kadar gizli kalır
  double? visibleOpponentScore(String me, int round) {
    if (!(scores[me]?.containsKey(round) ?? false) && !isDone) return null;
    return scores[opponentOf(me)]?[round];
  }

  /// Tur galibiyetleri: (benim, rakibin)
  (int, int) roundWins(String me) {
    final opp = opponentOf(me);
    var mine = 0, theirs = 0;
    for (var r = 0; r < rounds; r++) {
      final a = scores[me]?[r], b = scores[opp]?[r];
      if (a == null || b == null) continue;
      if (a > b) mine++;
      if (b > a) theirs++;
    }
    return (mine, theirs);
  }

  double totalOf(String id) => (scores[id]?.values ?? const <double>[]).fold(0.0, (a, b) => a + b);

  /// İki oyuncu da bitirdiyse kazanan: önce tur sayısı, eşitse toplam skor
  static String? decideWinner(Duel d) {
    if (!d.bothFinished) return null;
    final a = d.players[0], b = d.players[1];
    final (wa, wb) = d.roundWins(a);
    if (wa != wb) return wa > wb ? a : b;
    final ta = d.totalOf(a), tb = d.totalOf(b);
    if ((ta - tb).abs() < 0.01) return 'draw';
    return ta > tb ? a : b;
  }

  /// Süresi dolan düello: turlarını bitiren kazanır; ikisi de bitirmediyse berabere
  static String decideExpired(Duel d) {
    final fa = d.finishedBy(d.players[0]), fb = d.finishedBy(d.players[1]);
    if (fa && !fb) return d.players[0];
    if (fb && !fa) return d.players[1];
    return decideWinner(d) ?? 'draw';
  }

  DuelResult? resultFor(String me) {
    if (!isDone || winner == null) return null;
    if (winner == 'draw') return DuelResult.draw;
    return winner == me ? DuelResult.win : DuelResult.loss;
  }

  factory Duel.fromMap(String id, Map<String, dynamic> m) {
    Map<String, String> strMap(String k) =>
        (m[k] as Map<String, dynamic>? ?? {}).map((key, v) => MapEntry(key, v as String));
    final rawScores = m['scores'] as Map<String, dynamic>? ?? {};
    final updated = m['updatedAt'];
    return Duel(
      id: id,
      players: (m['players'] as List<dynamic>).cast<String>(),
      games: (m['games'] as List<dynamic>).cast<String>(),
      seed: m['seed'] as int,
      names: strMap('names'),
      avatars: strMap('avatars'),
      banners: strMap('banners'),
      scores: rawScores.map((player, rs) => MapEntry(
            player,
            (rs as Map<String, dynamic>).map((r, v) => MapEntry(int.parse(r), (v as num).toDouble())),
          )),
      status: m['status'] as String? ?? 'active',
      winner: m['winner'] as String?,
      updatedAt: updated is DateTime ? updated : (updated?.toDate() as DateTime?) ?? DateTime.now(),
    );
  }
}

/// Kupa ligi
class DuelLeague {
  final String nameTr;
  final String nameEn;
  final int minTrophies;
  final int color;

  const DuelLeague(this.nameTr, this.nameEn, this.minTrophies, this.color);

  static const List<DuelLeague> all = [
    DuelLeague('Bronz', 'Bronze', 0, 0xFFD7A26C),
    DuelLeague('Gümüş', 'Silver', 150, 0xFFCFD8DC),
    DuelLeague('Altın', 'Gold', 400, 0xFFFFD54F),
    DuelLeague('Elmas', 'Diamond', 800, 0xFF6FD6FF),
    DuelLeague('Usta', 'Master', 1500, 0xFFB66DFF),
  ];

  static DuelLeague of(int trophies) => all.lastWhere((l) => trophies >= l.minTrophies);

  /// Bir sonraki lig (Usta'da null)
  static DuelLeague? next(int trophies) {
    final i = all.indexOf(of(trophies));
    return i + 1 < all.length ? all[i + 1] : null;
  }
}

/// Düello ödülleri
class DuelRewards {
  static const int winTrophies = 30, drawTrophies = 10, lossTrophies = -15;
  static const int winCoins = 20, drawCoins = 8, lossCoins = 3;

  static (int trophies, int coins) of(DuelResult r) => switch (r) {
        DuelResult.win => (winTrophies, winCoins),
        DuelResult.draw => (drawTrophies, drawCoins),
        DuelResult.loss => (lossTrophies, lossCoins),
      };
}
