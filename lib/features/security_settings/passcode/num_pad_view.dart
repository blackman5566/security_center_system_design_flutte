// num_pad_view.dart
//
// Mirrors: NumPadView.swift + NumberView.swift
//
// 數字鍵盤：0-9、刪除、生物辨識按鈕（可選）
// digits 參數允許外部傳入自訂排列（對應 SwiftUI 的 @Binding var digits: [Int]）
// 亂數模式由上層（UnlockView）負責 shuffle，此元件只負責 rendering。

import 'package:flutter/material.dart';
import '../../../app_core/security/biometry/biometry_type.dart';

class NumPadView extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometry;
  final BiometryType? biometryType;
  final bool isEnabled;

  /// 自訂數字排列（10 個元素：positions 0-8 填 3x3，position 9 填底部中間）
  /// null = 標準排列 ['1'-'9', '0']
  /// Mirrors: @Binding var digits: [Int]（PasscodeView.swift）
  final List<String>? digits;

  static const _defaultDigits = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '0',
  ];

  const NumPadView({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometry,
    this.biometryType,
    this.isEnabled = true,
    this.digits,
  });

  @override
  Widget build(BuildContext context) {
    final d = digits ?? _defaultDigits;
    return Column(
      children: [
        _buildRow([d[0], d[1], d[2]]),
        const SizedBox(height: 12),
        _buildRow([d[3], d[4], d[5]]),
        const SizedBox(height: 12),
        _buildRow([d[6], d[7], d[8]]),
        const SizedBox(height: 12),
        // Bottom row: biometry/empty | d[9] | delete
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _biometryOrEmpty(),
            const SizedBox(width: 12),
            _digitButton(d[9]),
            const SizedBox(width: 12),
            _deleteButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> rowDigits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: rowDigits
          .expand((d) => [_digitButton(d), const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _digitButton(String digit) {
    return _NumPadButton(
      onTap: isEnabled ? () => onDigit(digit) : null,
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _deleteButton() {
    return _NumPadButton(
      onTap: isEnabled ? onDelete : null,
      child: const Icon(Icons.backspace_outlined, color: Colors.white, size: 24),
    );
  }

  Widget _biometryOrEmpty() {
    if (onBiometry != null && biometryType != null) {
      final icon = biometryType == BiometryType.faceId
          ? Icons.face_retouching_natural
          : Icons.fingerprint;
      return _NumPadButton(
        onTap: isEnabled ? onBiometry : null,
        child: Icon(icon, color: Colors.white, size: 28),
      );
    }
    // 空佔位（保持佈局對稱）
    return const SizedBox(width: 80, height: 80);
  }
}

class _NumPadButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _NumPadButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: onTap != null ? 0.15 : 0.05),
        ),
        child: Center(child: child),
      ),
    );
  }
}
