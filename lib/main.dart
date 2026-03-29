// main.dart
//
// Mirrors: SecurityCenter_SystemDesignApp.swift + AppSceneDelegate.swift
//
// ── 啟動流程對照 ─────────────────────────────────────────────────────────────
//
// Swift:
//   1. @main App.init() → AppCore.initApp() → 建立所有 manager（eager init）
//   2. AppSceneDelegate 橋接 UIKit lifecycle → 呼叫 manager 方法
//   3. 根 View = SecuritySettingsModule.view()（DI 組裝）
//
// Flutter:
//   1. main() async → SharedPreferences.getInstance()
//      → ProviderScope(overrides: [...]) 即是 AppCore 的 DI container
//      （ProviderScope 的 lazy Provider 等效於 AppCore.initApp() 的 eager init）
//   2. SecurityCenterApp 掛載 WidgetsBindingObserver
//      → 接收 AppLifecycleState → 呼叫 manager 方法
//      （等效於 AppSceneDelegate 的 scene lifecycle callbacks）
//   3. 根 Widget Stack：
//      - Layer 1: SecuritySettingsView（主內容）
//      - Layer 2: CoverOverlay（隱私遮蓋）← CoverManager.isCoverVisible
//      - Layer 3: AppUnlockView（解鎖畫面）← LockManager.isLocked
//      （等效於 Swift 的多層 UIWindow，但用 declarative Stack 替代 imperative addSubview）
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_providers.dart';
import 'features/security_settings/security_settings_view.dart';
import 'features/security_settings/unlock/app_unlock_view.dart';
import 'features/cover_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 非同步初始化 SharedPreferences ─────────────────────────────
  // Mirrors: UserDefaultsStorage.init()（Swift 是同步，Flutter 需 async）
  final prefs = await SharedPreferences.getInstance();

  // ── 首次安裝：清除 SecureStorage 殘留資料 ──────────────────────
  // Mirrors: KeychainManager.handleLaunch()
  // 原因：iOS Keychain 在 App 刪除後仍保留資料，
  // 重裝 App 時若有殘留 passcode 會造成無法解鎖的死結
  const firstLaunchKey = 'did_launch_once';
  if (!prefs.containsKey(firstLaunchKey)) {
    await const FlutterSecureStorage().deleteAll();
    await prefs.setBool(firstLaunchKey, true);
  }

  runApp(
    ProviderScope(
      overrides: [
        // SharedPreferences 需要 async init，因此在 main() 中 override。
        // 其他 provider（SecureStorage、managers 等）是同步的，
        // 由 ProviderScope 的 lazy init 機制自動建立。
        //
        // Mirrors: AppCore.init() 的所有 try { self.storage = CoreStorage(...) } 邏輯
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SecurityCenterApp(),
    ),
  );
}

// ── Root Application Widget ────────────────────────────────────────────────────

/// Mirrors: SecurityCenter_SystemDesignApp（@main）+ AppSceneDelegate 的功能合併
///
/// 為何合併：
/// - Swift 需要 UIWindowSceneDelegate 橋接 UIKit lifecycle
/// - Flutter 直接在 Widget 層透過 WidgetsBindingObserver 監聽，不需要額外橋接
class SecurityCenterApp extends ConsumerStatefulWidget {
  const SecurityCenterApp({super.key});

  @override
  ConsumerState<SecurityCenterApp> createState() => _SecurityCenterAppState();
}

class _SecurityCenterAppState extends ConsumerState<SecurityCenterApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App lifecycle → manager method 映射
  ///
  /// Mirrors: AppSceneDelegate 的各個 scene lifecycle callbacks
  ///   sceneDidEnterBackground    → didEnterBackground
  ///   sceneWillEnterForeground   → willEnterForeground
  ///   sceneWillResignActive      → coverManager.show()
  ///   sceneDidBecomeActive       → coverManager.hide()
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
        // App 完全進入背景
        ref.read(lockManagerProvider.notifier).didEnterBackground();
        ref.read(coverManagerProvider.notifier).show();
        break;

      case AppLifecycleState.resumed:
        // App 回到前景
        ref.read(coverManagerProvider.notifier).hide();
        ref.read(lockManagerProvider.notifier).willEnterForeground();
        // 裝置安全狀態檢查（Mirrors: PasscodeLockManager.handleForeground）
        ref.read(passcodeLockManagerProvider.notifier).checkDeviceSecurity(
          onSecurityCompromised: () {
            debugPrint('[SecurityCenter] Device security compromised!');
            // 實際 App：在此觸發資料保護流程（清除敏感資料、強制登出等）
          },
        );
        break;

      case AppLifecycleState.inactive:
        // App 即將失去 active 狀態（例如來電、控制中心）
        ref.read(coverManagerProvider.notifier).show();
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(lockManagerProvider);
    final coverState = ref.watch(coverManagerProvider);

    return MaterialApp(
      title: 'Security Center',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          surface: Color(0xFF2C2C2E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2C2C2E),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 17),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      // ── App Root Stack ────────────────────────────────────────────
      //
      // 架構說明（對應 Swift 的多層 UIWindow）：
      //
      // Swift UIWindow 層次：
      //   App Window (normal)
      //   Cover Window (alert - 2)   ← CoverManager
      //   Lock Window  (alert - 1)   ← LockManager
      //
      // Flutter Stack 層次（等效）：
      //   [0] SecuritySettingsView  ← 主要內容（always present）
      //   [1] _CoverOverlay         ← 條件顯示（coverState.isCoverVisible）
      //   [2] AppUnlockView         ← 條件顯示（lockState.isLocked）
      //
      // Flutter 的優勢：
      // - 不需要手動建立/釋放 UIWindow（imperative）
      // - 狀態驅動 → 自動 diff → 只更新需要改變的層（declarative）
      // - isLocked 從 true → false 時，AppUnlockView 自動從 Stack 移除
      home: Stack(
        children: [
          // Layer 1: 主要內容
          const SecuritySettingsView(),

          // Layer 2: 隱私遮蓋
          // Mirrors: CoverManager 的 UIWindow
          if (coverState.isCoverVisible)
            const CoverOverlay(),

          // Layer 3: 解鎖畫面
          // Mirrors: LockManager.lock() → UIWindow(rootViewController: AppUnlockView)
          // 解鎖後：LockManager.unlock() → isLocked = false → Stack 自動移除此層
          if (lockState.isLocked)
            const AppUnlockView(),
        ],
      ),
    );
  }
}
