// secure_storage.dart
//
// Mirrors: KeychainStorage.swift
//
// 角色：敏感資料的持久化層（Passcode、Lockout 計數）
// 對應 Swift Keychain 的 .whenPasscodeSetThisDeviceOnly 保護等級。
//
// 為何獨立封裝：
// - 讓 domain manager 不直接依賴 flutter_secure_storage API
// - 便於未來替換底層實作（例如切成其他 secure enclave 方案）

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  // iOS: KeychainAccessibility.passcode
  //   = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
  //   完全對應 Swift 的 .whenPasscodeSetThisDeviceOnly：
  //   只有在裝置設有 passcode 時才可存取，且資料不同步到其他裝置。
  // Android: EncryptedSharedPreferences
  final FlutterSecureStorage _storage;

  SecureStorage()
      : _storage = FlutterSecureStorage(
          iOptions: const IOSOptions(
            accessibility: KeychainAccessibility.passcode,
          ),
          aOptions: const AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  /// Mirrors: KeychainManager.handleLaunch() — 首次安裝清除殘留資料
  Future<void> deleteAll() => _storage.deleteAll();

  Future<bool> containsKey(String key) => _storage.containsKey(key: key);
}
