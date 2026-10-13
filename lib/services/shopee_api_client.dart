import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'shopee_auth_service.dart';
import 'shopee_config.dart';

/// Lỗi trả về từ Shopee Open API.
class ShopeeApiException implements Exception {
  final String code;
  final String message;

  ShopeeApiException(this.code, this.message);

  @override
  String toString() => 'ShopeeApiException($code): $message';

  /// true khi lỗi do access_token hết hạn / không hợp lệ -> cần refresh.
  bool get isAuthError {
    final c = code.toLowerCase();
    final m = message.toLowerCase();
    return c.contains('auth') ||
        m.contains('invalid access_token') ||
        m.contains('access_token is expired') ||
        m.contains('invalid_access_token') ||
        m.contains('token expired');
  }
}

/// Client gọi Shopee Open API (v2) đã ký chuẩn.
///
/// Mỗi request gồm query: partner_id, timestamp, access_token, shop_id, sign
/// với sign = HMAC-SHA256(partnerKey, "$partnerId$path$timestamp$token$shop").
/// Tự refresh token 1 lần khi gặp lỗi auth rồi thử lại.
class ShopeeApiClient {
  final ShopeeConfig config;
  String accessToken;
  String refreshToken;
  final String shopId;
  final http.Client _http;
  final Future<void> Function({
    required String accessToken,
    required String refreshToken,
    required int expireIn,
  })? onTokensRefreshed;

  ShopeeApiClient({
    required this.config,
    required this.accessToken,
    required this.refreshToken,
    required this.shopId,
    http.Client? httpClient,
    this.onTokensRefreshed,
  }) : _http = httpClient ?? http.Client();

  String get _host => config.environment.host;

  /// POST JSON tới [path] (vd /api/v2/product/get_item_list), trả về `data`.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _postOnce(path, body, accessToken);
    } on ShopeeApiException catch (e) {
      if (!e.isAuthError || refreshToken.isEmpty) rethrow;
      // Refresh token rồi thử lại 1 lần.
      final renewed = await ShopeeAuthService.refreshAccessToken(
        config: config,
        refreshToken: refreshToken,
        shopId: shopId,
        client: _http,
      );
      accessToken = renewed.accessToken;
      refreshToken = renewed.refreshToken;
      await onTokensRefreshed?.call(
        accessToken: renewed.accessToken,
        refreshToken: renewed.refreshToken,
        expireIn: renewed.expireIn,
      );
      return await _postOnce(path, body, accessToken);
    }
  }

  Future<Map<String, dynamic>> _postOnce(
    String path,
    Map<String, dynamic> body,
    String token,
  ) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final sign = ShopeeAuthService.sign(
      partnerKey: config.partnerKey,
      partnerId: config.partnerId,
      path: path,
      timestamp: ts,
      accessToken: token,
      shopId: shopId,
    );
    final uri = Uri.https(_host, path, {
      'partner_id': config.partnerId,
      'timestamp': '$ts',
      'access_token': token,
      'shop_id': shopId,
      'sign': sign,
    });
    final resp = await _http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw ShopeeApiException(
          'http_${resp.statusCode}', 'Shopee HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final error = data['error'];
    final isOk = error == null || error == '' || error == 0;
    if (!isOk) {
      throw ShopeeApiException(
        '$error',
        (data['message'] ?? 'Lỗi không xác định từ Shopee').toString(),
      );
    }
    final payload = data['response'] ?? data['data'] ?? {};
    return (payload as Map).cast<String, dynamic>();
  }
}
