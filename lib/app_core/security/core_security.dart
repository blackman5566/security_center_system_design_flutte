// core_security.dart
//
// Mirrors: CoreSecurity.swift
//
// 角色：Security domain 的協調容器。
// 持有所有 6 個 security manager，但本身不含業務邏輯，
// 只是統一的 entry point（對應 Swift 的 CoreSecurity struct）。
//
// 在 Riverpod 架構中，這個類別本身不是 StateNotifier，
// 而是一個純粹的 value holder，由 coreSecurity provider 持有。
// 各 manager 各自有對應的 StateNotifierProvider。

import 'biometry/biometry_manager.dart';
import 'passcode/passcode_manager.dart';
import 'lock/lock_manager.dart';
import 'lockout/lockout_manager.dart';
import 'cover/cover_manager.dart';
import 'passcode_lock/passcode_lock_manager.dart';

class CoreSecurity {
  final PasscodeManager passcodeManager;
  final BiometryManager biometryManager;
  final LockManager lockManager;
  final LockoutManager lockoutManager;
  final CoverManager coverManager;
  final PasscodeLockManager passcodeLockManager;

  const CoreSecurity({
    required this.passcodeManager,
    required this.biometryManager,
    required this.lockManager,
    required this.lockoutManager,
    required this.coverManager,
    required this.passcodeLockManager,
  });
}
