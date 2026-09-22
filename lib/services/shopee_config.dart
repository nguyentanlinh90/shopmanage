import 'package:shared_preferences/shared_preferences.dart';

/// Môi trường Shopee Open Platform.
enum ShopeeEnvironment { test, live }

extension ShopeeEnvironmentX on ShopeeEnvironment {
  String get label => this == ShopeeEnvironment.live ? 'Live' : 'Test (Sandbox)';

  /// Host theo tài liệu Shopee Open Platform v2.
  String get host {
    switch (this) {
      case ShopeeEnvironment.test:
        return 'partner.test-stable.shopeemarketplace.com';
      case ShopeeEnvironment.live:
        return 'partner.shopeemobile.com';
    }
  }
}

/// Cấu hình Partner để kết nối Shopee (Partner ID / Partner Key).
class ShopeeConfig {
  final String partnerId;
  final String partnerKey;
  final String redirectUrl;
  final ShopeeEnvironment environment;

  const ShopeeConfig({
    required this.partnerId,
    required this.partnerKey,
    required this.redirectUrl,
    required this.environment,
  });

  static const String defaultRedirectUrl = 'https://shopmanage.example.com/oauth/shopee';

  static const ShopeeConfig empty = ShopeeConfig(
    partnerId: '',
    partnerKey: '',
    redirectUrl: defaultRedirectUrl,
    environment: ShopeeEnvironment.test,
  );

  bool get isValid => partnerId.trim().isNotEmpty && partnerKey.trim().isNotEmpty;

  static const _kPartnerId = 'shopee_partner_id';
  static const _kPartnerKey = 'shopee_partner_key';
  static const _kRedirect = 'shopee_redirect_url';
  static const _kEnv = 'shopee_env';

  static Future<ShopeeConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ShopeeConfig(
      partnerId: prefs.getString(_kPartnerId) ?? '',
      partnerKey: prefs.getString(_kPartnerKey) ?? '',
      redirectUrl: prefs.getString(_kRedirect) ?? defaultRedirectUrl,
      environment: (prefs.getString(_kEnv) ?? 'test') == 'live'
          ? ShopeeEnvironment.live
          : ShopeeEnvironment.test,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPartnerId, partnerId);
    await prefs.setString(_kPartnerKey, partnerKey);
    await prefs.setString(_kRedirect, redirectUrl);
    await prefs.setString(
        _kEnv, environment == ShopeeEnvironment.live ? 'live' : 'test');
  }
}
