import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/ui_kit.dart';
import 'home_screen.dart';
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
    void goToTab(int i) => nav.goTo(i);

    final screens = [
      HomeScreen(onGoToTab: goToTab),
      const BoxScreen(),
      const TodayScreen(),
      const LaterScreen(),
    ];

    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: nav.tab, children: screens)),
      floatingActionButton: _Fab(
        onTap: () => AddTaskSheet.present(context,
            onSort: () => goToTab(AppNavigation.boxTab)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav.tab,
        onDestinationSelected: goToTab,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8E8EC),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: 'BOX'),
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'TODAY'),
          NavigationDestination(icon: Icon(Icons.nightlight_outlined), selectedIcon: Icon(Icons.nightlight), label: 'LATER'),
        ],
      ),
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
        color: AppTheme.ink,
        shadow: AppTheme.floatShadow,
        radius: const BorderRadius.all(Radius.circular(20)),
        padding: const EdgeInsets.all(17),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}
