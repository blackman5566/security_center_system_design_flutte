// security_settings_view.dart
//
// Mirrors: SecuritySettingsView.swift
//
// 主設定畫面：顯示 passcode / biometry / auto-lock 的開關與設定入口。
// 所有狀態來自 SecuritySettingsNotifier，動作委派給 notifier。
//
// Edit/Disable Passcode：
//   Mirrors: Coordinator.presentAfterUnlock / performAfterUnlock
//   → 先 push ModuleUnlockView，解鎖成功後再執行動作
//
// Biometry 無密碼自動提示：
//   Mirrors: .onChange(of: viewModel.biometryEnabledType) { type in
//     if !viewModel.isPasscodeSet, type.isEnabled {
//       presentCreatePasscode(reason: .biometry(...))
//     }
//   }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_core/security/biometry/biometry_manager.dart';
import '../../app_core/security/biometry/biometry_type.dart';
import 'security_settings_notifier.dart';
import 'passcode/set_passcode_view.dart';
import 'passcode/create_passcode_notifier.dart';
import 'passcode/edit_passcode_notifier.dart';
import 'auto_lock/auto_lock_view.dart';
import 'unlock/module_unlock_view.dart';
import 'widgets/section_header.dart';
import 'widgets/setting_row.dart';

class SecuritySettingsView extends ConsumerWidget {
  const SecuritySettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(securitySettingsNotifierProvider);
    final notifier = ref.read(securitySettingsNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text(
          'Security',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // ── Passcode Section ──────────────────────────────────
          SectionHeader(title: 'PASSCODE'),
          if (!state.isPasscodeSet) ...[
            SettingRow(
              title: 'Enable Passcode',
              titleColor: Colors.blue,
              onTap: () => _pushCreatePasscode(context),
            ),
          ] else ...[
            SettingRow(
              title: 'Edit Passcode',
              // Mirrors: Coordinator.presentAfterUnlock { EditPasscodeModule.editPasscodeView(...) }
              onTap: () => _pushModuleUnlock(
                context,
                title: 'Edit Passcode',
                onUnlock: () => _pushEditPasscode(context),
              ),
            ),
            SettingRow(
              title: 'Disable Passcode',
              titleColor: Colors.red,
              // Mirrors: Coordinator.performAfterUnlock { viewModel.removePasscode() }
              onTap: () => _pushModuleUnlock(
                context,
                title: 'Disable Passcode',
                onUnlock: notifier.removePasscode,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── Biometry Section ──────────────────────────────────
          if (state.biometryType != null) ...[
            SectionHeader(
              title: state.biometryType!.title.toUpperCase(),
            ),
            SettingRow(
              title: state.biometryType == BiometryType.faceId
                  ? 'Face ID'
                  : 'Touch ID',
              subtitle: state.biometryEnabledType.description,
              // Mirrors: Text(viewModel.biometryEnabledType.title) as trailing
              trailing: Text(
                state.biometryEnabledType.title,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              // Mirrors: Button always tappable (even without passcode)
              // onChange: if !isPasscodeSet && type.isEnabled → presentCreatePasscode(.biometry)
              onTap: () => _showBiometryOptions(context, state, notifier, ref),
            ),
            const SizedBox(height: 32),
          ],

          // ── Auto-Lock Section ─────────────────────────────────
          if (state.isPasscodeSet) ...[
            SectionHeader(title: 'AUTO-LOCK'),
            SettingRow(
              title: 'Lock After',
              trailing: Text(
                state.autoLockPeriod.title,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AutoLockView()),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────

  void _pushCreatePasscode(BuildContext context,
      {CreatePasscodeReason reason = CreatePasscodeReason.regular}) {
    final p = createPasscodeNotifierProvider(reason);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SetPasscodeView(
        stateProvider: p,
        notifierProvider: p.notifier,
      ),
    ));
  }

  void _pushEditPasscode(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SetPasscodeView(
        stateProvider: editPasscodeNotifierProvider,
        notifierProvider: editPasscodeNotifierProvider.notifier,
      ),
    ));
  }

  /// Mirrors: Coordinator.presentAfterUnlock / performAfterUnlock
  void _pushModuleUnlock(
    BuildContext context, {
    required String title,
    required VoidCallback onUnlock,
  }) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ModuleUnlockView(title: title, onUnlock: onUnlock),
    ));
  }

  // ── Biometry options ───────────────────────────────────────────

  /// Mirrors: Coordinator.present(type: .alert) { OptionAlertView(...) }
  /// + .onChange(of: viewModel.biometryEnabledType) { ... }
  void _showBiometryOptions(
    BuildContext context,
    SecuritySettingsState state,
    SecuritySettingsNotifier notifier,
    WidgetRef ref,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ...BiometryEnabledType.values.map((type) => ListTile(
                  title: Text(
                    type.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    type.description,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: state.biometryEnabledType == type
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    notifier.setBiometryEnabledType(type);
                    Navigator.pop(ctx);

                    // Mirrors: .onChange(of: viewModel.biometryEnabledType) { _, type in
                    //   if !viewModel.isPasscodeSet, type.isEnabled {
                    //     presentCreatePasscode(reason: .biometry(...))
                    //   }
                    // }
                    if (type.isEnabled && !state.isPasscodeSet) {
                      _pushCreatePasscodeForBiometry(context, type, notifier, ref);
                    }
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 使用者想啟用生物辨識但尚未設定密碼 → 先建立密碼
  /// 建立完成後密碼已存在，biometryEnabledType 保持使用者選擇的值
  /// 若使用者取消（沒有建立密碼），則重置 biometryEnabledType 為 off
  ///
  /// Mirrors: CreatePasscodeModule.createPasscodeView(
  ///   reason: .biometry(enabledType:type:),
  ///   onCreate: { viewModel.set(biometryEnabledType: enabledType) },
  ///   onCancel: { viewModel.biometryEnabledType = .off }
  /// )
  void _pushCreatePasscodeForBiometry(
    BuildContext context,
    BiometryEnabledType selectedType,
    SecuritySettingsNotifier notifier,
    WidgetRef ref,
  ) {
    final p = createPasscodeNotifierProvider(CreatePasscodeReason.biometry);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SetPasscodeView(
        stateProvider: p,
        notifierProvider: p.notifier,
      ),
    )).then((_) {
      // 使用者取消（沒有建立密碼）→ 重置 biometry 為 off
      final isPasscodeSet = ref.read(securitySettingsNotifierProvider).isPasscodeSet;
      if (!isPasscodeSet) {
        notifier.setBiometryEnabledType(BiometryEnabledType.off);
      }
    });
  }
}
