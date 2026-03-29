<div align="left">
  <a href="README_CN.md"><img alt="中文" src="https://img.shields.io/badge/Documentation-中文-blue"></a>
</div>

# Security Center – Modular Security Subsystem (Flutter / Riverpod)

## Overview

**Security is not a screen — it's a system.**

This project is a **Flutter / Riverpod port** of the same Security Center subsystem, originally built in SwiftUI.

> SwiftUI version → [SecurityCenter-SystemDesign](https://github.com/blackman5566/SecurityCenter-SystemDesign)

The goal is not to build another Flutter app.
The goal is to **prove that the system design is framework-agnostic**.

When presenting system design in interviews, showing a SwiftUI app to non-iOS engineers creates an unnecessary barrier.
This port removes that barrier — by implementing the **exact same domain architecture** in a cross-platform framework, making the design visible to anyone.

The UI layer is swapped. The system design is not.

<p align="center">
  <img 
    src="https://github.com/blackman5566/security_center_system_design_flutte/blob/main/image.png" 
    alt="SecurityCenter-SystemDesign Demo" 
    width="640"
  />
</p>

---

## Why This Exists

> If a system design only works in one framework, it's not really a system design.

In both versions, security is modeled as an independent **domain layer** with explicit ownership and clear boundaries.
The only thing that changes between SwiftUI and Flutter is the syntax of the reactive layer:

| SwiftUI / Combine | Flutter / Riverpod |
|---|---|
| `@ObservableObject` + `@Published` | `StateNotifier<State>` |
| `Combine` sink + cancellables | `stream.listen()` + `StreamSubscription` |
| `AppCore.shared` singleton | `ProviderScope` + lazy providers |
| `UIWindowSceneDelegate` | `WidgetsBindingObserver` |
| Multi-layer `UIWindow` | Declarative root `Stack` |
| `LAContext.evaluatePolicy` | `local_auth` plugin |
| `Keychain` | `flutter_secure_storage` |
| `UserDefaults` | `shared_preferences` |

The managers, state machines, policies, and boundaries are identical.
The framework is different. The architecture is the same.

---

## Key Features

- **Passcode lifecycle**
  - Create / Edit / Disable passcode
  - Edit and Disable require passcode re-authentication (via Module Unlock)
- **Biometric authentication**
  - Face ID / Touch ID support
  - Three modes: Off / Manual (button-triggered) / Auto (on app launch)
- **Randomized keypad**
  - Protects against shoulder-surfing attacks
- **Auto-lock policies**
  - Never / 1 min / 5 min / 15 min / 30 min / 1 hour
- **Retry limits & exponential backoff lockout**
  - 5 attempts → 5 / 10 / 15 / 30 min cooldown
  - Persisted across app restarts
- **Secure background protection**
  - Automatic cover view when app becomes inactive or enters background
- **Unified unlock flow**
  - Centralized handling for passcode, biometric, and fallback paths

---

## Architecture

This project models security as an independent **domain layer**, not UI-driven logic.

```
lib/
├─ app_core/
│   ├─ security/
│   │   ├─ PasscodeManager      // Passcode creation, validation, multi-layer
│   │   ├─ BiometryManager      // Face ID / Touch ID detection & policy
│   │   ├─ LockManager          // App lock / unlock state + auto-lock timer
│   │   ├─ LockoutManager       // Retry limits & exponential backoff
│   │   ├─ CoverManager         // Background privacy overlay
│   │   └─ PasscodeLockManager  // Device-level passcode detection
│   └─ storage/
│       ├─ SecureStorage        // flutter_secure_storage  (mirrors Keychain)
│       └─ PreferencesStorage   // shared_preferences      (mirrors UserDefaults)
│
├─ providers/
│   └─ app_providers.dart       // DI graph (mirrors AppCore.shared)
│
└─ features/
    └─ security_settings/
        ├─ passcode/            // SetPasscode / Create / Edit  (Template Method)
        ├─ unlock/              // AppUnlock / ModuleUnlock / BaseUnlock (Template Method)
        ├─ auto_lock/           // AutoLockView
        └─ widgets/             // SectionHeader / SettingRow / LockoutCountdown
```

---

## Design Principles

- **Single Responsibility**
  - Each security capability owns its own behavior and state
- **Explicit Boundaries via Dependency Injection**
  - Managers are injected through providers — no global access
- **State-driven UI**
  - Views react to security state instead of deciding behavior
- **Template Method Pattern**
  - `BaseUnlockNotifier` and `SetPasscodeNotifier` define the algorithm skeleton; subclasses override only what differs
- **Declarative Overlay Architecture**
  - Lock screen and cover overlay are Stack layers driven by state, not imperative window manipulation

---

## Why This Matters

> With AI accelerating implementation, **system boundaries and responsibility design**
> are becoming the real differentiators.

Security features tend to grow organically and become fragile over time.
By treating security as a subsystem — and proving it holds across two different UI frameworks:

- New policies can be added without touching existing UI
- Rules remain consistent across the app
- Behavior stays predictable as complexity increases
- The system becomes easier to test and reason about

---

## Tech Stack

| | |
|---|---|
| Language | Dart 3.8 |
| Framework | Flutter 3.32 |
| State Management | flutter_riverpod 2.x |
| Secure Storage | flutter_secure_storage |
| Preferences | shared_preferences |
| Biometrics | local_auth |

---

## Running the Project

```bash
flutter pub get

# Android emulator
flutter run

# iOS physical device (recommended: profile mode to avoid JIT W^X issue)
flutter run --profile
```

---

## Notes

- This repository focuses on **system design and architecture**
- UI is kept intentionally minimal to highlight behavioral correctness
- Read alongside the [SwiftUI version](https://github.com/blackman5566/SecurityCenter-SystemDesign) to see the same design expressed in two different frameworks
