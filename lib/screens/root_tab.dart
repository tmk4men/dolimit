import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/ui_kit.dart';
import 'home_screen.dart';
import 'box_screen.dart';
import 'today_screen.dart';
import 'later_screen.dart';
import 'settings_screen.dart';

/// 下部タブ + 全画面共通 FAB（＋）
class RootTab extends StatefulWidget {
  const RootTab({super.key});

  @override
  State<RootTab> createState() => _RootTabState();
}

class _RootTabState extends State<RootTab> {
  int _index = 0;

  void _goToTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onGoToTab: _goToTab),
      const BoxScreen(),
      const TodayScreen(),
      const LaterScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _index, children: screens)),
      floatingActionButton: _Fab(
        onTap: () => AddTaskSheet.present(context, onSort: () => _goToTab(1)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8E8EC),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: 'BOX'),
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'TODAY'),
          NavigationDestination(icon: Icon(Icons.nightlight_outlined), selectedIcon: Icon(Icons.nightlight), label: 'LATER'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
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
