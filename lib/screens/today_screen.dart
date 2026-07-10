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
import '../widgets/ui_kit.dart';
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
        ScreenHeader(
          title: 'TODAY',
          count: all.length,
          capacity: app.capacityFor(TaskStatus.today)!,
          trailing: const RemainingTime(fontSize: 14),
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
              ? const EmptyState(
                  icon: Icons.wb_sunny_outlined,
                  title: 'TODAYは空です',
                  subtitle: 'BOXから仕分けましょう。')
              : (canReorder
                  ? ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
                      itemCount: tasks.length,
                      proxyDecorator: (child, index, anim) => Material(
                        color: Colors.transparent,
                        child: child,
                      ),
                      onReorder: (o, n) => app.reorderToday(o, n),
                      itemBuilder: (_, i) => Padding(
                        key: ValueKey(tasks[i].id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _card(context, app, tasks[i]),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _card(context, app, tasks[i]),
                    )),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, AppState app, TaskItem task) {
    final stale = task.consecutiveUnfinishedDays >= 3;
    // LATER が満杯で追放できないタスクは TODAY に留まる。理由を見せる。
    final subtitle = task.pendingAutoMoveToLater
        ? '${task.ageLabel}  ·  追放待ち（LATERが満杯）'
        : task.ageLabel;
    return TaskCard(
      task: task,
      genre: app.genreById(task.genreId),
      subtitle: subtitle,
      subtitleColor: stale ? AppTheme.todayAccent : AppTheme.sub,
      onToggle: () => app.complete(task),
      onTapBody: () => EditTaskSheet.present(context, task),
      menu: [
        TaskMenuAction('編集', Icons.edit_outlined, () => EditTaskSheet.present(context, task)),
        TaskMenuAction('ジャンル変更', Icons.label_outline, () => GenrePickerSheet.present(context, task)),
        TaskMenuAction('LATERへ移動', Icons.nightlight_outlined, () {
          if (!app.move(task, TaskStatus.later)) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(Limits.fullMessage(TaskStatus.later))));
          }
        }),
        TaskMenuAction('削除', Icons.delete_outline, () => app.deleteTask(task), destructive: true),
      ],
    );
  }
}
