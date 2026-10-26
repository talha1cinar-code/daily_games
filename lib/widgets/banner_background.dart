import 'package:flutter/material.dart';
import '../models/banner_style.dart';

/// Banner arka planı. [scrim] açıksa, üzerindeki yazı okunsun diye soldan
/// sağa koyulaşan bir gölge eklenir.
class BannerBackground extends StatelessWidget {
  final String? bannerId;
  final BorderRadius borderRadius;
  final Widget child;
  final bool scrim;

  /// Sade banner'da kullanılacak zemin (ör. sıralamadaki normal satır rengi)
  final Color? plainColor;

  const BannerBackground({
    super.key,
    required this.bannerId,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.plainColor,
    this.scrim = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = BannerStyle.byId(bannerId);
    final asset = style.asset;
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(color: asset == null ? (plainColor ?? style.tint) : style.tint),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (asset != null) ...[
              Positioned.fill(child: Image.asset(asset, fit: BoxFit.cover, cacheWidth: 900)),
              if (scrim)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.1)],
                      ),
                    ),
                  ),
                ),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
