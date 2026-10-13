import '../models/shop_product.dart';
import 'shopee_api_client.dart';

/// Service quản lý sản phẩm shop thật qua Shopee Open API.
///
/// Dùng các endpoint public (không cần duyệt scope riêng):
/// get_item_list -> get_item_base_info (+ get_item_extra_info) ->
/// get_model_list / update_price / update_stock.
class ProductService {
  final ShopeeApiClient client;

  ProductService(this.client);

  /// Lấy toàn bộ item NORMAL (page_size 100, theo has_next_page).
  /// [maxItems] giới hạn để tránh tải quá lâu với shop lớn.
  Future<List<int>> fetchAllItemIds({int maxItems = 1000}) async {
    final ids = <int>[];
    var offset = 0;
    const pageSize = 100;
    while (ids.length < maxItems) {
      final data = await client.post('/api/v2/product/get_item_list', {
        'offset': offset,
        'page_size': pageSize,
        'item_status': ['NORMAL'],
      });
      final items = (data['item'] as List? ?? []).cast<Map<String, dynamic>>();
      for (final it in items) {
        final id = (it['item_id'] as num?)?.toInt();
        if (id != null) ids.add(id);
      }
      final hasNext = data['has_next_page'] == true;
      final nextOffset = (data['next_offset'] as num?)?.toInt() ?? 0;
      if (!hasNext || items.isEmpty) break;
      offset = nextOffset <= offset ? offset + items.length : nextOffset;
      if (ids.length >= maxItems) break;
    }
    return ids.take(maxItems).toList();
  }

  /// Lấy chi tiết 1 lô item (tối đa 50 id/lần theo giới hạn API).
  Future<List<ShopProduct>> fetchItemDetails(List<int> itemIds) async {
    final result = <ShopProduct>[];
    for (var i = 0; i < itemIds.length; i += 50) {
      final batch = itemIds.sublist(
          i, (i + 50).clamp(0, itemIds.length));
      final baseData =
          await client.post('/api/v2/product/get_item_base_info', {
        'item_id_list': batch,
      });
      final baseList =
          (baseData['item_list'] as List? ?? []).cast<Map<String, dynamic>>();

      Map<int, Map<String, dynamic>> extraById = {};
      try {
        final extraData =
            await client.post('/api/v2/product/get_item_extra_info', {
          'item_id_list': batch,
        });
        final extraList =
            (extraData['item_list'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final e in extraList) {
          final id = (e['item_id'] as num?)?.toInt();
          if (id != null) extraById[id] = e;
        }
      } catch (_) {
        // Extra info là API bổ trợ, lỗi thì vẫn hiển thị base info.
      }

      for (final b in baseList) {
        final id = (b['item_id'] as num?)?.toInt() ?? 0;
        result.add(ShopProduct.fromApi(b, extraById[id]));
      }
    }
    return result;
  }

  /// Lấy danh sách phân loại của sản phẩm có biến thể.
  Future<List<ProductModel>> fetchModels(int itemId) async {
    final data = await client.post('/api/v2/product/get_model_list', {
      'item_id': itemId,
    });
    final models =
        (data['model'] as List? ?? []).cast<Map<String, dynamic>>();
    return models.map(ProductModel.fromApi).toList();
  }

  /// Sửa giá. Sản phẩm không biến thể: [modelId] = 0.
  Future<void> updatePrice({
    required int itemId,
    required double price,
    int modelId = 0,
  }) async {
    await client.post('/api/v2/product/update_price', {
      'item_id': itemId,
      'price_list': [
        {
          'model_id': modelId,
          'original_price': price,
          'current_price': price,
        }
      ],
    });
  }

  /// Sửa tồn kho. Sản phẩm không biến thể: [modelId] = 0.
  Future<void> updateStock({
    required int itemId,
    required int stock,
    int modelId = 0,
  }) async {
    await client.post('/api/v2/product/update_stock', {
      'item_id': itemId,
      'stock_list': [
        {
          'model_id': modelId,
          'normal_stock': stock,
        }
      ],
    });
  }
}
