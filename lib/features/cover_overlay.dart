import 'package:flutter/material.dart';

/// Mirrors: CoverManager 在 Swift 建立的 UIWindow 內容
/// 純色遮蓋，防止多工截圖（App Switcher）洩漏 App 敏感畫面
class CoverOverlay extends StatelessWidget {
  const CoverOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: Colors.white24, size: 56),
            SizedBox(height: 16),
            Text(
              'Security Center',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
