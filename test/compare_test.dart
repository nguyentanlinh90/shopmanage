import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manage/models/compare_product.dart';
import 'package:shop_manage/models/shop_platform.dart';
import 'package:shop_manage/services/product_compare_service.dart';

void main() {
  test('parse link Shopee ra san + tu khoa', () {
    final info = parseProductLink(
        'https://shopee.vn/Ao-thun-nam-cotton-i.123456.7890123');
    expect(info.platform, ShopPlatform.shopee);
    expect(info.keyword, 'Ao thun nam cotton');
  });

  test('parse link Lazada / TikTok', () {
    expect(
        parseProductLink(
                'https://www.lazada.vn/products/tai-nghe-bluetooth-123456.html')
            .platform,
        ShopPlatform.lazada);
    expect(
        parseProductLink('https://www.tiktok.com/@shop/product/987654')
            .platform,
        ShopPlatform.tiktok);
  });

  test('search tra 20 item/trang, tong 120, sort ban chay giam dan',
      () async {
    final svc = ProductCompareService();
    final p1 = await svc.search(
      keyword: 'ao thun',
      page: 1,
      pageSize: 20,
      sort: CompareSort.bestSold,
      platforms: Set.of(ShopPlatform.values),
    );
    expect(p1.items.length, 20);
    expect(p1.total, 120);
    for (var i = 0; i < p1.items.length - 1; i++) {
      expect(p1.items[i].sold >= p1.items[i + 1].sold, isTrue);
    }

    final p2 = await svc.search(
      keyword: 'ao thun',
      page: 2,
      pageSize: 20,
      sort: CompareSort.bestSold,
      platforms: Set.of(ShopPlatform.values),
    );
    expect(p2.items.length, 20);
    expect(p2.items.first.id != p1.items.first.id, isTrue);
  });

  test('loc 1 san + sort gia tang dan', () async {
    final svc = ProductCompareService();
    final r = await svc.search(
      keyword: 'ao thun',
      page: 1,
      pageSize: 20,
      sort: CompareSort.priceAsc,
      platforms: {ShopPlatform.shopee},
    );
    expect(r.total, 40);
    expect(r.items.every((e) => e.platform == ShopPlatform.shopee), isTrue);
    for (var i = 0; i < r.items.length - 1; i++) {
      expect(r.items[i].price <= r.items[i + 1].price, isTrue);
    }
  });

  test('resolve link rut gon -> ten san pham that (redirect chain)',
      () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    final port = server.port;
    server.listen((req) async {
      if (req.uri.path == '/s/abc123') {
        // Giong s.shopee.vn: redirect ve URL day du co slug ten.
        req.response.statusCode = 302;
        req.response.headers.set(
            'location', 'https://shopee.vn/Ao-thun-nam-cotton-i.12345.67890');
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    });

    final info =
        await resolveLinkInfo('http://127.0.0.1:$port/s/abc123');
    expect(info.platform, ShopPlatform.shopee);
    expect(info.keyword, 'Ao thun nam cotton');
    await server.close(force: true);
  });

  test('slug toan so -> doc ten tu og:title', () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    final port = server.port;
    server.listen((req) async {
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.html;
      req.response.write(
          '<html><head><meta property="og:title" content="Tai nghe Bluetooth X | Shopee Vi\u1ec7t Nam">'
          '</head><body></body></html>');
      await req.response.close();
    });

    final info = await resolveLinkInfo(
        'http://127.0.0.1:$port/product/123/456');
    expect(info.keyword, 'Tai nghe Bluetooth X');
    await server.close(force: true);
  });

  test('go tu khoa thuong (khong phai URL) dung truc tiep', () async {
    final info = await resolveLinkInfo('ao thun nam cotton');
    expect(info.platform, isNull);
    expect(info.keyword, 'ao thun nam cotton');
  });

  test('trang trung gian kieu Shopee (httpUrl nhung) -> ten + shop/item id',
      () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    final port = server.port;
    server.listen((req) async {
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.html;
      req.response.write(
          '<html><head></head><body><script>var x={httpUrl:'
          '"https:\\/\\/shopee.vn\\/Ao-thun-dep-i.11.22?uls_trackid=abc"};'
          '</script></body></html>');
      await req.response.close();
    });

    final info =
        await resolveLinkInfo('http://127.0.0.1:$port/s/xyz');
    expect(info.platform, ShopPlatform.shopee);
    expect(info.keyword, 'Ao thun dep');
    expect(info.keywordUncertain, isFalse);
    expect(info.shopId, '11');
    expect(info.itemId, '22');
    await server.close(force: true);
  });

  test('slug ID-only khong doc duoc -> uncertain de hoi lai user',
      () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    final port = server.port;
    server.listen((req) async {
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.html;
      req.response.write('<html><head></head><body></body></html>');
      await req.response.close();
    });

    final info = await resolveLinkInfo(
        'http://127.0.0.1:$port/product/123/456');
    expect(info.keywordUncertain, isTrue);
    await server.close(force: true);
  });
}
