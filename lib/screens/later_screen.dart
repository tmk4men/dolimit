import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/day_clock.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/task_card.dart';
import '../widgets/genre_chip.dart';
import '../widgets/ui_kit.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/genre_picker_sheet.dart';
import '../widgets/later_detail_sheet.dart';
import '../widgets/undo_snack.dart';
import '../widgets/upgrade.dart';

/// あとでやるタスク。開始日順にグループ表示。
class LaterScreen extends StatefulWidget {
  const LaterScreen({super.key});

  @override
  State<LaterScreen> createState() => _LaterScreenState();
}

class _LaterScreenState extends State<LaterScreen> {
  GenreFilter _filter = const FilterAll();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = app.tasksIn(TaskStatus.later);
    // ジャンルが2個以上あるときだけフィルタを出す。
    final showFilter = app.genres.length >= 2;
    final filter = showFilter ? _filter : const FilterAll();
    final tasks = all.where((t) => filter.matches(t.genreId)).toList();
    final groups = _group(app, tasks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          title: 'LATER',
          count: all.length,
          capacity: app.capacityFor(TaskStatus.later)!,
          barColor: context.c.laterAccent,
          action: const AppMenuButton(),
        ),
        if (showFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: GenreFilterBar(
              genres: app.genres,
              selection: _filter,
              onSelect: (f) => setState(() => _filter = f),
            ),
          ),
        Expanded(
          child: tasks.isEmpty
              ? const EmptyState(
                  icon: Icons.nightlight_outlined,
                  title: 'LATERは空です',
                  subtitle: 'BOXから左スワイプで送れます。')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
                  children: [
                    for (final g in groups)
                      if (g.tasks.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
                          child: Row(
                            children: [
                              Text(g.label,
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w900, color: context.c.ink2, letterSpacing: 0.5)),
                              const SizedBox(width: 8),
                              Text('${g.tasks.length}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.c.sub)),
                            ],
                          ),
                        ),
                        for (final t in g.tasks) ...[
                          _card(context, app, t),
                          const SizedBox(height: 12),
                        ],
                      ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, AppState app, TaskItem task) {
    final due = app.effectiveStartDate(task);
    final parts = <String>[];
    if (due != null) parts.add(_fmt(task, due));
    if (task.reminderEnabled) parts.add('通知あり');
    if (task.pendingMoveToToday) parts.add('移動待ち');

    final flagged = task.pendingMoveToToday;

    return TaskCard(
      task: task,
      genre: app.genreById(task.genreId),
      subtitle: parts.isEmpty ? '開始日なし' : parts.join('  ·  '),
      subtitleColor: flagged ? context.c.todayAccent : context.c.laterAccent,
      onToggle: () { app.complete(task); showUndoSnack(context, '完了にしました'); },
      onTapBody: () => LaterDetailSheet.present(context, task),
      menu: [
        TaskMenuAction('TODAYへ移動', Icons.wb_sunny_outlined, () {
          if (app.move(task, TaskStatus.today)) {
            showUndoSnack(context, 'TODAYへ移動しました');
          } else {
            showCapacityFullSnack(context, TaskStatus.today);
          }
        }),
        TaskMenuAction('開始日 / 通知を設定', Icons.event_outlined, () => LaterDetailSheet.present(context, task)),
        TaskMenuAction('ジャンル変更', Icons.label_outline, () => GenrePickerSheet.present(context, task)),
        TaskMenuAction('編集', Icons.edit_outlined, () => EditTaskSheet.present(context, task)),
        TaskMenuAction('削除', Icons.delete_outline,
            () { app.deleteTask(task); showUndoSnack(context, '削除しました'); }, destructive: true),
      ],
    );
  }

  String _fmt(TaskItem task, DateTime due) {
    final d = '${due.month}/${due.day}';
    if (task.startDateOnly) return d;
    return '$d ${due.hour}:${due.minute.toString().padLeft(2, '0')}';
  }

  List<_Group> _group(AppState app, List<TaskItem> tasks) {
    final today = _Group('今日');
    final tomorrow = _Group('明日');
    final week = _Group('今週');
    final beyond = _Group('それ以降');
    final none = _Group('開始日なし');
    final now = DateTime.now();
    final startToday = DayClock.startOfDay(now);

    for (final t in tasks) {
      final due = app.effectiveStartDate(t);
      if (due == null) {
        none.tasks.add(t);
        continue;
      }
      final days = DayClock.daysBetween(startToday, due);
      if (days <= 0) {
        today.tasks.add(t);
      } else if (days == 1) {
        tomorrow.tasks.add(t);
      } else if (days <= 7) {
        week.tasks.add(t);
      } else {
        beyond.tasks.add(t);
      }
    }

    int cmp(TaskItem a, TaskItem b) {
      final da = app.effectiveStartDate(a);
      final db = app.effectiveStartDate(b);
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    }

    for (final g in [today, tomorrow, week, beyond]) {
      g.tasks.sort(cmp);
    }
    return [today, tomorrow, week, beyond, none];
  }
}

class _Group {
  final String label;
  final List<TaskItem> tasks = [];
  _Group(this.label);
}
