import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop_account.dart';
import '../models/shop_platform.dart';

/// Quản lý danh sách gian hàng đã kết nối, lưu local bằng SharedPreferences.
class ShopProvider extends ChangeNotifier {
  static const String storageKey = 'shop_accounts_v1';

  final List<ShopAccount> _accounts = [];
  bool _loaded = false;

  List<ShopAccount> get accounts => List.unmodifiable(_accounts);
  bool get isLoaded => _loaded;
  bool get isEmpty => _accounts.isEmpty;

  List<ShopAccount> accountsOf(ShopPlatform platform) =>
      _accounts.where((a) => a.platform == platform).toList();

  int countOf(ShopPlatform platform) => accountsOf(platform).length;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _accounts
          ..clear()
          ..addAll(list.map(ShopAccount.fromJson));
      } catch (_) {
        _accounts.clear();
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_accounts.map((e) => e.toJson()).toList());
    await prefs.setString(storageKey, raw);
  }

  bool exists(ShopPlatform platform, String shopId) =>
      _accounts.any((a) => a.platform == platform && a.shopId == shopId);

  Future<void> addOrUpdate(ShopAccount account) async {
    final index = _accounts.indexWhere(
        (a) => a.platform == account.platform && a.shopId == account.shopId);
    if (index >= 0) {
      _accounts[index] = account;
    } else {
      _accounts.add(account);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> disconnect(String id) => remove(id);
}
