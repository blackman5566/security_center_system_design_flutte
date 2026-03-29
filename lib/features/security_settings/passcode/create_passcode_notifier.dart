// create_passcode_notifier.dart
//
// Mirrors: CreatePasscodeViewModel.swift
//
// 繼承 SetPasscodeNotifier，只覆寫：
// - title / descriptions（文案）
// - onEnter（成功後：寫入 keychain + 發出 completed 事件）
//
// 這是 Template Method Pattern 的 concrete implementation。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import 'set_passcode_notifier.dart';

// ── 建立原因（對應 Swift CreatePasscodeModule.CreatePasscodeReason）───────────

enum CreatePasscodeReason {
  regular,

  /// Mirrors: CreatePasscodeReason.biometry(enabledType:type:)
  /// Dart enum 不支援 associated values，biometryType 由呼叫端從 biometryManagerProvider 取得
  biometry,

  duress;

  String get description {
    switch (this) {
      case CreatePasscodeReason.regular:
        return 'Enter a 6-digit passcode';
      case CreatePasscodeReason.biometry:
        return 'Set a passcode to enable biometric authentication';
      case CreatePasscodeReason.duress:
        return 'Enter a duress passcode';
    }
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Mirrors: CreatePasscodeViewModel (subclass of SetPasscodeViewModel)
class CreatePasscodeNotifier extends SetPasscodeNotifier {
  final CreatePasscodeReason reason;

  CreatePasscodeNotifier({
    required super.passcodeManager,
    this.reason = CreatePasscodeReason.regular,
  }) : super() {
    // 重新同步 description（因為 reason 在 super.init() 之後才設定）
    state = state.copyWith(description: passcodeDescription);
  }

  // ── Template method overrides ──────────────────────────────────

  @override
  String get title => 'Create Passcode';

  @override
  String get passcodeDescription => reason.description;

  @override
  String get confirmDescription => 'Confirm';

  /// Mirrors:
  ///   override func onEnter(passcode: String) {
  ///     try passcodeManager.set(passcode: passcode)
  ///     finishSubject.send()
  ///     onCreate()
  ///   }
  @override
  Future<void> onEnter(String passcode) async {
    await passcodeManager.set(passcode);
    state = state.copyWith(event: SetPasscodeEvent.completed);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Mirrors: CreatePasscodeModule.createPasscodeView() — DI 組裝根
final createPasscodeNotifierProvider = StateNotifierProvider.autoDispose
    .family<CreatePasscodeNotifier, SetPasscodeState, CreatePasscodeReason>(
  (ref, reason) => CreatePasscodeNotifier(
    passcodeManager: ref.read(passcodeManagerProvider.notifier),
    reason: reason,
  ),
);
