import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/compare_product.dart';
import '../models/shop_platform.dart';
import '../providers/compare_provider.dart';
import '../widgets/platform_avatar.dart';

/// Màn hình So Sánh Sản Phẩm: dán link 1 sản phẩm -> liệt kê sản phẩm
/// tương tự trên Shopee / Lazada / TikTok, 20 item/trang, kéo để tải thêm.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _linkCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final pos = _scrollCtrl.position;
      if (pos.pixels >= pos.maxScrollExtent - 300) {
        context.read<CompareProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _doSearch() {
    FocusScope.of(context).unfocus();
    if (_linkCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Dán link sản phẩm Shopee / Lazada / TikTok trước nhé')),
      );
      return;
    }
    context.read<CompareProvider>().search(_linkCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('So Sánh Sản Phẩm')),
      body: Column(
        children: [
          _SearchBar(controller: _linkCtrl, onSearch: _doSearch),
          _ResultHeader(onFilter: () => _openFilter(context)),
          Expanded(
            child: Consumer<CompareProvider>(
              builder: (context, state, _) {
                if (state.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!state.searched) {
                  return _EmptyHint(onTry: (link) {
                    _linkCtrl.text = link;
                    _doSearch();
                  });
                }
                if (state.items.isEmpty) {
                  return const Center(
                      child: Text('Không tìm thấy sản phẩm phù hợp bộ lọc'));
                }
                return ListView.separated(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount:
                      state.items.length + (state.hasMore || state.loadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i >= state.items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _ProductCard(product: state.items[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openFilter(BuildContext context) {
    final state = context.read<CompareProvider>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: state,
        child: const _FilterSheet(),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;

  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                hintText: 'Dán link sản phẩm Shopee / Lazada / TikTok...',
                prefixIcon: Icon(Icons.link_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSearch,
            style: FilledButton.styleFrom(
              minimumSize: const Size(52, 52),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Icon(Icons.search),
          ),
        ],
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  final VoidCallback onFilter;

  const _ResultHeader({required this.onFilter});

  @override
  Widget build(BuildContext context) {
    return Consumer<CompareProvider>(
      builder: (context, state, _) {
        if (!state.searched) return const SizedBox.shrink();
        final activeFilters =
            state.platforms.length != ShopPlatform.values.length ? 1 : 0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${state.total} sản phẩm • ${state.sort.label}',
                  style: TextStyle(
                      color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onFilter,
                icon: Badge(
                  isLabelVisible: activeFilters > 0,
                  child: const Icon(Icons.tune, size: 18),
                ),
                label: const Text('Lọc'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final void Function(String link) onTry;

  const _EmptyHint({required this.onTry});

  static const _samples = [
    ('Shopee', 'https://shopee.vn/Ao-thun-nam-cotton-i.123456.7890123'),
    ('Lazada', 'https://www.lazada.vn/products/tai-nghe-bluetooth-123456.html'),
    ('TikTok', 'https://www.tiktok.com/@shop/product/987654'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(Icons.compare_arrows,
                size: 44, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 16),
          const Text('So sánh giá 3 sàn',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Dán link 1 sản phẩm bất kỳ, app sẽ tìm các sản phẩm tương tự '
            'trên Shopee, Lazada và TikTok, sắp xếp theo lượt bán.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Thử nhanh:',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          for (final (label, link) in _samples)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.link_outlined, size: 20),
                title: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward, size: 18),
                onTap: () => onTry(link),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final CompareProduct product;

  const _ProductCard({required this.product});

  static final _priceFmt = NumberFormat('#,###', 'vi_VN');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  static String compact(int n) {
    if (n >= 1000) {
      final v = n / 1000;
      return '${v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}k';
    }
    return '$n';
  }

  Future<void> _openProduct(BuildContext context) async {
    final uri = Uri.parse(product.productUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không mở được link ${product.platform.label}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openProduct(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  product.imageUrl,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 88,
                    height: 88,
                    color: product.platform.brandColor.withValues(alpha: 0.15),
                    child: Icon(product.platform.icon,
                        color: product.platform.brandColor, size: 36),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PlatformAvatar(
                            platform: product.platform, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            product.shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                        const Icon(Icons.open_in_new,
                            size: 14, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 15, color: Colors.amber),
                        Text(' ${product.rating.toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Text('Đã bán ${compact(product.sold)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${_priceFmt.format(product.price)}₫',
                          style: const TextStyle(
                            color: Color(0xFFEE4D2D),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Kho: ${compact(product.stock)} • ${_dateFmt.format(product.listedDate)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// BottomSheet lọc: sort + chọn sàn.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late CompareSort _sort;
  late Set<ShopPlatform> _platforms;

  @override
  void initState() {
    super.initState();
    final state = context.read<CompareProvider>();
    _sort = state.sort;
    _platforms = Set.of(state.platforms);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sắp xếp',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            for (final s in CompareSort.values)
              RadioListTile<CompareSort>(
                value: s,
                groupValue: _sort,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.label, style: const TextStyle(fontSize: 14)),
                onChanged: (v) => setState(() => _sort = v!),
              ),
            const Divider(),
            const Text('Sàn áp dụng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            for (final p in ShopPlatform.values)
              CheckboxListTile(
                value: _platforms.contains(p),
                dense: true,
                contentPadding: EdgeInsets.zero,
                secondary: PlatformAvatar(platform: p, size: 30),
                title: Text(p.label, style: const TextStyle(fontSize: 14)),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _platforms.add(p);
                  } else if (_platforms.length > 1) {
                    _platforms.remove(p);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Giữ lại ít nhất 1 sàn để so sánh')),
                    );
                  }
                }),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _sort = CompareSort.bestSold;
                      _platforms = Set.of(ShopPlatform.values);
                    }),
                    child: const Text('Đặt lại'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      context
                          .read<CompareProvider>()
                          .applyFilter(_sort, _platforms);
                      Navigator.pop(context);
                    },
                    child: const Text('Áp dụng'),
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
