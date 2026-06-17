import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import '../widgets/remaining_time.dart';
import '../widgets/task_card.dart';
import '../widgets/genre_chip.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/genre_picker_sheet.dart';

/// 今日やるタスク。並び替え（Drag & Drop）対応。
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  GenreFilter _filter = const FilterAll();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = app.tasksIn(TaskStatus.today);
    final tasks = all.where((t) => _filter.matches(t.genreId)).toList();
    final canReorder = _filter is FilterAll;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('TODAY', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Text('${all.length}/${Limits.today}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: all.length >= Limits.today ? AppTheme.todayAccent : AppTheme.sub)),
                ],
              ),
              const Padding(padding: EdgeInsets.only(bottom: 4), child: RemainingTime(fontSize: 16)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: GenreFilterBar(
            genres: app.genres,
            selection: _filter,
            onSelect: (f) => setState(() => _filter = f),
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? _empty()
              : (canReorder
                  ? ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                      itemCount: tasks.length,
                      onReorder: (o, n) => app.reorderToday(o, n),
                      itemBuilder: (_, i) => Padding(
                        key: ValueKey(tasks[i].id),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _card(context, app, tasks[i]),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _card(context, app, tasks[i]),
                    )),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, AppState app, TaskItem task) {
    final stale = task.consecutiveUnfinishedDays >= 3;
    return TaskCard(
      task: task,
      genre: app.genreById(task.genreId),
      subtitle: task.ageLabel,
      subtitleColor: stale ? AppTheme.todayAccent : AppTheme.sub,
      onToggle: () => app.complete(task),
      onTapBody: () => EditTaskSheet.present(context, task),
      menu: [
        TaskMenuAction('編集', Icons.edit, () => EditTaskSheet.present(context, task)),
        TaskMenuAction('ジャンル変更', Icons.tag, () => GenrePickerSheet.present(context, task)),
        TaskMenuAction('LATERへ移動', Icons.nightlight, () {
          if (!app.move(task, TaskStatus.later)) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(Limits.fullMessage(TaskStatus.later))));
          }
        }),
        TaskMenuAction('削除', Icons.delete, () => app.deleteTask(task), destructive: true),
      ],
    );
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_sunny_outlined, size: 40, color: AppTheme.sub),
            SizedBox(height: 10),
            Text('TODAYは空です。', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('BOXから仕分けましょう。', style: TextStyle(fontSize: 12, color: AppTheme.sub)),
          ],
        ),
      ),
    );
  }
}
