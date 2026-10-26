import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/banner_style.dart';
import '../screens/store_screen.dart';
import '../services/app_strings.dart';
import '../services/avatar_service.dart';
import '../services/coin_service.dart';
import '../services/leaderboard_service.dart';
import '../services/sound_service.dart';
import 'avatar_view.dart';
import 'banner_background.dart';
import 'chunky_button.dart';
import 'coin_badge.dart';

/// Kilitli kozmetik önizlemesi: dokununca satın alınmaz, önce burada gösterilir.
class _Pending {
  final bool isBanner;
  final String id;
  final int price;
  const _Pending(this.isBanner, this.id, this.price);
}

/// Profil görünümü: banner ve avatar seçimi. Sahip olunanlar dokununca kullanılır;
/// kilitliler önizlenir ve ancak "Satın al" ile alınır.
class AvatarPickerSheet extends StatefulWidget {
  final String? previewBanner;
  final String? previewAvatar;

  const AvatarPickerSheet({super.key, this.previewBanner, this.previewAvatar});

  static Future<void> show(BuildContext context, {String? previewBanner, String? previewAvatar}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarPickerSheet(previewBanner: previewBanner, previewAvatar: previewAvatar),
    );
  }

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  _Pending? _pending;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    final b = widget.previewBanner;
    final a = widget.previewAvatar;
    if (b != null && !_ownsBanner(BannerStyle.byId(b))) {
      _pending = _Pending(true, b, BannerStyle.byId(b).price);
    } else if (a != null && !_ownsAvatar(a, free: false)) {
      _pending = _Pending(false, a, CoinService.priceOfAvatar(a));
    }
  }

  bool _ownsBanner(BannerStyle b) => b.isFree || CoinService().ownsBanner(b.id);
  bool _ownsAvatar(String a, {required bool free}) => free || CoinService().ownedAvatars.contains(a);

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.redAccent : const Color(0xFF2A2340),
        content: Text(text, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
      ));
  }

  Future<void> _tapAvatar(String avatar, {required bool free}) async {
    HapticFeedback.selectionClick();
    if (_ownsAvatar(avatar, free: free)) {
      SoundService().playKeyTap();
      await LeaderboardService().setAvatar(avatar);
      setState(() {
        if (_pending?.isBanner == false) _pending = null;
      });
    } else {
      setState(() => _pending = _Pending(false, avatar, CoinService.priceOfAvatar(avatar)));
    }
  }

  Future<void> _tapBanner(BannerStyle b) async {
    HapticFeedback.selectionClick();
    if (_ownsBanner(b)) {
      SoundService().playKeyTap();
      await LeaderboardService().setBanner(b.id);
      setState(() {
        if (_pending?.isBanner == true) _pending = null;
      });
    } else {
      setState(() => _pending = _Pending(true, b.id, b.price));
    }
  }

  Future<void> _buy() async {
    final p = _pending;
    if (p == null || _buying) return;
    setState(() => _buying = true);
    final ok = p.isBanner ? await CoinService().buyBanner(p.id, p.price) : await CoinService().buyAvatar(p.id);
    if (ok) {
      p.isBanner ? await LeaderboardService().setBanner(p.id) : await LeaderboardService().setAvatar(p.id);
      SoundService().playCoin();
      _toast(AppStrings.purchased);
    } else {
      _toast(AppStrings.notEnoughCoins, error: true);
    }
    if (mounted) {
      setState(() {
        _buying = false;
        if (ok) _pending = null;
      });
    }
  }

  // ─── Hücreler ──────────────────────────────────────────────────
  Widget _priceTag(int price) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 13),
            const SizedBox(width: 3),
            Text('$price', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
          ],
        ),
      );

  Widget _bannerCell(BannerStyle b, String equipped) {
    final owned = _ownsBanner(b);
    final isEquipped = BannerStyle.byId(equipped).id == b.id;
    final isPending = _pending?.isBanner == true && _pending!.id == b.id;
    return GestureDetector(
      onTap: () => _tapBanner(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 10 / 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isEquipped
                      ? const Color(0xFF3DDC84)
                      : isPending
                          ? const Color(0xFFFFC233)
                          : Colors.white12,
                  width: isEquipped || isPending ? 3 : 1,
                ),
              ),
              child: BannerBackground(
                bannerId: b.id,
                scrim: false,
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  children: [
                    if (!owned) Positioned(right: 6, top: 6, child: _priceTag(b.price)),
                    if (isEquipped)
                      const Positioned(
                        right: 6,
                        top: 6,
                        child: Icon(Icons.check_circle_rounded, color: Color(0xFF3DDC84), size: 20),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(b.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                  fontSize: 12, fontWeight: FontWeight.w800, color: owned ? Colors.white : Colors.white60)),
        ],
      ),
    );
  }

  Widget _avatarCell(String avatar, String equipped, {required bool free}) {
    final owned = _ownsAvatar(avatar, free: free);
    final isEquipped = avatar == equipped;
    final isPending = _pending?.isBanner == false && _pending!.id == avatar;
    return GestureDetector(
      onTap: () => _tapAvatar(avatar, free: free),
      child: SizedBox(
        width: 64,
        height: 84,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AvatarView(
                  avatar: avatar,
                  size: 60,
                  ring: isEquipped
                      ? const Color(0xFF3DDC84)
                      : isPending
                          ? const Color(0xFFFFC233)
                          : null,
                ),
                if (!owned)
                  Positioned(
                    right: -4,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Color(0xFF1C1640), shape: BoxShape.circle),
                      child: const Icon(Icons.lock_rounded, size: 14, color: Colors.white70),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 18,
              child: owned
                  ? null
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CoinIcon(size: 13),
                        const SizedBox(width: 3),
                        Text('${CoinService.priceOfAvatar(avatar)}',
                            style: GoogleFonts.nunito(
                                fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFFFC233))),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(
          t.toUpperCase(),
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      );

  // ─── Önizleme ve satın alma ────────────────────────────────────
  Widget _preview(String avatar, String banner) {
    final lb = LeaderboardService();
    final shownBanner = _pending?.isBanner == true ? _pending!.id : banner;
    final shownAvatar = _pending?.isBanner == false ? _pending!.id : avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AspectRatio(
          aspectRatio: 10 / 3.4,
          child: BannerBackground(
            bannerId: shownBanner,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  AvatarView(avatar: shownAvatar, size: 62, ring: Colors.white),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      lb.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: const [Shadow(color: Color(0x88000000), blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_pending != null)
          Positioned(
            left: 12,
            top: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFFFC233), borderRadius: BorderRadius.circular(10)),
              child: Text(AppStrings.previewing,
                  style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF3A2400))),
            ),
          ),
      ],
    );
  }

  Widget _buyBar() {
    final p = _pending!;
    final canAfford = CoinService().balance >= p.price;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF241C52),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _pending = null),
              child: Text(AppStrings.cancel,
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white60)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: canAfford
                  ? ChunkyButton(
                      face: const Color(0xFF3DDC84),
                      lip: const Color(0xFF1E9E55),
                      height: 54,
                      onTap: _buying ? null : _buy,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AppStrings.buy,
                              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(width: 10),
                          const CoinIcon(size: 22),
                          const SizedBox(width: 4),
                          Text('${p.price}',
                              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    )
                  : ChunkyButton(
                      face: const Color(0xFFFFB627),
                      lip: const Color(0xFFC77F00),
                      height: 54,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoreScreen())),
                      child: Text(
                        AppStrings.needMoreCoins(p.price - CoinService().balance),
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lb = LeaderboardService();
    final avatar = lb.avatar;
    final banner = lb.banner;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1640),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(AppStrings.chooseAvatar,
                            style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                      CoinBadge(amount: CoinService().balance),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _preview(avatar, banner),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.changeLookDesc,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54),
                  ),
                  _title(AppStrings.banners),
                  for (var i = 0; i < BannerStyle.all.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _bannerCell(BannerStyle.all[i], banner)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: i + 1 < BannerStyle.all.length
                                ? _bannerCell(BannerStyle.all[i + 1], banner)
                                : const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                  _title(AppStrings.characters),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      for (final id in AvatarService.freeCharacters)
                        _avatarCell(AvatarService.character(id), avatar, free: true),
                      for (final id in AvatarService.premiumCharacters)
                        _avatarCell(AvatarService.character(id), avatar, free: false),
                    ],
                  ),
                  _title(AppStrings.emojis),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      for (final e in LeaderboardService.emojiAvatars) _avatarCell(e, avatar, free: false),
                      for (final e in StoreScreen.premiumAvatars) _avatarCell(e, avatar, free: false),
                    ],
                  ),
                ],
              ),
            ),
            if (_pending != null) _buyBar(),
          ],
        ),
      ),
    );
  }
}
