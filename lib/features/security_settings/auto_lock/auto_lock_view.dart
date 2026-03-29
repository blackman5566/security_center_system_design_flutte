// auto_lock_view.dart
//
// Mirrors: AutoLockView.swift
//
// 選擇自動上鎖時間的設定頁面

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app_core/security/lock/auto_lock_period.dart';
import '../security_settings_notifier.dart';

class AutoLockView extends ConsumerWidget {
  const AutoLockView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(securitySettingsNotifierProvider);
    final notifier = ref.read(securitySettingsNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text(
          'Auto-Lock',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: AutoLockPeriod.values.map((period) {
          final isSelected = period == state.autoLockPeriod;
          return ListTile(
            title: Text(
              period.title,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.blue)
                : null,
            onTap: () {
              notifier.setAutoLockPeriod(period);
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      ),
    );
  }
}
