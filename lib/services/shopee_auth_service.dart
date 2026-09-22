import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'shopee_config.dart';

/// Kết quả parse từ redirect sau khi shop xác nhận ủy quyền.
class ShopeeAuthResult {
  final String code;
  final String shopId;
  final String? shopIdList;

  ShopeeAuthResult({required this.code, required this.shopId, this.shopIdList});

  /// Parse từ URL redirect, ví dụ:
  /// https://redirect/?code=xxxx&shop_id=123&shop_id_list=123
  static ShopeeAuthResult? tryParse(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final code = uri.queryParameters['code'];
    final shopId = uri.queryParameters['shop_id'] ??
        uri.queryParameters['shop_id_list'];
    if (code == null || code.isEmpty || shopId == null || shopId.isEmpty) {
      return null;
    }
    return ShopeeAuthResult(
      code: code,
      shopId: shopId,
      shopIdList: uri.queryParameters['shop_id_list'],
    );
  }
}

/// Kết quả đổi code -> access token.
class ShopeeToken {
  final String accessToken;
  final String refreshToken;
  final int expireIn;
  final String shopId;

  ShopeeToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expireIn,
    required this.shopId,
  });

  factory ShopeeToken.fromJson(Map<String, dynamic> json, String fallbackShopId) {
    return ShopeeToken(
      accessToken: (json['access_token'] ?? '') as String,
      refreshToken: (json['refresh_token'] ?? '') as String,
      expireIn: (json['expire_in'] as num?)?.toInt() ?? 14400,
      shopId: '${json['shop_id'] ?? fallbackShopId}',
    );
  }
}

/// Service xác thực Shopee Open Platform (API v2).
///
/// Tài liệu: https://open.shopee.com/developer-guide (Shop Authorisation).
/// Luồng:
/// 1. buildAuthUrl() -> mở WebView cho chủ shop bấm "Xác nhận ủy quyền".
/// 2. Shopee redirect về [redirectUrl] kèm `code` + `shop_id`.
/// 3. exchangeCodeForToken() đổi code lấy access_token / refresh_token.
class ShopeeAuthService {
  static const String _authPath = '/api/v2/shop/auth_partner';
  static const String _tokenPath = '/api/v2/auth/token/get';
  static const String _refreshPath = '/api/v2/auth/access_token/get';

  /// Chữ ký HMAC-SHA256 theo chuẩn Shopee:
  /// baseString = "$partnerId$path$timestamp[$accessToken$shopId]"
  static String sign({
    required String partnerKey,
    required String partnerId,
    required String path,
    required int timestamp,
    String? accessToken,
    String? shopId,
  }) {
    final base =
        '$partnerId$path$timestamp${accessToken ?? ''}${shopId ?? ''}';
    final hmac = Hmac(sha256, utf8.encode(partnerKey));
    return hmac.convert(utf8.encode(base)).toString();
  }

  /// Tạo URL ủy quyền để mở trong WebView / trình duyệt.
  static String buildAuthUrl(ShopeeConfig config, {int? timestamp}) {
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signature = sign(
      partnerKey: config.partnerKey,
      partnerId: config.partnerId,
      path: _authPath,
      timestamp: ts,
    );
    final uri = Uri.https(config.environment.host, _authPath, {
      'partner_id': config.partnerId,
      'timestamp': '$ts',
      'sign': signature,
      'redirect': config.redirectUrl,
    });
    return uri.toString();
  }

  /// Đổi authorization `code` lấy token.
  static Future<ShopeeToken> exchangeCodeForToken({
    required ShopeeConfig config,
    required String code,
    required String shopId,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signature = sign(
      partnerKey: config.partnerKey,
      partnerId: config.partnerId,
      path: _tokenPath,
      timestamp: ts,
    );
    final uri = Uri.https(config.environment.host, _tokenPath, {
      'partner_id': config.partnerId,
      'timestamp': '$ts',
      'sign': signature,
    });
    final resp = await httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'shop_id': int.tryParse(shopId) ?? shopId,
        'partner_id': int.tryParse(config.partnerId) ?? config.partnerId,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Shopee trả về HTTP ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['error'] != null &&
        '${data['error']}'.isNotEmpty &&
        data['error'] != 0) {
      throw Exception('Shopee lỗi ${data['error']}: ${data['message']}');
    }
    return ShopeeToken.fromJson(
        (data['data'] ?? data) as Map<String, dynamic>, shopId);
  }

  /// Làm mới access token bằng refresh token.
  static Future<ShopeeToken> refreshAccessToken({
    required ShopeeConfig config,
    required String refreshToken,
    required String shopId,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signature = sign(
      partnerKey: config.partnerKey,
      partnerId: config.partnerId,
      path: _refreshPath,
      timestamp: ts,
    );
    final uri = Uri.https(config.environment.host, _refreshPath, {
      'partner_id': config.partnerId,
      'timestamp': '$ts',
      'sign': signature,
    });
    final resp = await httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'refresh_token': refreshToken,
        'shop_id': int.tryParse(shopId) ?? shopId,
        'partner_id': int.tryParse(config.partnerId) ?? config.partnerId,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Shopee trả về HTTP ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['error'] != null &&
        '${data['error']}'.isNotEmpty &&
        data['error'] != 0) {
      throw Exception('Shopee lỗi ${data['error']}: ${data['message']}');
    }
    return ShopeeToken.fromJson(
        (data['data'] ?? data) as Map<String, dynamic>, shopId);
  }
}
