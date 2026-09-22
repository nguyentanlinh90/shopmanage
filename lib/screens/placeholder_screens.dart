import 'package:flutter/material.dart';

import '../widgets/empty_placeholder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyPlaceholder(
      icon: Icons.home_outlined,
      title: 'Trang Chủ',
      message: 'Màn hình tổng quan sẽ được phát triển sau.\n'
          'Hãy kết nối gian hàng ở menu Tài Khoản trước nhé.',
    );
  }
}

class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyPlaceholder(
      icon: Icons.inventory_2_outlined,
      title: 'Sản Phẩm',
      message:
          'Quản lý sản phẩm (đồng bộ, tồn kho, giá) sẽ được phát triển sau.',
    );
  }
}

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyPlaceholder(
      icon: Icons.receipt_long_outlined,
      title: 'Đơn Hàng',
      message: 'Quản lý đơn hàng các sàn sẽ được phát triển sau.',
    );
  }
}
