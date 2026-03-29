// set_passcode_notifier.dart
//
// Mirrors: SetPasscodeViewModel.swift
//
// 核心設計：Template Method Pattern
// - 這是抽象基底類別，定義「輸入 → 驗證 → 確認」的兩段式狀態機
// - 子類只需覆寫：title / descriptions / isCurrent / onEnter / onCancel
// - 基底類處理：passcode 累積、防重複、確認比對、錯誤回饋
//
// Riverpod 對應：
// - Swift ObservableObject + @Published → StateNotifier<SetPasscodeState>
// - Swift finishSubject.send() → state.isCompleted = true → ref.listen 觸發導航

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app_core/security/passcode/passcode_manager.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// SetPasscodeEvent：一次性導航事件
/// Mirrors: finishSubject (PassthroughSubject) + onCancel callback
enum SetPasscodeEvent { completed, cancelled }

class SetPasscodeState {
  /// 使用者目前輸入的 passcode（由 NumPad 累積）
  /// Mirrors: @Published var passcode: String
  final String passcode;

  /// 主提示文字（在「輸入新密碼」vs「確認密碼」之間切換）
  /// Mirrors: @Published var description: String
  final String description;

  /// 錯誤提示文字（密碼重複、確認不一致）
  /// Mirrors: @Published var errorText: String
  final String errorText;

  /// 抖動觸發器（每次錯誤 +1）
  /// Mirrors: @Published var shakeTrigger: Int
  final int shakeTrigger;

  /// 一次性導航事件
  /// Mirrors: finishSubject.send() / onCancel()
  final SetPasscodeEvent? event;

  const SetPasscodeState({
    this.passcode = '',
    this.description = '',
    this.errorText = '',
    this.shakeTrigger = 0,
    this.event,
  });

  SetPasscodeState copyWith({
    String? passcode,
    String? description,
    String? errorText,
    int? shakeTrigger,
    SetPasscodeEvent? event,
    bool clearEvent = false,
  }) {
    return SetPasscodeState(
      passcode: passcode ?? this.passcode,
      description: description ?? this.description,
      errorText: errorText ?? this.errorText,
      shakeTrigger: shakeTrigger ?? this.shakeTrigger,
      event: clearEvent ? null : (event ?? this.event),
    );
  }
}

// ── Base Notifier ─────────────────────────────────────────────────────────────

/// Mirrors: SetPasscodeViewModel (base class)
///
/// 所有子類繼承此類，覆寫 template method hooks：
///   isCurrent / onEnter / onCancel / title / descriptions
abstract class SetPasscodeNotifier extends StateNotifier<SetPasscodeState> {
  static const passcodeLength = 6;

  final PasscodeManager passcodeManager;

  /// 第一段輸入的暫存（nil = 尚在「輸入」階段；non-nil = 已進入「確認」階段）
  /// Mirrors: private var enteredPasscode: String?
  String? _enteredPasscode;

  SetPasscodeNotifier({required this.passcodeManager})
      : super(const SetPasscodeState()) {
    // 初始化時根據當前階段更新描述文字
    // Mirrors: init() → syncDescription()
    state = state.copyWith(description: passcodeDescription);
  }

  // ── Template Method Hooks ──────────────────────────────────────
  // Mirrors: Swift abstract / override var / func

  String get title => '';
  String get passcodeDescription => '';
  String get confirmDescription => '';

  /// 輸入的 passcode 是否為「目前正在使用的 passcode」（允許重複使用自身）
  /// Mirrors: func isCurrent(passcode:) -> Bool
  bool isCurrent(String passcode) => false;

  /// 確認成功後的行為（寫入 keychain、通知外部等）
  /// Mirrors: func onEnter(passcode:)
  Future<void> onEnter(String passcode);

  /// 取消流程
  /// Mirrors: func onCancel()
  void onCancel() {
    state = state.copyWith(event: SetPasscodeEvent.cancelled);
  }

  // ── NumPad Interaction ─────────────────────────────────────────

  /// NumPad 數字按下
  void addDigit(String digit) {
    if (state.passcode.length >= passcodeLength) return;
    final newPasscode = state.passcode + digit;
    state = state.copyWith(passcode: newPasscode, clearEvent: true);
    // 清除 errorText（使用者重新輸入中）
    if (newPasscode.isNotEmpty) {
      state = state.copyWith(errorText: '');
    }
    // 達到長度 → 延遲 200ms 再驗證（讓 UI 先顯示最後一顆點）
    // Mirrors: DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200))
    if (newPasscode.length == passcodeLength) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _handleEntered(newPasscode);
      });
    }
  }

  /// NumPad 刪除按下
  void removeDigit() {
    if (state.passcode.isEmpty) return;
    state = state.copyWith(
      passcode: state.passcode.substring(0, state.passcode.length - 1),
    );
  }

  // ── Core Flow ──────────────────────────────────────────────────

  /// 核心兩段式狀態機
  /// Mirrors: func handleEntered(passcode:)
  void _handleEntered(String passcode) {
    if (!mounted) return;

    if (_enteredPasscode != null) {
      // ── 第二段：確認 ─────────────────────────────────────────
      if (_enteredPasscode == passcode) {
        // 兩次一致 → 呼叫子類 onEnter
        onEnter(passcode);
      } else {
        // 不一致 → 退回第一段，顯示錯誤
        _enteredPasscode = null;
        state = state.copyWith(
          passcode: '',
          description: passcodeDescription,
          errorText: 'Invalid confirmation',
        );
      }
    } else {
      // ── 第一段：輸入新密碼 ────────────────────────────────────
      if (passcodeManager.has(passcode) && !isCurrent(passcode)) {
        // 密碼已存在於其他層 → 拒絕（防重複）
        state = state.copyWith(
          passcode: '',
          errorText: 'This passcode is already being used',
          shakeTrigger: state.shakeTrigger + 1,
        );
      } else {
        // 合法 → 暫存，進入第二段
        _enteredPasscode = passcode;
        state = state.copyWith(
          passcode: '',
          description: confirmDescription,
        );
      }
    }
  }
}
