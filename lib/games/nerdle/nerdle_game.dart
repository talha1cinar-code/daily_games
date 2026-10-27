import 'dart:math';

/// Nerdle oyun mantığı — 9 karakterlik matematik denklemi
class NerdleGame {
  static const int equationLength = 9;
  static const int maxAttempts = 6;

  final String targetEquation;
  final List<List<String>> guesses = [];
  final List<List<LetterStatus>> guessStatuses = [];
  List<String> currentGuess = [];
  bool isGameOver = false;
  bool isWon = false;

  // Klavyedeki her karakterin durumu
  final Map<String, LetterStatus> keyStatuses = {};

  NerdleGame({required this.targetEquation})
    : assert(
        targetEquation.length == equationLength,
        'Equation "$targetEquation" has ${targetEquation.length} chars, expected $equationLength',
      );

  // ─── Günün denklemi (ileride Firebase'den gelecek) ───────────────
  static const List<String> _equations = [
    '15+9*3=42', // 15+27=42
    '3*9+13=40', // 27+13=40
    '72/9+2=10', // 8+2=10
    '11*7-2=75', // 77-2=75
    '5+36/6=11', // 5+6=11
    '81/9*4=36', // 9*4=36
    '25-3*4=13', // 25-12=13
    '63/9+4=11', // 7+4=11
    '14+9*2=32', // 14+18=32
    '56/7+3=11', // 8+3=11
    '12*4-9=39', // 48-9=39
    '99-7*8=43', // 99-56=43
    '45/9+6=11', // 5+6=11
    '18/3+7=13', // 6+7=13
    '6*8-13=35', // 48-13=35
    '48/6+9=17', // 8+9=17
    '27+6*4=51', // 27+24=51
    '36/4+8=17', // 9+8=17
    '7*9-18=45', // 63-18=45
    '54/6+7=16', // 9+7=16
  ];

  /// Denklem listesine erişim (seed motoru için)
  static List<String> get equations => _equations;

