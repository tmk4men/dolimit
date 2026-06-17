import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/genre.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import 'genre_chip.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onToggle,
            icon: Icon(done ? Icons.check_circle : Icons.circle_outlined,
                size: 26, color: done ? AppTheme.ink : AppTheme.sub),
          ),
          Expanded(
            child: InkWell(
              onTap: onTapBody,
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
                        fontWeight: FontWeight.w600,
                        color: AppTheme.ink,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: AppTheme.sub,
                      ),
                    ),
                    if (genre != null || subtitle != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          GenreChip(genre: genre),
                          if (genre != null && subtitle != null) const SizedBox(width: 8),
                          if (subtitle != null)
                            Text(subtitle!,
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: subtitleColor)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_horiz, color: AppTheme.sub),
            onSelected: (i) => menu[i].onTap(),
            itemBuilder: (_) => [
              for (var i = 0; i < menu.length; i++)
                PopupMenuItem<int>(
                  value: i,
                  child: Row(
                    children: [
                      Icon(menu[i].icon,
                          size: 20,
                          color: menu[i].destructive ? AppTheme.todayAccent : AppTheme.ink),
                      const SizedBox(width: 12),
                      Text(menu[i].label,
                          style: TextStyle(
                              color: menu[i].destructive ? AppTheme.todayAccent : AppTheme.ink)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
