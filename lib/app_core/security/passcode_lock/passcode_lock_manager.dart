// passcode_lock_manager.dart
//
// Mirrors: PasscodeLockManager.swift
//
// 核心職責：
// - 偵測「裝置層級的安全機制」是否仍然有效
//   （裝置 passcode 是否還在、biometry 是否被停用）
// - 若裝置安全降級，觸發資料保護流程（例如清除敏感資料）
//
// 注意：這是 device-level 保護，與 app-level passcode 不同。
// 對應 Swift 的 LAContext().canEvaluatePolicy(.deviceOwnerAuthentication)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class PasscodeLockState {
  /// 裝置是否仍有系統層級的 passcode/biometry 保護
  /// Mirrors: 隱式的裝置安全狀態
  final bool isDeviceSecure;

  const PasscodeLockState({this.isDeviceSecure = true});
}

// ── Manager ───────────────────────────────────────────────────────────────────

/// Mirrors: PasscodeLockManager (class)
class PasscodeLockManager extends StateNotifier<PasscodeLockState> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  PasscodeLockManager() : super(const PasscodeLockState());

  /// App 進入前景時呼叫，重新評估裝置安全狀態
  /// Mirrors: func handleForeground() → checkDevicePasscode()
  Future<void> checkDeviceSecurity({
    required void Function() onSecurityCompromised,
  }) async {
    try {
      // deviceOwnerAuthentication 包含 passcode + biometry
      final isSecure = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();

      state = PasscodeLockState(isDeviceSecure: isSecure);

      if (!isSecure) {
        onSecurityCompromised();
      }
    } catch (_) {
      // 無法評估時，保守地視為安全（避免誤刪資料）
    }
  }
}
