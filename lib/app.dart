import 'dart:async';

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
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // フォアグラウンド常駐中も、時刻をまたぐ自動移動/自動追放を反映させる。
    // resumed だけだと開きっぱなしの間はメンテナンスが走らないため。
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) context.read<AppState>().runMaintenance();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
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
