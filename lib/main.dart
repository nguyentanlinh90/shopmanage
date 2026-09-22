import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/shop_provider.dart';
import 'screens/main_shell.dart';
import 'screens/shopee_connect_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final shopProvider = ShopProvider();
  await shopProvider.load();
  runApp(ShopManageApp(shopProvider: shopProvider));
}

/// App Shop Manage - quản lý gian hàng Shopee / Lazada / TikTok.
class ShopManageApp extends StatelessWidget {
  final ShopProvider shopProvider;

  const ShopManageApp({super.key, required this.shopProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: shopProvider,
      child: MaterialApp(
        title: 'Shop Manage',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const MainShell(),
        routes: {
          '/connect/shopee': (_) => const ShopeeConnectScreen(),
        },
      ),
    );
  }
}
