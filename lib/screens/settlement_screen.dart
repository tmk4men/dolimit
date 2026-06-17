import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/genre_chip.dart';

/// 今日の精算。TODAY に残る未完了タスクを 1 件ずつ「残す？戻す？消す？」
class SettlementScreen extends StatelessWidget {
  const SettlementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tasks = app.tasksIn(TaskStatus.today);

    return Scaffold(
      appBar: AppBar(title: const Text('今日の精算')),
      body: SafeArea(
        child: tasks.isEmpty ? _done(context) : _active(context, app, tasks.first, tasks.length),
      ),
    );
  }

  Widget _active(BuildContext context, AppState app, task, int remaining) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('残り $remaining 件', style: const TextStyle(color: AppTheme.sub, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('残す？戻す？消す？', style: TextStyle(fontSize: 13, color: AppTheme.sub)),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              children: [
                Text(task.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                GenreChip(genre: app.genreById(task.genreId)),
                const SizedBox(height: 6),
                Text(task.ageLabel, style: const TextStyle(fontSize: 12, color: AppTheme.sub)),
              ],
            ),
          ),
          const Spacer(),
          _btn(context, '明日もTODAY', Icons.wb_sunny, AppTheme.todayAccent, () => app.settleKeepInToday(task)),
          const SizedBox(height: 10),
          _btn(context, 'LATERへ移動', Icons.nightlight, AppTheme.laterAccent, () {
            app.settleMoveToLater(task);
          }),
          const SizedBox(height: 10),
          _btn(context, '完了', Icons.check_circle, AppTheme.ink, () => app.complete(task)),
          const SizedBox(height: 10),
          _btn(context, '削除', Icons.delete, AppTheme.sub, () => app.deleteTask(task)),
        ],
      ),
    );
  }

  Widget _btn(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        onPressed: onTap,
      ),
    );
  }

  Widget _done(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 56, color: AppTheme.ink),
            const SizedBox(height: 16),
            const Text('精算完了', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('ToDoを溜めるな。今日に決着を。',
                style: TextStyle(fontSize: 13, color: AppTheme.sub)),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.ink),
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}
