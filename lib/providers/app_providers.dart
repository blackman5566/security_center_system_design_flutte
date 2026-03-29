// app_providers.dart
//
// Mirrors: AppCore.swift  +  AppCore.init()  的 DI 組裝順序
//
// ┌─────────────────────────────────────────────────────────┐
// │  Provider Graph（對應 AppCore 的依賴層次）               │
// │                                                         │
// │  sharedPreferencesProvider  (overridden in main())      │
// │         ↓                                               │
// │  preferencesStorageProvider                             │
// │  secureStorageProvider                                  │
// │         ↓                                               │
// │  coreStorageProvider                                    │
// │         ↓                                               │
// │  passcodeManagerProvider                                │
// │  biometryManagerProvider                                │
// │  lockoutManagerProvider                                 │
// │  lockManagerProvider  (depends on passcodeManager)      │
// │  coverManagerProvider                                   │
// │  passcodeLockManagerProvider                            │
// └─────────────────────────────────────────────────────────┘
//
// 設計重點：
// - ProviderScope 在 main() 初始化後即是整個 App 的「DI container」
//   完全對應 Swift 的 AppCore.shared singleton
// - Provider 的 lazy 特性：只有被 watch/read 時才建立 instance
//   對應 Swift lazy var 或手動初始化的行為

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_core/storage/secure_storage.dart';
import '../app_core/storage/preferences_storage.dart';
import '../app_core/storage/core_storage.dart';
import '../app_core/security/passcode/passcode_manager.dart';
import '../app_core/security/biometry/biometry_manager.dart';
import '../app_core/security/lock/lock_manager.dart';
import '../app_core/security/lockout/lockout_manager.dart';
import '../app_core/security/cover/cover_manager.dart';
import '../app_core/security/passcode_lock/passcode_lock_manager.dart';

// ── [1] SharedPreferences bootstrap ───────────────────────────────────────────
//
// 必須在 main() 中用 ProviderScope.overrides 覆寫此 provider，
// 因為 SharedPreferences.getInstance() 是 async。
// 對應 Swift 的 UserDefaultsStorage 直接 init（同步）。
//
// 使用方式（main.dart）：
//   final prefs = await SharedPreferences.getInstance();
//   runApp(ProviderScope(
//     overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
//     child: const SecurityCenterApp(),
//   ));
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Must be overridden in main()'),
);

// ── [2] Storage Layer ──────────────────────────────────────────────────────────
//
// Mirrors: CoreStorage.init(keychainService: "io.wallet.dev")

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => SecureStorage(),
);

final preferencesStorageProvider = Provider<PreferencesStorage>(
  (ref) => PreferencesStorage(ref.watch(sharedPreferencesProvider)),
);

final coreStorageProvider = Provider<CoreStorage>(
  (ref) => CoreStorage(
    secureStorage: ref.watch(secureStorageProvider),
    preferencesStorage: ref.watch(preferencesStorageProvider),
  ),
);

// ── [3] Domain Managers ────────────────────────────────────────────────────────
//
// 每個 Manager = Swift 的一個 @ObservableObject class
// StateNotifierProvider = Swift 的 @Published 發布機制
// ref.read(xProvider.notifier) = 取得 manager instance，呼叫 method
// ref.watch(xProvider) = 取得 manager 的 state，綁定到 UI

/// Mirrors: AppCore.passcodeManager / CoreSecurity.passcodeManager
final passcodeManagerProvider =
    StateNotifierProvider<PasscodeManager, PasscodeState>(
  (ref) {
    final storage = ref.watch(coreStorageProvider);
    return PasscodeManager(storage.secureStorage);
  },
);

/// Mirrors: AppCore.biometryManager / CoreSecurity.biometryManager
final biometryManagerProvider =
    StateNotifierProvider<BiometryManager, BiometryState>(
  (ref) {
    final storage = ref.watch(coreStorageProvider);
    return BiometryManager(storage.preferencesStorage);
  },
);

/// Mirrors: CoreSecurity.lockoutManager
final lockoutManagerProvider =
    StateNotifierProvider<LockoutManager, LockoutState>(
  (ref) {
    final storage = ref.watch(coreStorageProvider);
    return LockoutManager(storage.secureStorage);
  },
);

/// Mirrors: CoreSecurity.lockManager
///
/// 注意：LockManager 需要知道 isPasscodeSet，
/// 用 closure 注入（依賴反轉）避免 Manager 之間的循環依賴，
/// 對應 Swift 用 passivly 持有 passcodeManager 的方式。
final lockManagerProvider =
    StateNotifierProvider<LockManager, LockState>(
  (ref) {
    final storage = ref.watch(coreStorageProvider);
    return LockManager(
      secureStorage: storage.secureStorage,
      prefs: storage.preferencesStorage,
      isPasscodeSet: () => ref.read(passcodeManagerProvider).isPasscodeSet,
    );
  },
);

/// Mirrors: CoreSecurity.coverManager
final coverManagerProvider =
    StateNotifierProvider<CoverManager, CoverState>(
  (ref) => CoverManager(),
);

/// Mirrors: CoreSecurity.passcodeLockManager
final passcodeLockManagerProvider =
    StateNotifierProvider<PasscodeLockManager, PasscodeLockState>(
  (ref) => PasscodeLockManager(),
);
