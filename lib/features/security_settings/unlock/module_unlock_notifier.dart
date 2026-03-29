// module_unlock_notifier.dart
//
// Mirrors: ModuleUnlockViewModel.swift
//
// 用途：敏感操作的二次確認解鎖（例如：查看 duress passcode 設定）
// 與 AppUnlockNotifier 的差異：
// - 只接受「主 passcode」（不接受 duress）
// - 解鎖成功不呼叫 lockManager.unlock()，只回傳成功事件給上層

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import 'base_unlock_notifier.dart';

/// Mirrors: ModuleUnlockViewModel (subclass of BaseUnlockViewModel)
class ModuleUnlockNotifier extends BaseUnlockNotifier {
  ModuleUnlockNotifier({
    required super.passcodeManager,
    required super.lockoutManager,
    required super.biometryManager,
  }) : super(biometryAllowed: false); // 敏感操作不允許 biometry

  /// 只驗證主 passcode（非 has() 而是 isValid()）
  /// Mirrors: override func isValid(passcode:) -> Bool
  /// { passcodeManager.isValid(passcode: passcode) }
  @override
  bool isValid(String passcode) => passcodeManager.isValid(passcode);

  /// 成功 → 發出 completed 事件（不解鎖整個 App）
  @override
  void onEnterValid(String passcode) {
    state = state.copyWith(event: UnlockEvent.completed);
  }

  @override
  void onBiometryUnlock() {
    // biometryAllowed = false，此方法不會被呼叫
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final moduleUnlockNotifierProvider = StateNotifierProvider.autoDispose<
    ModuleUnlockNotifier, UnlockState>(
  (ref) => ModuleUnlockNotifier(
    passcodeManager: ref.read(passcodeManagerProvider.notifier),
    lockoutManager: ref.read(lockoutManagerProvider.notifier),
    biometryManager: ref.read(biometryManagerProvider.notifier),
  ),
);
