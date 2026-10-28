import 'package:flutter/material.dart';
import '../services/language_service.dart';

/// Profil banner'ı: çizilmiş manzara (`assets/banners/<id>.png`, 10:3).
/// Sıralama kaydında yalnızca [id] tutulur.
class BannerStyle {
  final String id;
  final String nameTr;
  final String nameEn;
  final int price;

  /// Banner yüklenene kadar ve sade banner için zemin rengi
  final Color tint;

  const BannerStyle(this.id, this.nameTr, this.nameEn, this.price, this.tint);

  String get name => LanguageService().isTurkish ? nameTr : nameEn;
  bool get isFree => price == 0;
  String? get asset => id == none ? null : 'assets/banners/$id.png';

  static const String none = 'none';

  static const List<BannerStyle> all = [
    BannerStyle(none, 'Sade', 'Plain', 0, Color(0xFF2A2550)),
    BannerStyle('ocean', 'Okyanus', 'Ocean', 1000, Color(0xFF2E9FD6)),
    BannerStyle('forest', 'Orman', 'Forest', 1000, Color(0xFF3E9A68)),
    BannerStyle('desert', 'Çöl', 'Desert', 1000, Color(0xFFE08A3C)),
    BannerStyle('candy', 'Şeker', 'Candy', 1000, Color(0xFFFFB3DE)),
    BannerStyle('city', 'Gece Şehri', 'Night City', 1500, Color(0xFF24204F)),
    BannerStyle('sakura', 'Sakura', 'Sakura', 1500, Color(0xFFFFC2DA)),
    BannerStyle('synthwave', 'Synthwave', 'Synthwave', 2000, Color(0xFF8A2A7A)),
    BannerStyle('lava', 'Lav', 'Lava', 2000, Color(0xFF3A0E08)),
    BannerStyle('circuit', 'Devre', 'Circuit', 2000, Color(0xFF04232A)),
    BannerStyle('aurora', 'Kutup Işığı', 'Aurora', 2500, Color(0xFF0B2E4A)),
    BannerStyle('space', 'Uzay', 'Space', 2500, Color(0xFF1B0F44)),
    BannerStyle('gold', 'Altın', 'Gold', 5000, Color(0xFF2A1A05)),
  ];

  /// Önceki sürümdeki gradyan banner kimlikleri → yeni karşılıkları
  static const Map<String, String> legacy = {
    'sunset': 'synthwave',
    'galaxy': 'space',
    'ice': 'aurora',
    'fire': 'lava',
    'neon': 'circuit',
  };

  static BannerStyle byId(String? id) {
    final key = legacy[id] ?? id;
    return all.firstWhere((b) => b.id == key, orElse: () => all.first);
  }
}
