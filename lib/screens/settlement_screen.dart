import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/genre_chip.dart';
import '../widgets/upgrade.dart';

/// 今日の精算。TODAY に残る未完了タスクを 1 件ずつ「残す？戻す？消す？」
class SettlementScreen extends StatelessWidget {
  const SettlementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // 精算済みのタスクは除く。TODAY 全件を見ると「明日もTODAY」で先へ進めない。
    final tasks = app.pendingSettlement;

    return Scaffold(
      appBar: AppBar(title: const Text('今日の精算')),
      body: SafeArea(
        child: tasks.isEmpty
            ? _done(context)
            : _active(context, app, tasks.first, tasks.length),
      ),
    );
  }

  Widget _active(
      BuildContext context, AppState app, TaskItem task, int remaining) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('残り $remaining 件',
                style: TextStyle(
                    color: context.c.sub, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('残す？戻す？消す？',
                style: TextStyle(fontSize: 13, color: context.c.sub)),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: context.c.card, borderRadius: BorderRadius.circular(24)),
            child: Column(
              children: [
                Text(task.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                GenreChip(genre: app.genreById(task.genreId)),
                const SizedBox(height: 6),
                Text(task.ageLabel,
                    style: TextStyle(fontSize: 12, color: context.c.sub)),
              ],
            ),
          ),
          const Spacer(),
          _btn(context, '明日もTODAY', Icons.wb_sunny, context.c.todayAccent,
              () => app.settleKeepInToday(task)),
          const SizedBox(height: 10),
          _btn(context, 'LATERへ移動', Icons.nightlight, context.c.laterAccent,
              () {
            if (!app.settleMoveToLater(task)) {
              showCapacityFullSnack(context, TaskStatus.later);
            }
          }),
          const SizedBox(height: 10),
          _btn(context, '完了', Icons.check_circle, context.c.ink,
              () => app.complete(task)),
          const SizedBox(height: 10),
          _btn(context, '削除', Icons.delete, context.c.sub,
              () => app.deleteTask(task)),
        ],
      ),
    );
  }

  Widget _btn(BuildContext context, String label, IconData icon, Color color,
      VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            Icon(Icons.check_circle_outline, size: 56, color: context.c.ink),
            const SizedBox(height: 16),
            const Text('精算完了',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.c.ink),
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}
