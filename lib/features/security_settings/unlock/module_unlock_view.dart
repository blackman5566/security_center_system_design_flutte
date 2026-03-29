// module_unlock_view.dart
//
// Mirrors: ModuleUnlockView.swift
//
// 敏感操作（Edit Passcode、Disable Passcode）的解鎖確認畫面。
// 解鎖成功後呼叫 onUnlock callback，由呼叫端決定後續行為。
//
// SwiftUI 對應：
//   Coordinator.presentAfterUnlock { ... } / Coordinator.performAfterUnlock { ... }
//   → ModuleUnlockView(onUnlock:)
//
// 使用 moduleUnlockNotifierProvider（autoDispose）確保每次 push 都是全新狀態。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_unlock_notifier.dart';
import 'module_unlock_notifier.dart';
import 'unlock_view.dart';

class ModuleUnlockView extends ConsumerStatefulWidget {
  final String title;
  final VoidCallback onUnlock;

  const ModuleUnlockView({
    super.key,
    required this.title,
    required this.onUnlock,
  });

  @override
  ConsumerState<ModuleUnlockView> createState() => _ModuleUnlockViewState();
}

class _ModuleUnlockViewState extends ConsumerState<ModuleUnlockView> {
  @override
  Widget build(BuildContext context) {
    // Mirrors: onReceive(viewModel.finishSubject) { dismiss(); onUnlock() }
    ref.listen<UnlockState>(moduleUnlockNotifierProvider, (_, next) {
      if (next.event == UnlockEvent.completed) {
        // Pop 先完成，再執行 onUnlock（避免 Navigator overlap）
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onUnlock();
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2E),
        title: Text(widget.title),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: UnlockView(
        stateProvider: moduleUnlockNotifierProvider,
        notifierProvider: moduleUnlockNotifierProvider.notifier,
      ),
    );
  }
}
