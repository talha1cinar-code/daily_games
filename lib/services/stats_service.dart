import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oynanan oyunun yerel sonucunu temsil eder.
class GameStat {
  final String date;
  final bool isWin;
  final int attempts;
  final int maxAttempts;
  final double score; // Bazı oyunlar (RGBle, Timele) için
  final String? targetValue; // O günkü kelime/denklem vb.
  final int? durationMs; // Milisaniye cinsinden süre

  GameStat({
    required this.date,
    required this.isWin,
    this.attempts = 0,
    this.maxAttempts = 0,
    this.score = 0.0,
    this.targetValue,
    this.durationMs,
  });

  factory GameStat.fromJson(Map<String, dynamic> json) {
    return GameStat(
      date: json['date'] as String,
      isWin: json['isWin'] as bool,
      attempts: json['attempts'] as int? ?? 0,
      maxAttempts: json['maxAttempts'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      targetValue: json['targetValue'] as String?,
      durationMs: json['durationMs'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'isWin': isWin,
        'attempts': attempts,
        'maxAttempts': maxAttempts,
        'score': score,
        'targetValue': targetValue,
        'durationMs': durationMs,
      };
}

/// Sadece Günlük Oyun (Daily) oynandığında performansı kaydeden servis.
class StatsService extends ChangeNotifier {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  static const String _prefsKeyPrefix = 'stats_';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Günlük oyun sonucunu kaydeder.
  Future<void> saveDailyStat({
    required String gameId,
    required bool isWin,
    int attempts = 0,
    int maxAttempts = 0,
    double score = 0.0,
    String? targetValue,
    int? durationMs,
  }) async {
    if (_prefs == null) return;
    
    final stats = getStats(gameId);
    
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    // Zaten varsa (aynı gün) üzerine yaz (eğer ki çoklu oynanma olursa diye ama günlük tek olmalı)
    stats.removeWhere((s) => s.date == todayStr);
    
    stats.add(GameStat(
      date: todayStr,
      isWin: isWin,
      attempts: attempts,
      maxAttempts: maxAttempts,
      score: score,
      targetValue: targetValue,
      durationMs: durationMs,
    ));

    final key = '$_prefsKeyPrefix$gameId';
    final jsonList = stats.map((s) => s.toJson()).toList();
    await _prefs!.setString(key, jsonEncode(jsonList));
    
    notifyListeners();
  }

  /// O oyuna ait tüm yerel günlük istatistikleri getirir.
  List<GameStat> getStats(String gameId) {
    if (_prefs == null) return [];
    
    final key = '$_prefsKeyPrefix$gameId';
    final jsonStr = _prefs!.getString(key);
    
    if (jsonStr == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => GameStat.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('StatsService Error: $e');
      return [];
    }
  }

  /// Oyunun kazanma oranı, vs gibi genel bir özeti için helper
  Map<String, dynamic> getSummary(String gameId) {
    final stats = getStats(gameId);
    if (stats.isEmpty) {
      return {'played': 0, 'wins': 0, 'winRate': 0.0, 'streak': 0};
    }
    
    int wins = stats.where((s) => s.isWin).length;
    double winRate = (wins / stats.length) * 100;
    
    // Basit bir streak hesabı
    int streak = 0;
    for (int i = stats.length - 1; i >= 0; i--) {
      if (stats[i].isWin) {
        streak++;
      } else {
        break;
      }
    }

    return {
      'played': stats.length,
      'wins': wins,
      'winRate': winRate,
      'streak': streak,
    };
  }
}
