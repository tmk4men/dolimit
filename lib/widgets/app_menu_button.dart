import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';

/// 全タブ右上のハンバーガーメニュー。
/// タップすると「設定」を選べて、設定ページ（フルスクリーン）へ遷移する。
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.menu_rounded, color: context.c.ink),
      tooltip: 'メニュー',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == 'settings') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 20, color: context.c.ink),
              const SizedBox(width: 12),
              const Text('設定'),
            ],
          ),
        ),
      ],
    );
  }
}
