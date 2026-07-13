import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'services/notification_route.dart';
import 'state/app_navigation.dart';
import 'state/app_state.dart';
import 'models/enums.dart';
import 'screens/root_tab.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settlement_screen.dart';

/// 通知タップから画面ツリーの外側で遷移するために使う。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class DoLimitApp extends StatelessWidget {
  const DoLimitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'やっとこ',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const _Gate(),
    );
  }
}

/// オンボーディング未完了ならオンボーディング、完了後はタブへ。
/// 復帰時にメンテナンス（自動移動・自動追放）を実行し、
/// 通知タップに応じて該当画面へ飛ばす。
class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> with WidgetsBindingObserver {
  Timer? _tick;
  final List<StreamSubscription<String>> _taps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // フォアグラウンド常駐中も、時刻をまたぐ自動移動/自動追放を反映させる。
    // resumed だけだと開きっぱなしの間はメンテナンスが走らないため。
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) context.read<AppState>().runMaintenance();
    });

    // 通知とホーム画面ウィジェットは同じペイロード書式を使うので、
    // 遷移の扱いも一本にまとめる。
    final app = context.read<AppState>();
    _taps.add(app.notifier.taps.listen(_handlePayload));
    final widgets = app.widgets;
    if (widgets != null) _taps.add(widgets.taps.listen(_handlePayload));

    // タップでアプリが起動した場合（コールドスタート）。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final fromNotification = await app.notifier.initialTapPayload();
      final payload = fromNotification ?? await widgets?.initialTapPayload();
      if (payload != null && mounted) _handlePayload(payload);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final s in _taps) {
      s.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().runMaintenance();
    }
  }

  /// 通知ペイロードに応じて遷移する。オンボーディング中は何もしない。
  void _handlePayload(String payload) {
    if (!mounted) return;
    final app = context.read<AppState>();
    if (!app.settings.onboardingDone) return;

    final target = parseNotificationPayload(payload);
    if (target == null) return;

    final nav = context.read<AppNavigation>();
    switch (target) {
      case OpenSettlement():
        _openSettlement();
      case OpenBox(:final box):
        nav.goTo(_tabForBox(box));
      case OpenTask(:final taskId):
        // 通知を出した後にタスクが動いている可能性があるので、
        // 保存された箱ではなく「いまの status」でタブを決める。
        final task = app.taskById(taskId);
        if (task == null) return;
        final tab = switch (task.status) {
          TaskStatus.box => AppNavigation.boxTab,
          TaskStatus.today => AppNavigation.todayTab,
          TaskStatus.later => AppNavigation.laterTab,
          // 完了・削除済みなら開く先がないので TODAY に留める。
          _ => AppNavigation.todayTab,
        };
        nav.goTo(tab);
    }
  }

  int _tabForBox(NotificationBox box) => switch (box) {
        NotificationBox.box => AppNavigation.boxTab,
        NotificationBox.today => AppNavigation.todayTab,
        NotificationBox.later => AppNavigation.laterTab,
      };

  void _openSettlement() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    // 連続タップで精算画面が積み重ならないようにする。
    navigator.popUntil((r) => r.isFirst);
    navigator.push(MaterialPageRoute(builder: (_) => const SettlementScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final done = context.select<AppState, bool>((s) => s.settings.onboardingDone);
    return done ? const RootTab() : const OnboardingScreen();
  }
}
