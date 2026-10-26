import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'settings_service.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;

  /// Hiçbir oynatıcı ses odağını (audio focus) almasın; efekt çalınca müzik susmasın
  static final AudioContext _mixContext = AudioContextConfig(
    route: AudioContextConfigRoute.system,
    focus: AudioContextConfigFocus.mixWithOthers,
    respectSilence: false,
    stayAwake: false,
  ).build();

  /// Kısa efektler üst üste çalabilsin diye sırayla kullanılan küçük oynatıcı havuzu
  final List<AudioPlayer> _sfxPool = List.generate(4, (_) => AudioPlayer());
  int _nextSfx = 0;
  final AudioPlayer _bgmPlayer = AudioPlayer();

  bool _isInMiniGame = false;
  bool _isBgmInitialized = false;

  SoundService._internal() {
    AudioPlayer.global.setAudioContext(_mixContext);
    for (final p in _sfxPool) {
      p
        ..setAudioContext(_mixContext)
        ..setReleaseMode(ReleaseMode.stop);
    }
    _bgmPlayer
      ..setAudioContext(_mixContext)
      ..setReleaseMode(ReleaseMode.loop);
  }

  /// Mini oyun içinde olup olmadığını döner
  bool get isInMiniGame => _isInMiniGame;

  /// Mini oyuna girerken çağır — müziği durdurur
  Future<void> enterMiniGame() async {
    _isInMiniGame = true;
    await pauseBgm();
  }

  /// Mini oyundan çıkarken çağır — müziği devam ettirir
  Future<void> exitMiniGame() async {
    _isInMiniGame = false;
    await updateBgmState();
  }

  /// Arka plan müziğini başlat veya devam ettir
  Future<void> playBgm() async {
    if (!SettingsService().isMusicEnabled || _isInMiniGame) {
      return;
    }
    
    try {
      if (!_isBgmInitialized) {
        _isBgmInitialized = true;
        await _bgmPlayer.play(AssetSource('sounds/game_music.mp3'), volume: 0.1);
      } else {
        await _bgmPlayer.resume();
      }
    } catch (e) {
      // Fallback: resume başarısız olursa, sıfırdan başlat
      try {
        await _bgmPlayer.play(AssetSource('sounds/game_music.mp3'), volume: 0.1);
        _isBgmInitialized = true;
      } catch (_) {}
    }
  }

  /// Arka plan müziğini duraklat
  Future<void> pauseBgm() async {
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  /// Settings güncellendiğinde veya ana ekrana dönüldüğünde çağrılır
  Future<void> updateBgmState() async {
    if (_isInMiniGame || !SettingsService().isMusicEnabled) {
      await pauseBgm();
    } else {
      await playBgm();
    }
  }

  void _vibrate(HapticFeedbackType type) {
    if (!SettingsService().isVibrationEnabled) return;
    switch (type) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }

  Future<void> _playSound(String fileName, {double volume = 1.0}) async {
    if (!SettingsService().isSfxEnabled) return;
    final player = _sfxPool[_nextSfx];
    _nextSfx = (_nextSfx + 1) % _sfxPool.length;
    try {
      await player.stop();
      await player.play(AssetSource('sounds/$fileName'), volume: volume);
    } catch (_) {}
  }

  /// Tuş, buton ve klavye dokunuşu
  Future<void> playKeyTap() async {
    _vibrate(HapticFeedbackType.light);
    await _playSound('tap.wav', volume: _isInMiniGame ? 0.5 : 0.7);
  }

  Future<void> playDelete() async {
    _vibrate(HapticFeedbackType.light);
    await _playSound('tap.wav', volume: 0.4);
  }

  /// Hücre çevirme, seçim, sıradan bir tur
  Future<void> playFlip() async {
    _vibrate(HapticFeedbackType.selection);
    await _playSound('flip.wav', volume: 0.7);
  }

  /// Tur içinde doğru / iyi sonuç
  Future<void> playCorrect() async {
    _vibrate(HapticFeedbackType.medium);
    await _playSound('correct.wav', volume: 0.8);
  }

  /// Yanlış hamle
  Future<void> playError() async {
    _vibrate(HapticFeedbackType.heavy);
    await _playSound('error.wav', volume: 0.8);
  }

  /// Geri sayımın sonu ("Başla!")
  Future<void> playGo() async {
    _vibrate(HapticFeedbackType.medium);
    await _playSound('go.wav', volume: 0.8);
  }

  /// Oyunu kazanma, rekor
  Future<void> playWin() async {
    _vibrate(HapticFeedbackType.heavy);
    await _playSound('win.wav', volume: 0.45);
  }

  /// Oyunu kaybetme
  Future<void> playLose() async {
    _vibrate(HapticFeedbackType.heavy);
    await _playSound('lose.wav', volume: 0.85);
  }

  /// Coin kazanma veya harcama (satın alma)
  Future<void> playCoin() async {
    _vibrate(HapticFeedbackType.medium);
    await _playSound('coin.wav', volume: 0.85);
  }

  /// Echole pedlerinin tonu (0-3)
  Future<void> playPad(int i) async {
    _vibrate(HapticFeedbackType.light);
    await _playSound('echo_$i.wav', volume: 0.8);
  }

  /// Rozet, sandık, seri kutlaması gibi büyük ödüller
  Future<void> playReward() async {
    _vibrate(HapticFeedbackType.heavy);
    await _playSound('reward.wav');
  }

  void dispose() {
    for (final p in _sfxPool) {
      p.dispose();
    }
    _bgmPlayer.dispose();
  }
}

enum HapticFeedbackType { light, medium, heavy, selection }
