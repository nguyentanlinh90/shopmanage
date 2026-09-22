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

  /// true khi resolve xong mà không đọc được tên -> UI hỏi lại người dùng.
  bool _needsKeyword = false;
  ProductLinkInfo? _pendingInfo;
  bool get needsKeyword => _needsKeyword;
  ProductLinkInfo? get pendingInfo => _pendingInfo;

  /// Bắt đầu tìm kiếm mới từ link / từ khóa người dùng nhập.
  /// Link rút gọn (s.shopee.vn...) được resolve ra tên sản phẩm thật trước.
  /// Nếu không đọc được tên (chỉ có ID) -> dừng lại, đặt needsKeyword
  /// để UI hỏi tên, KHÔNG tìm bằng mã ID.
  Future<void> search(String input) async {
    if (input.trim().isEmpty) return;
    _items.clear();
    _page = 0;
    _total = 0;
    _searched = false;
    _needsKeyword = false;
    _pendingInfo = null;
    _loading = true;
    _loadingMore = false;
    notifyListeners();

    // Resolve link rút gọn -> tên sản phẩm (có gọi mạng, tối đa ~18s).
    final info = await resolveLinkInfo(input);
    if (info.keyword.isEmpty) {
      _loading = false;
      notifyListeners();
      return;
    }
    if (info.keywordUncertain) {
      _loading = false;
      _needsKeyword = true;
      _pendingInfo = info;
      notifyListeners();
      return;
    }
    await searchResolved(keyword: info.keyword, source: info.platform);
  }

  /// Chạy tìm kiếm với từ khóa đã chốt (từ link hoặc user nhập tay).
  Future<void> searchResolved(
      {required String keyword, ShopPlatform? source}) async {
    _keyword = keyword;
    _sourcePlatform = source;
    _items.clear();
    _page = 0;
    _total = 0;
    _searched = true;
    _needsKeyword = false;
    _pendingInfo = null;
    _loading = true;
    _loadingMore = false;
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

  /// User xác nhận tên sản phẩm sau dialog hỏi lại.
  Future<void> confirmKeyword(String keyword) =>
      searchResolved(keyword: keyword, source: _pendingInfo?.platform);

  /// User hủy dialog hỏi tên.
  void cancelKeyword() {
    _needsKeyword = false;
    _pendingInfo = null;
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
