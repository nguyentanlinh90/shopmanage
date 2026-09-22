import 'package:flutter/material.dart';

import '../widgets/empty_placeholder.dart';
import 'compare_screen.dart';

/// Trang Chủ: danh sách công cụ theo chiều dọc.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Công cụ',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B3D62), Color(0xFF1B6CA8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.compare_arrows,
                  color: Colors.white),
            ),
            title: const Text('So Sánh Sản Phẩm',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text(
              'Dán link Shopee / Lazada / TikTok để so sánh giá, lượt bán, tồn kho',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CompareScreen()),
            ),
          ),
        ),
      ],
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
