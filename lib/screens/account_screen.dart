import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/shop_platform.dart';
import '../providers/shop_provider.dart';
import '../widgets/connect_shop_sheet.dart';
import '../widgets/platform_avatar.dart';

/// Menu Tài Khoản: danh sách gian hàng đã kết nối + nút "Kết nối gian hàng".
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (context, shop, _) {
        final accounts = shop.accounts;
        return Column(
          children: [
            _SummaryHeader(shop: shop),
            Expanded(
              child: accounts.isEmpty
                  ? _EmptyState(onConnect: () => showConnectShopSheet(context))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: accounts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final acc = accounts[i];
                        return _AccountCard(accountId: acc.id);
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: () => showConnectShopSheet(context),
                  icon: const Icon(Icons.add_link),
                  label: const Text('Kết nối gian hàng'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final ShopProvider shop;

  const _SummaryHeader({required this.shop});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3D62), Color(0xFF1B6CA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final p in ShopPlatform.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  PlatformAvatar(platform: p, size: 40),
                  const SizedBox(height: 4),
                  Text(
                    '${shop.countOf(p)}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${shop.accounts.length} gian hàng đã liên kết',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shopee • Lazada • TikTok Shop',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onConnect;

  const _EmptyState({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                PlatformAvatar(platform: ShopPlatform.shopee),
                SizedBox(width: 12),
                PlatformAvatar(platform: ShopPlatform.lazada),
                SizedBox(width: 12),
                PlatformAvatar(platform: ShopPlatform.tiktok),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Chưa có gian hàng nào',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Nhấn "Kết nối gian hàng" bên dưới để liên kết\nShopee, Lazada hoặc TikTok Shop.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.add_link),
              label: const Text('Kết nối ngay'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final String accountId;

  const _AccountCard({required this.accountId});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final acc =
        shop.accounts.firstWhere((e) => e.id == accountId);
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PlatformAvatar(platform: acc.platform),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          acc.shopName.isEmpty
                              ? 'Shop ${acc.shopId}'
                              : acc.shopName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      _StatusChip(isDemo: acc.isDemo),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${acc.platform.label} • ID: ${acc.shopId}',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Liên kết: ${dateFmt.format(acc.connectedAt)}',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'disconnect') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Ngắt kết nối?'),
                      content: Text(
                          'Ngắt liên kết gian hàng "${acc.shopName.isEmpty ? acc.shopId : acc.shopName}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Ngắt kết nối'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    await context
                        .read<ShopProvider>()
                        .disconnect(acc.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Đã ngắt kết nối gian hàng')),
                      );
                    }
                  }
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'disconnect',
                  child: Row(
                    children: [
                      Icon(Icons.link_off, size: 18),
                      SizedBox(width: 8),
                      Text('Ngắt kết nối'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isDemo;

  const _StatusChip({required this.isDemo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDemo ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDemo
                ? Colors.orange.shade200
                : Colors.green.shade200),
      ),
      child: Text(
        isDemo ? 'Demo' : 'Đã kết nối',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color:
              isDemo ? Colors.orange.shade800 : Colors.green.shade700,
        ),
      ),
    );
  }
}
