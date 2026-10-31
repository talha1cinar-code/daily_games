import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/services/sound_service.dart';

void main() {
  test('yarım ve üstü kazanma, altı kaybetme sesi', () {
    expect(SoundService.isGoodEnd(0), isFalse);
    expect(SoundService.isGoodEnd(49.9), isFalse);
    expect(SoundService.isGoodEnd(50), isTrue);
    expect(SoundService.isGoodEnd(100), isTrue);
  });
}
