// app_unlock_notifier.dart
//
// Mirrors: AppUnlockViewModel.swift
//
// 繼承 BaseUnlockNotifier，覆寫：
// - isValid：接受「任何層」的 passcode（包含 duress）
// - onEnterValid：切換 currentPasscodeLevel + 解鎖 App
// - onBiometryUnlock：setLastPasscode + 解鎖 App

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app_core/security/lock/lock_manager.dart';
import '../../../providers/app_providers.dart';
import 'base_unlock_notifier.dart';

/// Mirrors: AppUnlockViewModel (subclass of BaseUnlockViewModel)
class AppUnlockNotifier extends BaseUnlockNotifier {
  final LockManager _lockManager;

  AppUnlockNotifier({
    required super.passcodeManager,
    required super.lockoutManager,
    required super.biometryManager,
    required LockManager lockManager,
  })  : _lockManager = lockManager,
        super(biometryAllowed: true);

  // ── Template method overrides ──────────────────────────────────

  /// 任何層的 passcode 都算合法（含 duress）
  /// Mirrors: override func isValid(passcode:) -> Bool
  /// { passcodeManager.has(passcode: passcode) }
  @override
  bool isValid(String passcode) => passcodeManager.has(passcode);

  /// 正確 passcode → 切換層級 + 解鎖 App
  /// Mirrors: override func onEnterValid(passcode:)
  /// { passcodeManager.set(currentPasscode: passcode); lockManager.unlock() }
  @override
  void onEnterValid(String passcode) {
    passcodeManager.setCurrentPasscode(passcode);
    _lockManager.unlock();
    state = state.copyWith(event: UnlockEvent.completed);
  }

  /// 生物辨識成功 → 切換到最後一層 + 解鎖 App
  /// Mirrors: override func onBiometryUnlock()
  /// { passcodeManager.setLastPasscode(); lockManager.unlock() }
  @override
  void onBiometryUnlock() {
    passcodeManager.setLastPasscode();
    _lockManager.unlock();
    state = state.copyWith(event: UnlockEvent.completed);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final appUnlockNotifierProvider = StateNotifierProvider.autoDispose<
    AppUnlockNotifier, UnlockState>(
  (ref) => AppUnlockNotifier(
    passcodeManager: ref.read(passcodeManagerProvider.notifier),
    lockoutManager: ref.read(lockoutManagerProvider.notifier),
    biometryManager: ref.read(biometryManagerProvider.notifier),
    lockManager: ref.read(lockManagerProvider.notifier),
  ),
);
