import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/compare_product.dart';
import '../models/shop_platform.dart';

/// Kết quả parse link sản phẩm người dùng dán vào.
class ProductLinkInfo {
  final ShopPlatform? platform;
  final String keyword;

  /// Link gốc người dùng dán.
  final String raw;

  /// true khi không đọc được tên thật (chỉ có ID) -> cần hỏi lại người dùng.
  final bool keywordUncertain;

  /// Shop ID / Item ID nếu trích được (hiển thị lúc hỏi lại).
  final String? shopId;
  final String? itemId;

  ProductLinkInfo({
    required this.platform,
    required this.keyword,
    required this.raw,
    this.keywordUncertain = false,
    this.shopId,
    this.itemId,
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
      // Dạng /<ten-sp>/<shopid>/<itemid> (share từ app): slug cuối
      // toàn số -> lấy segment đầu làm tên.
      if (_isDigits(keyword) &&
          segments.length >= 3 &&
          !_isDigits(segments.first)) {
        keyword = segments.first.replaceAll(RegExp(r'[-_+]+'), ' ').trim();
      }
    }
    if (keyword.isEmpty) keyword = uri.host;
  }
  // Giới hạn độ dài từ khóa để hiển thị gọn.
  if (keyword.length > 60) keyword = keyword.substring(0, 60);

  return ProductLinkInfo(platform: platform, keyword: keyword, raw: text);
}

/// Link rút gọn (s.shopee.vn, shope.ee, vt.tiktok.com...) phải resolve
/// ra URL đầy đủ mới lấy được tên sản phẩm.
///
/// Ví dụ: `https://s.shopee.vn/3VkSPUoPYx`
/// -> trang trung gian chứa `httpUrl:"https://shopee.vn/<slug>-i.<shop>.<item>"`
/// -> keyword từ slug. Nếu slug không đọc được (ID mã hóa / JS shell
/// không có og:title) thì đánh dấu `keywordUncertain` để hỏi lại người dùng,
/// TUYỆT ĐỐI không tìm bằng mã rút gọn.
Future<ProductLinkInfo> resolveLinkInfo(String input) async {
  final text = input.trim();
  final uri = Uri.tryParse(text);

  // Không phải URL (người dùng gõ từ khóa thường) -> dùng trực tiếp.
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    final keyword =
        text.length > 60 ? text.substring(0, 60) : text;
    return ProductLinkInfo(platform: null, keyword: keyword, raw: text);
  }

  // URL đầy đủ của sàn -> parse ngay, không cần request mạng.
  if (_isFullShopUrl(uri)) {
    final info = parseProductLink(text);
    return _withUncertaintyCheck(info, text);
  }

  // Link rút gọn / lạ -> tải trang, lần redirect + moi URL sản phẩm nhúng.
  try {
    final fetched = await _fetchWithRedirects(text)
        .timeout(const Duration(seconds: 10));

    // 1. Shopee: httpUrl:"https:\/\/shopee.vn\/<slug>-i.<shop>.<item>..."
    final embedded = _extractEmbeddedShopUrl(fetched.body);
    if (embedded != null) {
      final info = parseProductLink(embedded);
      final withIds = _attachIds(info, text, embedded);
      return await _withOgFallback(withIds, text, embedded);
    }

    // 2. Redirect thường / trang lạ: parse URL cuối, thiếu tên thì đọc og:title.
    final info = parseProductLink(fetched.finalUrl);
    return await _withOgFallback(info, text, fetched.finalUrl);
  } catch (_) {
    return _withUncertaintyCheck(parseProductLink(text), text);
  }
}

/// Đánh dấu uncertain nếu từ khóa chỉ là ID/mã (số hoặc token ngắn
/// không dấu phân tách, vd "3VkSPUoPYx", "opaanlp", "123456").
ProductLinkInfo _withUncertaintyCheck(ProductLinkInfo info, String raw) {
  final k = info.keyword;
  final compact = k.replaceAll(RegExp(r'[\s\-_.]+'), '');
  final numeric = compact.isNotEmpty && RegExp(r'^\d+$').hasMatch(compact);
  final tokenLike = !k.contains(RegExp(r'[\s\-_]')) && k.length <= 12;
  if (numeric || tokenLike) {
    return ProductLinkInfo(
      platform: info.platform,
      keyword: k,
      raw: raw,
      keywordUncertain: true,
      shopId: info.shopId,
      itemId: info.itemId,
    );
  }
  return info;
}

/// Gắn shop/item ID trích từ URL sản phẩm (hiển thị lúc hỏi lại user).
ProductLinkInfo _attachIds(
    ProductLinkInfo info, String raw, String productUrl) {
  final m = RegExp(r'/(\d+)/(\d+)').firstMatch(productUrl) ??
      RegExp(r'i\.(\d+)\.(\d+)').firstMatch(productUrl);
  if (m == null) return info;
  return ProductLinkInfo(
    platform: info.platform,
    keyword: info.keyword,
    raw: raw,
    keywordUncertain: info.keywordUncertain,
    shopId: m.group(1),
    itemId: m.group(2),
  );
}

/// Nếu từ khóa là ID/mã -> thử đọc tên thật từ og:title của trang
/// sản phẩm (hiệu quả với Lazada / TikTok / web tĩnh).
Future<ProductLinkInfo> _withOgFallback(
    ProductLinkInfo info, String raw, String pageUrl) async {
  final checked = _withUncertaintyCheck(info, raw);
  if (!checked.keywordUncertain) return checked;
  try {
    final ogTitle =
        await _fetchOgTitle(pageUrl).timeout(const Duration(seconds: 8));
    if (ogTitle != null && ogTitle.isNotEmpty) {
      return ProductLinkInfo(
        platform: info.platform,
        keyword: ogTitle,
        raw: raw,
        shopId: info.shopId,
        itemId: info.itemId,
      );
    }
  } catch (_) {
    // Giữ nguyên info cũ.
  }
  return checked;
}

