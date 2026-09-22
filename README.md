# Shop Manage

App Flutter quản lý gian hàng Shopee / Lazada / TikTok Shop.

- Tên app: **Shop Manage**
- 4 menu bottom: **Trang Chủ, Sản Phẩm, Đơn Hàng, Tài Khoản**
  - Trang Chủ / Sản Phẩm / Đơn Hàng: màn hình chờ, làm sau.
  - Tài Khoản: danh sách gian hàng đã liên kết + nút **Kết nối gian hàng** (chọn Shopee / Lazada / TikTok).
- **Shopee đã làm trước**: kết nối thật qua Shopee Open Platform (API v2) + chế độ Demo.

## Chạy app

```bash
cd shop_manage
flutter pub get
flutter run
```

## Kết nối Shopee (thật)

1. Đăng ký App tại https://open.shopee.com/ để lấy **Partner ID** và **Partner Key**,
   khai báo **Redirect URL** (mặc định app dùng
   `https://shopmanage.example.com/oauth/shopee` — nên đổi thành URL bạn
   đã đăng ký với Shopee; với mobile có thể dùng custom scheme).
2. Mở app → menu **Tài Khoản** → **Kết nối gian hàng** → **Shopee**.
3. Nhập Partner ID / Partner Key, chọn môi trường **Test** (sandbox) hoặc **Live**, bấm **Lưu**.
4. Bấm **Mở trang ủy quyền Shopee** → đăng nhập tài khoản seller → bấm xác nhận.
5. App tự bắt redirect chứa `code` + `shop_id`, sau đó bấm
   **Đổi code & lưu gian hàng** để đổi token (`POST /api/v2/auth/token/get`)
   và lưu vào danh sách.

Luồng ký (sign) theo chuẩn Shopee:
`HMAC-SHA256(partnerKey, "$partnerId$path$timestamp")` cho bước auth,
và thêm access_token/shop khi gọi API shop.

Code liên quan:
- `lib/services/shopee_config.dart` — lưu Partner ID/Key/Redirect/Env.
- `lib/services/shopee_auth_service.dart` — tạo auth URL, đổi code lấy token, refresh token.
- `lib/screens/shopee_connect_screen.dart` — UI cấu hình + WebView bắt `code`.

Chưa có key? Dùng nút **Thử Demo** để thêm gian hàng demo trải nghiệm UI.

## Lazada / TikTok

Hiện hiển thị **Sắp ra mắt**. Khi bấm sẽ báo snackbar, chờ phát triển tương tự
(Lazada OAuth2 `auth/token`, TikTok Shop Authorization).

## Cấu trúc

```
lib/
  main.dart
  models/ (shop_platform, shop_account)
  providers/ (shop_provider - lưu SharedPreferences)
  services/ (shopee_config, shopee_auth_service)
  screens/ (main_shell, placeholder_screens, account_screen, shopee_connect_screen)
  widgets/ (platform_avatar, connect_shop_sheet, empty_placeholder)
  theme/ (app_theme)
assets/icon/app_icon.png (tự vẽ: mái hiên shop + túi S)
```

Icon app: `assets/icon/app_icon.png`, đã generate launcher Android/iOS bằng
`flutter_launcher_icons`. Icon menu: Material icon phù hợp từng tab
(home / inventory / receipt / person), avatar sàn vẽ gradient theo màu thương hiệu.
