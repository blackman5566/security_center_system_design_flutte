// security_settings_notifier.dart
//
// Mirrors: SecuritySettingsViewModel.swift
//
// 角色：
// - 把 PasscodeManager / BiometryManager / LockManager 的狀態聚合成
//   一個 SecuritySettingsState，供 SecuritySettingsView 使用
// - 監聽三個 manager 的 stream（對應 Swift Combine sink）
// - 提供 removePasscode / setAutoLockPeriod / setBiometryMode 等 action
//
// Riverpod 對應：
// - Swift @Published → StateNotifier.state
// - Swift Combine sink + store(in: &cancellables) → StreamSubscription + dispose()
// - Swift passcodeManager.$isPasscodeSet.sink → passcodeManager.stream.listen()

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_core/security/passcode/passcode_manager.dart';
import '../../app_core/security/biometry/biometry_manager.dart';
import '../../app_core/security/lock/lock_manager.dart';
import '../../app_core/security/lock/auto_lock_period.dart';
import '../../app_core/security/biometry/biometry_type.dart';
import '../../providers/app_providers.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// Mirrors: SecuritySettingsViewModel 的所有 @Published 欄位
class SecuritySettingsState {
  final int currentPasscodeLevel;
  final bool isPasscodeSet;
  final bool isDuressPasscodeSet;
  final BiometryType? biometryType;
  final BiometryEnabledType biometryEnabledType;
  final AutoLockPeriod autoLockPeriod;

  const SecuritySettingsState({
    this.currentPasscodeLevel = 0,
    this.isPasscodeSet = false,
    this.isDuressPasscodeSet = false,
    this.biometryType,
    this.biometryEnabledType = BiometryEnabledType.off,
    this.autoLockPeriod = AutoLockPeriod.minute1,
  });

  SecuritySettingsState copyWith({
    int? currentPasscodeLevel,
    bool? isPasscodeSet,
    bool? isDuressPasscodeSet,
    BiometryType? biometryType,
    bool clearBiometryType = false,
    BiometryEnabledType? biometryEnabledType,
    AutoLockPeriod? autoLockPeriod,
  }) {
    return SecuritySettingsState(
      currentPasscodeLevel:
          currentPasscodeLevel ?? this.currentPasscodeLevel,
      isPasscodeSet: isPasscodeSet ?? this.isPasscodeSet,
      isDuressPasscodeSet: isDuressPasscodeSet ?? this.isDuressPasscodeSet,
      biometryType:
          clearBiometryType ? null : (biometryType ?? this.biometryType),
      biometryEnabledType: biometryEnabledType ?? this.biometryEnabledType,
      autoLockPeriod: autoLockPeriod ?? this.autoLockPeriod,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Mirrors: SecuritySettingsViewModel (ObservableObject)
///
/// 依賴注入：manager 的 StateNotifier instance（非 provider），
/// 讓此 Notifier 可以訂閱 manager 的 stream，對應 Swift Combine pipeline。
class SecuritySettingsNotifier extends StateNotifier<SecuritySettingsState> {
  final PasscodeManager _passcodeManager;
  final BiometryManager _biometryManager;
  final LockManager _lockManager;
  final List<StreamSubscription<dynamic>> _subs = [];

  SecuritySettingsNotifier({
    required PasscodeManager passcodeManager,
    required BiometryManager biometryManager,
    required LockManager lockManager,
  })  : _passcodeManager = passcodeManager,
        _biometryManager = biometryManager,
        _lockManager = lockManager,
        super(_buildState(
          passcodeManager.state,
          biometryManager.state,
          lockManager.state,
        )) {
    // ── Combine 訂閱 ────────────────────────────────────────────
    // Mirrors:
    //   passcodeManager.$isPasscodeSet.sink { self?.isPasscodeSet = $0 }
    //   biometryManager.$biometryType.sink { self?.biometryType = $0 }
    //   等等...
    _subs.addAll([
      passcodeManager.stream.listen((_) => _syncState()),
      biometryManager.stream.listen((_) => _syncState()),
      lockManager.stream.listen((_) => _syncState()),
    ]);
  }

  static SecuritySettingsState _buildState(
    PasscodeState passcode,
    BiometryState biometry,
    LockState lock,
  ) {
    return SecuritySettingsState(
      currentPasscodeLevel: passcode.currentPasscodeLevel,
      isPasscodeSet: passcode.isPasscodeSet,
      isDuressPasscodeSet: passcode.isDuressPasscodeSet,
      biometryType: biometry.biometryType,
      biometryEnabledType: biometry.enabledType,
      autoLockPeriod: lock.autoLockPeriod,
    );
  }

  void _syncState() {
    state = _buildState(
      _passcodeManager.state,
      _biometryManager.state,
      _lockManager.state,
    );
  }

  // ── Actions ────────────────────────────────────────────────────

  /// Mirrors: func removePasscode()
  Future<void> removePasscode() async {
    await _passcodeManager.removePasscode();
    // 若移除 passcode，biometry 應強制關閉（安全保護）
    // Mirrors: PasscodeManager.syncState() 中的 biometry 安全保護邏輯
    if (!_passcodeManager.state.isPasscodeSet &&
        _biometryManager.state.enabledType.isEnabled) {
      await _biometryManager.setEnabledType(BiometryEnabledType.off);
    }
    _lockManager.syncPasscodeState();
  }

  /// Mirrors: func set(biometryEnabledType:)
  Future<void> setBiometryEnabledType(BiometryEnabledType type) async {
    if (!state.isPasscodeSet) return; // 沒有 passcode 不能開 biometry
    await _biometryManager.setEnabledType(type);
  }

  /// Mirrors: lockManager.autoLockPeriod = autoLockPeriod (didSet)
  Future<void> setAutoLockPeriod(AutoLockPeriod period) async {
    await _lockManager.setAutoLockPeriod(period);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Mirrors: SecuritySettingsModule.view() — DI 組裝根
///
/// autoDispose：畫面離開時自動釋放，對應 SwiftUI View 的生命週期
final securitySettingsNotifierProvider = StateNotifierProvider.autoDispose<
    SecuritySettingsNotifier, SecuritySettingsState>(
  (ref) => SecuritySettingsNotifier(
    passcodeManager: ref.read(passcodeManagerProvider.notifier),
    biometryManager: ref.read(biometryManagerProvider.notifier),
    lockManager: ref.read(lockManagerProvider.notifier),
  ),
);
