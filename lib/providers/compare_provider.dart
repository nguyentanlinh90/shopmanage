import 'package:flutter/foundation.dart';

import '../models/compare_product.dart';
import '../models/shop_platform.dart';
import '../services/product_compare_service.dart';

/// State cho màn hình So Sánh Sản Phẩm: query, phân trang, sort, lọc sàn.
class CompareProvider extends ChangeNotifier {
  static const int pageSize = 20;

  final ProductCompareService _service = ProductCompareService();

  String _keyword = '';
  ShopPlatform? _sourcePlatform;
  final List<CompareProduct> _items = [];
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _searched = false;
  CompareSort _sort = CompareSort.bestSold;
  Set<ShopPlatform> _platforms = Set.of(ShopPlatform.values);

  String get keyword => _keyword;
  ShopPlatform? get sourcePlatform => _sourcePlatform;
  List<CompareProduct> get items => List.unmodifiable(_items);
  int get total => _total;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get searched => _searched;
  CompareSort get sort => _sort;
  Set<ShopPlatform> get platforms => Set.unmodifiable(_platforms);
  bool get hasMore => _searched && _items.length < _total;

  /// Bắt đầu tìm kiếm mới từ link / từ khóa người dùng nhập.
  Future<void> search(String input) async {
    final info = parseProductLink(input);
    if (info.keyword.isEmpty) return;
    _keyword = info.keyword;
    _sourcePlatform = info.platform;
    _items.clear();
    _page = 0;
    _total = 0;
    _searched = true;
    _loading = true;
    notifyListeners();

    final result = await _service.search(
      keyword: _keyword,
      page: 1,
      pageSize: pageSize,
      sort: _sort,
      platforms: _platforms,
    );
    _items.addAll(result.items);
    _total = result.total;
    _page = 1;
    _loading = false;
    notifyListeners();
  }

  /// Tải thêm 20 sản phẩm khi kéo xuống cuối.
  Future<void> loadMore() async {
    if (_loading || _loadingMore || !hasMore) return;
    _loadingMore = true;
    notifyListeners();

    final result = await _service.search(
      keyword: _keyword,
      page: _page + 1,
      pageSize: pageSize,
      sort: _sort,
      platforms: _platforms,
    );
    _items.addAll(result.items);
    _total = result.total;
    _page += 1;
    _loadingMore = false;
    notifyListeners();
  }

  /// Đổi sort / lọc sàn -> tìm lại từ trang 1.
  Future<void> applyFilter(CompareSort sort, Set<ShopPlatform> platforms) async {
    if (platforms.isEmpty) return;
    _sort = sort;
    _platforms = Set.of(platforms);
    notifyListeners();
    if (_searched && _keyword.isNotEmpty) {
      await search(_keyword);
    }
  }
}
