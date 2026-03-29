// app_unlock_view.dart
//
// Mirrors: AppUnlockView.swift
//
// App 層級的解鎖畫面（LockManager.isLocked == true 時由 app root Stack 顯示）。
// 解鎖成功後，LockManager.isLocked 變為 false → Stack 自動移除此 overlay。
// 這是 Flutter declarative UI 的精髓：不需要手動 dismiss，狀態驅動 UI。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_unlock_notifier.dart';
import 'unlock_view.dart';

class AppUnlockView extends ConsumerWidget {
  const AppUnlockView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: const Color(0xFF1C1C1E),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // App icon / branding
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Security Center',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: UnlockView(
                stateProvider: appUnlockNotifierProvider,
                notifierProvider: appUnlockNotifierProvider.notifier,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
