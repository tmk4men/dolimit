import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/remaining_time.dart';
import '../widgets/task_card.dart';
import '../widgets/genre_chip.dart';
import '../widgets/ui_kit.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/genre_picker_sheet.dart';
import '../widgets/undo_snack.dart';
import 'settlement_screen.dart';

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
    // ジャンルが2個以上あるときだけフィルタを出す（使わない人には見せない）。
    final showFilter = app.genres.length >= 2;
    final filter = showFilter ? _filter : const FilterAll();
    final tasks = all.where((t) => filter.matches(t.genreId)).toList();
    final canReorder = filter is FilterAll;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          title: 'TODAY',
          count: all.length,
          capacity: app.capacityFor(TaskStatus.today)!,
          trailing: const RemainingTime(fontSize: 14),
          action: const AppMenuButton(),
        ),
        // 今日の精算：夜の精算に設定した時刻を過ぎたら TODAY のトップに出す。
        if (_afterSettlementTime(app))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: _SettlementButton(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SettlementScreen())),
            ),
          ),
        if (showFilter)
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
              ? (all.isEmpty
                  ? (app.clearedToday
                      // 今日ぶんを片づけ切った達成の演出。
                      ? _TodayCleared(streak: app.currentStreak)
                      : const EmptyState(
                          icon: Icons.wb_sunny_outlined,
                          title: 'TODAYは空です',
                          subtitle: 'BOXから仕分けましょう。'))
                  // フィルタで該当が無いだけ（TODAY自体は空でない）。
                  : const EmptyState(
                      icon: Icons.filter_list_off,
                      title: '該当なし',
                      subtitle: '別のジャンルを選んでください。'))
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
      subtitleColor: stale ? context.c.todayAccent : context.c.sub,
      onToggle: () { app.complete(task); showUndoSnack(context, '完了にしました'); },
      onTapBody: () => EditTaskSheet.present(context, task),
      menu: [
        TaskMenuAction('編集', Icons.edit_outlined, () => EditTaskSheet.present(context, task)),
        TaskMenuAction('ジャンル変更', Icons.label_outline, () => GenrePickerSheet.present(context, task)),
        TaskMenuAction('LATERへ移動', Icons.nightlight_outlined, () {
          if (app.move(task, TaskStatus.later)) {
            showUndoSnack(context, 'LATERへ移動しました');
          } else {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(Limits.fullMessage(TaskStatus.later))));
          }
        }),
        TaskMenuAction('削除', Icons.delete_outline,
            () { app.deleteTask(task); showUndoSnack(context, '削除しました'); }, destructive: true),
      ],
    );
  }

  /// 夜の精算に設定した時刻を今日すでに過ぎているか。
  bool _afterSettlementTime(AppState app) {
    final now = DateTime.now();
    final s = app.settings.settlement;
    final at = DateTime(now.year, now.month, now.day, s.hour, s.minute);
    return !now.isBefore(at);
  }
}

/// TODAY を今日ぶん片づけ切ったときの達成表示。連続日数（ストリーク）も見せる。
class _TodayCleared extends StatelessWidget {
  final int streak;
  const _TodayCleared({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: context.c.todaySoft, shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded, size: 38, color: context.c.todayAccent),
            ),
            const SizedBox(height: 16),
            Text('今日は決着！',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.c.ink)),
            const SizedBox(height: 6),
            Text('TODAYを片づけました。おつかれさま。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.c.sub)),
            if (streak >= 1) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: context.c.boxSoft, borderRadius: AppTheme.radiusPill),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text('$streak日連続で決着',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.c.ink2)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 「今日の精算」への導線。夜の精算時刻以降に TODAY のトップへ出す。
class _SettlementButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SettlementButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      color: context.c.ink,
      shadow: AppTheme.floatShadow,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: [
          Icon(Icons.nights_stay_outlined, color: context.c.bg, size: 22),
          const SizedBox(width: 12),
          Text('今日の精算', style: TextStyle(color: context.c.bg, fontWeight: FontWeight.w800, fontSize: 16)),
          const Spacer(),
          Icon(Icons.chevron_right, color: context.c.bg.withOpacity(0.7), size: 20),
        ],
      ),
    );
  }
}
