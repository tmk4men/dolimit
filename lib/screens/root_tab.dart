import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/add_task_sheet.dart';
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
      body: SafeArea(child: IndexedStack(index: _index, children: screens)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () => AddTaskSheet.present(context, onSort: () => _goToTab(1)),
        child: const Icon(Icons.add, size: 28),
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
