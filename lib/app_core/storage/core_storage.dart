// core_storage.dart
//
// Mirrors: CoreStorage.swift
//
// 角色：Storage 層的協調容器。
// 把 SecureStorage（Keychain equiv）與 PreferencesStorage（UserDefaults equiv）
// 統一持有，讓 CoreSecurity 只依賴這一個 entry point，
// 而不用分別依賴兩個 storage 實作。

import 'secure_storage.dart';
import 'preferences_storage.dart';

class CoreStorage {
  final SecureStorage secureStorage;
  final PreferencesStorage preferencesStorage;

  const CoreStorage({
    required this.secureStorage,
    required this.preferencesStorage,
  });
}
