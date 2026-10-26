import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
class TicketState {
  final int tickets;
  final DateTime? lastRecharge;
  final String? lastDailyPlayedDate;
  final DateTime? lastAdWatchTime;

  TicketState({
    required this.tickets,
    this.lastRecharge,
    this.lastDailyPlayedDate,
    this.lastAdWatchTime,
  });

  factory TicketState.fromJson(Map<String, dynamic> json) {
    return TicketState(
      tickets: json['tickets'] as int? ?? 2,
      lastRecharge: json['lastRecharge'] != null
          ? DateTime.parse(json['lastRecharge'] as String)
          : null,
      lastDailyPlayedDate: json['lastDailyPlayedDate'] as String?,
      lastAdWatchTime: json['lastAdWatchTime'] != null
          ? DateTime.parse(json['lastAdWatchTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'tickets': tickets,
        'lastRecharge': lastRecharge?.toIso8601String(),
        'lastDailyPlayedDate': lastDailyPlayedDate,
        'lastAdWatchTime': lastAdWatchTime?.toIso8601String(),
      };
}

/// Her oyunun kendine özel 4 biletini, bilet yenilenmesini ve 
/// günlük oyun (ücretsiz) oynama durumunu yöneten servis.
class TicketService extends ChangeNotifier {
  static final TicketService _instance = TicketService._internal();
  factory TicketService() => _instance;
  TicketService._internal();

  static const int maxTickets = 2;
  static const int rechargeMinutes = 30;
  static const int adCooldownMinutes = 35;
  static const String _prefsKeyPrefix = 'ticket_state_';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Bilet durumlarını kontrol et ve gerekirse yenile
    notifyListeners();
  }

  /// O güne ait tarih string'i
  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Oyun id'sine göre mevcut bilet durumunu alır (zaman bazlı yenilemeleri hesaplar)
  TicketState getTicketState(String gameId) {
    if (_prefs == null) return TicketState(tickets: maxTickets);

    final key = '$_prefsKeyPrefix$gameId';
    final jsonStr = _prefs!.getString(key);
    
    TicketState state;
    if (jsonStr != null) {
      state = TicketState.fromJson(jsonDecode(jsonStr));
    } else {
      state = TicketState(tickets: maxTickets);
    }

    // Bilet dolumunu hesapla
    if (state.tickets < maxTickets && state.lastRecharge != null) {
      final now = DateTime.now();
      final difference = now.difference(state.lastRecharge!);
      final earnedTickets = (difference.inMinutes / rechargeMinutes).floor();

      if (earnedTickets > 0) {
        int newTickets = state.tickets + earnedTickets;
        DateTime newLastRecharge = state.lastRecharge!.add(Duration(minutes: earnedTickets * rechargeMinutes));

        if (newTickets >= maxTickets) {
          newTickets = maxTickets;
          newLastRecharge = now; // Full ise artık recharge saymaya gerek yok
        }

        state = TicketState(
          tickets: newTickets,
          lastRecharge: newLastRecharge,
          lastDailyPlayedDate: state.lastDailyPlayedDate,
          lastAdWatchTime: state.lastAdWatchTime,
        );
        _saveState(gameId, state);
        AnalyticsService().logTicketEarned(earnedTickets, 'time_recharge');
      }
    }

    return state;
  }

  /// Biletin tamamen (1 tane daha) dolmasına kalan süreyi döndürür
  Duration? getTimeUntilNextTicket(String gameId) {
    final state = getTicketState(gameId);
    if (state.tickets >= maxTickets || state.lastRecharge == null) {
      return null;
    }
    
    final now = DateTime.now();
    final difference = now.difference(state.lastRecharge!);
    final minutesPassed = difference.inMinutes % rechargeMinutes;
    final remainingMinutes = rechargeMinutes - minutesPassed;
    final secondsPassed = difference.inSeconds % 60;
    
    return Duration(minutes: remainingMinutes - 1, seconds: 60 - secondsPassed);
  }

  /// Reklam izlemek için kalan süreyi döndürür
  Duration? getTimeUntilNextAd(String gameId) {
    final state = getTicketState(gameId);
    if (state.lastAdWatchTime == null) {
      return null;
    }
    
    final now = DateTime.now();
    final difference = now.difference(state.lastAdWatchTime!);
    
    if (difference.inMinutes >= adCooldownMinutes) {
      return null;
    }
    
    final remainingDuration = Duration(minutes: adCooldownMinutes) - difference;
    return remainingDuration;
  }

  /// Bilet düşer. Yeterli bilet yoksa false döner.
  bool useTicket(String gameId) {
    final state = getTicketState(gameId);
    if (state.tickets <= 0) return false;

    // Eğer biletler full ise, dolum süresi şu andan itibaren başlar
    DateTime rechargeTime = state.tickets == maxTickets 
        ? DateTime.now() 
        : (state.lastRecharge ?? DateTime.now());

    final newState = TicketState(
      tickets: state.tickets - 1,
      lastRecharge: rechargeTime,
      lastDailyPlayedDate: state.lastDailyPlayedDate,
      lastAdWatchTime: state.lastAdWatchTime,
    );

    _saveState(gameId, newState);
    AnalyticsService().logTicketSpent(1, gameId);
    return true;
  }

  /// Günlük oyun oynandığında işaretler
  void markDailyPlayed(String gameId) {
    final state = getTicketState(gameId);
    final newState = TicketState(
      tickets: state.tickets,
      lastRecharge: state.lastRecharge,
      lastDailyPlayedDate: _todayKey(),
      lastAdWatchTime: state.lastAdWatchTime,
    );
    _saveState(gameId, newState);
  }

  /// Reklam izlendikten sonra biletleri full doldurur (süreyi sıfırlar) ve reklam bekleme süresini başlatır
  void resetTickets(String gameId) {
    final state = getTicketState(gameId);
    final newState = TicketState(
      tickets: maxTickets,
      lastRecharge: null,
      lastDailyPlayedDate: state.lastDailyPlayedDate,
      lastAdWatchTime: DateTime.now(),
    );
    _saveState(gameId, newState);
    AnalyticsService().logTicketEarned(maxTickets - state.tickets, 'ad_reward');
  }

  /// Coin ile doldurma: reklam bekleme süresine dokunmadan biletleri fuller.
  void refillWithCoins(String gameId) {
    final state = getTicketState(gameId);
    _saveState(gameId, TicketState(
      tickets: maxTickets,
      lastRecharge: null,
      lastDailyPlayedDate: state.lastDailyPlayedDate,
      lastAdWatchTime: state.lastAdWatchTime,
    ));
    AnalyticsService().logTicketEarned(maxTickets - state.tickets, 'coins');
  }

  /// Bugün günlük oyun oynanmış mı?
  bool isDailyPlayed(String gameId) {
    final state = getTicketState(gameId);
    return state.lastDailyPlayedDate == _todayKey();
  }

  Future<void> _saveState(String gameId, TicketState state) async {
    final key = '$_prefsKeyPrefix$gameId';
    await _prefs?.setString(key, jsonEncode(state.toJson()));
    notifyListeners();
  }
}
