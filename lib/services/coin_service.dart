import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import '../models/banner_style.dart';
import 'avatar_service.dart';

/// Oyun içi para birimi. Gerçek parayla satılmaz; oyun bitirerek, günde bir
/// ödüllü reklamla, Daily Run sandığı, günlük ödül ve rozetlerle kazanılır.
/// Bilet, donma hakkı, ipucu, avatar ve banner'lara harcanır.
class CoinService extends ChangeNotifier {
  static final CoinService _instance = CoinService._internal();
  factory CoinService() => _instance;
  CoinService._internal();

  // ─── Ödüller ve fiyatlar ─────────────────────────────────────────
  static const int startingCoins = 50;
  // Kazanç: düzenli oynayan biri günde ~150-180 coin toplar
  static const int adReward = 25;
  static const int achievementReward = 30;
  static const int gameRewardBase = 3;
  static const int gameRewardMax = 6;
  // Oyun içi kullanımlar uygun kalır, kozmetikler emek ister (avatar ~1 hafta)
  static const int ticketRefillPrice = 60;
  static const int freezePrice = 300;
  static const int hintPrice = 50;
  static const int extraLifePrice = 80;
  static const int avatarPrice = 1200;
  static const int emojiPrice = 500;

  /// Çizilmiş karakterler emojilerden pahalı
  static int priceOfAvatar(String avatar) => avatar.startsWith(AvatarService.imagePrefix) ? avatarPrice : emojiPrice;

  static const String _balanceKey = 'coins_balance';
  static const String _adDayKey = 'coins_ad_day';
  static const String _freeAvatarMigrationKey = 'coins_free4_migrated';
  static const String _ownedKey = 'coins_owned_avatars'; // avatarlar ve 'banner:' önekli banner'lar

  SharedPreferences? _prefs;
  int _balance = 0;

  int get balance => _balance;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_prefs!.containsKey(_balanceKey)) {
      await _prefs!.setInt(_balanceKey, startingCoins);
    }
    _balance = _prefs!.getInt(_balanceKey) ?? 0;
    // Eskiden ücretsiz olan avatarı takılı olan kullanıcı onu kaybetmesin
    if (!(_prefs!.getBool(_freeAvatarMigrationKey) ?? false)) {
      final current = _prefs!.getString('leaderboard_avatar');
      if (current != null && !AvatarService.isFree(current)) {
        await _prefs!.setStringList(_ownedKey, [..._owned, current]);
      }
      await _prefs!.setBool(_freeAvatarMigrationKey, true);
    }
  }

  Future<void> earn(int amount, String source) async {
    if (amount <= 0) return;
    _balance += amount;
    await _prefs?.setInt(_balanceKey, _balance);
    AnalyticsService().logCoinsEarned(amount, source);
    notifyListeners();
  }

  /// Yeterli coin varsa düşer ve true döner.
  Future<bool> spend(int amount, String item) async {
    if (_balance < amount) return false;
    _balance -= amount;
    await _prefs?.setInt(_balanceKey, _balance);
    AnalyticsService().logCoinsSpent(amount, item);
    notifyListeners();
    return true;
  }

  /// Oyun bitirme ödülü: 0-100 normalize skora göre 5-10 coin.
  static int gameReward(double normalizedScore) =>
      gameRewardBase + ((gameRewardMax - gameRewardBase) * (normalizedScore.clamp(0, 100) / 100)).round();

  // ─── Reklamla coin: günde bir kez ────────────────────────────────
  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  bool get canWatchAdToday => _prefs?.getString(_adDayKey) != _today;

  Future<void> rewardAdWatched() async {
    if (!canWatchAdToday) return;
    await _prefs?.setString(_adDayKey, _today);
    await earn(adReward, 'rewarded_ad');
  }

  // ─── Kozmetikler ─────────────────────────────────────────────────
  Set<String> get _owned => (_prefs?.getStringList(_ownedKey) ?? []).toSet();

  Set<String> get ownedAvatars => _owned.where((e) => !e.startsWith('banner:')).toSet();

  /// Eski sürümden alınmış banner'lar yeni karşılıklarıyla sayılır
  bool ownsBanner(String id) =>
      _owned.contains('banner:$id') ||
      BannerStyle.legacy.entries.any((e) => e.value == id && _owned.contains('banner:${e.key}'));

  Future<bool> _buy(String key, int price, String item) async {
    if (_owned.contains(key)) return true;
    if (!await spend(price, item)) return false;
    await _prefs?.setStringList(_ownedKey, [..._owned, key]);
    notifyListeners();
    return true;
  }

  Future<bool> buyAvatar(String avatar) => _buy(avatar, priceOfAvatar(avatar), 'avatar');

  Future<bool> buyBanner(String id, int price) => _buy('banner:$id', price, 'banner');
}
