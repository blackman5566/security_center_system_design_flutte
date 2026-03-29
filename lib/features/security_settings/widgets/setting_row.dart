import 'package:flutter/material.dart';

/// 設定頁的一列項目
/// 支援：標題、副標題、自訂 trailing widget、點擊事件
class SettingRow extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingRow({
    super.key,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2E),
        border: Border(
          bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
        ),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? Colors.white,
            fontSize: 16,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle!, style: const TextStyle(color: Colors.grey))
            : null,
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right, color: Colors.grey)
                : null),
        onTap: onTap,
      ),
    );
  }
}
