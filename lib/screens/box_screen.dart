import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import '../widgets/task_card.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/genre_picker_sheet.dart';

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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              const Text('BOX', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Text('${tasks.length}/${Limits.box}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: tasks.length >= Limits.box ? AppTheme.todayAccent : AppTheme.sub)),
            ],
          ),
        ),
        // スワイプ説明（常に薄く表示）
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: _SwipeHint(),
        ),
        Expanded(
          child: tasks.isEmpty
              ? _empty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _swipeable(context, app, tasks[i]),
                ),
        ),
      ],
    );
  }

  Widget _swipeable(BuildContext context, AppState app, TaskItem task) {
    return Dismissible(
      key: ValueKey(task.id),
      // 右スワイプ = TODAY（赤〜オレンジ）
      background: _bg(Alignment.centerLeft, AppTheme.todayAccent, Icons.wb_sunny, 'TODAY'),
      // 左スワイプ = LATER（青）
      secondaryBackground: _bg(Alignment.centerRight, AppTheme.laterAccent, Icons.nightlight, 'LATER', reverse: true),
      confirmDismiss: (dir) async {
        final target = dir == DismissDirection.startToEnd ? TaskStatus.today : TaskStatus.later;
        final ok = app.move(task, target);
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(Limits.fullMessage(target))));
        }
        return ok; // 成功時のみカードを消す（状態が変わって BOX から外れる）
      },
      child: TaskCard(
        task: task,
        genre: app.genreById(task.genreId),
        onToggle: () => app.complete(task),
        onTapBody: () => EditTaskSheet.present(context, task),
        menu: [
          TaskMenuAction('編集', Icons.edit, () => EditTaskSheet.present(context, task)),
          TaskMenuAction('ジャンル設定', Icons.tag, () => GenrePickerSheet.present(context, task)),
          TaskMenuAction('削除', Icons.delete, () => app.deleteTask(task), destructive: true),
        ],
      ),
    );
  }

  Widget _bg(Alignment align, Color color, IconData icon, String label, {bool reverse = false}) {
    final children = [
      Icon(icon, color: Colors.white),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    ];
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reverse ? children.reversed.toList() : children,
      ),
    );
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: AppTheme.sub),
            SizedBox(height: 10),
            Text('BOXは空です。', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('＋ で、やることを入れよう。', style: TextStyle(fontSize: 12, color: AppTheme.sub)),
          ],
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: const [
          Icon(Icons.arrow_back, size: 14, color: AppTheme.laterAccent),
          SizedBox(width: 4),
          Text('LATER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.laterAccent)),
        ]),
        Row(children: const [
          Text('TODAY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.todayAccent)),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward, size: 14, color: AppTheme.todayAccent),
        ]),
      ],
    );
  }
}
