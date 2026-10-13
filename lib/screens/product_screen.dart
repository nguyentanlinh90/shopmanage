import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/shop_account.dart';
import '../models/shop_product.dart';
import '../providers/product_provider.dart';
import '../widgets/platform_avatar.dart';

/// Menu Sản Phẩm (shop thật): chọn shop, tìm kiếm, xem chi tiết,
/// sửa giá / tồn kho (kể cả theo phân loại).
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, state, _) {
        if (!state.hasUsableShop) {
          return _NoShop(
            onConnect: () =>
                Navigator.of(context).pushNamed('/connect/shopee'),
          );
        }
        return Column(
          children: [
            _ShopBar(
              accounts: state.shopeeAccounts,
              selected: state.selected,
              onSelect: state.selectShop,
              onReload: state.loadProducts,
            ),
            _SearchBar(
              controller: _searchCtrl,
              onChanged: state.setQuery,
            ),
            if (state.error != null)
              _ErrorBanner(
                  message: state.error!, onRetry: state.loadProducts),
            Expanded(child: _Body(state: state)),
          ],
        );
      },
    );
  }
}

class _NoShop extends StatelessWidget {
  final VoidCallback onConnect;

  const _NoShop({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(Icons.inventory_2_outlined,
                  size: 44, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            const Text('Chưa có shop để quản lý',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Kết nối gian hàng Shopee của bạn để xem\n'
              'và quản lý sản phẩm thật.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.add_link),
              label: const Text('Kết nối gian hàng'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopBar extends StatelessWidget {
  final List<ShopAccount> accounts;
  final ShopAccount? selected;
  final void Function(ShopAccount?) onSelect;
  final VoidCallback onReload;

  const _ShopBar({
    required this.accounts,
    required this.selected,
    required this.onSelect,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ShopAccount>(
                  value: selected,
                  isExpanded: true,
                  items: accounts
                      .map((a) => DropdownMenuItem(
                            value: a,
                            child: Row(
                              children: [
                                PlatformAvatar(
                                    platform: a.platform, size: 26),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    a.shopName.isEmpty
                                        ? 'Shop ${a.shopId}'
                                        : a.shopName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                if (a.isDemo)
                                  Text('Demo',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade700)),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: onSelect,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onReload,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Tìm theo tên, SKU, mã sản phẩm...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                      fontSize: 13, color: Colors.red.shade800))),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ProductProvider state;

  const _Body({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.products.isEmpty) {
      return Center(
        child: Text(
          state.query.isEmpty
              ? 'Shop chưa có sản phẩm nào'
              : 'Không tìm thấy "${state.query}"',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: state.loadProducts,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${state.totalCount} sản phẩm',
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: state.products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _ProductTile(product: state.products[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ShopProduct product;

  const _ProductTile({required this.product});

  static String compact(int n) {
    if (n >= 1000) {
      final v = n / 1000;
      return '${v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}k';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => ChangeNotifierProvider.value(
            value: context.read<ProductProvider>(),
            child: _ProductDetail(productId: product.itemId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  product.firstImage,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_outlined,
                        color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${product.itemId}'
                      '${product.sku != null && product.sku!.isNotEmpty ? ' • ${product.sku}' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          product.priceLabel,
                          style: const TextStyle(
                            color: Color(0xFFEE4D2D),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 13, color: Colors.amber),
                        Text(' ${product.ratingStar.toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 8),
                        Text('Đã bán ${compact(product.sold)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600)),
                        const Spacer(),
                        Text('Kho: ${compact(product.totalStock)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600)),
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

/// Chi tiết sản phẩm: ảnh, thông số, phân loại, sửa giá/kho.
class _ProductDetail extends StatefulWidget {
  final int productId;

  const _ProductDetail({required this.productId});

  @override
  State<_ProductDetail> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<_ProductDetail> {
  List<ProductModel>? _models;
  bool _loadingModels = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProductProvider>();
    final product =
        provider.products.firstWhere((p) => p.itemId == widget.productId);
    if (product.hasModel) {
      _loadingModels = true;
      provider.loadModels(product).then((models) {
        if (mounted) {
          setState(() {
            _models = models;
            _loadingModels = false;
          });
        }
      });
    } else {
      _models = const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, state, _) {
        final product = state.products.firstWhere(
          (p) => p.itemId == widget.productId,
          orElse: () => state.products.first,
        );
        final dateFmt = DateFormat('dd/MM/yyyy');
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.images.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: PageView(
                      children: product.images
                          .take(5)
                          .map((u) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    u,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                          Icons.image_outlined),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(product.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '#${product.itemId}'
                  '${product.sku != null && product.sku!.isNotEmpty ? ' • SKU: ${product.sku}' : ''}',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                Text(
                  product.priceLabel,
                  style: const TextStyle(
                    color: Color(0xFFEE4D2D),
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatChip(Icons.star, '${product.ratingStar}'),
                    _StatChip(Icons.shopping_bag_outlined,
                        'Đã bán ${product.sold}'),
                    _StatChip(Icons.inventory_2_outlined,
                        'Kho ${product.totalStock}'),
                    _StatChip(Icons.visibility_outlined,
                        '${product.views} lượt xem'),
                    if (product.createTime != null)
                      _StatChip(Icons.calendar_today_outlined,
                          'Đăng ${dateFmt.format(product.createTime!)}'),
                  ],
                ),
                const SizedBox(height: 16),
                if (product.hasModel) ...[
                  const Text('Phân loại',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_loadingModels)
                    const Center(child: CircularProgressIndicator())
                  else if ((_models ?? []).isEmpty)
                    Text('Không tải được phân loại',
                        style: TextStyle(color: Colors.grey.shade600))
                  else
                    for (final m in _models!)
                      _ModelTile(product: product, model: m),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _editPrice(context, state, product, 0),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Sửa giá'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _editStock(context, state, product, 0),
                          icon: const Icon(
                              Icons.inventory_2_outlined, size: 18),
                          label: const Text('Sửa kho'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editPrice(BuildContext context, ProductProvider state,
      ShopProduct product, int modelId) async {
    final current = modelId == 0
        ? product.priceMin
        : product.models
            .firstWhere((m) => m.modelId == modelId,
                orElse: () => product.models.first)
            .price;
    final value = await _askNumber(
      context,
      title: 'Sửa giá bán',
      initial: current.toInt().toString(),
      suffix: '₫',
    );
    if (value == null || !context.mounted) return;
    final ok = await state.editPrice(
        product: product, price: value.toDouble(), modelId: modelId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Đã cập nhật giá'
              : 'Cập nhật thất bại: ${state.error ?? ''}')),
    );
  }

  Future<void> _editStock(BuildContext context, ProductProvider state,
      ShopProduct product, int modelId) async {
    final current = modelId == 0
        ? product.totalStock
        : product.models
            .firstWhere((m) => m.modelId == modelId,
                orElse: () => product.models.first)
            .stock;
    final value = await _askNumber(
      context,
      title: 'Sửa tồn kho',
      initial: '$current',
      suffix: 'sp',
    );
    if (value == null || !context.mounted) return;
    final ok = await state.editStock(
        product: product, stock: value.toInt(), modelId: modelId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Đã cập nhật tồn kho'
              : 'Cập nhật thất bại: ${state.error ?? ''}')),
    );
  }

  Future<num?> _askNumber(
    BuildContext context, {
    required String title,
    required String initial,
    required String suffix,
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: suffix,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) =>
              Navigator.pop(ctx, num.tryParse(v.replaceAll('.', ''))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx, num.tryParse(ctrl.text.replaceAll('.', ''))),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final ShopProduct product;
  final ProductModel model;

  const _ModelTile({required this.product, required this.model});

  @override
  Widget build(BuildContext context) {
    final state = context.read<ProductProvider>();
    final detail = context
        .findAncestorStateOfType<_ProductDetailState>()!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(model.name ?? model.sku ?? 'Phân loại ${model.modelId}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(
          '${ShopProduct.formatPrice(model.price)} • Kho: ${model.stock}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'price') {
              detail._editPrice(context, state, product, model.modelId);
            } else {
              detail._editStock(context, state, product, model.modelId);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'price', child: Text('Sửa giá')),
            PopupMenuItem(value: 'stock', child: Text('Sửa kho')),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
