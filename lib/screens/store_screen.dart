import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/banner_style.dart';
import '../services/ad_service.dart';
import '../services/app_strings.dart';
import '../services/avatar_service.dart';
import '../services/coin_service.dart';
import '../services/leaderboard_service.dart';
import '../services/sound_service.dart';
import '../services/streak_service.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/avatar_view.dart';
import '../widgets/banner_background.dart';
import '../widgets/chunky_button.dart';
import '../widgets/coin_badge.dart';

/// Coin mağazası. Gerçek parayla satın alma yok: coin oynayarak ve günde bir
/// ödüllü reklamla kazanılır.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  static const List<String> premiumAvatars = ['👑', '🐉', '🚀', '🦈', '👾', '🤖', '🦅', '💎', '🔥', '⚡', '🎮', '🌈'];

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final _listenables = Listenable.merge([CoinService(), StreakService()]);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Günlük hediye geri sayımı
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !CoinService().canWatchAdToday) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.redAccent : const Color(0xFF2A2340),
        content: Text(text, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
      ));
  }

  void _watchAd() {
    if (!AdService().isRewardedReady) {
      _toast(AppStrings.adNotReady, error: true);
      return;
    }
    AdService().showRewardedAd(onUserEarnedReward: () async {
      await CoinService().rewardAdWatched();
      SoundService().playCoin();
      if (mounted) _toast(AppStrings.coinsEarned(CoinService.adReward));
    });
  }

  Future<void> _buyFreeze() async {
    if (StreakService().freezeCount >= StreakService.maxFreezes) {
      _toast(AppStrings.freezeFull, error: true);
      return;
    }
    if (await CoinService().spend(CoinService.freezePrice, 'streak_freeze')) {
      await StreakService().addFreeze();
      SoundService().playCoin();
      if (mounted) _toast(AppStrings.freezeBought);
    } else if (mounted) {
      _toast(AppStrings.notEnoughCoins, error: true);
    }
  }

  Future<void> _openLook({String? banner, String? avatar}) async {
    await AvatarPickerSheet.show(context, previewBanner: banner, previewAvatar: avatar);
    if (mounted) setState(() {});
  }

  String _untilMidnight() {
    final now = DateTime.now();
    final left = DateTime(now.year, now.month, now.day + 1).difference(now);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
  }

  /// Günün öne çıkan banner'ı ve avatarı: tarihe göre döner, sahip olunmayanlar önce.
  int get _dayIndex {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).difference(DateTime(n.year)).inDays;
  }

  BannerStyle get _featuredBanner {
    final paid = BannerStyle.all.where((b) => !b.isFree).toList();
    final unowned = paid.where((b) => !CoinService().ownsBanner(b.id)).toList();
    final pool = unowned.isEmpty ? paid : unowned;
    return pool[_dayIndex % pool.length];
  }

  String get _featuredAvatar {
    final all = AvatarService.premiumCharacters.map(AvatarService.character).toList();
    final unowned = all.where((a) => !CoinService().ownedAvatars.contains(a)).toList();
    final pool = unowned.isEmpty ? all : unowned;
    return pool[(_dayIndex + 3) % pool.length];
  }

  // ─── Bileşenler ────────────────────────────────────────────────
  Text _h(String t) => Text(t, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white));

  Widget _priceLabel(int price) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 20),
          const SizedBox(width: 5),
          Text('$price', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      );

  Widget _gift() {
    final available = CoinService().canWatchAdToday;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: available
              ? const [Color(0xFFFFC94D), Color(0xFFFF8A2F)]
              : const [Color(0xFF4A3F78), Color(0xFF2E2658)],
        ),
        boxShadow: available
            ? [BoxShadow(color: const Color(0xFFFF8A2F).withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(22)),
            child: Icon(available ? Icons.redeem_rounded : Icons.lock_clock_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.dailyGift,
                    style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  available ? AppStrings.dailyGiftDesc(CoinService.adReward) : AppStrings.nextGiftIn(_untilMidnight()),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 12),
                if (available)
                  SizedBox(
                    width: 150,
                    child: ChunkyButton(
                      face: Colors.white,
                      lip: const Color(0xFFE0B080),
                      height: 44,
                      radius: 14,
                      onTap: _watchAd,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded, color: Color(0xFFE0651F)),
                          Text('+${CoinService.adReward}',
                              style: GoogleFonts.nunito(
                                  fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFFE0651F))),
                          const SizedBox(width: 4),
                          const CoinIcon(size: 18),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shelfCard({
    required Widget art,
    required String title,
    required String subtitle,
    required Widget button,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF241C52),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 100, child: art),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white54)),
                ],
              ),
            ),
            const Spacer(),
            Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: button),
          ],
        ),
      ),
    );
  }

  Widget _shelf() {
    final lb = LeaderboardService();
    final banner = _featuredBanner;
    final bannerOwned = CoinService().ownsBanner(banner.id);
    final avatar = _featuredAvatar;
    final avatarOwned = CoinService().ownedAvatars.contains(avatar);
    final freezes = StreakService().freezeCount;

    Widget buyButton(Widget label, VoidCallback? onTap, {Color face = const Color(0xFF3DDC84), Color lip = const Color(0xFF1E9E55)}) =>
        ChunkyButton(face: face, lip: lip, height: 40, radius: 13, onTap: onTap, child: label);
    Widget textLabel(String t) =>
        Text(t, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white));

    final cards = <Widget>[
        _shelfCard(
          art: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8FE3FF), Color(0xFF3A8DFF)],
              ),
            ),
            child: const Center(child: Icon(Icons.ac_unit_rounded, color: Colors.white, size: 64)),
          ),
          title: AppStrings.streakFreeze,
          subtitle: AppStrings.freezeOwnedShort(freezes, StreakService.maxFreezes),
          button: buyButton(_priceLabel(CoinService.freezePrice), freezes >= StreakService.maxFreezes ? null : _buyFreeze,
              face: const Color(0xFF4F8BFF), lip: const Color(0xFF2E5BC4)),
          onTap: null,
        ),
        _shelfCard(
          art: BannerBackground(
            bannerId: banner.id,
            scrim: false,
            borderRadius: BorderRadius.zero,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFF4D6D), borderRadius: BorderRadius.circular(8)),
                child: Text(AppStrings.todaysPick,
                    style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ),
          title: banner.name,
          subtitle: AppStrings.bannerLabel,
          button: bannerOwned
              ? buyButton(textLabel(AppStrings.owned), () => _openLook(),
                  face: const Color(0xFF5A6080), lip: const Color(0xFF3A3F58))
              : buyButton(_priceLabel(banner.price), () => _openLook(banner: banner.id)),
          onTap: () => _openLook(banner: bannerOwned ? null : banner.id),
        ),
        _shelfCard(
          art: Container(
            color: const Color(0xFF3A2D7A),
            child: Center(child: AvatarView(avatar: avatar, size: 84, ring: Colors.white)),
          ),
          title: AppStrings.todaysAvatar,
          subtitle: AppStrings.characters,
          button: avatarOwned
              ? buyButton(textLabel(AppStrings.owned), () => _openLook(),
                  face: const Color(0xFF5A6080), lip: const Color(0xFF3A3F58))
              : buyButton(_priceLabel(CoinService.avatarPrice), () => _openLook(avatar: avatar)),
          onTap: () => _openLook(avatar: avatarOwned ? null : avatar),
        ),
        _shelfCard(
          art: BannerBackground(
            bannerId: lb.banner,
            borderRadius: BorderRadius.zero,
            child: Center(child: AvatarView(avatar: lb.avatar, size: 72, ring: Colors.white)),
          ),
          title: AppStrings.myLook,
          subtitle: AppStrings.allItems,
          button: buyButton(textLabel(AppStrings.edit), () => _openLook(),
              face: const Color(0xFFB66DFF), lip: const Color(0xFF7A3BC2)),
          onTap: () => _openLook(),
        ),
    ];
    // Yazı boyutu büyük cihazlarda taşmasın diye yükseklik içerikten gelir
    Widget pair(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)],
          ),
        );
    return Column(
      children: [
        pair(cards[0], cards[1]),
        const SizedBox(height: 14),
        pair(cards[2], cards[3]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A0F6E), Color(0xFF1A1450), Color(0xFF0E1638)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _listenables,
            builder: (context, _) => ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(22)),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(AppStrings.store,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    CoinBadge(amount: CoinService().balance),
                  ],
                ),
                const SizedBox(height: 18),
                _gift(),
                const SizedBox(height: 24),
                _h(AppStrings.shelf),
                const SizedBox(height: 12),
                _shelf(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
