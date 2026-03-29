// passcode_manager.dart
//
// Mirrors: PasscodeManager.swift
//
// 核心職責：
// - 支援「多層 passcode」（passcodes 陣列，index = 層級）
// - 支援「duress passcode」（currentPasscodeLevel + 1 的那層）
// - 持久化到 SecureStorage（對應 Keychain）
//
// 儲存格式：passcode0|passcode1|passcode2...（以 "|" 分隔，對應 Swift 實作）
//
// 與 BiometryManager 的耦合說明：
// - Swift 版在 syncState() 中若無 passcode 且 biometry enabled → 強制關掉 biometry
// - Flutter 版將此邏輯移到 SecuritySettingsNotifier（feature layer），
//   保持 domain manager 的單一職責

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../storage/secure_storage.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class PasscodeState {
  /// passcodes[index] = 對應層級的 passcode 字串
  /// 初始：['']（空字串代表尚未設定）
  final List<String> passcodes;

  /// 目前生效的層級 index（主密碼指向哪一層）
  final int currentPasscodeLevel;

  const PasscodeState({
    this.passcodes = const [''],
    this.currentPasscodeLevel = 0,
  });

  /// 主密碼是否已設定（最後一層非空）
  /// Mirrors: var isPasscodeSet: Bool
  bool get isPasscodeSet =>
      passcodes.isNotEmpty && passcodes.last.isNotEmpty;

  /// duress passcode 是否存在（主層級的下一層是否存在）
  /// Mirrors: var isDuressPasscodeSet: Bool
  bool get isDuressPasscodeSet =>
      passcodes.length > currentPasscodeLevel + 1;

  PasscodeState copyWith({
    List<String>? passcodes,
    int? currentPasscodeLevel,
  }) {
    return PasscodeState(
      passcodes: passcodes ?? this.passcodes,
      currentPasscodeLevel:
          currentPasscodeLevel ?? this.currentPasscodeLevel,
    );
  }
}

// ── Manager ───────────────────────────────────────────────────────────────────

/// Mirrors: PasscodeManager (class)
///
/// Riverpod 對應：
/// - Swift @DistinctPublished isPasscodeSet → 從 state.isPasscodeSet 衍生
/// - Swift @DistinctPublished currentPasscodeLevel → state.currentPasscodeLevel
class PasscodeManager extends StateNotifier<PasscodeState> {
  static const _passcodeKey = 'pin_keychain_key';
  static const _separator = '|';

  final SecureStorage _storage;

  PasscodeManager(this._storage) : super(const PasscodeState()) {
    _loadState();
  }

  // ── 初始化 ──────────────────────────────────────────────────────

  Future<void> _loadState() async {
    final raw = await _storage.read(_passcodeKey);
    List<String> passcodes;
    if (raw != null && raw.isNotEmpty) {
      passcodes = raw.split(_separator);
    } else {
      passcodes = [''];
    }
    final level = passcodes.length - 1;
    state = PasscodeState(passcodes: passcodes, currentPasscodeLevel: level);
  }

  Future<void> _saveState(List<String> passcodes) async {
    await _storage.write(_passcodeKey, passcodes.join(_separator));
  }

  // ── Validation ──────────────────────────────────────────────────

  /// 主 passcode 是否正確（對應 currentPasscodeLevel 那層）
  /// Mirrors: func isValid(passcode:) -> Bool
  bool isValid(String passcode) {
    final level = state.currentPasscodeLevel;
    if (level >= state.passcodes.length) return false;
    return state.passcodes[level] == passcode;
  }

  /// duress passcode 是否正確（currentPasscodeLevel + 1）
  /// Mirrors: func isValid(duressPasscode:) -> Bool
  bool isValidDuress(String passcode) {
    final duressLevel = state.currentPasscodeLevel + 1;
    if (state.passcodes.length <= duressLevel) return false;
    return state.passcodes[duressLevel] == passcode;
  }

  /// 某 passcode 是否存在於任何層（防重複使用）
  /// Mirrors: func has(passcode:) -> Bool
  bool has(String passcode) => state.passcodes.contains(passcode);

  // ── Layer switching ─────────────────────────────────────────────

  /// 切換到最後一層（新增 passcode 後呼叫）
  /// Mirrors: func setLastPasscode()
  void setLastPasscode() {
    if (state.passcodes.isEmpty) return;
    final level = state.passcodes.length - 1;
    if (state.currentPasscodeLevel == level) return;
    state = state.copyWith(currentPasscodeLevel: level);
  }

  /// 依照輸入的 passcode 切換層級
  /// Mirrors: func set(currentPasscode:)
  void setCurrentPasscode(String passcode) {
    final idx = state.passcodes.indexOf(passcode);
    if (idx < 0 || idx == state.currentPasscodeLevel) return;
    state = state.copyWith(currentPasscodeLevel: idx);
  }

  // ── CRUD ────────────────────────────────────────────────────────

  /// 設定/更新主 passcode（currentPasscodeLevel 指向的那格）
  /// Mirrors: func set(passcode:) throws
  Future<void> set(String passcode) async {
    final list = List<String>.from(state.passcodes);
    list[state.currentPasscodeLevel] = passcode;
    await _saveState(list);
    state = state.copyWith(passcodes: list);
  }

  /// 移除主 passcode（同時截斷 duress 層）
  /// Mirrors: func removePasscode() throws
  Future<void> removePasscode() async {
    final list = List<String>.from(state.passcodes);
    list[state.currentPasscodeLevel] = '';
    final truncated = list.sublist(0, state.currentPasscodeLevel + 1);
    await _saveState(truncated);
    state = state.copyWith(passcodes: truncated);
  }

  /// 設定/更新 duress passcode（currentPasscodeLevel + 1）
  /// Mirrors: func set(duressPasscode:) throws
  Future<void> setDuress(String passcode) async {
    final list = List<String>.from(state.passcodes);
    final duressLevel = state.currentPasscodeLevel + 1;
    if (list.length > duressLevel) {
      list[duressLevel] = passcode;
    } else {
      list.add(passcode);
    }
    await _saveState(list);
    state = state.copyWith(passcodes: list);
  }

  /// 移除 duress passcode（截斷到 currentPasscodeLevel + 1）
  /// Mirrors: func removeDuressPasscode() throws
  Future<void> removeDuress() async {
    final truncated = state.passcodes.sublist(
      0,
      state.currentPasscodeLevel + 1,
    );
    await _saveState(truncated);
    state = state.copyWith(passcodes: truncated);
  }
}
