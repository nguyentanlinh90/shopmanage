/// Sản phẩm Shopee (shop thật) + phân loại (model).
class ShopProduct {
  final int itemId;
  final String name;
  final String? sku;
  final String itemStatus;
  final List<String> images;
  final double priceMin;
  final double priceMax;
  final int totalStock;
  final int sold;
  final int views;
  final int likes;
  final double ratingStar;
  final int ratingCount;
  final DateTime? createTime;
  final DateTime? updateTime;
  final bool hasModel;
  final List<ProductModel> models;

  ShopProduct({
    required this.itemId,
    required this.name,
    this.sku,
    required this.itemStatus,
    required this.images,
    required this.priceMin,
    required this.priceMax,
    required this.totalStock,
    this.sold = 0,
    this.views = 0,
    this.likes = 0,
    this.ratingStar = 0,
    this.ratingCount = 0,
    this.createTime,
    this.updateTime,
    this.hasModel = false,
    this.models = const [],
  });

  String get firstImage => images.isNotEmpty ? images.first : '';

  String get priceLabel {
    if (priceMin == priceMax) return formatPrice(priceMin);
    return '${formatPrice(priceMin)} - ${formatPrice(priceMax)}';
  }

  ShopProduct copyWith({
    double? priceMin,
    double? priceMax,
    int? totalStock,
    List<ProductModel>? models,
  }) {
    return ShopProduct(
      itemId: itemId,
      name: name,
      sku: sku,
      itemStatus: itemStatus,
      images: images,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      totalStock: totalStock ?? this.totalStock,
      sold: sold,
      views: views,
      likes: likes,
      ratingStar: ratingStar,
      ratingCount: ratingCount,
      createTime: createTime,
      updateTime: updateTime,
      hasModel: hasModel,
      models: models ?? this.models,
    );
  }

  /// Parse từ get_item_base_info + get_item_extra_info (đã merge).
  factory ShopProduct.fromApi(
      Map<String, dynamic> base, Map<String, dynamic>? extra) {
    DateTime? toTime(dynamic v) {
      if (v is int && v > 0) {
        return DateTime.fromMillisecondsSinceEpoch(v * 1000);
      }
      return null;
    }

    final images = <String>[];
    final img = base['image'];
    if (img is Map && img['image_url_list'] is List) {
      for (final u in (img['image_url_list'] as List)) {
        images.add(normalizeImageUrl('$u'));
      }
    }

    double priceOf(Map<String, dynamic> p) =>
        (p['current_price'] as num?)?.toDouble() ??
        (p['original_price'] as num?)?.toDouble() ??
        0;

    double min = double.infinity;
    double max = 0;
    final priceInfo = base['price_info'];
    if (priceInfo is List && priceInfo.isNotEmpty) {
      for (final p in priceInfo.cast<Map<String, dynamic>>()) {
        final v = priceOf(p);
        if (v < min) min = v;
        if (v > max) max = v;
      }
    } else {
      min = _num(base['price_min']).toDouble();
      max = _num(base['price_max']).toDouble();
      if (max == 0) max = min;
    }
    if (min == double.infinity) min = 0;

    int stock = 0;
    final stockV2 = base['stock_info_v2'];
    if (stockV2 is Map) {
      final summary = stockV2['summary'];
      if (summary is Map) {
        stock = _num(summary['total_available_stock']).toInt();
      } else {
        stock = _num(stockV2['total_available_stock']).toInt();
      }
    }
    if (stock == 0) {
      stock = _num((base['stock_info'] as Map?)?['normal_stock']).toInt();
    }

    return ShopProduct(
      itemId: _num(base['item_id']).toInt(),
      name: (base['item_name'] ?? '').toString(),
      sku: base['item_sku']?.toString(),
      itemStatus: (base['item_status'] ?? '').toString(),
      images: images,
      priceMin: min,
      priceMax: max,
      totalStock: stock,
      sold: _num(extra?['sale']).toInt(),
      views: _num(extra?['views']).toInt(),
      likes: _num(extra?['likes']).toInt(),
      ratingStar: _num(extra?['rating_star']).toDouble(),
      ratingCount: _num(extra?['comment_count'] ?? extra?['rating_count'])
          .toInt(),
      createTime: toTime(base['create_time']),
      updateTime: toTime(base['update_time']),
      hasModel: base['has_model'] == true,
    );
  }

  static num _num(dynamic v) => v is num ? v : 0;

  /// Chuẩn hóa URL ảnh: API thường trả full URL, nếu chỉ là hash thì
  /// ghép với CDN Shopee.
  static String normalizeImageUrl(String u) {
    if (u.startsWith('http')) return u;
    if (u.isEmpty) return '';
    return 'https://cf.shopee.vn/file/$u';
  }

  /// Giá Shopee v2 trả theo đơn vị tiền thật (vd 150000 = ₫150.000).
  static String formatPrice(double v) {
    final n = v.toInt();
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '₫${buf.toString()}';
  }
}

/// Phân loại hàng (model) của sản phẩm có biến thể.
class ProductModel {
  final int modelId;
  final String? sku;
  final String? name;
  final double price;
  final int stock;

  ProductModel({
    required this.modelId,
    this.sku,
    this.name,
    required this.price,
    required this.stock,
  });

  factory ProductModel.fromApi(Map<String, dynamic> json) {
    double price = 0;
    final pi = json['price_info'];
    if (pi is Map) {
      price = (pi['current_price'] as num?)?.toDouble() ??
          (pi['original_price'] as num?)?.toDouble() ??
          0;
    } else {
      price = (json['price'] as num?)?.toDouble() ?? 0;
    }
    int stock = 0;
    final si = json['stock_info'];
    if (si is Map) {
      stock = (si['normal_stock'] as num?)?.toInt() ?? 0;
    }
    if (stock == 0) {
      final v2 = json['stock_info_v2'];
      if (v2 is Map && v2['summary'] is Map) {
        stock = ((v2['summary'] as Map)['total_available_stock'] as num?)
                ?.toInt() ??
            0;
      }
    }
    if (stock == 0) {
      stock = (json['current_stock'] as num?)?.toInt() ?? 0;
    }
    var name = json['model_name']?.toString() ?? json['name']?.toString();
    final tier = json['tier_index'];
    if ((name == null || name.isEmpty) && tier is List) {
      name = tier.join(' / ');
    }
    return ProductModel(
      modelId: (json['model_id'] as num?)?.toInt() ?? 0,
      sku: json['model_sku']?.toString(),
      name: name,
      price: price,
      stock: stock,
    );
  }

  ProductModel copyWith({double? price, int? stock}) => ProductModel(
        modelId: modelId,
        sku: sku,
        name: name,
        price: price ?? this.price,
        stock: stock ?? this.stock,
      );
}
