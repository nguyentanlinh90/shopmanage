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
}
