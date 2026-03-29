// base_unlock_notifier.dart
//
// Mirrors: BaseUnlockViewModel.swift
//
// 核心設計：Template Method Pattern（與 SetPasscodeNotifier 相同概念）
// - 共用解鎖流程（輸入 → 驗證 → lockout 計數 → biometry 整合）
// - 子類只需覆寫：isValid / onEnterValid / onBiometryUnlock
//
// 整合三個 manager（對應 Swift 用 AppCore.shared 直接取）：
// - PasscodeManager（驗證 passcode）
// - LockoutManager（計數 / 鎖定策略）
// - BiometryManager（顯示 FaceID/TouchID 按鈕）

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app_core/security/passcode/passcode_manager.dart';
import '../../../app_core/security/biometry/biometry_manager.dart';
import '../../../app_core/security/lockout/lockout_manager.dart';
import '../../../app_core/security/biometry/biometry_type.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum UnlockEvent { completed }

class UnlockState {
  /// 使用者目前輸入的 passcode
  /// Mirrors: @Published var passcode: String
  final String passcode;

  /// 主提示文字
  /// Mirrors: @Published var description: String
  final String description;

  /// 錯誤提示（剩餘次數等）
  /// Mirrors: @Published var errorText: String
  final String errorText;

  /// 抖動觸發器（輸錯時 +1）
  /// Mirrors: @Published var shakeTrigger: Int
  final int shakeTrigger;

  /// 最終要顯示的生物辨識按鈕類型（null = 不顯示）
  /// Mirrors: @Published var resolvedBiometryType: BiometryType?
  final BiometryType? resolvedBiometryType;

  /// Lockout 狀態（供 UI 決定是否禁用輸入）
  /// Mirrors: @Published var lockoutState: LockoutState
  final LockoutState lockoutState;

  /// 一次性導航事件
  final UnlockEvent? event;

  const UnlockState({
    this.passcode = '',
    this.description = 'Enter Passcode',
    this.errorText = '',
    this.shakeTrigger = 0,
    this.resolvedBiometryType,
    this.lockoutState =
        const LockoutUnlocked(attemptsLeft: 5, maxAttempts: 5),
    this.event,
  });

  UnlockState copyWith({
    String? passcode,
    String? description,
    String? errorText,
    int? shakeTrigger,
    BiometryType? resolvedBiometryType,
    bool clearBiometry = false,
    LockoutState? lockoutState,
    UnlockEvent? event,
    bool clearEvent = false,
  }) {
    return UnlockState(
      passcode: passcode ?? this.passcode,
      description: description ?? this.description,
      errorText: errorText ?? this.errorText,
      shakeTrigger: shakeTrigger ?? this.shakeTrigger,
      resolvedBiometryType: clearBiometry
          ? null
          : (resolvedBiometryType ?? this.resolvedBiometryType),
      lockoutState: lockoutState ?? this.lockoutState,
      event: clearEvent ? null : (event ?? this.event),
    );
  }
}

// ── Base Notifier ─────────────────────────────────────────────────────────────

/// Mirrors: BaseUnlockViewModel (base class)
abstract class BaseUnlockNotifier extends StateNotifier<UnlockState> {
  static const _passcodeLength = 6;

  final PasscodeManager passcodeManager;
  final LockoutManager lockoutManager;
  final BiometryManager biometryManager;
  final bool biometryAllowed;

  final List<StreamSubscription<dynamic>> _subs = [];

  BaseUnlockNotifier({
    required this.passcodeManager,
    required this.lockoutManager,
    required this.biometryManager,
    this.biometryAllowed = true,
  }) : super(const UnlockState()) {
    // 初始化時從 managers 讀取狀態
    final initialLockout = lockoutManager.state;
    state = state.copyWith(
      lockoutState: initialLockout,
      errorText: _buildErrorText(initialLockout),
    );
    _syncBiometryType();

    // 訂閱 manager 狀態變化（對應 Swift Combine subscriptions）
    _subs.addAll([
      lockoutManager.stream.listen((lockout) {
        if (!mounted) return;
        state = state.copyWith(
          lockoutState: lockout,
          errorText: _buildErrorText(lockout),
        );
        _syncBiometryType();
      }),
      biometryManager.stream.listen((_) {
        if (!mounted) return;
        _syncBiometryType();
      }),
    ]);
  }

  // ── Template Method Hooks ──────────────────────────────────────

  /// Mirrors: func isValid(passcode:) -> Bool
  bool isValid(String passcode);

  /// Mirrors: func onEnterValid(passcode:)
  void onEnterValid(String passcode);

  /// Mirrors: func onBiometryUnlock()
  void onBiometryUnlock();

  // ── Biometry UI State ──────────────────────────────────────────

  /// 計算是否要顯示 biometry 按鈕
  /// Mirrors: func syncBiometryType()
  void _syncBiometryType() {
    final shouldShow = biometryAllowed &&
        biometryManager.state.enabledType.isEnabled &&
        !state.lockoutState.isAttempted;

    state = state.copyWith(
      resolvedBiometryType:
          shouldShow ? biometryManager.state.biometryType : null,
      clearBiometry: !shouldShow,
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────

  /// View 的 onAppear → 如果是 auto biometry，自動觸發
  /// Mirrors: func onAppear()
  bool get shouldAutoTriggerBiometry {
    return state.resolvedBiometryType != null &&
        biometryManager.state.enabledType.isAuto;
  }

  // ── NumPad Interaction ─────────────────────────────────────────

  void addDigit(String digit) {
    if (state.lockoutState.isLocked) return;
    if (state.passcode.length >= _passcodeLength) return;
    final newPasscode = state.passcode + digit;
    state = state.copyWith(passcode: newPasscode);
    if (newPasscode.length == _passcodeLength) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _handleEntered(newPasscode);
      });
    }
  }

  void removeDigit() {
    if (state.passcode.isEmpty) return;
    state = state.copyWith(
      passcode: state.passcode.substring(0, state.passcode.length - 1),
    );
  }

  // ── Core Flow ──────────────────────────────────────────────────

  /// Mirrors: func handleEntered(passcode:)
  Future<void> _handleEntered(String passcode) async {
    if (!mounted) return;
    if (isValid(passcode)) {
      // 驗證成功
      onEnterValid(passcode);
      await lockoutManager.didUnlock();
    } else {
      // 驗證失敗
      state = state.copyWith(
        passcode: '',
        shakeTrigger: state.shakeTrigger + 1,
      );
      await lockoutManager.didFailUnlock();
    }
  }

  /// Biometry 按鈕點擊（或 onAppear 自動觸發）
  /// Mirrors: unlockWithBiometrySubject → LAContext.evaluatePolicy
  Future<void> unlockWithBiometry() async {
    final success = await biometryManager.authenticate();
    if (!mounted) return;
    if (success) {
      onBiometryUnlock();
    }
  }

  // ── Error Text ─────────────────────────────────────────────────

  /// Mirrors: func syncErrorText()
  static String _buildErrorText(LockoutState lockout) {
    switch (lockout) {
      case LockoutUnlocked s:
        return s.attemptsLeft == s.maxAttempts
            ? ''
            : 'Attempts left: ${s.attemptsLeft}';
      case LockoutLocked _:
        return '';
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}
