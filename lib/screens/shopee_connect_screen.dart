import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/shop_account.dart';
import '../models/shop_platform.dart';
import '../providers/shop_provider.dart';
import '../services/shopee_auth_service.dart';
import '../services/shopee_config.dart';

/// Màn hình kết nối gian hàng Shopee.
///
/// Hỗ trợ 2 cách:
/// A. Chính thức qua Shopee Open Platform (cần Partner ID / Partner Key).
/// B. Chế độ Demo (không cần key) để trải nghiệm UI ngay.
class ShopeeConnectScreen extends StatefulWidget {
  const ShopeeConnectScreen({super.key});

  @override
  State<ShopeeConnectScreen> createState() => _ShopeeConnectScreenState();
}

class _ShopeeConnectScreenState extends State<ShopeeConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _partnerIdCtrl = TextEditingController();
  final _partnerKeyCtrl = TextEditingController();
  final _redirectCtrl =
      TextEditingController(text: ShopeeConfig.defaultRedirectUrl);
  final _codeCtrl = TextEditingController();
  final _shopIdCtrl = TextEditingController();

  ShopeeEnvironment _env = ShopeeEnvironment.test;
  bool _loadingConfig = true;
  bool _obscureKey = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    final cfg = await ShopeeConfig.load();
    _partnerIdCtrl.text = cfg.partnerId;
    _partnerKeyCtrl.text = cfg.partnerKey;
    _redirectCtrl.text =
        cfg.redirectUrl.isEmpty ? ShopeeConfig.defaultRedirectUrl : cfg.redirectUrl;
    _env = cfg.environment;
    if (mounted) setState(() => _loadingConfig = false);
  }

  @override
  void dispose() {
    _partnerIdCtrl.dispose();
    _partnerKeyCtrl.dispose();
    _redirectCtrl.dispose();
    _codeCtrl.dispose();
    _shopIdCtrl.dispose();
    super.dispose();
  }

  ShopeeConfig _currentConfig() => ShopeeConfig(
        partnerId: _partnerIdCtrl.text.trim(),
        partnerKey: _partnerKeyCtrl.text.trim(),
        redirectUrl: _redirectCtrl.text.trim().isEmpty
            ? ShopeeConfig.defaultRedirectUrl
            : _redirectCtrl.text.trim(),
        environment: _env,
      );

  Future<void> _saveConfig() async {
    await _currentConfig().save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu cấu hình Shopee')),
    );
  }

  /// Mở WebView ủy quyền Shopee.
  Future<void> _startOAuth() async {
    if (!_formKey.currentState!.validate()) return;
    final cfg = _currentConfig();
    await cfg.save();
    if (!mounted) return;
    final authUrl = ShopeeAuthService.buildAuthUrl(cfg);
    final result = await Navigator.of(context).push<ShopeeAuthResult>(
      MaterialPageRoute(
        builder: (_) => ShopeeWebViewScreen(
          authUrl: authUrl,
          redirectPrefix: cfg.redirectUrl,
        ),
      ),
    );
    if (result != null) {
      _codeCtrl.text = result.code;
      _shopIdCtrl.text = result.shopId;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Đã nhận code, Shop ID: ${result.shopId}. Nhấn "Đổi code lấy token" để hoàn tất.')),
        );
      }
    }
  }

  /// Đổi code -> token -> lưu gian hàng.
  Future<void> _exchangeAndSave() async {
    final cfg = _currentConfig();
    final code = _codeCtrl.text.trim();
    final shopId = _shopIdCtrl.text.trim();
    if (code.isEmpty || shopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vui lòng nhập đầy đủ code và shop_id')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final token = await ShopeeAuthService.exchangeCodeForToken(
        config: cfg,
        code: code,
        shopId: shopId,
      );
      final account = ShopAccount(
        id: 'shopee_${token.shopId}_${DateTime.now().millisecondsSinceEpoch}',
        platform: ShopPlatform.shopee,
        shopId: token.shopId,
        shopName: 'Shopee Shop ${token.shopId}',
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        tokenExpireAt:
            DateTime.now().add(Duration(seconds: token.expireIn)),
        connectedAt: DateTime.now(),
      );
      if (!mounted) return;
      await context.read<ShopProvider>().addOrUpdate(account);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã kết nối ${account.shopName}')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đổi token thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kết nối nhanh chế độ Demo (không cần Partner Key).
  Future<void> _connectDemo() async {
    final shopId = _shopIdCtrl.text.trim().isEmpty
        ? '123456'
        : _shopIdCtrl.text.trim();
    final account = ShopAccount(
      id: 'shopee_demo_$shopId',
      platform: ShopPlatform.shopee,
      shopId: shopId,
      shopName: 'Shopee Demo Shop $shopId',
      connectedAt: DateTime.now(),
      isDemo: true,
    );
    await context.read<ShopProvider>().addOrUpdate(account);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã thêm gian hàng Demo')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _openInBrowser() async {
    final cfg = _currentConfig();
    final url = Uri.parse(ShopeeAuthService.buildAuthUrl(cfg));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kết nối Shopee')),
      body: _loadingConfig
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IntroCard(onOpenDocs: _openDocs),
                  const SizedBox(height: 16),
                  const Text('1. Cấu hình Partner (Shopee Open Platform)',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _partnerIdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Partner ID *',
                            hintText: 'VD: 123456',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Nhập Partner ID'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _partnerKeyCtrl,
                          obscureText: _obscureKey,
                          decoration: InputDecoration(
                            labelText: 'Partner Key *',
                            hintText: 'Dán key từ open.shopee.com',
                            prefixIcon: const Icon(Icons.key_outlined),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                  () => _obscureKey = !_obscureKey),
                              icon: Icon(_obscureKey
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Nhập Partner Key'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _redirectCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Redirect URL',
                            prefixIcon: Icon(Icons.link_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Môi trường:'),
                            const SizedBox(width: 8),
                            SegmentedButton<ShopeeEnvironment>(
                              segments: const [
                                ButtonSegment(
                                    value: ShopeeEnvironment.test,
                                    label: Text('Test')),
                                ButtonSegment(
                                    value: ShopeeEnvironment.live,
                                    label: Text('Live')),
                              ],
                              selected: {_env},
                              onSelectionChanged: (s) =>
                                  setState(() => _env = s.first),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _saveConfig,
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: const Text('Lưu'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('2. Ủy quyền gian hàng',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _startOAuth,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Mở trang ủy quyền Shopee'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openInBrowser,
                    icon: const Icon(Icons.open_in_browser_outlined),
                    label: const Text('Mở bằng trình duyệt ngoài'),
                  ),
                  const SizedBox(height: 16),
                  const Text('3. Đổi code lấy token',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Authorization code',
                      hintText: 'Tự điền sau redirect, hoặc copy từ URL',
                      prefixIcon: Icon(Icons.qr_code_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _shopIdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Shop ID',
                      hintText: 'VD: 123456',
                      prefixIcon: Icon(Icons.store_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _exchangeAndSave,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.swap_horiz),
                    label: const Text('Đổi code & lưu gian hàng'),
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEE4D2D)),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.science_outlined,
                        color: Colors.orange),
                    title: const Text('Chưa có Partner Key?',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Dùng chế độ Demo để trải nghiệm luồng kết nối ngay.'),
                    trailing: TextButton(
                      onPressed: _connectDemo,
                      child: const Text('Thử Demo'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _openDocs() async {
    final url = Uri.parse('https://open.shopee.com/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

class _IntroCard extends StatelessWidget {
  final VoidCallback onOpenDocs;

  const _IntroCard({required this.onOpenDocs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEE4D2D), Color(0xFFFF7337)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shopping_bag,
                color: Color(0xFFEE4D2D), size: 30),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shopee Open Platform (API v2)',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(
                  'Đăng ký App tại open.shopee.com để lấy Partner ID / Key, sau đó ủy quyền shop.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpenDocs,
            icon: const Icon(Icons.open_in_new, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// WebView mở trang ủy quyền Shopee, tự bắt redirect chứa code + shop_id.
class ShopeeWebViewScreen extends StatefulWidget {
  final String authUrl;
  final String redirectPrefix;

  const ShopeeWebViewScreen({
    super.key,
    required this.authUrl,
    required this.redirectPrefix,
  });

  @override
  State<ShopeeWebViewScreen> createState() => _ShopeeWebViewScreenState();
}

class _ShopeeWebViewScreenState extends State<ShopeeWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (req) {
            final parsed = ShopeeAuthResult.tryParse(req.url);
            // Ưu tiên khớp redirect đã khai báo, nhưng vẫn chấp nhận mọi URL có code+shop_id.
            if (parsed != null && !_handled) {
              final redirectHost = Uri.tryParse(widget.redirectPrefix)?.host;
              final reqHost = Uri.tryParse(req.url)?.host;
              final matchesRedirect =
                  redirectHost == null || redirectHost.isEmpty
                      ? true
                      : reqHost == redirectHost ||
                          req.url.startsWith(widget.redirectPrefix);
              if (matchesRedirect) {
                _handled = true;
                Navigator.of(context).pop(parsed);
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ủy quyền Shopee'),
        actions: [
          IconButton(
            tooltip: 'Dán code thủ công',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Sau khi bấm "Xác nhận ủy quyền" trên trang Shopee, app sẽ tự nhận code và quay lại.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
