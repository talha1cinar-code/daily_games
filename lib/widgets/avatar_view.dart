import 'package:flutter/material.dart';
import '../services/avatar_service.dart';

/// Emoji ya da çizilmiş karakter avatarını daire içinde gösterir.
class AvatarView extends StatelessWidget {
  final String avatar;
  final double size;
  final Color? ring;

  const AvatarView({super.key, required this.avatar, this.size = 40, this.ring});

  @override
  Widget build(BuildContext context) {
    final asset = AvatarService.assetFor(avatar);
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();

    Widget emoji() => Container(
          color: const Color(0xFF6C4BFF),
          alignment: Alignment.center,
          child: Text(
            // Bilinmeyen biçimdeki eski değerler (ör. silinen fotoğraf avatarı) için varsayılan
            avatar.contains(':') ? '🙂' : avatar,
            style: TextStyle(fontSize: size * 0.55),
          ),
        );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring != null ? Border.all(color: ring!, width: size * 0.06) : null,
      ),
      child: ClipOval(
        child: asset != null
            ? Image.asset(asset, fit: BoxFit.cover, cacheWidth: px, errorBuilder: (_, _, _) => emoji())
            : emoji(),
      ),
    );
  }
}
