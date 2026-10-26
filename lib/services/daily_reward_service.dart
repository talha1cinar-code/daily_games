import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'coin_service.dart';
import 'daily_run_service.dart';

/// 7 günlük giriş ödülü takvimi. Ardışık günlerde ödül büyür; bir gün
/// atlanırsa takvim başa döner. 7. günden sonra yeniden 1. gün başlar.
class DailyRewardService extends ChangeNotifier {
  static final DailyRewardService _instance = DailyRewardService._internal();
  factory DailyRewardService() => _instance;
  DailyRewardService._internal();

  static const List<int> rewards = [10, 15, 20, 25, 30, 40, 100];
  static const String _lastKey = 'daily_reward_last';
  static const String _dayKey = 'daily_reward_day';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _today => _key(DailyRunService.turkeyNow);
  String get _yesterday => _key(DailyRunService.turkeyNow.subtract(const Duration(days: 1)));

  bool get canClaim => _prefs?.getString(_lastKey) != _today;

  /// Bugün alınacak (veya alınmışsa bugün alınan) ödülün 0 tabanlı günü
  int get currentDay {
    final last = _prefs?.getString(_lastKey);
    final stored = _prefs?.getInt(_dayKey) ?? 0;
    if (last == _today) return (stored - 1) % rewards.length;
    if (last == _yesterday) return stored % rewards.length;
    return 0; // hiç alınmamış ya da gün atlanmış
  }

  Future<int> claim() async {
    if (!canClaim) return 0;
    final day = currentDay;
    final amount = rewards[day];
    await _prefs?.setString(_lastKey, _today);
    await _prefs?.setInt(_dayKey, day + 1);
    await CoinService().earn(amount, 'daily_reward');
    notifyListeners();
    return amount;
  }
}
