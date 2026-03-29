import 'package:flutter/material.dart';

/// 設定頁的 section 標題列（灰色小字）
/// 例：「PASSCODE」、「FACE ID」、「AUTO-LOCK」
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
