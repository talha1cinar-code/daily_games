import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../services/language_service.dart';

/// Wordle oyununun tüm mantığını yöneten sınıf
class WordleGame {
  static List<String> _allWordsTr = [];
  static List<String> _allWordsEn = [];
  static bool _isLoadedTr = false;
  static bool _isLoadedEn = false;

  final String targetWord;
  final List<List<String>> guesses = [];
  final List<List<LetterStatus>> guessStatuses = [];
  List<String> currentGuess = [];
  bool isGameOver = false;
  bool isWon = false;
  int maxAttempts = 6;
  int wordLength = 5;

  // Klavyedeki harflerin durumları
  final Map<String, LetterStatus> keyboardStatuses = {};

  WordleGame({required this.targetWord});

  // Türkçe alfabe karakterleri
  static final RegExp _turkishLetters = RegExp(r'^[A-ZÇĞIİÖŞÜ]+$');
  // İngilizce alfabe karakterleri
  static final RegExp _englishLetters = RegExp(r'^[A-Z]+$');

  /// Aktif dildeki kelime listesine erişim
  static List<String> get allWords =>
      LanguageService().isTurkish ? _allWordsTr : _allWordsEn;

  /// JSON dosyasından kelimeleri yükle (dile göre)
  static Future<void> loadWords() async {
    final lang = LanguageService().currentLanguage;

    if (lang == 'tr') {
      await _loadTurkishWords();
    } else {
      await _loadEnglishWords();
    }
  }

  /// Türkçe kelimeleri yükle
  static Future<void> _loadTurkishWords() async {
    if (_isLoadedTr) return;

    final String jsonString =
        await rootBundle.loadString('assets/words/turkish_5_letter_words.json');
    final List<dynamic> jsonList = json.decode(jsonString);

    _allWordsTr = jsonList
        .cast<String>()
        .map((w) => _normalizeTurkish(w.trim()))
        .where((w) => w.length == 5 && _turkishLetters.hasMatch(w))
        .toSet()
        .toList();

    _isLoadedTr = true;
  }

  /// İngilizce kelimeleri yükle
  static Future<void> _loadEnglishWords() async {
    if (_isLoadedEn) return;

    final String jsonString =
        await rootBundle.loadString('assets/words/english_5_letter_words.json');
    final List<dynamic> jsonList = json.decode(jsonString);

    _allWordsEn = jsonList
        .cast<String>()
        .map((w) => w.trim().toUpperCase())
        .where((w) => w.length == 5 && _englishLetters.hasMatch(w))
        .toSet()
        .toList();

    _isLoadedEn = true;
  }

  /// Türkçe karakterleri doğru büyütecek fonksiyon
  static String toUpperCaseTurkish(String text) {
    return text
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .replaceAll('ş', 'Ş')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ç', 'Ç')
        .replaceAll('ö', 'Ö')
        .replaceAll('ü', 'Ü')
        .toUpperCase();
  }

  /// Dile göre doğru büyük harf çevirimi
  static String toUpperCaseForLanguage(String text) {
    if (LanguageService().isTurkish) {
      return toUpperCaseTurkish(text);
    }
    return text.toUpperCase();
  }

  /// Türkçe karakter normalizasyonu (â → A, î → İ, vb.)
  static String _normalizeTurkish(String word) {
    return toUpperCaseTurkish(word)
        .replaceAll('Â', 'A')
        .replaceAll('Î', 'İ')
        .replaceAll('Û', 'U')
        .replaceAll('Ê', 'E');
  }

  /// Günün kelimesini seç (tarihe göre deterministik)
  static String getWordOfTheDay() {
    final words = allWords;
    if (words.isEmpty) return LanguageService().isTurkish ? 'KELME' : 'WORDS';

    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);
    return words[random.nextInt(words.length)];
  }

  /// Rastgele bir kelime seç (biletli oynanış için)
  static String getRandomWord() {
    final words = allWords;
    if (words.isEmpty) return LanguageService().isTurkish ? 'KELME' : 'WORDS';
    final random = Random();
    return words[random.nextInt(words.length)];
  }

  /// Kelime geçerli mi kontrol et
  bool isValidWord(String word) {
    return allWords.contains(toUpperCaseForLanguage(word));
  }

  /// Mevcut tahmini harf olarak ekle
  bool addLetter(String letter) {
    if (isGameOver) return false;
    if (currentGuess.length >= wordLength) return false;

    currentGuess.add(toUpperCaseForLanguage(letter));
    return true;
  }

  /// Son harfi sil
  bool removeLetter() {
    if (isGameOver) return false;
    if (currentGuess.isEmpty) return false;

    currentGuess.removeLast();
    return true;
  }

  /// Tahmin yap ve sonucu döndür
  GuessResult submitGuess() {
    if (isGameOver) return GuessResult.gameOver;
    if (currentGuess.length != wordLength) return GuessResult.notEnoughLetters;

    final word = currentGuess.join();

    if (!isValidWord(word)) return GuessResult.invalidWord;

    // Renk durumlarını hesapla
    final statuses = _calculateStatuses(word);

    guesses.add(List.from(currentGuess));
    guessStatuses.add(statuses);

    // Klavye durumlarını güncelle
    for (int i = 0; i < word.length; i++) {
      final letter = word[i];
      final newStatus = statuses[i];
      final currentStatus = keyboardStatuses[letter];

      // Öncelik: correct > present > absent
      if (currentStatus == null ||
          _statusPriority(newStatus) > _statusPriority(currentStatus)) {
        keyboardStatuses[letter] = newStatus;
      }
    }

    // Kazanma kontrolü
    if (word == targetWord) {
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

  /// Harf durumlarını hesapla (Wordle algoritması)
  List<LetterStatus> _calculateStatuses(String guess) {
    final statuses = List.filled(wordLength, LetterStatus.absent);
    final targetChars = targetWord.split('');
    final guessChars = guess.split('');
    final used = List.filled(wordLength, false);

    // 1. geçiş: doğru konumdaki harfleri bul
    for (int i = 0; i < wordLength; i++) {
      if (guessChars[i] == targetChars[i]) {
        statuses[i] = LetterStatus.correct;
        used[i] = true;
      }
    }

    // 2. geçiş: yanlış konumdaki harfleri bul
    for (int i = 0; i < wordLength; i++) {
      if (statuses[i] == LetterStatus.correct) continue;

      for (int j = 0; j < wordLength; j++) {
        if (!used[j] && guessChars[i] == targetChars[j]) {
          statuses[i] = LetterStatus.present;
          used[j] = true;
          break;
        }
      }
    }

    return statuses;
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
  invalidWord,
  notEnoughLetters,
  outOfAttempts,
  gameOver,
}
