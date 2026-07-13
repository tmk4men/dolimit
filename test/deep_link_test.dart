import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/app.dart';
import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/services/notification_route.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/state/app_navigation.dart';
import 'package:dolimit/state/app_state.dart';

/// タップを任意に流し込める通知スタブ。
class TappableNotificationService extends StubNotificationService {
  final _controller = StreamController<String>.broadcast();
  String? initialPayload;

  @override
  Stream<String> get taps => _controller.stream;

  @override
  Future<String?> initialTapPayload() async => initialPayload;

  void tap(String payload) => _controller.add(payload);
  void dispose() => _controller.close();
}

Future<(AppState, TappableNotificationService)> newState(
    {bool onboarded = true}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final notifier = TappableNotificationService();
  final app = AppState(store: store, notifier: notifier);
  await app.load();
  if (onboarded) app.updateSettings((s) => s.onboardingDone = true);
  return (app, notifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ペイロードの解釈', () {
    test('既知のペイロードを解釈する', () {
      expect(parseNotificationPayload('settlement'), const OpenSettlement());
      expect(parseNotificationPayload('today'), const OpenBox(NotificationBox.today));
      expect(parseNotificationPayload('later'), const OpenBox(NotificationBox.later));
      expect(parseNotificationPayload('box'), const OpenBox(NotificationBox.box));
      expect(parseNotificationPayload('task:abc'), const OpenTask('abc'));
    });

    test('未知・空・壊れたペイロードは null', () {
      expect(parseNotificationPayload(null), isNull);
      expect(parseNotificationPayload(''), isNull);
      expect(parseNotificationPayload('   '), isNull);
      expect(parseNotificationPayload('unknown'), isNull);
      expect(parseNotificationPayload('task:'), isNull, reason: 'id なしは無効');
    });

    test('id に : が含まれても落とさない', () {
      expect(parseNotificationPayload('task:a:b'), const OpenTask('a:b'));
    });

    test('NotificationPayload.task は解釈と往復する', () {
      const id = '3f2b-9c';
      expect(parseNotificationPayload(NotificationPayload.task(id)), const OpenTask(id));
    });
  });

  group('通知タップの遷移', () {
    Future<void> pumpApp(WidgetTester tester, AppState app) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: app),
          ChangeNotifierProvider(create: (_) => AppNavigation()),
        ],
        child: const DoLimitApp(),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('today ペイロードで TODAY タブへ移る', (tester) async {
      final (app, notifier) = await newState();
      addTearDown(notifier.dispose);
      await pumpApp(tester, app);

      // 起動直後は TODAY タブ。別タブへ移ってから today で戻れることを確認する。
      expect(find.text('TODAYは空です'), findsOneWidget, reason: '最初は TODAY');

      notifier.tap(NotificationPayload.box);
      await tester.pumpAndSettle();
      expect(find.text('BOXは空です'), findsOneWidget);

      notifier.tap(NotificationPayload.today);
      await tester.pumpAndSettle();

      expect(find.text('TODAYは空です'), findsOneWidget);
    });

    testWidgets('settlement ペイロードで精算画面が開く', (tester) async {
      final (app, notifier) = await newState();
      addTearDown(notifier.dispose);
      await pumpApp(tester, app);

      notifier.tap(NotificationPayload.settlement);
      await tester.pumpAndSettle();

      expect(find.text('夜のかたづけ'), findsWidgets);
      expect(find.text('おしまい！'), findsOneWidget, reason: 'TODAY が空なので完了表示');
    });

    testWidgets('連続タップしても精算画面は積み重ならない', (tester) async {
      final (app, notifier) = await newState();
      addTearDown(notifier.dispose);
      await pumpApp(tester, app);

      notifier.tap(NotificationPayload.settlement);
      await tester.pumpAndSettle();
      notifier.tap(NotificationPayload.settlement);
      await tester.pumpAndSettle();

      // 1 枚だけ積まれている。戻れば TODAY タブに着く。
      Navigator.of(appNavigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      expect(find.text('TODAYは空です'), findsOneWidget);
    });

    testWidgets('task ペイロードは今の status のタブを開く', (tester) async {
      final (app, notifier) = await newState();
      addTearDown(notifier.dispose);
      app.addToBox('歯医者');
      final t = app.tasksIn(TaskStatus.box).single;
      app.move(t, TaskStatus.later);
      await pumpApp(tester, app);

      notifier.tap(NotificationPayload.task(t.id));
      await tester.pumpAndSettle();
      expect(find.text('歯医者'), findsWidgets, reason: 'LATER タブに移り、タスクが見える');

      // TODAY へ動かしてから同じ通知をタップすると TODAY が開く。
      app.move(t, TaskStatus.today);
      notifier.tap(NotificationPayload.task(t.id));
      await tester.pumpAndSettle();
      expect(find.text('放置0日目'), findsNothing);
      expect(find.text('歯医者'), findsWidgets);
    });

    testWidgets('存在しないタスクのタップは無視される', (tester) async {
      final (app, notifier) = await newState();
      addTearDown(notifier.dispose);
      await pumpApp(tester, app);

      notifier.tap(NotificationPayload.task('missing-id'));
      await tester.pumpAndSettle();

      expect(find.text('TODAYは空です'), findsOneWidget, reason: 'TODAY のまま');
    });

    testWidgets('オンボーディング未完了なら遷移しない', (tester) async {
      final (app, notifier) = await newState(onboarded: false);
      addTearDown(notifier.dispose);
      await pumpApp(tester, app);

      notifier.tap(NotificationPayload.settlement);
      await tester.pumpAndSettle();

      expect(find.text('タスク、溜めすぎてない？'), findsOneWidget);
    });

    testWidgets('コールドスタート時の初期ペイロードを処理する', (tester) async {
      final (app, notifier) = await newState();
      addTearDown(notifier.dispose);
      notifier.initialPayload = NotificationPayload.later;

      await pumpApp(tester, app);
      await tester.pumpAndSettle();

      expect(find.text('LATERは空です'), findsOneWidget, reason: 'LATER タブが開く');
    });
  });
}
