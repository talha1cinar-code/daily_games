import 'wikitrivia_data.dart';

/// Wikitrivia oyununun veri modeli ve mantığı
class HistoricalEvent {
  final String title;
  final int year;
  final String? imageUrl; // İleride Firebase'den gelecek

  const HistoricalEvent({
    required this.title,
    required this.year,
    this.imageUrl,
  });
}

enum PlacementResult { correct, incorrect }

class WikitriviaGame {
  /// Zaman çizelgesine yerleştirilmiş olaylar (sıralı)
  final List<HistoricalEvent> timeline = [];

  /// Henüz oynanmamış olaylar (sırada bekleyenler)
  final List<HistoricalEvent> _remainingEvents = [];

  /// Mevcut sürüklenecek kart
  HistoricalEvent? currentCard;

  /// Skor ve yanlış hakları
  int score = 0;
  int totalAttempts = 0;
  int maxWrongs = 2;
  int wrongCount = 0;
  
  /// Kazanmak için gereken doğru yerleştirme sayısı
  final int targetScore = 7;

  bool get isGameOver =>
      score >= targetScore ||
      (currentCard == null && _remainingEvents.isEmpty) ||
      wrongCount >= maxWrongs;

  bool get isWon => score >= targetScore;

  int get remainingLives => maxWrongs - wrongCount;

  /// [externalEvents] ileride Firebase gibi dış kaynaklardan çekilen veriyi alır.
  /// Eğer null verilirse, oyun kendi içindeki varsayılan (offline) devasa listeyi kullanır.
  WikitriviaGame({List<HistoricalEvent>? externalEvents}) {
    _initGame(externalEvents: externalEvents);
  }

  void _initGame({List<HistoricalEvent>? externalEvents}) {
    // Dışarıdan olay geldiyse onu, gelmediyse varsayılan çevrimdışı arşivimizi kullan
    final sourceEvents = externalEvents ?? defaultHistoricalEvents;
    
    // Olayları karıştır
    final shuffled = List<HistoricalEvent>.from(sourceEvents)..shuffle();

    // İlk kartı zaman çizelgesine koy
    timeline.add(shuffled.removeAt(0));

    // Geri kalanları sıraya koy
    _remainingEvents.addAll(shuffled);

    // İlk sürüklenecek kartı ayarla
    _drawNextCard();
  }

  void _drawNextCard() {
    if (_remainingEvents.isNotEmpty) {
      currentCard = _remainingEvents.removeAt(0);
    } else {
      currentCard = null;
    }
  }

  /// Kartı belirli bir pozisyona yerleştir.
  /// [insertIndex]: timeline listesindeki konum (0 = en sola)
  /// Doğru/yanlış sonucunu ve doğru pozisyonu döndürür.
  PlacementInfo placeCard(int insertIndex) {
    if (currentCard == null) {
      return PlacementInfo(
        result: PlacementResult.incorrect,
        insertedIndex: insertIndex,
        correctIndex: insertIndex,
      );
    }

    final card = currentCard!;
    totalAttempts++;

    // Doğru pozisyonu bul
    int correctIndex = 0;
    for (int i = 0; i < timeline.length; i++) {
      if (card.year >= timeline[i].year) {
        correctIndex = i + 1;
      }
    }

    final isCorrect = insertIndex == correctIndex;

    if (isCorrect) {
      score++;
      timeline.insert(insertIndex, card);
    } else {
      wrongCount++;
      // Yanlışsa da doğru yere ekle
      timeline.insert(correctIndex, card);
    }

    final info = PlacementInfo(
      result: isCorrect ? PlacementResult.correct : PlacementResult.incorrect,
      insertedIndex: insertIndex,
      correctIndex: correctIndex,
    );

    if (!isGameOver) {
      _drawNextCard();
    } else {
      currentCard = null;
    }

    return info;
  }
}

class PlacementInfo {
  final PlacementResult result;
  final int insertedIndex;
  final int correctIndex;

  const PlacementInfo({
    required this.result,
    required this.insertedIndex,
    required this.correctIndex,
  });
}
