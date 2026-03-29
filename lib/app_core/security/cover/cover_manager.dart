// cover_manager.dart
//
// Mirrors: CoverManager.swift
//
// 核心職責：
// - App 進入背景時顯示隱私遮蓋（防止多工截圖洩漏敏感畫面）
// - App 回到前景時隱藏遮蓋
//
// Flutter 實作差異說明：
// - Swift 用獨立 UIWindow（windowLevel = alert - 2）覆蓋
// - Flutter 改用 app root Stack 的條件渲染（isCoverVisible 控制）
//   視覺效果相同，但實作更符合 Flutter declarative 渲染模型

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class CoverState {
  final bool isCoverVisible;
  const CoverState({this.isCoverVisible = false});

  CoverState copyWith({bool? isCoverVisible}) =>
      CoverState(isCoverVisible: isCoverVisible ?? this.isCoverVisible);
}

// ── Manager ───────────────────────────────────────────────────────────────────

/// Mirrors: CoverManager (class)
class CoverManager extends StateNotifier<CoverState> {
  CoverManager() : super(const CoverState());

  /// 顯示遮蓋（App 進入背景時呼叫）
  /// Mirrors: 由 AppSceneDelegate.sceneWillResignActive() 觸發
  void show() {
    state = state.copyWith(isCoverVisible: true);
  }

  /// 隱藏遮蓋（App 回到前景時呼叫）
  /// Mirrors: 由 AppSceneDelegate.sceneDidBecomeActive() 觸發
  void hide() {
    state = state.copyWith(isCoverVisible: false);
  }
}
