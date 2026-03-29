// lock_manager.dart
//
// Mirrors: LockManager.swift
//
// 核心職責：
// - 追蹤 App 是否處於鎖定狀態
// - App 進入背景時記錄時間，回到前景時判斷是否超過 autoLockPeriod
// - 提供 lock() / unlock() API 給外層（AppLifecycleObserver、AppUnlockNotifier）
//
// Flutter 實作差異說明：
// - Swift 用 UIWindow overlay 顯示解鎖畫面
// - Flutter 改用 app root 的 Stack，由 lockManagerProvider 的 isLocked
//   控制是否顯示 AppUnlockView（更符合 Flutter 的 declarative 渲染模型）

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../storage/preferences_storage.dart';
import '../../storage/secure_storage.dart';
import 'auto_lock_period.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class LockState {
  /// App 是否處於鎖定狀態
  /// Mirrors: @DistinctPublished var isLocked: Bool
  final bool isLocked;

  /// 使用者設定的自動上鎖時間
  /// Mirrors: var autoLockPeriod: AutoLockPeriod
  final AutoLockPeriod autoLockPeriod;

  const LockState({
    this.isLocked = false,
    this.autoLockPeriod = AutoLockPeriod.minute1,
  });

  LockState copyWith({bool? isLocked, AutoLockPeriod? autoLockPeriod}) {
    return LockState(
      isLocked: isLocked ?? this.isLocked,
      autoLockPeriod: autoLockPeriod ?? this.autoLockPeriod,
    );
  }
}

// ── Manager ───────────────────────────────────────────────────────────────────

/// Mirrors: LockManager (class)
class LockManager extends StateNotifier<LockState> {
  static const _lastExitKey = 'last_exit_date_key';
  static const _autoLockPeriodKey = 'auto-lock-period';

  final SecureStorage _secureStorage;
  final PreferencesStorage _prefs;

  // 由外部注入：是否有設定 passcode（決定是否可以鎖定）
  // Mirrors: private let passcodeManager: PasscodeManager（依賴反轉，避免循環依賴）
  bool Function() isPasscodeSet;

  LockManager({
    required SecureStorage secureStorage,
    required PreferencesStorage prefs,
    required this.isPasscodeSet,
  })  : _secureStorage = secureStorage,
        _prefs = prefs,
        super(const LockState()) {
    _loadPrefs();
  }

  void _loadPrefs() {
    final raw = _prefs.getString(_autoLockPeriodKey);
    final period =
        AutoLockPeriod.fromRawValue(raw) ?? AutoLockPeriod.minute1;
    // 初始化：若有設定 passcode 就直接鎖
    // Mirrors: isLocked = passcodeManager.isPasscodeSet
    state = LockState(
      isLocked: isPasscodeSet(),
      autoLockPeriod: period,
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────

  /// App 進入背景 → 記錄時間戳
  /// Mirrors: func didEnterBackground()
  Future<void> didEnterBackground() async {
    if (state.isLocked) return; // 已鎖就不覆寫時間
    final now = DateTime.now().millisecondsSinceEpoch;
    await _secureStorage.write(_lastExitKey, '$now');
  }

  /// App 回到前景 → 判斷是否需要鎖
  /// Mirrors: func willEnterForeground()
  Future<void> willEnterForeground() async {
    if (state.isLocked) return; // 已鎖就不重複 lock

    final rawTs = await _secureStorage.read(_lastExitKey);
    final exitMs = int.tryParse(rawTs ?? '') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = Duration(milliseconds: now - exitMs);

    // 偏安全 default：沒有記錄就視為很久沒用 → 鎖
    if (elapsed >= state.autoLockPeriod.duration) {
      _lock();
    }
  }

  // ── Lock / Unlock ──────────────────────────────────────────────

  /// 進入鎖定狀態
  /// Mirrors: private func lock() — 但 Flutter 版不建立 UIWindow，
  /// 改由 app root Stack 根據 isLocked 顯示 AppUnlockView
  void _lock() {
    if (!isPasscodeSet()) return;
    state = state.copyWith(isLocked: true);
  }

  /// 供外部直接呼叫（例如 AppCore 初始化後確認要鎖）
  void lock() => _lock();

  /// 解鎖成功後呼叫（由 AppUnlockNotifier 觸發）
  /// Mirrors: func unlock()
  void unlock() {
    state = state.copyWith(isLocked: false);
  }

  // ── Settings ───────────────────────────────────────────────────

  /// 更新 autoLockPeriod 設定
  /// Mirrors: var autoLockPeriod { didSet }
  Future<void> setAutoLockPeriod(AutoLockPeriod period) async {
    state = state.copyWith(autoLockPeriod: period);
    await _prefs.setString(_autoLockPeriodKey, period.rawValue);
  }

  /// 重新評估鎖定狀態（例如 passcode 被刪除後呼叫）
  void syncPasscodeState() {
    if (!isPasscodeSet() && state.isLocked) {
      state = state.copyWith(isLocked: false);
    }
  }
}
