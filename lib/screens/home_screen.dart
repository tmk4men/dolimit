import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import '../widgets/remaining_time.dart';
import '../widgets/task_card.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/genre_picker_sheet.dart';
import 'settlement_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onGoToTab;
  const HomeScreen({super.key, required this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final todayTasks = app.tasksIn(TaskStatus.today);
    final next = todayTasks.isEmpty ? null : todayTasks.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        // TODAY 数 + 残り時間
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TODAY',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.sub, letterSpacing: 1)),
                Text('${app.todayUnfinished}/${Limits.today}',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: RemainingTime(fontSize: 22),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('TODAYには、今日しかない。', style: TextStyle(fontSize: 13, color: AppTheme.sub)),
        const SizedBox(height: 20),

        // 次にやる1件
        const Text('次にやる', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.sub)),
        const SizedBox(height: 8),
        if (next != null)
          TaskCard(
            task: next,
            genre: app.genreById(next.genreId),
            subtitle: next.ageLabel,
            onToggle: () => app.complete(next),
            onTapBody: () => EditTaskSheet.present(context, next),
            menu: [
              TaskMenuAction('編集', Icons.edit, () => EditTaskSheet.present(context, next)),
              TaskMenuAction('ジャンル変更', Icons.tag, () => GenrePickerSheet.present(context, next)),
              TaskMenuAction('LATERへ移動', Icons.nightlight, () {
                if (!app.move(next, TaskStatus.later)) {
                  _snack(context, Limits.fullMessage(TaskStatus.later));
                }
              }),
              TaskMenuAction('削除', Icons.delete, () => app.deleteTask(next), destructive: true),
            ],
          )
        else
          _emptyNext(context),

        const SizedBox(height: 24),

        // 箱の件数
        Row(
          children: [
            Expanded(child: _miniCount(context, 'BOX', app.count(TaskStatus.box), Limits.box, () => onGoToTab(1))),
            const SizedBox(width: 12),
            Expanded(child: _miniCount(context, 'LATER', app.count(TaskStatus.later), Limits.later, () => onGoToTab(3))),
          ],
        ),

        const SizedBox(height: 24),

        // 今日の精算
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.ink,
              side: const BorderSide(color: AppTheme.line),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.nights_stay_outlined),
            label: const Text('今日の精算', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettlementScreen())),
          ),
        ),
      ],
    );
  }

  Widget _emptyNext(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
      child: Column(
        children: [
          const Icon(Icons.wb_sunny_outlined, size: 36, color: AppTheme.sub),
          const SizedBox(height: 8),
          const Text('TODAYは空です。', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('BOXから仕分けましょう', style: TextStyle(fontSize: 12, color: AppTheme.sub)),
        ],
      ),
    );
  }

  Widget _miniCount(BuildContext context, String label, int count, int cap, VoidCallback onTap) {
    final full = count >= cap;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.sub, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('$count/$cap',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: full ? AppTheme.todayAccent : AppTheme.ink)),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
