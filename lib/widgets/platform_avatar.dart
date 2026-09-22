import 'package:flutter/material.dart';

import '../models/shop_platform.dart';

/// Avatar tròn theo màu thương hiệu từng sàn (S / L / T) + icon nhỏ.
class PlatformAvatar extends StatelessWidget {
  final ShopPlatform platform;
  final double size;

  const PlatformAvatar({super.key, required this.platform, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [platform.brandColor, platform.brandAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            platform.shortChar,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.44,
            ),
          ),
          Positioned(
            right: size * 0.12,
            bottom: size * 0.12,
            child: Icon(
              platform.icon,
              size: size * 0.26,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
