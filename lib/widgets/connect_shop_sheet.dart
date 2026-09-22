import 'package:flutter/material.dart';

import '../models/shop_platform.dart';
import 'platform_avatar.dart';

/// BottomSheet "Kết nối gian hàng" với 3 lựa chọn Shopee / Lazada / TikTok.
Future<void> showConnectShopSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kết nối gian hàng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Chọn sàn thương mại điện tử để liên kết',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            for (final platform in ShopPlatform.values)
              _PlatformTile(platform: platform),
          ],
        ),
      ),
    ),
  );
}

class _PlatformTile extends StatelessWidget {
  final ShopPlatform platform;

  const _PlatformTile({required this.platform});

  @override
  Widget build(BuildContext context) {
    final ready = platform.isReady;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: PlatformAvatar(platform: platform, size: 44),
        title: Row(
          children: [
            Text(platform.label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (ready)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'Hỗ trợ',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600),
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'Sắp ra mắt',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        subtitle: Text(
          ready
              ? 'Kết nối qua Shopee Open Platform'
              : 'Đang phát triển, vui lòng quay lại sau',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).pop();
          if (ready) {
            Navigator.of(context).pushNamed('/connect/shopee');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Kết nối ${platform.label} đang phát triển, sẽ ra mắt sớm!')),
            );
          }
        },
      ),
    );
  }
}
