import 'shop_platform.dart';

/// Một gian hàng đã kết nối (Shopee / Lazada / TikTok).
class ShopAccount {
  final String id;
  final ShopPlatform platform;
  final String shopId;
  final String shopName;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? tokenExpireAt;
  final DateTime connectedAt;
  final bool isDemo;

  ShopAccount({
    required this.id,
    required this.platform,
    required this.shopId,
    required this.shopName,
    this.accessToken,
    this.refreshToken,
    this.tokenExpireAt,
    required this.connectedAt,
    this.isDemo = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'platform': platform.name,
        'shopId': shopId,
        'shopName': shopName,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'tokenExpireAt': tokenExpireAt?.toIso8601String(),
        'connectedAt': connectedAt.toIso8601String(),
        'isDemo': isDemo,
      };

  factory ShopAccount.fromJson(Map<String, dynamic> json) {
    return ShopAccount(
      id: json['id'] as String,
      platform: ShopPlatform.values.firstWhere(
        (e) => e.name == json['platform'],
        orElse: () => ShopPlatform.shopee,
      ),
      shopId: (json['shopId'] ?? '') as String,
      shopName: (json['shopName'] ?? '') as String,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      tokenExpireAt: json['tokenExpireAt'] != null
          ? DateTime.tryParse(json['tokenExpireAt'] as String)
          : null,
      connectedAt:
          DateTime.tryParse(json['connectedAt'] as String? ?? '') ??
              DateTime.now(),
      isDemo: json['isDemo'] == true,
    );
  }
}
