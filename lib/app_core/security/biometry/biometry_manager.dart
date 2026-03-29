// biometry_manager.dart
//
// Mirrors: BiometryManager.swift
//
// 核心職責：
// 1. 偵測裝置支援的生物辨識類型（FaceID / TouchID / none）
// 2. 管理使用者設定（off / manual / on）
// 3. 持久化到 PreferencesStorage（對應 UserDefaults）
//
// iOS 平台設定：需在 ios/Runner/Info.plist 加入：
//   <key>NSFaceIDUsageDescription</key>
//   <string>Used to unlock the app</string>
// Android 設定：需在 AndroidManifest.xml 加入 USE_BIOMETRIC 權限

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../storage/preferences_storage.dart';
import 'biometry_type.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// 使用者設定的生物辨識啟用模式
/// Mirrors: BiometryManager.BiometryEnabledType
enum BiometryEnabledType {
  /// 完全關閉
  off,

  /// 手動：需要按按鈕才觸發（不自動彈出）
  manual,

  /// 自動：進入解鎖流程時自動觸發
  on;

  String get rawValue => name;

  static BiometryEnabledType? fromRawValue(String? raw) {
    if (raw == null) return null;
    for (final v in BiometryEnabledType.values) {
      if (v.rawValue == raw) return v;
    }
    return null;
  }

  bool get isEnabled => this != BiometryEnabledType.off;
  bool get isAuto => this == BiometryEnabledType.on;

  String get title {
    switch (this) {
      case BiometryEnabledType.off:
        return 'Off';
      case BiometryEnabledType.manual:
        return 'Manual';
      case BiometryEnabledType.on:
        return 'On';
    }
  }

  String get description {
    switch (this) {
      case BiometryEnabledType.off:
        return 'Disabled in all cases';
      case BiometryEnabledType.manual:
        return 'Scanning with the button';
      case BiometryEnabledType.on:
        return 'Automatic scanning';
    }
  }
}

class BiometryState {
  /// 裝置實際支援的生物辨識類型（null = 不支援 / 未偵測到）
  /// Mirrors: var biometryType: BiometryType?
  final BiometryType? biometryType;

  /// 使用者設定的啟用模式
  /// Mirrors: var biometryEnabledType: BiometryEnabledType
  final BiometryEnabledType enabledType;

  const BiometryState({
    this.biometryType,
    this.enabledType = BiometryEnabledType.off,
  });

  BiometryState copyWith({
    BiometryType? biometryType,
    bool clearBiometryType = false,
    BiometryEnabledType? enabledType,
  }) {
    return BiometryState(
      biometryType: clearBiometryType ? null : (biometryType ?? this.biometryType),
      enabledType: enabledType ?? this.enabledType,
    );
  }
}

// ── Manager ───────────────────────────────────────────────────────────────────

/// Mirrors: BiometryManager (class)
class BiometryManager extends StateNotifier<BiometryState> {
  static const _enabledTypeKey = 'biometric_enabled_type_key';

  final PreferencesStorage _prefs;
  final LocalAuthentication _localAuth = LocalAuthentication();

  BiometryManager(this._prefs) : super(const BiometryState()) {
    _loadPrefs();
    _refreshBiometryType();
  }

  void _loadPrefs() {
    final raw = _prefs.getString(_enabledTypeKey);
    final enabledType = BiometryEnabledType.fromRawValue(raw) ?? BiometryEnabledType.off;
    state = state.copyWith(enabledType: enabledType);
  }

  /// 偵測裝置生物辨識能力
  /// Mirrors: func refreshBiometry()
  Future<void> _refreshBiometryType() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        state = state.copyWith(clearBiometryType: true);
        return;
      }

      final types = await _localAuth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) {
        state = state.copyWith(biometryType: BiometryType.faceId);
      } else if (types.contains(BiometricType.fingerprint) ||
          types.contains(BiometricType.strong)) {
        state = state.copyWith(biometryType: BiometryType.touchId);
      } else {
        state = state.copyWith(clearBiometryType: true);
      }
    } catch (_) {
      state = state.copyWith(clearBiometryType: true);
    }
  }

  // ── Public API ─────────────────────────────────────────────────

  /// 更新啟用模式並持久化
  /// Mirrors: biometryEnabledType { didSet }
  Future<void> setEnabledType(BiometryEnabledType type) async {
    state = state.copyWith(enabledType: type);
    await _prefs.setString(_enabledTypeKey, type.rawValue);
  }

  /// 觸發生物辨識驗證（由 View 層呼叫）
  /// Mirrors: View 的 .onAppear → unlockWithBiometrySubject → LAContext.evaluatePolicy
  Future<bool> authenticate({String reason = 'Unlock the app'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
