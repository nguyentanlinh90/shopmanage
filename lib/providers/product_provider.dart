import 'package:flutter/foundation.dart';

import '../models/shop_account.dart';
import '../models/shop_platform.dart';
import '../models/shop_product.dart';
import '../services/product_service.dart';
import '../services/shopee_api_client.dart';
import '../services/shopee_config.dart';
import 'shop_provider.dart';

/// State menu Sản Phẩm (shop thật): chọn shop, tải danh sách, tìm kiếm,
/// sửa giá / tồn kho.
class ProductProvider extends ChangeNotifier {
  ShopProvider? _shops;
  ShopeeConfig? _config;

  List<ShopAccount> _shopeeAccounts = [];
  ShopAccount? _selected;
  final List<ShopProduct> _products = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String _query = '';

  List<ShopAccount> get shopeeAccounts => List.unmodifiable(_shopeeAccounts);
  ShopAccount? get selected => _selected;
  List<ShopProduct> get products => List.unmodifiable(_filtered);
  int get totalCount => _products.length;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;
  String get query => _query;
  bool get hasUsableShop => _selected != null;

  List<ShopProduct> get _filtered {
    if (_query.isEmpty) return _products;
    final q = _query.toLowerCase();
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.sku ?? '').toLowerCase().contains(q) ||
            '${p.itemId}'.contains(q))
        .toList();
  }

  /// Gọi từ ProxyProvider mỗi khi ShopProvider đổi.
  void updateShops(ShopProvider shops) {
    _shops = shops;
    final list = shops.accountsOf(ShopPlatform.shopee).where((a) {
      if (a.isDemo) return true; // Demo vẫn cho vào để thử UI.
      return (a.accessToken ?? '').isNotEmpty;
    }).toList();
    _shopeeAccounts = list;
    if (_selected != null &&
        !list.any((a) => a.id == _selected!.id)) {
      _selected = null;
      _products.clear();
    }
    _selected ??= list.isNotEmpty ? list.first : null;
    notifyListeners();
  }

  void selectShop(ShopAccount? account) {
    if (account?.id == _selected?.id) return;
    _selected = account;
    _products.clear();
    _error = null;
    notifyListeners();
    if (account != null) loadProducts();
  }

  void setQuery(String q) {
    _query = q.trim();
    notifyListeners();
  }

  ShopeeApiClient _clientFor(ShopAccount account, ShopeeConfig config) {
    return ShopeeApiClient(
      config: config,
      accessToken: account.accessToken ?? '',
      refreshToken: account.refreshToken ?? '',
      shopId: account.shopId,
      onTokensRefreshed: ({required accessToken, required refreshToken, required expireIn}) async {
        final updated = ShopAccount(
          id: account.id,
          platform: account.platform,
          shopId: account.shopId,
          shopName: account.shopName,
          accessToken: accessToken,
          refreshToken: refreshToken,
          tokenExpireAt: DateTime.now().add(Duration(seconds: expireIn)),
          connectedAt: account.connectedAt,
          isDemo: account.isDemo,
        );
        await _shops?.addOrUpdate(updated);
      },
    );
  }

  /// Tải toàn bộ sản phẩm của shop đang chọn.
  Future<void> loadProducts() async {
    final account = _selected;
    if (account == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (account.isDemo) {
        await Future.delayed(const Duration(milliseconds: 500));
        _products
          ..clear()
          ..addAll(_demoProducts());
      } else {
        _config ??= await ShopeeConfig.load();
        final config = _config!;
        if (!config.isValid) {
          throw ShopeeApiException(
              'no_config', 'Chưa cấu hình Partner ID/Key Shopee');
        }
        final service = ProductService(_clientFor(account, config));
        final ids = await service.fetchAllItemIds();
        _products
          ..clear()
          ..addAll(await service.fetchItemDetails(ids));
      }
    } on ShopeeApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Lỗi kết nối: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Sửa giá 1 item (không biến thể) hoặc 1 model.
  Future<bool> editPrice({
    required ShopProduct product,
    required double price,
    int modelId = 0,
  }) async {
    final account = _selected;
    if (account == null || price <= 0) return false;
    _saving = true;
    notifyListeners();
    try {
      if (!account.isDemo) {
        _config ??= await ShopeeConfig.load();
        final service =
            ProductService(_clientFor(account, _config!));
        await service.updatePrice(
            itemId: product.itemId, price: price, modelId: modelId);
      }
      _applyLocalPrice(product, price, modelId);
      return true;
    } on ShopeeApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Sửa tồn kho 1 item (không biến thể) hoặc 1 model.
  Future<bool> editStock({
    required ShopProduct product,
    required int stock,
    int modelId = 0,
  }) async {
    final account = _selected;
    if (account == null || stock < 0) return false;
    _saving = true;
    notifyListeners();
    try {
      if (!account.isDemo) {
        _config ??= await ShopeeConfig.load();
        final service =
            ProductService(_clientFor(account, _config!));
        await service.updateStock(
            itemId: product.itemId, stock: stock, modelId: modelId);
      }
      _applyLocalStock(product, stock, modelId);
      return true;
    } on ShopeeApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Tải phân loại cho sản phẩm có biến thể (demo: sinh sẵn).
  Future<List<ProductModel>> loadModels(ShopProduct product) async {
    final account = _selected;
    if (account == null) return product.models;
    if (account.isDemo) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _demoModels(product);
    }
    _config ??= await ShopeeConfig.load();
    final service = ProductService(_clientFor(account, _config!));
    return service.fetchModels(product.itemId);
  }

  void _applyLocalPrice(ShopProduct product, double price, int modelId) {
    final i = _products.indexWhere((p) => p.itemId == product.itemId);
    if (i < 0) return;
    if (modelId == 0 || product.models.isEmpty) {
      _products[i] = product.copyWith(priceMin: price, priceMax: price);
    } else {
      final models = product.models
          .map((m) => m.modelId == modelId ? m.copyWith(price: price) : m)
          .toList();
      final prices = models.map((m) => m.price);
      _products[i] = product.copyWith(
        models: models,
        priceMin: prices.reduce((a, b) => a < b ? a : b),
        priceMax: prices.reduce((a, b) => a > b ? a : b),
      );
    }
  }

  void _applyLocalStock(ShopProduct product, int stock, int modelId) {
    final i = _products.indexWhere((p) => p.itemId == product.itemId);
    if (i < 0) return;
    if (modelId == 0 || product.models.isEmpty) {
      _products[i] = product.copyWith(totalStock: stock);
    } else {
      final models = product.models
          .map((m) => m.modelId == modelId ? m.copyWith(stock: stock) : m)
          .toList();
      _products[i] = product.copyWith(
        models: models,
        totalStock: models.fold<int>(0, (s, m) => s + m.stock),
      );
    }
  }

  // ---- Dữ liệu demo để thử UI khi chưa có shop thật ----

  List<ShopProduct> _demoProducts() => [
        ShopProduct(
          itemId: 1001,
          name: 'Áo thun nam cotton 100% co giãn 4 chiều',
          sku: 'AT-NAM-01',
          itemStatus: 'NORMAL',
          images: ['https://picsum.photos/seed/shopdemo1/300'],
          priceMin: 99000,
          priceMax: 129000,
          totalStock: 350,
          sold: 12580,
          views: 88000,
          likes: 2300,
          ratingStar: 4.8,
          ratingCount: 3120,
          createTime: DateTime.now().subtract(const Duration(days: 400)),
          updateTime: DateTime.now().subtract(const Duration(days: 2)),
          hasModel: true,
        ),
        ShopProduct(
          itemId: 1002,
          name: 'Tai nghe Bluetooth không dây chống ồn',
          sku: 'TN-BT-02',
          itemStatus: 'NORMAL',
          images: ['https://picsum.photos/seed/shopdemo2/300'],
          priceMin: 249000,
          priceMax: 249000,
          totalStock: 120,
          sold: 5320,
          views: 41000,
          likes: 980,
          ratingStar: 4.6,
          ratingCount: 1204,
          createTime: DateTime.now().subtract(const Duration(days: 200)),
          updateTime: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ];

  List<ProductModel> _demoModels(ShopProduct product) {
    if (product.itemId == 1001) {
      return [
        ProductModel(
            modelId: 1, name: 'Trắng / M', price: 99000, stock: 120),
        ProductModel(
            modelId: 2, name: 'Đen / L', price: 109000, stock: 150),
        ProductModel(
            modelId: 3, name: 'Xanh / XL', price: 129000, stock: 80),
      ];
    }
    return [];
  }
}
