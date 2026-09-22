import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manage/providers/shop_provider.dart';
import 'package:shop_manage/main.dart';

void main() {
  testWidgets('Shop Manage hien thi 4 menu', (WidgetTester tester) async {
    final provider = ShopProvider();
    await tester.pumpWidget(ShopManageApp(shopProvider: provider));
    await tester.pumpAndSettle();
    expect(find.text('Trang Chủ'), findsWidgets);
    expect(find.text('Sản Phẩm'), findsOneWidget);
    expect(find.text('Đơn Hàng'), findsOneWidget);
    expect(find.text('Tài Khoản'), findsOneWidget);
  });
}
