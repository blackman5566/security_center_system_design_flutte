// unlock_view.dart
//
// Mirrors: UnlockView.swift → PasscodeView.swift (randomEnabled: true)
//
// 通用解鎖 UI：passcode 輸入點、錯誤訊息、生物辨識按鈕、lockout 顯示。
// 接受 ProviderListenable 讓此 View 同時支援：
// - AppUnlockNotifier（AutoDisposeStateNotifierProvider）
// - ModuleUnlockNotifier（AutoDisposeStateNotifierProvider）
//
// Random 鍵盤：
//   Mirrors: PasscodeView(randomEnabled: true)
//   UnlockView 永遠開啟 randomEnabled，SetPasscodeView 則不提供此按鈕。
//   按「Random」→ digits shuffle；再按 → 恢復標準排列。
//   Locked 狀態下 Random 按鈕禁用（Mirrors: .disabled(lockoutState.isLocked)）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app_core/security/lockout/lockout_manager.dart';
import 'base_unlock_notifier.dart';
import '../passcode/passcode_dots_view.dart';
import '../passcode/num_pad_view.dart';
import '../widgets/lockout_countdown.dart';

class UnlockView extends ConsumerStatefulWidget {
  final ProviderListenable<UnlockState> stateProvider;
  final ProviderListenable<BaseUnlockNotifier> notifierProvider;

  const UnlockView({
    super.key,
    required this.stateProvider,
    required this.notifierProvider,
  });

  @override
  ConsumerState<UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends ConsumerState<UnlockView>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  int _lastShakeTrigger = 0;

  // ── Random numpad state ────────────────────────────────────────────
  // Mirrors: @State var digits: [Int] + @State var randomized: Bool (PasscodeView.swift)
  List<String> _digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
  bool _randomized = false;

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

    // onAppear：若 auto biometry，自動觸發
    // Mirrors: func onAppear() → if auto → unlockWithBiometrySubject.send()
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(widget.notifierProvider);
      if (notifier.shouldAutoTriggerBiometry) {
        notifier.unlockWithBiometry();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  /// Mirrors: randomized.toggle() { digits = randomized ? (0...9).shuffled() : (1...9)+[0] }
  void _toggleRandom() {
    setState(() {
      _randomized = !_randomized;
      if (_randomized) {
        _digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']..shuffle();
      } else {
        _digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.stateProvider);
    final notifier = ref.read(widget.notifierProvider);
    final isLocked = state.lockoutState.isLocked;

    if (state.shakeTrigger != _lastShakeTrigger) {
      _lastShakeTrigger = state.shakeTrigger;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _shakeController.forward(from: 0);
      });
    }

    return Column(
      children: [
        const Spacer(),

        // ── Description text ──────────────────────────────────────────
        // Mirrors: Text(description).id(description).transition(.opacity.animation(.easeOut))
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Text(
            state.description,
            key: ValueKey(state.description),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Passcode dots (with shake) ────────────────────────────────
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: child,
          ),
          child: PasscodeDotsView(
            filledCount: state.passcode.length,
            hasError: state.errorText.isNotEmpty,
          ),
        ),

        const SizedBox(height: 16),
        _buildStatusText(state),
        const Spacer(),

        // ── Numpad ────────────────────────────────────────────────────
        NumPadView(
          digits: _digits,
          onDigit: notifier.addDigit,
          onDelete: notifier.removeDigit,
          onBiometry: state.resolvedBiometryType != null
              ? notifier.unlockWithBiometry
              : null,
          biometryType: state.resolvedBiometryType,
          isEnabled: !isLocked,
        ),

        // ── Random button ─────────────────────────────────────────────
        // Mirrors: randomButton() → Button("Random") .disabled(lockoutState.isLocked)
        const SizedBox(height: 8),
        TextButton(
          onPressed: isLocked ? null : _toggleRandom,
          child: const Text(
            'Random',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatusText(UnlockState state) {
    final lockout = state.lockoutState;
    if (lockout is LockoutLocked) {
      return LockoutCountdown(unlockTime: lockout.unlockTime);
    }
    return AnimatedOpacity(
      opacity: state.errorText.isNotEmpty ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Text(
        state.errorText,
        style: const TextStyle(color: Colors.orange, fontSize: 14),
      ),
    );
  }
}
