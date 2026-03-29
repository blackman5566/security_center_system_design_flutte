// edit_passcode_notifier.dart
//
// Mirrors: EditPasscodeViewModel.swift
//
// 與 CreatePasscodeNotifier 的差異：
// - isCurrent()：允許輸入當前 passcode（編輯情境下不算重複）
// - onEnter()：呼叫 passcodeManager.set()（更新，非新增）

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import 'set_passcode_notifier.dart';

/// Mirrors: EditPasscodeViewModel (subclass of SetPasscodeViewModel)
class EditPasscodeNotifier extends SetPasscodeNotifier {
  EditPasscodeNotifier({required super.passcodeManager}) : super() {
    state = state.copyWith(description: passcodeDescription);
  }

  @override
  String get title => 'Edit Passcode';

  @override
  String get passcodeDescription => 'Enter a new 6-digit passcode';

  @override
  String get confirmDescription => 'Confirm new passcode';

  /// 編輯情境：允許輸入與目前相同的 passcode
  /// Mirrors: override func isCurrent(passcode:) -> Bool
  @override
  bool isCurrent(String passcode) => passcodeManager.isValid(passcode);

  @override
  Future<void> onEnter(String passcode) async {
    await passcodeManager.set(passcode);
    state = state.copyWith(event: SetPasscodeEvent.completed);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Mirrors: EditPasscodeModule.editPasscodeView()
final editPasscodeNotifierProvider = StateNotifierProvider.autoDispose<
    EditPasscodeNotifier, SetPasscodeState>(
  (ref) => EditPasscodeNotifier(
    passcodeManager: ref.read(passcodeManagerProvider.notifier),
  ),
);