  static String getEquationOfTheDay() {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);
    return _equations[random.nextInt(_equations.length)];
  }

  /// Rastgele 9 karakterli matematiksel denklem üret (Biletli mod için)
  static String getRandomEquation() {
    final rng = Random();
    for (int i = 0; i < 500; i++) {
      final opType = rng.nextInt(5);
      String? equation;
      switch (opType) {
        case 0: // a+b=c  (iki basamaklı + iki basamaklı = iki/üç basamaklı)
          final a = rng.nextInt(90) + 10;
          final b = rng.nextInt(90) + 10;
          equation = '$a+$b=${a + b}';
          break;
        case 1: // a-b=c  (iki basamaklı - iki basamaklı)
          final a = rng.nextInt(80) + 20;
          final b = rng.nextInt(a - 10) + 10;
          equation = '$a-$b=${a - b}';
          break;
        case 2: // a*b-c=d veya a*b+c=d
          final a = rng.nextInt(9) + 2;
          final b = rng.nextInt(9) + 2;
          final product = a * b;
          final c = rng.nextInt(product.clamp(1, 99));
          final useAdd = rng.nextBool();
          if (useAdd) {
            equation = '$a*$b+$c=${product + c}';
          } else {
            equation = '$a*$b-$c=${product - c}';
          }
          break;
        case 3: // a/b+c=d
          final b = rng.nextInt(8) + 2;
          final quotient = rng.nextInt(9) + 2;
          final a = b * quotient;
          final c = rng.nextInt(9) + 1;
          equation = '$a/$b+$c=${quotient + c}';
          break;
        case 4: // a+b*c=d
          final b = rng.nextInt(9) + 2;
          final c = rng.nextInt(9) + 2;
          final a = rng.nextInt(90) + 1;
          equation = '$a+$b*$c=${a + b * c}';
          break;
      }
      if (equation != null && equation.length == equationLength) {
        return equation;
      }
    }
    return _equations[rng.nextInt(_equations.length)]; // Fallback
  }

  // ─── Kullanıcı girişi ────────────────────────────────────────────
  bool addCharacter(String char) {
    if (isGameOver) return false;
    if (currentGuess.length >= equationLength) return false;
    currentGuess.add(char);
    return true;
  }

  bool removeCharacter() {
    if (isGameOver) return false;
    if (currentGuess.isEmpty) return false;
    currentGuess.removeLast();
    return true;
  }

  // ─── Tahmin kontrolü ─────────────────────────────────────────────
  GuessResult submitGuess() {
    if (isGameOver) return GuessResult.gameOver;
    if (currentGuess.length != equationLength) {
      return GuessResult.notEnoughChars;
    }

    final guess = currentGuess.join();

    // = kontrolü
    if (!guess.contains('=')) return GuessResult.noEquals;
    final eqParts = guess.split('=');
    if (eqParts.length != 2) return GuessResult.invalidEquation;

    final leftSide = eqParts[0];
    final rightSide = eqParts[1];

    if (leftSide.isEmpty || rightSide.isEmpty) {
      return GuessResult.invalidEquation;
    }

    // Sağ taraf sayı mı kontrol et
    final rightValue = _tryParseNumber(rightSide);
    if (rightValue == null) return GuessResult.invalidEquation;

    // Sol tarafı hesapla
    final leftValue = _evaluateExpression(leftSide);
    if (leftValue == null) return GuessResult.invalidEquation;

    // Eşitlik kontrolü (floating point hassasiyeti)
    if ((leftValue - rightValue).abs() > 0.0001) {
      return GuessResult.wrongAnswer;
    }

    // Denklem geçerli — renkleri hesapla
    final statuses = _calculateStatuses(guess);
    guesses.add(List.from(currentGuess));
    guessStatuses.add(statuses);

    // Klavye durumlarını güncelle
    for (int i = 0; i < guess.length; i++) {
      final char = guess[i];
      final newStatus = statuses[i];
      final currentStatus = keyStatuses[char];

      if (currentStatus == null || _statusPriority(newStatus) > _statusPriority(currentStatus)) {
        keyStatuses[char] = newStatus;
      }
    }

    // Kazandı mı?
    if (guess == targetEquation) {
      isGameOver = true;
      isWon = true;
      currentGuess = [];
      return GuessResult.correct;
    }

    // Hak bitti mi?
    if (guesses.length >= maxAttempts) {
      isGameOver = true;
      isWon = false;
      currentGuess = [];
      return GuessResult.outOfAttempts;
    }

    currentGuess = [];
    return GuessResult.validGuess;
  }

  // ─── Renk hesaplama (Wordle algoritması) ──────────────────────────
  List<LetterStatus> _calculateStatuses(String guess) {
    final statuses = List.filled(equationLength, LetterStatus.absent);
    final targetChars = targetEquation.split('');
    final guessChars = guess.split('');
    final used = List.filled(equationLength, false);

    // 1. pas: doğru pozisyondakiler
    for (int i = 0; i < equationLength; i++) {
      if (guessChars[i] == targetChars[i]) {
        statuses[i] = LetterStatus.correct;
        used[i] = true;
      }
    }

    // 2. pas: yanlış pozisyondakiler
    for (int i = 0; i < equationLength; i++) {
      if (statuses[i] == LetterStatus.correct) continue;
      for (int j = 0; j < equationLength; j++) {
        if (!used[j] && guessChars[i] == targetChars[j]) {
          statuses[i] = LetterStatus.present;
          used[j] = true;
          break;
        }
      }
    }

    return statuses;
  }

  // ─── Matematiksel ifade değerlendiricisi ──────────────────────────
  /// İşlem önceliğine uygun expression evaluator
  static double? _evaluateExpression(String expr) {
    try {
      final tokens = _tokenize(expr);
      if (tokens == null) return null;
      return _parseExpression(tokens, 0, tokens.length);
    } catch (_) {
      return null;
    }
  }

  /// String'i token'lara ayır: sayılar ve operatörler
  static List<String>? _tokenize(String expr) {
    final tokens = <String>[];
    var i = 0;

    while (i < expr.length) {
      if ('+-*/'.contains(expr[i])) {
        // Negatif sayı kontrolü (başta veya operatörden sonra)
        if (expr[i] == '-' && (i == 0 || '+-*/'.contains(expr[i - 1]))) {
          // Negatif sayının parçası
          var num = '-';
          i++;
          while (i < expr.length && _isDigit(expr[i])) {
            num += expr[i];
            i++;
          }
          if (num == '-') return null; // Sadece - işareti
          tokens.add(num);
        } else {
          tokens.add(expr[i]);
          i++;
        }
      } else if (_isDigit(expr[i])) {
        var num = '';
        while (i < expr.length && _isDigit(expr[i])) {
          num += expr[i];
          i++;
        }
        tokens.add(num);
      } else {
        return null; // Geçersiz karakter
      }
    }

    return tokens;
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  /// Toplama/çıkarma seviyesi
  static double? _parseExpression(List<String> tokens, int start, int end) {
    if (start >= end) return null;

    // Önce çarpma/bölme yap, sonra toplama/çıkarma
    final numbers = <double>[];
    final operators = <String>[];

    var i = start;

    // İlk terimi oku
    if (i < end && double.tryParse(tokens[i]) != null) {
      numbers.add(double.parse(tokens[i]));
      i++;
    } else {
      return null;
    }

    // Kalan terimleri oku
    while (i < end) {
      if (i >= end) break;
      final op = tokens[i];
      if (!'+-*/'.contains(op)) return null;
      i++;

      if (i >= end) return null;
      final num = double.tryParse(tokens[i]);
      if (num == null) return null;
      i++;

      // * ve / hemen hesapla (öncelikli)
      if (op == '*' || op == '/') {
        if (op == '/' && num == 0) return null; // 0'a bölme
        final prev = numbers.removeLast();
        numbers.add(op == '*' ? prev * num : prev / num);
      } else {
        operators.add(op);
        numbers.add(num);
      }
    }

    // Şimdi + ve - hesapla
    var result = numbers[0];
    for (var j = 0; j < operators.length; j++) {
      if (operators[j] == '+') {
        result += numbers[j + 1];
      } else {
        result -= numbers[j + 1];
      }
    }

    return result;
  }

  static double? _tryParseNumber(String s) {
    return double.tryParse(s);
  }

  int _statusPriority(LetterStatus status) {
    switch (status) {
      case LetterStatus.correct:
        return 3;
      case LetterStatus.present:
        return 2;
      case LetterStatus.absent:
        return 1;
      case LetterStatus.empty:
        return 0;
    }
  }
}

enum LetterStatus { empty, absent, present, correct }

enum GuessResult {
  correct,
  validGuess,
  notEnoughChars,
  noEquals,
  invalidEquation,
  wrongAnswer,
  outOfAttempts,
  gameOver,
}
