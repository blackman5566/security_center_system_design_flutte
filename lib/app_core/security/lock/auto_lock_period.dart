// auto_lock_period.dart
//
// Mirrors: AutoLockPeriod.swift
//
// 設計目的：
// - 收斂自動鎖定時間成有限、有意義的選項
// - 同時服務 UI 顯示（title）與實際邏輯（duration）
// - 避免 magic number 散落在 LockManager 或其他地方

enum AutoLockPeriod {
  immediate,
  minute1,
  minute5,
  minute15,
  minute30,
  hour1;

  /// 對外的識別字串（用於 SharedPreferences 存取）
  /// 對應 Swift 的 rawValue
  String get rawValue => name;

  static AutoLockPeriod? fromRawValue(String? raw) {
    if (raw == null) return null;
    for (final v in AutoLockPeriod.values) {
      if (v.rawValue == raw) return v;
    }
    return null;
  }

  /// 對應的鎖定時間長度
  /// Mirrors: AutoLockPeriod.period (TimeInterval)
  Duration get duration {
    switch (this) {
      case AutoLockPeriod.immediate:
        return Duration.zero;
      case AutoLockPeriod.minute1:
        return const Duration(minutes: 1);
      case AutoLockPeriod.minute5:
        return const Duration(minutes: 5);
      case AutoLockPeriod.minute15:
        return const Duration(minutes: 15);
      case AutoLockPeriod.minute30:
        return const Duration(minutes: 30);
      case AutoLockPeriod.hour1:
        return const Duration(hours: 1);
    }
  }

  /// UI 顯示用標題
  String get title {
    switch (this) {
      case AutoLockPeriod.immediate:
        return 'Immediately';
      case AutoLockPeriod.minute1:
        return '1 minute';
      case AutoLockPeriod.minute5:
        return '5 minutes';
      case AutoLockPeriod.minute15:
        return '15 minutes';
      case AutoLockPeriod.minute30:
        return '30 minutes';
      case AutoLockPeriod.hour1:
        return '1 hour';
    }
  }
}
