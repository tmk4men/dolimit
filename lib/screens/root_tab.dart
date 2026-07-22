import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../state/app_navigation.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/ads.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/ui_kit.dart';
import 'box_screen.dart';
import 'today_screen.dart';
import 'later_screen.dart';

/// 下部タブ + 全画面共通 FAB（＋）
///
/// 選択中のタブは [AppNavigation] が持つ。通知タップのように
/// この画面の外からタブを切り替えたいため。
class RootTab extends StatelessWidget {
  const RootTab({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<AppNavigation>();
    final app = context.watch<AppState>();
    final todayCount = app.count(TaskStatus.today);
    final laterCount = app.count(TaskStatus.later);
    void goToTab(int i) => nav.goTo(i);

    // 開いているタブに応じて追加先を決める。TODAY タブなら TODAY、
    // LATER タブなら LATER、それ以外（BOX）は BOX へ。
    final addTarget = switch (nav.tab) {
      AppNavigation.todayTab => TaskStatus.today,
      AppNavigation.laterTab => TaskStatus.later,
      _ => TaskStatus.box,
    };

    final screens = [
      const BoxScreen(),
      const TodayScreen(),
      const LaterScreen(),
    ];

    // BOX タブでだけ、ナビバーの真上にバナーを出す（Pro は非表示）。
    // bottomNavigationBar に含めると Scaffold が FAB をこの上へ持ち上げるので、
    // ＋ボタンとも本文とも重ならない。
    final showBanner = nav.tab == AppNavigation.boxTab && !app.isPro;

    return Scaffold(
      body: SafeArea(
          bottom: false,
          child: IndexedStack(index: nav.tab, children: screens)),
      floatingActionButton: _Fab(
        onTap: () => AddTaskSheet.present(context,
            target: addTarget, onSort: () => goToTab(AppNavigation.boxTab)),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBanner) const AdBanner(),
          NavigationBar(
            selectedIndex: nav.tab,
            onDestinationSelected: goToTab,
            backgroundColor: context.c.card,
            indicatorColor: context.c.boxSoft,
            destinations: [
          const NavigationDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox),
              label: 'BOX'),
          NavigationDestination(
            icon: _CountBadge(
                count: todayCount, child: const Icon(Icons.wb_sunny_outlined)),
            selectedIcon: _CountBadge(
                count: todayCount, child: const Icon(Icons.wb_sunny)),
            label: 'TODAY',
          ),
          NavigationDestination(
            icon: _CountBadge(
                count: laterCount,
                child: const Icon(Icons.nightlight_outlined)),
            selectedIcon: _CountBadge(
                count: laterCount, child: const Icon(Icons.nightlight)),
            label: 'LATER',
          ),
            ],
          ),
        ],
      ),
    );
  }
}

/// タブアイコン右上の赤い件数バッジ。0 件のときは付けない。
class _CountBadge extends StatelessWidget {
  final int count;
  final Widget child;
  const _CountBadge({required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge(
      label: Text('$count'),
      textColor: context.c.bg,
      backgroundColor: context.c.todayAccent,
      child: child,
    );
  }
}

/// 大きめで押し心地のある ＋ ボタン
class _Fab extends StatelessWidget {
  final VoidCallback onTap;
  const _Fab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 4),
      child: PressableCard(
        onTap: onTap,
        color: context.c.ink,
        shadow: AppTheme.floatShadow,
        radius: const BorderRadius.all(Radius.circular(20)),
        padding: const EdgeInsets.all(17),
        child: Icon(Icons.add_rounded, color: context.c.bg, size: 30),
      ),
    );
  }
}
