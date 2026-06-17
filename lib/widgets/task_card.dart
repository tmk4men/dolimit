import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/genre.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import 'genre_chip.dart';
import 'ui_kit.dart';

/// ⋯ メニューの 1 項目
class TaskMenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  const TaskMenuAction(this.label, this.icon, this.onTap, {this.destructive = false});
}

/// 汎用タスクカード。チェック・タイトル・ジャンル・補助情報・⋯メニュー。
class TaskCard extends StatelessWidget {
  final TaskItem task;
  final Genre? genre;
  final String? subtitle;
  final Color subtitleColor;
  final VoidCallback onToggle;
  final VoidCallback? onTapBody;
  final List<TaskMenuAction> menu;

  const TaskCard({
    super.key,
    required this.task,
    required this.genre,
    this.subtitle,
    this.subtitleColor = AppTheme.sub,
    required this.onToggle,
    this.onTapBody,
    required this.menu,
  });

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    return PressableCard(
      onTap: onTapBody,
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Row(
        children: [
          _CheckButton(checked: done, onTap: onToggle),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: done ? AppTheme.sub : AppTheme.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: AppTheme.sub,
                    ),
                  ),
                  if (genre != null || subtitle != null) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (genre != null) GenreChip(genre: genre),
                        if (genre != null && subtitle != null) const SizedBox(width: 8),
                        if (subtitle != null)
                          Flexible(
                            child: Text(subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700, color: subtitleColor)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          _MenuButton(menu: menu),
        ],
      ),
    );
  }
}

/// 弾むチェックボタン
class _CheckButton extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  const _CheckButton({required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: checked
              ? Container(
                  key: const ValueKey(true),
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: AppTheme.ink, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 17, color: Colors.white),
                )
              : Container(
                  key: const ValueKey(false),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.sub.withOpacity(0.55), width: 2),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final List<TaskMenuAction> menu;
  const _MenuButton({required this.menu});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '',
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      icon: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppTheme.fill, shape: BoxShape.circle),
        child: const Icon(Icons.more_horiz, size: 18, color: AppTheme.ink2),
      ),
      onSelected: (i) => menu[i].onTap(),
      itemBuilder: (_) => [
        for (var i = 0; i < menu.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 46,
            child: Row(
              children: [
                Icon(menu[i].icon,
                    size: 19, color: menu[i].destructive ? AppTheme.todayAccent : AppTheme.ink2),
                const SizedBox(width: 12),
                Text(menu[i].label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: menu[i].destructive ? AppTheme.todayAccent : AppTheme.ink)),
              ],
            ),
          ),
      ],
    );
  }
}
