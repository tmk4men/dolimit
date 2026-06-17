import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'state/app_state.dart';
import 'screens/root_tab.dart';
import 'screens/onboarding_screen.dart';

class DoLimitApp extends StatelessWidget {
  const DoLimitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoLimit / 今日やる枠',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _Gate(),
    );
  }
}

/// オンボーディング未完了ならオンボーディング、完了後はタブへ。
/// 復帰時にメンテナンス（自動移動・自動追放）を実行。
class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().runMaintenance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = context.select<AppState, bool>((s) => s.settings.onboardingDone);
    return done ? const RootTab() : const OnboardingScreen();
  }
}
