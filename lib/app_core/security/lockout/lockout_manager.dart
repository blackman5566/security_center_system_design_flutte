// lockout_manager.dart
//
// Mirrors: LockoutManager.swift
//
// 核心職責：
// - 管理解鎖失敗次數（anti-brute-force）
// - 失敗到達閾值後進入 lockout，以指數退避策略決定等待時長
// - 狀態持久化到 SecureStorage（對應 Keychain），重開 App 仍保留
//
// 與 Swift 的差異說明（刻意保留相同設計意圖）：
// - Swift 用 clock_gettime(CLOCK_MONOTONIC_RAW) 防時鐘篡改
// - Dart 無跨平台 monotonic persistent clock；改用 wall-clock (DateTime.now())
//   搭配 SecureStorage 儲存時間戳。此設計在跨 App 重啟時等效，
//   但無法防止同一 session 內的系統時鐘篡改（已在注釋說明 tradeoff）

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../storage/secure_storage.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// Mirrors: LockoutState (Swift enum)
/// 使用 Dart 3 sealed class，完整對應 Swift 的 associated value enum
sealed class LockoutState {
  const LockoutState();

  bool get isLocked => this is LockoutLocked;

  /// 是否已嘗試過（用於 UI 決定是否顯示剩餘次數）
  bool get isAttempted {
    switch (this) {
      case LockoutUnlocked s:
        return s.attemptsLeft != s.maxAttempts;
      case LockoutLocked _:
        return true;
    }
  }
}

/// 未鎖定：可輸入，顯示剩餘次數
class LockoutUnlocked extends LockoutState {
  final int attemptsLeft;
  final int maxAttempts;
  const LockoutUnlocked({required this.attemptsLeft, required this.maxAttempts});
}

/// 鎖定中：顯示解鎖時間，禁止輸入
class LockoutLocked extends LockoutState {
  final DateTime unlockTime;
  const LockoutLocked({required this.unlockTime});
}

// ── Manager ───────────────────────────────────────────────────────────────────

/// Mirrors: LockoutManager (class) + @PostPublished var lockoutState
///
/// Riverpod 對應：
/// - Swift @PostPublished → StateNotifier.state（Riverpod 自動 diff + notify）
/// - Swift Timer → Dart Timer
class LockoutManager extends StateNotifier<LockoutState> {
  static const _attemptsKey = 'unlock_attempts_keychain_key';
  static const _timestampKey = 'lock_timestamp_keychain_key';
  static const _maxAttempts = 5;

  final SecureStorage _storage;
  Timer? _timer;

  // 記憶體內的計數，didSet 會同步寫 SecureStorage（對應 Swift didSet keychain）
  int _unlockAttempts = 0;
  int _lockTimestampMs = 0; // 以 ms since epoch 儲存

  LockoutManager(this._storage)
      : super(const LockoutUnlocked(attemptsLeft: 5, maxAttempts: 5)) {
    _loadAndSync();
  }

  Future<void> _loadAndSync() async {
    final attemptsRaw = await _storage.read(_attemptsKey);
    final tsRaw = await _storage.read(_timestampKey);

    _unlockAttempts = int.tryParse(attemptsRaw ?? '') ?? 0;
    _lockTimestampMs =
        int.tryParse(tsRaw ?? '') ?? DateTime.now().millisecondsSinceEpoch;

    _syncState();
  }

  // ── 指數退避策略 ────────────────────────────────────────────────
  // Mirrors: var lockoutInterval: TimeInterval (Swift switch)
  Duration get _lockoutDuration {
    if (_unlockAttempts == _maxAttempts) {
      return const Duration(minutes: 5);
    } else if (_unlockAttempts == _maxAttempts + 1) {
      return const Duration(minutes: 10);
    } else if (_unlockAttempts == _maxAttempts + 2) {
      return const Duration(minutes: 15);
    } else {
      return const Duration(minutes: 30);
    }
  }

  // ── Core sync ──────────────────────────────────────────────────
  // Mirrors: func syncState()
  void _syncState() {
    _timer?.cancel();

    if (_unlockAttempts < _maxAttempts) {
      state = LockoutUnlocked(
        attemptsLeft: _maxAttempts - _unlockAttempts,
        maxAttempts: _maxAttempts,
      );
    } else {
      final lockTimestamp =
          DateTime.fromMillisecondsSinceEpoch(_lockTimestampMs);
      final elapsed = DateTime.now().difference(lockTimestamp);
      final lockoutDuration = _lockoutDuration;

      if (elapsed > lockoutDuration) {
        // 鎖定期已過：給 1 次嘗試機會（與 Swift 實作相同的 attemptsLeft = 1）
        state = const LockoutUnlocked(attemptsLeft: 1, maxAttempts: _maxAttempts);
      } else {
        final remaining = lockoutDuration - elapsed;
        final unlockTime = DateTime.now().add(remaining);
        state = LockoutLocked(unlockTime: unlockTime);

        // 排 Timer，到期後自動 refresh（Mirrors: Timer.scheduledTimer）
        _timer = Timer(remaining, _syncState);
      }
    }
  }

  // ── Public API ─────────────────────────────────────────────────

  /// 解鎖成功 → 歸零計數  Mirrors: func didUnlock()
  Future<void> didUnlock() async {
    _unlockAttempts = 0;
    await _storage.write(_attemptsKey, '0');
    _syncState();
  }

  /// 解鎖失敗 → 計數 +1，更新 timestamp  Mirrors: func didFailUnlock()
  Future<void> didFailUnlock() async {
    _unlockAttempts++;
    _lockTimestampMs = DateTime.now().millisecondsSinceEpoch;
    await Future.wait([
      _storage.write(_attemptsKey, '$_unlockAttempts'),
      _storage.write(_timestampKey, '$_lockTimestampMs'),
    ]);
    _syncState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
