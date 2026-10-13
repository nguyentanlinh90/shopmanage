import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_manage/models/shop_product.dart';
import 'package:shop_manage/services/product_service.dart';
import 'package:shop_manage/services/shopee_api_client.dart';
import 'package:shop_manage/services/shopee_auth_service.dart';
import 'package:shop_manage/services/shopee_config.dart';

ShopeeConfig _testConfig() => const ShopeeConfig(
      partnerId: '123456',
      partnerKey: 'testkey',
      redirectUrl: ShopeeConfig.defaultRedirectUrl,
      environment: ShopeeEnvironment.test,
    );

/// Mock trả về đúng shape Shopee API v2.
MockClient _mockClient() {
  return MockClient((req) async {
    final path = req.url.path;
    Map<String, dynamic> ok(Map<String, dynamic> data) =>
        {'error': '', 'message': 'success', 'data': data};
    if (path.endsWith('/get_item_list')) {
      return http.Response(
          jsonEncode(ok({
            'total_count': 2,
            'has_next_page': false,
            'next_offset': 0,
            'item': [
              {'item_id': 101, 'item_status': 'NORMAL', 'update_time': 1700000000},
              {'item_id': 102, 'item_status': 'NORMAL', 'update_time': 1700000001},
            ],
          })),
          200);
    }
    if (path.endsWith('/get_item_base_info')) {
      return http.Response(
          jsonEncode(ok({
            'item_list': [
              {
                'item_id': 101,
                'item_name': 'Ao thun test',
                'item_sku': 'SKU-01',
                'item_status': 'NORMAL',
                'create_time': 1699000000,
                'update_time': 1700000000,
                'price_info': [
                  {'currency': 'VND', 'current_price': 99000}
                ],
                'stock_info_v2': {
                  'summary': {'total_available_stock': 50}
                },
                'image': {
                  'image_url_list': ['https://cf.shopee.vn/file/abc123']
                },
                'has_model': false,
              },
              {
                'item_id': 102,
                'item_name': 'Quan jean test',
                'item_status': 'NORMAL',
                'create_time': 1699000000,
                'update_time': 1700000001,
                'price_min': 199000,
                'price_max': 249000,
                'image': {'image_url_list': []},
                'has_model': true,
              },
            ],
          })),
          200);
    }
    if (path.endsWith('/get_item_extra_info')) {
      return http.Response(
          jsonEncode(ok({
            'item_list': [
              {
                'item_id': 101,
                'sale': 1500,
                'views': 20000,
                'likes': 300,
                'rating_star': 4.7,
                'comment_count': 200
              },
            ],
          })),
          200);
    }
    if (path.endsWith('/get_model_list')) {
      return http.Response(
          jsonEncode(ok({
            'model': [
              {
                'model_id': 1,
                'model_sku': 'QJ-M',
                'price_info': {'current_price': 199000},
                'stock_info': {'normal_stock': 20},
                'tier_index': ['Xanh', 'M'],
              },
            ],
          })),
          200);
    }
    if (path.endsWith('/update_price') || path.endsWith('/update_stock')) {
      return http.Response(jsonEncode(ok({})), 200);
    }
    return http.Response('not found', 404);
  });
}

ShopeeApiClient _client({http.Client? httpClient}) => ShopeeApiClient(
      config: _testConfig(),
      accessToken: 'token',
      refreshToken: 'refresh',
      shopId: '999',
      httpClient: httpClient ?? _mockClient(),
    );

void main() {
  test('sign dung format HMAC-SHA256 hex 64 ky tu', () {
    final sign = ShopeeAuthService.sign(
      partnerKey: 'key',
      partnerId: '1',
      path: '/api/v2/product/get_item_list',
      timestamp: 1700000000,
      accessToken: 'tok',
      shopId: '9',
    );
    expect(sign.length, 64);
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(sign), isTrue);
  });

  test('fetchAllItemIds lay du 2 id, dung phan trang', () async {
    final svc = ProductService(_client());
    final ids = await svc.fetchAllItemIds();
    expect(ids, [101, 102]);
  });

  test('fetchItemDetails parse base + extra', () async {
    final svc = ProductService(_client());
    final products = await svc.fetchItemDetails([101, 102]);
    expect(products.length, 2);
    final p = products.firstWhere((e) => e.itemId == 101);
    expect(p.name, 'Ao thun test');
    expect(p.priceMin, 99000);
    expect(p.totalStock, 50);
    expect(p.sold, 1500);
    expect(p.ratingStar, 4.7);
    expect(p.firstImage, 'https://cf.shopee.vn/file/abc123');
    final q = products.firstWhere((e) => e.itemId == 102);
    expect(q.hasModel, isTrue);
    expect(q.priceMin, 199000);
    expect(q.priceMax, 249000);
  });

  test('fetchModels parse phan loai', () async {
    final svc = ProductService(_client());
    final models = await svc.fetchModels(102);
    expect(models.length, 1);
    expect(models.first.name, 'Xanh / M');
    expect(models.first.price, 199000);
    expect(models.first.stock, 20);
  });

  test('updatePrice/updateStock thanh cong', () async {
    final svc = ProductService(_client());
    await svc.updatePrice(itemId: 101, price: 89000);
    await svc.updateStock(itemId: 101, stock: 60);
  });

  test('token het han -> tu refresh va thu lai', () async {
    var tokenCalls = 0;
    var refreshed = false;
    final mock = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/access_token/get')) {
        return http.Response(
            jsonEncode({
              'error': '',
              'data': {
                'access_token': 'newtok',
                'refresh_token': 'newref',
                'expire_in': 14400,
                'shop_id': 999,
              }
            }),
            200);
      }
      if (path.endsWith('/get_item_list')) {
        tokenCalls++;
        if (tokenCalls == 1) {
          return http.Response(
              jsonEncode(
                  {'error': 'error_auth', 'message': 'Invalid access_token'}),
              200);
        }
        return http.Response(
            jsonEncode({
              'error': '',
              'data': {
                'total_count': 0,
                'has_next_page': false,
                'next_offset': 0,
                'item': []
              }
            }),
            200);
      }
      return http.Response('not found', 404);
    });
    final client = ShopeeApiClient(
      config: _testConfig(),
      accessToken: 'expired',
      refreshToken: 'refresh',
      shopId: '999',
      httpClient: mock,
      onTokensRefreshed: ({required accessToken, required refreshToken, required expireIn}) async {
        refreshed = true;
      },
    );
    final ids = await ProductService(client).fetchAllItemIds();
    expect(ids, isEmpty);
    expect(refreshed, isTrue);
    expect(client.accessToken, 'newtok');
  });

  test('formatPrice VND', () {
    expect(ShopProduct.formatPrice(150000), '₫150.000');
    expect(ShopProduct.formatPrice(99000), '₫99.000');
  });
}
