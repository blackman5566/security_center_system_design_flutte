// no_passcode_view.dart
//
// Mirrors: NoPasscodeView.swift
//
// 裝置未設置螢幕鎖（screen lock / passcode）時顯示的提示畫面。
// Mode 對應 Swift 的 NoPasscodeView.Mode enum。

import 'package:flutter/material.dart';

/// Mirrors: NoPasscodeView.swift
class NoPasscodeView extends StatelessWidget {
  final NoPasscodeViewMode mode;

  const NoPasscodeView({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            mode.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Mirrors: NoPasscodeView.Mode (Swift enum)
enum NoPasscodeViewMode {
  noPasscode,
  cannotCheckPasscode;

  String get description {
    switch (this) {
      case NoPasscodeViewMode.noPasscode:
        return 'This app requires that phone has the passcode (screen lock) enabled.\n\n'
            'You may enable it in iOS settings.\n\n'
            'Please note that when you disabled the PIN on the OS level the security measures '
            'in safe storage of your phone made the previously stored data invalid. '
            'You will need to Restore your wallet keys to get back to your wallet.';
      case NoPasscodeViewMode.cannotCheckPasscode:
        return 'Unable to check the state of passcode (screen lock). '
            'Please restart the application.';
    }
  }
}
