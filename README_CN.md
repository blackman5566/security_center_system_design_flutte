<div align="left">
  <a href="README.md"><img alt="English" src="https://img.shields.io/badge/Documentation-English-blue"></a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.32-54C5F8?logo=flutter">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.8-0175C2?logo=dart">
  <img alt="Riverpod" src="https://img.shields.io/badge/Riverpod-2.x-00BCD4">
</div>

# Security Center－模組化安全子系統（Flutter / Riverpod）

## 專案概覽

**Security 不是一個畫面，而是一個系統。**

本專案是相同 Security Center 安全子系統的 **Flutter / Riverpod 版本**，原始版本以 SwiftUI 實作。

> SwiftUI 版本 → [SecurityCenter-SystemDesign](https://github.com/blackman5566/SecurityCenter-SystemDesign)

這個專案的目標，不是「再做一個 Flutter App」。
目標是 **證明這套系統設計是框架無關的（framework-agnostic）**。

在面試中說明系統設計，如果只有 SwiftUI 版本，非 iOS 工程師往往需要跨越一道語言框架的理解障礙。
Flutter 版本消除了這道障礙——用跨平台框架實作相同的 Domain 架構，讓系統設計本身對所有人都清晰可見。

UI 層換了。系統設計沒有換。

<p align="center">
  <img 
    src="https://github.com/blackman5566/security_center_system_design_flutte/blob/main/image.png" 
    alt="SecurityCenter-SystemDesign Demo" 
    width="640"
  />
</p>

---

## 為什麼做這個？

> 如果一套系統設計只能在一個框架裡運作，它就不是真正的系統設計。

兩個版本都將安全邏輯建模為獨立的 **Domain Layer**，具備明確的責任邊界與 ownership。
SwiftUI 與 Flutter 之間，唯一真正改變的是響應式層的語法：

| SwiftUI / Combine | Flutter / Riverpod |
|---|---|
| `@ObservableObject` + `@Published` | `StateNotifier<State>` |
| `Combine` sink + cancellables | `stream.listen()` + `StreamSubscription` |
| `AppCore.shared` singleton | `ProviderScope` + lazy providers |
| `UIWindowSceneDelegate` | `WidgetsBindingObserver` |
| 多層 `UIWindow` | 宣告式 root `Stack` |
| `LAContext.evaluatePolicy` | `local_auth` plugin |
| `Keychain` | `flutter_secure_storage` |
| `UserDefaults` | `shared_preferences` |

Manager、狀態機、策略規則、邊界劃分——完全一致。
框架不同。架構相同。

---

## 核心功能

- **密碼（Passcode）生命週期**
  - 建立 / 修改 / 停用密碼
  - 修改與停用需先通過密碼驗證（Module Unlock）
- **生物識別解鎖**
  - 支援 Face ID / Touch ID
  - 三種模式：關閉 / 手動觸發 / 自動觸發
- **隨機鍵盤**
  - 防止側錄與偷看（Shoulder Surfing）
- **自動上鎖策略**
  - 永不 / 1 分鐘 / 5 分鐘 / 15 分鐘 / 30 分鐘 / 1 小時
- **錯誤次數限制與指數退避鎖定**
  - 5 次失敗 → 5 / 10 / 15 / 30 分鐘冷卻鎖定
  - 持久化至 Secure Storage，重啟 App 仍保留
- **背景保護機制**
  - App 進入背景或非活躍狀態時自動顯示隱私遮罩
- **統一解鎖流程**
  - 密碼、生物識別與 fallback 路徑集中處理

---

## 架構設計

本專案將安全邏輯建模為獨立的 **Domain Layer**，而非 UI 導向實作。

```
lib/
├─ app_core/
│   ├─ security/
│   │   ├─ PasscodeManager      // 密碼建立、驗證與生命週期（多層支援）
│   │   ├─ BiometryManager      // Face ID / Touch ID 偵測與策略管理
│   │   ├─ LockManager          // App 上鎖 / 解鎖狀態 + 自動上鎖計時
│   │   ├─ LockoutManager       // 嘗試次數限制與指數退避鎖定
│   │   ├─ CoverManager         // 背景隱私遮罩
│   │   └─ PasscodeLockManager  // 裝置層級密碼狀態偵測
│   └─ storage/
│       ├─ SecureStorage        // flutter_secure_storage（對應 Keychain）
│       └─ PreferencesStorage   // shared_preferences（對應 UserDefaults）
│
├─ providers/
│   └─ app_providers.dart       // DI 圖（對應 AppCore.shared）
│
└─ features/
    └─ security_settings/
        ├─ passcode/            // SetPasscode / Create / Edit（Template Method）
        ├─ unlock/              // AppUnlock / ModuleUnlock / BaseUnlock（Template Method）
        ├─ auto_lock/           // AutoLockView
        └─ widgets/             // SectionHeader / SettingRow / LockoutCountdown
```

---

## 設計原則

- **單一責任（Single Responsibility）**
  - 每一項安全能力由獨立 Manager 負責，互不干涉
- **依賴注入（Dependency Injection）**
  - 所有 Manager 透過 Provider 注入，無全域存取
- **狀態驅動 UI（State-driven UI）**
  - UI 只訂閱狀態，不自行推導安全行為
- **Template Method Pattern**
  - `BaseUnlockNotifier` 與 `SetPasscodeNotifier` 定義演算法骨架，子類只覆寫差異部分
- **宣告式 Overlay 架構**
  - 鎖定畫面與隱私遮罩是狀態驅動的 Stack 層，而非命令式 window 操作

---

## 為什麼這樣設計？

> 在 AI 大幅加速實作的時代，
> **系統邊界與責任劃分的設計能力，才是真正的差異化。**

安全需求往往隨產品成長而持續堆疊，若缺乏邊界與 ownership，系統將快速變得脆弱。
透過將安全視為獨立子系統——並且在兩個不同 UI 框架中驗證它依然成立：

- 可在不修改 UI 的情況下新增安全策略
- 規則一致，避免各頁分散實作造成漏洞
- 系統在複雜度提升時仍保持可預期行為
- 測試性與可理解性大幅提升

---

## 技術棧

| | |
|---|---|
| 語言 | Dart 3.8 |
| 框架 | Flutter 3.32 |
| 狀態管理 | flutter_riverpod 2.x |
| 安全儲存 | flutter_secure_storage |
| 偏好設定 | shared_preferences |
| 生物識別 | local_auth |

---

## 執行方式

```bash
flutter pub get

# Android 模擬器
flutter run

# iOS 實體機（建議使用 profile mode，避免 JIT W^X 問題）
flutter run --profile
```

---

## 備註

- 本專案重點在於 **系統設計與架構思維**
- UI 僅作為狀態呈現，非設計重點
- 建議與 [SwiftUI 版本](https://github.com/blackman5566/SecurityCenter-SystemDesign) 並排閱讀，以相同設計在兩個框架中的表達方式為比較基準
