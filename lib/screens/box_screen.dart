import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/task_card.dart';
import '../widgets/ui_kit.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/genre_picker_sheet.dart';
import '../widgets/undo_snack.dart';
import '../widgets/upgrade.dart';

/// 未分類タスクを仕分ける場所。右スワイプ=TODAY / 左スワイプ=LATER。削除はスワイプに含めない。
class BoxScreen extends StatelessWidget {
  const BoxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tasks = app.tasksIn(TaskStatus.box);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          title: 'BOX',
          count: tasks.length,
          capacity: app.capacityFor(TaskStatus.box)!,
          action: const AppMenuButton(),
        ),
        Expanded(
          child: tasks.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'BOXは空です',
                  subtitle: '＋ で、やることを入れよう。')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _swipeable(context, app, tasks[i]),
                ),
        ),
      ],
    );
  }

  Widget _swipeable(BuildContext context, AppState app, TaskItem task) {
    return Dismissible(
      key: ValueKey(task.id),
      movementDuration: const Duration(milliseconds: 220),
      // 右スワイプ = TODAY（赤）
      background: _bg(Alignment.centerLeft, context.c.todayAccent, Icons.wb_sunny_rounded, 'TODAY'),
      // 左スワイプ = LATER（青）
      secondaryBackground: _bg(Alignment.centerRight, context.c.laterAccent, Icons.nightlight_round, 'LATER', reverse: true),
      confirmDismiss: (dir) async {
        final target = dir == DismissDirection.startToEnd ? TaskStatus.today : TaskStatus.later;
        final ok = app.move(task, target);
        if (ok) {
          showUndoSnack(context, target == TaskStatus.today ? 'TODAYへ移動しました' : 'LATERへ移動しました');
        } else {
          showCapacityFullSnack(context, target);
        }
        return ok;
      },
      child: TaskCard(
        task: task,
        genre: app.genreById(task.genreId),
        onToggle: () { app.complete(task); showUndoSnack(context, '完了にしました'); },
        onTapBody: () => EditTaskSheet.present(context, task),
        menu: [
          TaskMenuAction('編集', Icons.edit_outlined, () => EditTaskSheet.present(context, task)),
          TaskMenuAction('ジャンル設定', Icons.label_outline, () => GenrePickerSheet.present(context, task)),
          TaskMenuAction('削除', Icons.delete_outline,
              () { app.deleteTask(task); showUndoSnack(context, '削除しました'); }, destructive: true),
        ],
      ),
    );
  }

  Widget _bg(Alignment align, Color color, IconData icon, String label, {bool reverse = false}) {
    final children = [
      Icon(icon, color: Colors.white, size: 26),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
    ];
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: reverse ? Alignment.centerLeft : Alignment.centerRight,
          end: reverse ? Alignment.centerRight : Alignment.centerLeft,
          colors: [color, color.withOpacity(0.82)],
        ),
        borderRadius: AppTheme.radiusCard,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reverse ? children.reversed.toList() : children,
      ),
    );
  }
}

