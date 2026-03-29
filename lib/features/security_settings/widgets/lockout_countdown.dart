// lockout_countdown.dart
//
// Mirrors: PasscodeView.swift locked state UI
//
// Swift:
//   Image("lock_48").foregroundColor(.gray)
//   Text("Disabled until: \(DateFormatter.cachedFormatter(format: "hh:mm:ss").string(from: unlockDate))")
//
// Flutter:
//   Icon(Icons.lock_outline) + "Disabled until: HH:mm:ss"
//   LockoutManager 內建 Timer 到期後會自動 syncState()，
//   state 從 LockoutLocked → LockoutUnlocked，UI 自動移除此 widget。
//   故此 widget 不需要 countdown timer，直接顯示靜態解鎖時間即可。

import 'package:flutter/material.dart';

/// Mirrors: PasscodeView locked state (Image("lock_48") + "Disabled until:")
class LockoutCountdown extends StatelessWidget {
  final DateTime unlockTime;
  const LockoutCountdown({super.key, required this.unlockTime});

  @override
  Widget build(BuildContext context) {
    final h = unlockTime.hour.toString().padLeft(2, '0');
    final m = unlockTime.minute.toString().padLeft(2, '0');
    final s = unlockTime.second.toString().padLeft(2, '0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mirrors: Image("lock_48").foregroundColor(.gray)
        const Icon(Icons.lock_outline, color: Colors.grey, size: 48),
        const SizedBox(height: 12),
        Text(
          'Disabled until: $h:$m:$s',
          style: const TextStyle(color: Colors.red, fontSize: 14),
        ),
      ],
    );
  }
}
