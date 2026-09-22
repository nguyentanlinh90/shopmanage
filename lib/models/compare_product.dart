import '../models/shop_platform.dart';

/// Sản phẩm dùng cho màn hình So Sánh (tổng hợp từ 3 sàn).
class CompareProduct {
  final String id;
  final ShopPlatform platform;
  final String title;
  final String shopName;
  final String imageUrl;
  final double price;
  final int sold;
  final int stock;
  final double rating;
  final DateTime listedDate;
  final String productUrl;

  const CompareProduct({
    required this.id,
    required this.platform,
    required this.title,
    required this.shopName,
    required this.imageUrl,
    required this.price,
    required this.sold,
    required this.stock,
    required this.rating,
    required this.listedDate,
    required this.productUrl,
  });
}

/// Kiểu sắp xếp danh sách so sánh.
enum CompareSort { bestSold, priceAsc, priceDesc, newest, stockDesc }

extension CompareSortX on CompareSort {
  String get label {
    switch (this) {
      case CompareSort.bestSold:
        return 'Bán chạy nhất';
      case CompareSort.priceAsc:
        return 'Giá thấp đến cao';
      case CompareSort.priceDesc:
        return 'Giá cao đến thấp';
      case CompareSort.newest:
        return 'Mới đăng nhất';
      case CompareSort.stockDesc:
        return 'Tồn kho nhiều nhất';
    }
  }
}
