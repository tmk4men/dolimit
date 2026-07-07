import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import '../widgets/remaining_time.dart';
import '../widgets/task_card.dart';
import '../widgets/ui_kit.dart';
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
      children: [
        // ヘッダー：日付ラベル + 残り時間
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('今日',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.sub, letterSpacing: 1)),
            RemainingTime(fontSize: 16),
          ],
        ),
        const SizedBox(height: 18),

        // TODAY 大カウンター
        _TodayHero(count: app.todayUnfinished, cap: app.capacityFor(TaskStatus.today)!),

        const SizedBox(height: 24),

        // 次にやる
        Row(
          children: [
            const Text('次にやる',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.ink2, letterSpacing: 0.5)),
            const SizedBox(width: 8),
            if (next != null)
              AccentPill(next.ageLabel, color: AppTheme.ink2, background: AppTheme.boxSoft),
          ],
        ),
        const SizedBox(height: 10),
        if (next != null)
          TaskCard(
            task: next,
            genre: app.genreById(next.genreId),
            subtitle: next.ageLabel,
            onToggle: () => app.complete(next),
            onTapBody: () => EditTaskSheet.present(context, next),
            menu: [
              TaskMenuAction('編集', Icons.edit_outlined, () => EditTaskSheet.present(context, next)),
              TaskMenuAction('ジャンル変更', Icons.label_outline, () => GenrePickerSheet.present(context, next)),
              TaskMenuAction('LATERへ移動', Icons.nightlight_outlined, () {
                if (!app.move(next, TaskStatus.later)) {
                  _snack(context, Limits.fullMessage(TaskStatus.later));
                }
              }),
              TaskMenuAction('削除', Icons.delete_outline, () => app.deleteTask(next), destructive: true),
            ],
          )
        else
          _emptyNext(context),

        const SizedBox(height: 24),

        // 箱の件数
        Row(
          children: [
            Expanded(child: _StatTile(label: 'BOX', count: app.count(TaskStatus.box), cap: app.capacityFor(TaskStatus.box)!, accent: AppTheme.boxAccent, onTap: () => onGoToTab(1))),
            const SizedBox(width: 14),
            Expanded(child: _StatTile(label: 'LATER', count: app.count(TaskStatus.later), cap: app.capacityFor(TaskStatus.later)!, accent: AppTheme.laterAccent, onTap: () => onGoToTab(3))),
          ],
        ),

        const SizedBox(height: 24),

        // 今日の精算
        _SettlementButton(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SettlementScreen())),
        ),
      ],
    );
  }

  Widget _emptyNext(BuildContext context) {
    return PressableCard(
      onTap: null,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: const BoxDecoration(color: AppTheme.boxSoft, shape: BoxShape.circle),
            child: const Icon(Icons.wb_sunny_outlined, size: 28, color: AppTheme.sub),
          ),
          const SizedBox(height: 12),
          const Text('TODAYは空です。', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('BOXから仕分けましょう', style: TextStyle(fontSize: 12.5, color: AppTheme.sub)),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// TODAY 大カウンター（ヒーロー）
class _TodayHero extends StatelessWidget {
  final int count;
  final int cap;
  const _TodayHero({required this.count, required this.cap});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: null,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('TODAY',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.ink, letterSpacing: 2)),
              Text('今日しかない', style: TextStyle(fontSize: 12, color: AppTheme.sub, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$count',
                  style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -2)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('/ $cap',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.sub)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(count == 0 ? '未完了なし' : '未完了 $count 件',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink2)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CapacityBar(count: count, capacity: cap, color: AppTheme.ink2, height: 8),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final int cap;
  final Color accent;
  final VoidCallback onTap;
  const _StatTile({required this.label, required this.count, required this.cap, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final full = count >= cap;
    return PressableCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: accent, letterSpacing: 1)),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 18, color: AppTheme.sub),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$count',
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w900, color: full ? AppTheme.todayAccent : AppTheme.ink)),
              Text(' /$cap',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.sub)),
            ],
          ),
          const SizedBox(height: 10),
          CapacityBar(count: count, capacity: cap, color: accent),
        ],
      ),
    );
  }
}

class _SettlementButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SettlementButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      color: AppTheme.ink,
      shadow: AppTheme.floatShadow,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      child: Row(
        children: const [
          Icon(Icons.nights_stay_outlined, color: Colors.white, size: 22),
          SizedBox(width: 12),
          Text('今日の精算', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          Spacer(),
          Text('残す？戻す？消す？', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
          SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.white70, size: 20),
        ],
      ),
    );
  }
}
