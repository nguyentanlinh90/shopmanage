import 'package:flutter/material.dart';

/// Các sàn TMĐT được hỗ trợ.
enum ShopPlatform { shopee, lazada, tiktok }

extension ShopPlatformX on ShopPlatform {
  String get label {
    switch (this) {
      case ShopPlatform.shopee:
        return 'Shopee';
      case ShopPlatform.lazada:
        return 'Lazada';
      case ShopPlatform.tiktok:
        return 'TikTok Shop';
    }
  }

  /// Màu thương hiệu của từng sàn.
  Color get brandColor {
    switch (this) {
      case ShopPlatform.shopee:
        return const Color(0xFFEE4D2D);
      case ShopPlatform.lazada:
        return const Color(0xFF0F146D);
      case ShopPlatform.tiktok:
        return const Color(0xFF010101);
    }
  }

  Color get brandAccent {
    switch (this) {
      case ShopPlatform.shopee:
        return const Color(0xFFFF7337);
      case ShopPlatform.lazada:
        return const Color(0xFF1A0DAB);
      case ShopPlatform.tiktok:
        return const Color(0xFFFE2C55);
    }
  }

  /// Ký tự đại diện khi vẽ avatar (S / L / T).
  String get shortChar {
    switch (this) {
      case ShopPlatform.shopee:
        return 'S';
      case ShopPlatform.lazada:
        return 'L';
      case ShopPlatform.tiktok:
        return 'T';
    }
  }

  /// Icon minh hoạ cho từng sàn (dùng Material icon gần nghĩa nhất).
  IconData get icon {
    switch (this) {
      case ShopPlatform.shopee:
        return Icons.shopping_bag_outlined;
      case ShopPlatform.lazada:
        return Icons.shopping_cart_outlined;
      case ShopPlatform.tiktok:
        return Icons.music_note_outlined;
    }
  }

  bool get isReady => this == ShopPlatform.shopee;
}
