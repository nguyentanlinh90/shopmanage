import 'dart:math';

import '../models/compare_product.dart';
import '../models/shop_platform.dart';

/// Kết quả parse link sản phẩm người dùng dán vào.
class ProductLinkInfo {
  final ShopPlatform? platform;
  final String keyword;
  final String raw;

  ProductLinkInfo({
    required this.platform,
    required this.keyword,
    required this.raw,
  });
}

/// Parse link Shopee / Lazada / TikTok -> sàn + từ khóa.
///
/// Ví dụ: `https://shopee.vn/Ao-thun-nam-i.12345.67890`
/// -> platform: shopee, keyword: "Ao thun nam".
ProductLinkInfo parseProductLink(String input) {
  final text = input.trim();
  final lower = text.toLowerCase();

  ShopPlatform? platform;
  if (lower.contains('shopee.')) {
    platform = ShopPlatform.shopee;
  } else if (lower.contains('lazada.')) {
    platform = ShopPlatform.lazada;
  } else if (lower.contains('tiktok.')) {
    platform = ShopPlatform.tiktok;
  }

  String keyword = text;
  final uri = Uri.tryParse(text);
  if (uri != null && uri.host.isNotEmpty) {
    final segments =
        uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      var slug = segments.last;
      // Lazada: ten-sp-123456.html -> bỏ đuôi id.
      slug = slug.replaceAll(RegExp(r'\.html?$'), '');
      slug = slug.replaceAll(RegExp(r'[-_]?i\.\d+\.\d+$'), '');
      slug = slug.replaceAll(RegExp(r'[-_]\d{4,}$'), '');
      keyword = slug.replaceAll(RegExp(r'[-_+]+'), ' ').trim();
    }
    if (keyword.isEmpty) keyword = uri.host;
  }
  // Giới hạn độ dài từ khóa để hiển thị gọn.
  if (keyword.length > 60) keyword = keyword.substring(0, 60);

  return ProductLinkInfo(platform: platform, keyword: keyword, raw: text);
}

/// Service tìm sản phẩm tương tự trên 3 sàn.
///
/// Hiện dùng dữ liệu mô phỏng (deterministic theo từ khóa) để chạy ngay.
/// Khi có API thật (Shopee Affiliate / Lazada LazOP / TikTok Shop),
/// chỉ cần thay phần `_generatePool` bằng gọi HTTP, giữ nguyên interface.
class ProductCompareService {
  static const int poolSize = 120;

  static const _titleTemplates = [
    '{k} cao cấp chính hãng',
    '{k} giá rẻ bán chạy',
    '{k} mẫu mới 2026',
    'Combo 2 {k} tiết kiệm',
    '{k} loại 1 bảo hành 12 tháng',
    '{k} nhập khẩu full box',
    '{k} freeship hỏa tốc',
    '{k} shop mall uy tín',
  ];

  static const _shopNames = [
    'Shop Uy Tín',
    'Tổng Kho Giá Sỉ',
    'Mall Chính Hãng',
    'Shop Yêu Thích+',
    'Kho Hàng SG',
    'Siêu Thị Online',
    'Shop HN Giá Rẻ',
    'Official Store',
  ];

  /// Tìm kiếm 1 trang. Trả về (items, total).
  Future<({List<CompareProduct> items, int total})> search({
    required String keyword,
    required int page,
    required int pageSize,
    required CompareSort sort,
    required Set<ShopPlatform> platforms,
  }) async {
    // Giả lập độ trễ mạng.
    await Future.delayed(
        Duration(milliseconds: page == 1 ? 600 : 400));

    final pool = _generatePool(keyword)
        .where((p) => platforms.contains(p.platform))
        .toList();
    _sort(pool, sort);

    final total = pool.length;
    final start = (page - 1) * pageSize;
    if (start >= total) return (items: <CompareProduct>[], total: total);
    final end = (start + pageSize).clamp(0, total);
    return (items: pool.sublist(start, end), total: total);
  }

  void _sort(List<CompareProduct> list, CompareSort sort) {
    switch (sort) {
      case CompareSort.bestSold:
        list.sort((a, b) => b.sold.compareTo(a.sold));
        break;
      case CompareSort.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case CompareSort.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case CompareSort.newest:
        list.sort((a, b) => b.listedDate.compareTo(a.listedDate));
        break;
      case CompareSort.stockDesc:
        list.sort((a, b) => b.stock.compareTo(a.stock));
        break;
    }
  }

  /// Sinh dữ liệu mô phỏng ổn định theo từ khóa (cùng từ khóa -> cùng kết quả).
  List<CompareProduct> _generatePool(String keyword) {
    final seed = keyword.toLowerCase().hashCode;
    final rand = Random(seed);
    final k = keyword.isEmpty ? 'Sản phẩm' : keyword;
    final platforms = ShopPlatform.values;
    final now = DateTime.now();

    return List.generate(poolSize, (i) {
      final platform = platforms[i % platforms.length];
      final template =
          _titleTemplates[rand.nextInt(_titleTemplates.length)];
      final title = template.replaceAll('{k}', k);
      final price =
          (rand.nextInt(290) + 3) * 10000.0 + rand.nextInt(9) * 1000;
      final sold = _biasedSold(rand, i);
      final stock = rand.nextInt(5000);
      final rating =
          (35 + rand.nextInt(16)) / 10.0; // 3.5 - 5.0
      final listedDate =
          now.subtract(Duration(days: rand.nextInt(730)));
      final shopId = 100000 + rand.nextInt(900000);
      final itemId = 1000000 + rand.nextInt(9000000);

      return CompareProduct(
        id: '${platform.name}_$itemId',
        platform: platform,
        title: '$title (Shop ${i + 1})',
        shopName:
            '${_shopNames[rand.nextInt(_shopNames.length)]} ${platform.label}',
        imageUrl: 'https://picsum.photos/seed/${platform.name}$itemId/300',
        price: price,
        sold: sold,
        stock: stock,
        rating: rating,
        listedDate: listedDate,
        productUrl: _productUrl(platform, k, shopId, itemId),
      );
    });
  }

  int _biasedSold(Random rand, int index) {
    // Vài sản phẩm đầu bán rất chạy để danh sách trông thực tế.
    if (index < 5) return 20000 + rand.nextInt(30000);
    if (index < 20) return 5000 + rand.nextInt(15000);
    return rand.nextInt(5000);
  }

  String _productUrl(
      ShopPlatform platform, String keyword, int shopId, int itemId) {
    final slug =
        keyword.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    switch (platform) {
      case ShopPlatform.shopee:
        return 'https://shopee.vn/$slug-i.$shopId.$itemId';
      case ShopPlatform.lazada:
        return 'https://www.lazada.vn/products/$slug-$itemId.html';
      case ShopPlatform.tiktok:
        return 'https://www.tiktok.com/@shop/product/$itemId';
    }
  }
}