/// Toàn chữ số (đã bỏ dấu phân tách).
bool _isDigits(String s) {
  final compact = s.replaceAll(RegExp(r'[\s\-_.]+'), '');
  return compact.isNotEmpty && RegExp(r'^\d+$').hasMatch(compact);
}

/// URL đã là link đầy đủ của sàn (chứa slug tên sản phẩm).
/// Lưu ý: domain rút gọn (s.shopee.vn, shope.ee, vt.tiktok.com...)
/// KHÔNG tính là full dù vẫn chứa tên sàn.
bool _isFullShopUrl(Uri uri) {
  final host = uri.host.toLowerCase();
  if (_isShortHost(host)) return false;
  return host.contains('shopee.') ||
      host.contains('lazada.') ||
      host.contains('tiktok.');
}

/// Domain rút gọn link của các sàn.
bool _isShortHost(String host) {
  final h = host.toLowerCase();
  return h.startsWith('s.shopee.') ||
      h == 'shope.ee' ||
      h.endsWith('.shope.ee') ||
      h.startsWith('s.lazada.') ||
      h.startsWith('c.lazada.') ||
      h.startsWith('vt.tiktok.') ||
      h.startsWith('vm.tiktok.');
}

/// Tải trang, lần theo redirect (tối đa 5 hop), trả về URL cuối + body.
/// Dùng cho link rút gọn (thường trả 302, hoặc 200 + URL nhúng trong JS).
Future<({String finalUrl, String body})> _fetchWithRedirects(
    String url) async {
  const ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
      'Mobile/15E148 Safari/604.1';
  final client = http.Client();
  try {
    var uri = Uri.parse(url);
    String body = '';
    for (var i = 0; i < 5; i++) {
      final req = http.Request('GET', uri)..followRedirects = false;
      req.headers['User-Agent'] = ua;
      final resp = await client.send(req);
      final bytes = await resp.stream.toBytes();
      final location = resp.headers['location'];
      if (_isRedirect(resp.statusCode) && location != null) {
        uri = uri.resolve(location);
        continue;
      }
      body = utf8.decode(bytes, allowMalformed: true);
      break;
    }
    return (finalUrl: uri.toString(), body: body);
  } finally {
    client.close();
  }
}

bool _isRedirect(int status) =>
    status == 301 ||
    status == 302 ||
    status == 303 ||
    status == 307 ||
    status == 308;

/// Moi URL sản phẩm đầy đủ nhúng trong trang trung gian.
/// - Shopee: httpUrl:"https:\/\/shopee.vn\/..."
/// - Chung: thẻ og:url trỏ sang domain đầy đủ của sàn.
String? _extractEmbeddedShopUrl(String html) {
  if (html.isEmpty) return null;
  final httpUrlMatch = RegExp(
    r'httpUrl\s*:\s*"((?:[^"\\]|\\.)*)"',
  ).firstMatch(html);
  if (httpUrlMatch != null) {
    final unescaped = _unescapeJsString(httpUrlMatch.group(1)!);
    if (_isFullShopUrl(Uri.tryParse(unescaped) ??
        Uri.parse('https://invalid'))) {
      return unescaped;
    }
  }
  final ogUrlMatch = RegExp(
    '<meta[^>]+property=["\']og:url["\'][^>]+content=["\']([^"\']+)',
    caseSensitive: false,
  ).firstMatch(html);
  if (ogUrlMatch != null) {
    final ogUrl = ogUrlMatch.group(1)!;
    final uri = Uri.tryParse(ogUrl);
    if (uri != null && _isFullShopUrl(uri) && !_isShortCodeUrl(uri)) {
      return ogUrl;
    }
  }
  return null;
}

/// URL og:url vẫn là mã rút gọn (vd s.shopee.vn/xxx) -> bỏ qua.
bool _isShortCodeUrl(Uri uri) {
  if (uri.pathSegments.length != 1) return false;
  final seg = uri.pathSegments.first;
  return seg.length <= 12 && !seg.contains(RegExp(r'[-_]'));
}

/// Gỡ escape chuỗi JS: \/ -> /, \u0026 -> &, \" -> ", \\ -> \.
String _unescapeJsString(String s) => s
    .replaceAll(r'\/', '/')
    .replaceAll(r'\u0026', '&')
    .replaceAll(r'\"', '"')
    .replaceAll('\\\\', '\\');

/// Đọc tên sản phẩm từ thẻ <meta property="og:title"> của trang.
Future<String?> _fetchOgTitle(String url) async {
  final resp = await http.get(
    Uri.parse(url),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
              'Mobile/15E148 Safari/604.1',
    },
  );
  if (resp.statusCode != 200) return null;
  final html = resp.body;
  final ogMatch = RegExp(
    '<meta[^>]+property=["\']og:title["\'][^>]+content=["\']([^"\']+)',
    caseSensitive: false,
  ).firstMatch(html);
  final raw = ogMatch?.group(1) ??
      RegExp('<title[^>]*>([^<]+)</title>', caseSensitive: false)
          .firstMatch(html)
          ?.group(1);
  if (raw == null) return null;
  var title = _decodeHtmlEntities(raw.trim());
  // Bỏ hậu tố tên sàn: "Tai nghe X | Shopee Việt Nam".
  title = title
      .replaceAll(RegExp(r'\s*[|\-–—]\s*(Shopee|Lazada|TikTok).*$',
          caseSensitive: false), '')
      .trim();
  if (title.isEmpty || title.length > 80) return null;
  return title;
}

String _decodeHtmlEntities(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#x27;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ');

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
