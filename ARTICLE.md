# 同一套系統設計，SwiftUI 與 Flutter 的對話——UI 可替換，架構才是核心

> 本文同時有 [SwiftUI 版本](https://github.com/blackman5566/SecurityCenter-SystemDesign) 與 [Flutter 版本](https://github.com/blackman5566/SecurityCenter-SystemDesign-Flutter) 供對照閱讀。

---

## 起點：一個面試現場的困境

「你說你做了一個 Security Center 的系統設計，能說明一下嗎？」

我打開 SwiftUI 的專案，開始講解 Manager 架構、狀態機、策略邊界。

對方是一位 Android 工程師。

他點著頭，但眼神透露出一種隔閡——不是不懂系統設計，而是語境不對。SwiftUI、`@Published`、`LAContext`⋯⋯這些詞彙構成了一道隱形的牆。**他在聽架構，卻先要穿越一層語言的翻譯。**

這個經驗讓我想清楚一件事：

> 如果一套系統設計只能在一個框架裡被理解，那它可能還不夠「設計」。

所以我做了 Flutter 版本。不是為了多一個 App，而是為了驗證一個假設：**相同的系統邊界、相同的狀態機、相同的策略規則，換一個 UI 框架，架構是否仍然成立？**

這篇文章就是這個驗證的紀錄。

---

## 系統設計的核心思路

在開始比較之前，先說明這套安全子系統在設計時的核心思路。

### 安全不是一個畫面，而是一個系統

大多數 App 的安全功能長這樣：「設定頁面有個 Toggle，打開就有 Face ID。」

這種做法的問題是，安全邏輯散落在 UI 各處：
- ViewController A 判斷要不要顯示解鎖畫面
- ViewController B 決定生物識別能不能用
- ViewController C 自己算失敗次數

當產品需求改變時，你要改的地方多、容易漏、難以測試。

**這個專案的做法是把安全視為獨立的 Domain Layer：**

```
Security
├─ PasscodeManager     → 密碼的建立、驗證、生命週期
├─ BiometryManager     → 生物識別的偵測與策略
├─ LockManager         → App 上鎖 / 解鎖狀態
├─ LockoutManager      → 錯誤次數與指數退避鎖定
├─ CoverManager        → 背景隱私遮罩
└─ PasscodeLockManager → 裝置層級密碼狀態偵測
```

**每個 Manager 擁有自己的狀態、自己的規則、自己的儲存邊界。** UI 只是這個系統的投影。

這樣設計的好處：
- 新增一條安全策略，只動對應的 Manager
- 規則在整個 App 中一致，不會在這個頁面開、在那個頁面忘了關
- 可以獨立測試每個 Manager 的行為，不需要跑 UI

---

## 框架對換，架構不變

現在進入核心：把相同的設計，從 SwiftUI / Combine 搬到 Flutter / Riverpod。

### 1. 響應式狀態層的對換

SwiftUI 的響應式核心是 `@ObservableObject` + `@Published`：

```swift
// SwiftUI — LockManager.swift
final class LockManager: ObservableObject {
    @Published private(set) var isLocked: Bool = false
    @Published private(set) var autoLockPeriod: AutoLockPeriod = .minute1

    func lock() {
        isLocked = true
    }
}
```

Flutter 的對應是 `StateNotifier<State>`：

```dart
// Flutter — lock_manager.dart
class LockState {
  final bool isLocked;
  final AutoLockPeriod autoLockPeriod;
  const LockState({this.isLocked = false, this.autoLockPeriod = AutoLockPeriod.minute1});
}

class LockManager extends StateNotifier<LockState> {
  LockManager() : super(const LockState());

  void lock() {
    state = state.copyWith(isLocked: true);
  }
}
```

**概念完全對應**。差異只在語法：
- SwiftUI 用 `@Published` 屬性自動觸發更新
- Flutter 用 `state = ...` 賦值觸發更新

狀態的責任邊界、不可變性（LockState 是 value type）、外部唯讀——兩邊一致。

---

### 2. 跨 Manager 的訂閱

SwiftUI 版的 `SecuritySettingsViewModel` 用 Combine 訂閱三個 Manager：

```swift
// SwiftUI — SecuritySettingsViewModel.swift
private var cancellables = Set<AnyCancellable>()

init() {
    passcodeManager.$state
        .combineLatest(biometryManager.$state, lockManager.$state)
        .sink { [weak self] _ in self?.syncState() }
        .store(in: &cancellables)
}
```

Flutter 版用 `stream.listen()` 做相同的事：

```dart
// Flutter — security_settings_notifier.dart
final List<StreamSubscription> _subs = [];

SecuritySettingsNotifier(...) : super(const SecuritySettingsState()) {
  _subs.addAll([
    passcodeManager.stream.listen((_) => _syncState()),
    biometryManager.stream.listen((_) => _syncState()),
    lockManager.stream.listen((_) => _syncState()),
  ]);
}

@override
void dispose() {
  for (final sub in _subs) sub.cancel();
  super.dispose();
}
```

**`Combine sink + cancellables` 對應 `stream.listen() + StreamSubscription.cancel()`。**
訂閱的生命週期管理、dispose 時取消——邏輯完全一樣。

---

### 3. DI Container 的對換

SwiftUI 用 `AppCore.shared` 這個 singleton 做依賴注入的根：

```swift
// SwiftUI — AppCore.swift
final class AppCore {
    static let shared = AppCore()
    let security: CoreSecurity

    private init() {
        let storage = try CoreStorage()
        security = CoreSecurity(storage: storage)
    }
}
```

Flutter 用 `ProviderScope` + lazy providers 取代：

```dart
// Flutter — app_providers.dart
final passcodeManagerProvider = StateNotifierProvider<PasscodeManager, PasscodeState>(
  (ref) => PasscodeManager(ref.read(coreStorageProvider)),
);

final lockManagerProvider = StateNotifierProvider<LockManager, LockState>(
  (ref) => LockManager(
    secureStorage: ref.read(secureStorageProvider),
    isPasscodeSet: () => ref.read(passcodeManagerProvider).isPasscodeSet,
  ),
);
```

兩者都是：
- 在應用程式最外層建立 container
- 內部 lazy 初始化，依賴關係由 container 解析
- Manager 之間不直接互相引用，透過 container 取得

**差異在於 Flutter 的 Provider graph 是宣告式的，循環依賴在編譯期就能被偵測。** 這是 Riverpod 相對 singleton 的優勢之一。

---

### 4. 多層 UIWindow → 宣告式 Stack

這是兩個框架差異最大的地方，也是最能體現「系統設計獨立於框架」的地方。

SwiftUI 版用多層 `UIWindow` 實作 Lock Screen 和 Cover Overlay：

```swift
// SwiftUI — LockManager.swift
func lock() {
    let window = UIWindow(windowScene: windowScene)
    window.windowLevel = .alert - 1
    window.rootViewController = UIHostingController(rootView: AppUnlockView())
    window.makeKeyAndVisible()
    lockWindow = window
}

func unlock() {
    lockWindow?.isHidden = true
    lockWindow = nil
}
```

Flutter 用宣告式的 root Stack 取代：

```dart
// Flutter — main.dart
home: Stack(
  children: [
    // Layer 1: 主要內容
    const SecuritySettingsView(),

    // Layer 2: 隱私遮罩（狀態驅動）
    if (coverState.isCoverVisible)
      const CoverOverlay(),

    // Layer 3: 解鎖畫面（狀態驅動）
    if (lockState.isLocked)
      const AppUnlockView(),
  ],
),
```

**實作方式完全不同，但行為完全相同：**
- 進背景時，Cover 出現
- 滿足 auto-lock 條件，AppUnlockView 出現
- 解鎖後，AppUnlockView 自動消失

SwiftUI 版需要命令式地 `addSubview` / `removeFromSuperview`。
Flutter 版只需要 `isLocked` 從 `true` 變成 `false`，Stack 自動 diff、自動移除。

這正是「系統設計獨立於框架」最清楚的體現：**`LockManager` 的責任是決定「應該鎖還是不鎖」，至於畫面怎麼長、用哪種方式呈現，是 UI 框架的問題。**

---

### 5. Template Method Pattern 的對換

解鎖流程（App Unlock / Module Unlock）和設定密碼流程（Create / Edit Passcode）都用了 Template Method Pattern。

SwiftUI 版用 class 繼承：

```swift
// SwiftUI — BaseUnlockViewModel.swift
class BaseUnlockViewModel: ObservableObject {
    // 骨架：輸入 → 驗證 → lockout 計數 → 成功 / 失敗
    func handleEntered(passcode: String) {
        if isValid(passcode: passcode) {
            onEnterValid(passcode: passcode)
            lockoutManager.didUnlock()
        } else {
            lockoutManager.didFailUnlock()
        }
    }

    // 子類覆寫
    func isValid(passcode: String) -> Bool { fatalError() }
    func onEnterValid(passcode: String) { fatalError() }
}

// AppUnlockViewModel.swift
class AppUnlockViewModel: BaseUnlockViewModel {
    override func isValid(passcode: String) -> Bool {
        passcodeManager.has(passcode: passcode)
    }
    override func onEnterValid(passcode: String) {
        lockManager.unlock()
    }
}
```

Flutter 版用 abstract class：

```dart
// Flutter — base_unlock_notifier.dart
abstract class BaseUnlockNotifier extends StateNotifier<UnlockState> {
  // 骨架：輸入 → 驗證 → lockout 計數 → 成功 / 失敗
  Future<void> _handleEntered(String passcode) async {
    if (isValid(passcode)) {
      onEnterValid(passcode);
      await lockoutManager.didUnlock();
    } else {
      await lockoutManager.didFailUnlock();
    }
  }

  // 子類覆寫
  bool isValid(String passcode);
  void onEnterValid(String passcode);
}

// app_unlock_notifier.dart
class AppUnlockNotifier extends BaseUnlockNotifier {
  @override
  bool isValid(String passcode) => passcodeManager.has(passcode);

  @override
  void onEnterValid(String passcode) {
    lockManager.unlock();
  }
}
```

**Pattern 相同，語法不同。** Swift 用 `fatalError()` 強制子類覆寫；Dart 用 `abstract` 方法在編譯期保證。

---

### 6. 指數退避鎖定（Lockout）

這是整套系統裡最純粹的「業務規則」，跟 UI 框架完全無關。

SwiftUI 版：

```swift
private var lockoutInterval: TimeInterval {
    switch unlockAttempts {
    case maxAttempts:     return 5 * 60
    case maxAttempts + 1: return 10 * 60
    case maxAttempts + 2: return 15 * 60
    default:              return 30 * 60
    }
}
```

Flutter 版：

```dart
Duration get _lockoutDuration {
  if (_unlockAttempts == _maxAttempts)     return const Duration(minutes: 5);
  if (_unlockAttempts == _maxAttempts + 1) return const Duration(minutes: 10);
  if (_unlockAttempts == _maxAttempts + 2) return const Duration(minutes: 15);
  return const Duration(minutes: 30);
}
```

**幾乎逐行對應。** 因為這是業務規則，不是框架行為。
兩個版本的 Keychain key 名稱也完全一樣（`"unlock_attempts_keychain_key"`、`"lock_timestamp_keychain_key"`），確保跨平台的語義一致性。

---

## 驗證結果

經過這次移植，原本的假設得到了驗證：

**相同的系統邊界 ✓** — 六個 Manager 的職責完全對應，沒有因為換框架而合併或拆分。

**相同的狀態機 ✓** — 鎖定 / 解鎖 / Lockout 的狀態轉換邏輯在兩邊完全一致。

**相同的安全策略 ✓** — 指數退避、Keychain key 命名、多層 passcode 格式——全部對齊。

**UI 層可替換 ✓** — `UIWindow` 換成 `Stack`；`Combine` 換成 `stream.listen()`；`@Published` 換成 `StateNotifier`——行為不變。

唯一有意義的差異：

| 差異點 | SwiftUI | Flutter | 原因 |
|---|---|---|---|
| 時鐘防篡改 | `CLOCK_MONOTONIC_RAW` | `DateTime.now()` | Dart 無跨平台 monotonic persistent clock |
| Overlay 實作 | 命令式 UIWindow | 宣告式 Stack | Flutter 的 idiomatic 做法 |
| Associated values | Swift enum with values | Dart sealed class | 語言特性差異 |

這些差異都是「如何表達」的問題，不是「設計決策」的問題。

---

## 核心體會

做完這個實驗，有三點感受：

**第一，系統設計的可搬移性是設計品質的指標。**
如果一個設計在換框架時需要大幅調整邊界，通常意味著它當初的邊界是由框架決定的，而不是由業務規則決定的。

**第二，響應式框架的差異比想像中小。**
`@Published` 和 `StateNotifier`，`Combine` 和 `stream.listen()`，本質上都是「狀態變化時通知觀察者」。語法不同，概念相同。真正需要理解的是狀態機，而不是哪個 operator。

**第三，跨框架表達讓設計更清晰。**
當你能用兩種語言說同一件事，你對這件事的理解才算紮實。這次移植逼迫我重新確認每一個設計決策的理由——為什麼要這樣切邊界、為什麼這個規則在這裡、為什麼狀態要這樣流動。

> 在 AI 大幅加速實作的時代，
> **系統邊界與責任劃分的設計能力，才是真正的差異化。**

---

## 延伸閱讀

- [SwiftUI 版本原始碼](https://github.com/blackman5566/SecurityCenter-SystemDesign)
- [Flutter 版本原始碼](https://github.com/blackman5566/SecurityCenter-SystemDesign-Flutter)
