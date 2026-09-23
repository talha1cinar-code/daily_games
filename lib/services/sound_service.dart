import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'settings_service.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;

  final AudioPlayer _sfxPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _bgmPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);

  bool _isInMiniGame = false;
  bool _isBgmInitialized = false;

  SoundService._internal() {
    AudioPlayer.global.setAudioContext(AudioContextConfig(
      route: AudioContextConfigRoute.system,
      focus: AudioContextConfigFocus.mixWithOthers,
      respectSilence: false,
      stayAwake: false,
    ).build());
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

  Future<void> _playSound(String fileName) async {
    if (!SettingsService().isSfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('sounds/$fileName'));
    } catch (_) {}
  }

  Future<void> playKeyTap() async {
    _vibrate(HapticFeedbackType.light);
    if (!_isInMiniGame) {
      await _playSound('click_sound.mp3');
    }
  }

  Future<void> playDelete() async {
    _vibrate(HapticFeedbackType.light);
    if (!_isInMiniGame) {
      await _playSound('click_sound.mp3');
    }
  }

  Future<void> playError() async {
    _vibrate(HapticFeedbackType.heavy);
    await _playSound('error.wav');
  }

  Future<void> playFlip() async {
    _vibrate(HapticFeedbackType.selection);
    if (!_isInMiniGame) {
      await _playSound('click_sound.mp3'); // Şimdilik click ile aynı
    }
  }

  Future<void> playWin() async {
    _vibrate(HapticFeedbackType.heavy);
    await _playSound('universfield-game-bonus.mp3');
  }

  Future<void> playLose() async {
    _vibrate(HapticFeedbackType.heavy);
    await _playSound('lose.wav');
  }

  void dispose() {
    _sfxPlayer.dispose();
    _bgmPlayer.dispose();
  }
}

enum HapticFeedbackType { light, medium, heavy, selection }
