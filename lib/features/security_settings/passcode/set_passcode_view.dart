// set_passcode_view.dart
//
// Mirrors: SetPasscodeView.swift
//
// 兩段式 passcode 設定畫面（輸入 → 確認）
//
// 設計說明（Riverpod 型別系統）：
// - 接受 ProviderListenable<SetPasscodeState> 作為狀態來源
// - 接受 ProviderListenable<SetPasscodeNotifier> 作為 notifier 來源
// - 這樣可以同時支援 StateNotifierProvider（EditPasscode）
//   與 AutoDisposeStateNotifierProvider.family（CreatePasscode）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'set_passcode_notifier.dart';
import 'passcode_dots_view.dart';
import 'num_pad_view.dart';

class SetPasscodeView extends ConsumerStatefulWidget {
  final ProviderListenable<SetPasscodeState> stateProvider;
  final ProviderListenable<SetPasscodeNotifier> notifierProvider;

  const SetPasscodeView({
    super.key,
    required this.stateProvider,
    required this.notifierProvider,
  });

  @override
  ConsumerState<SetPasscodeView> createState() => _SetPasscodeViewState();
}

class _SetPasscodeViewState extends ConsumerState<SetPasscodeView>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  int _lastShakeTrigger = 0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.stateProvider);
    final notifier = ref.read(widget.notifierProvider);

    // shakeTrigger 改變 → 播放抖動動畫
    // Mirrors: shakeTrigger += 1 → UI shake animation
    if (state.shakeTrigger != _lastShakeTrigger) {
      _lastShakeTrigger = state.shakeTrigger;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _shakeController.forward(from: 0);
      });
    }

    // 監聽 event → 導航
    // Mirrors: finishSubject.send() → dismiss, onCancel() → dismiss
    ref.listen(widget.stateProvider, (prev, next) {
      if (next.event == SetPasscodeEvent.completed ||
          next.event == SetPasscodeEvent.cancelled) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: notifier.onCancel,
        ),
        title: Text(
          notifier.title,
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Spacer(),
          // 描述文字
          Text(
            state.description,
            style: const TextStyle(color: Colors.white70, fontSize: 17),
          ),
          const SizedBox(height: 32),
          // Passcode dots + shake animation
          // Mirrors: PasscodeView + shake trigger
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              );
            },
            child: PasscodeDotsView(
              filledCount: state.passcode.length,
              hasError: state.errorText.isNotEmpty,
            ),
          ),
          const SizedBox(height: 16),
          // 錯誤文字
          AnimatedOpacity(
            opacity: state.errorText.isNotEmpty ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              state.errorText,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ),
          const Spacer(),
          // NumPad
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: NumPadView(
              onDigit: notifier.addDigit,
              onDelete: notifier.removeDigit,
            ),
          ),
        ],
      ),
    );
  }
}
