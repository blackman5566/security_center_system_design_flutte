// preferences_storage.dart
//
// Mirrors: UserDefaultsStorage.swift
//
// 角色：非敏感偏好設定的持久化層（autoLockPeriod、biometryMode、lastExitDate）
// 對應 Swift 的 UserDefaults，不儲存敏感資料。

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStorage {
  final SharedPreferences _prefs;

  PreferencesStorage(this._prefs);

  // ── String ──────────────────────────────────────────────────

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  // ── Bool ────────────────────────────────────────────────────

  bool? getBool(String key) => _prefs.getBool(key);

  Future<void> setBool(String key, bool value) =>
      _prefs.setBool(key, value);

  // ── Int ─────────────────────────────────────────────────────

  int? getInt(String key) => _prefs.getInt(key);

  Future<void> setInt(String key, int value) =>
      _prefs.setInt(key, value);

  // ── Double ──────────────────────────────────────────────────

  double? getDouble(String key) => _prefs.getDouble(key);

  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  // ── Remove ──────────────────────────────────────────────────

  Future<void> remove(String key) => _prefs.remove(key);

  bool containsKey(String key) => _prefs.containsKey(key);
}
