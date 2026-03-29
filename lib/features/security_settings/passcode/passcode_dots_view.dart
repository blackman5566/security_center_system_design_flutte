// passcode_dots_view.dart
//
// Mirrors: PasscodeView.swift
//
// 顯示 6 顆點（實心/空心）代表已輸入 / 尚未輸入的 passcode 位數

import 'package:flutter/material.dart';

class PasscodeDotsView extends StatelessWidget {
  final int filledCount;
  final int totalCount;
  final bool hasError;

  const PasscodeDotsView({
    super.key,
    required this.filledCount,
    this.totalCount = 6,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalCount, (index) {
        final isFilled = index < filledCount;
        return Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (hasError ? Colors.red : Colors.white)
                : Colors.transparent,
            border: Border.all(
              color: hasError ? Colors.red : Colors.white,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}
