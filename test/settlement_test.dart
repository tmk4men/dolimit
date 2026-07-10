import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/models/task.dart';
import 'package:dolimit/screens/genre_management_screen.dart';
import 'package:dolimit/screens/settlement_screen.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/state/app_state.dart';
import 'package:dolimit/util/limits.dart';

Future<AppState> newState() async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final app = AppState(store: store, notifier: StubNotificationService());
  await app.load();
  return app;
}

/// タイトルで引く。createdAt が同一ミリ秒だと並び順に頼れないため。
TaskItem byTitle(AppState app, TaskStatus status, String title) =>
    app.tasksIn(status).firstWhere((t) => t.title == title);

/// BOX を経由して [target] へ [n] 件積む。
List<TaskItem> fill(AppState app, TaskStatus target, int n, String prefix) {
  final out = <TaskItem>[];
  for (var i = 0; i < n; i++) {
    final title = '$prefix$i';
    app.addToBox(title);
    final t = byTitle(app, TaskStatus.box, title);
    app.move(t, target);
    out.add(t);
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('今日の精算（回帰テスト）', () {
    test('「明日もTODAY」を選ぶと次のタスクへ進む', () async {
      final app = await newState();
      fill(app, TaskStatus.today, 3, 'today');

      expect(app.pendingSettlement.length, 3);
      final first = app.pendingSettlement.first;

      app.settleKeepInToday(first);

      // 精算対象から外れる。ただし TODAY には残る。
      expect(app.pendingSettlement.length, 2);
      expect(app.pendingSettlement.any((t) => identical(t, first)), isFalse);
      expect(first.status, TaskStatus.today);
    });

    test('全件を精算すると精算対象が空になる', () async {
      final app = await newState();
      fill(app, TaskStatus.today, 3, 'today');

      for (var guard = 0; guard < 10 && app.pendingSettlement.isNotEmpty; guard++) {
        app.settleKeepInToday(app.pendingSettlement.first);
      }

      expect(app.pendingSettlement, isEmpty);
      expect(app.count(TaskStatus.today), 3);
    });

    test('LATER が満杯なら settleMoveToLater は false を返し、状態を変えない', () async {
      final app = await newState();
      fill(app, TaskStatus.later, Limits.later, 'later');
      final victim = fill(app, TaskStatus.today, 1, 'victim').single;

      expect(app.settleMoveToLater(victim), isFalse);
      expect(victim.status, TaskStatus.today);
      expect(victim.pendingAutoMoveToLater, isFalse);
      // 精算対象に残るので、LATER を空けてからやり直せる。
      expect(app.pendingSettlement.any((t) => identical(t, victim)), isTrue);
    });

    test('LATER に空きがあれば settleMoveToLater は成功する', () async {
      final app = await newState();
      final victim = fill(app, TaskStatus.today, 1, 'victim').single;

      expect(app.settleMoveToLater(victim), isTrue);
      expect(victim.status, TaskStatus.later);
      expect(app.pendingSettlement, isEmpty);
    });
  });

  group('精算画面（UI）', () {
    Future<void> pumpSettlement(WidgetTester tester, AppState app) async {
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: SettlementScreen()),
      ));
    }

    testWidgets('「明日もTODAY」を押すと次のタスクが表示される', (tester) async {
      final app = await newState();
      fill(app, TaskStatus.today, 3, 'today');
      await pumpSettlement(tester, app);

      expect(find.text('残り 3 件'), findsOneWidget);
      expect(find.text('today0'), findsOneWidget);

      await tester.tap(find.text('明日もTODAY'));
      await tester.pumpAndSettle();

      expect(find.text('today0'), findsNothing, reason: '同じタスクに留まらない');
      expect(find.text('today1'), findsOneWidget);
      expect(find.text('残り 2 件'), findsOneWidget);
    });

    testWidgets('全件を精算し終えると完了画面になる', (tester) async {
      final app = await newState();
      fill(app, TaskStatus.today, 2, 'today');
      await pumpSettlement(tester, app);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('明日もTODAY'));
        await tester.pumpAndSettle();
      }

      expect(find.text('精算完了'), findsOneWidget);
    });

    testWidgets('LATER が満杯だと「LATERへ移動」でメッセージが出る', (tester) async {
      final app = await newState();
      fill(app, TaskStatus.later, Limits.later, 'later');
      fill(app, TaskStatus.today, 1, 'victim');
      await pumpSettlement(tester, app);

      await tester.tap(find.text('LATERへ移動'));
      await tester.pump(); // スナックバーを出す

      expect(find.text(Limits.fullMessage(TaskStatus.later)), findsOneWidget);
      expect(find.text('victim0'), findsOneWidget, reason: '無言で消えない');
    });
  });

  group('ジャンル管理画面（UI）', () {
    testWidgets('空状態の上限表示が Pro の実効上限に追随する', (tester) async {
      final app = await newState();

      Future<void> pump() => tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
            value: app,
            child: const MaterialApp(home: GenreManagementScreen()),
          ));

      await pump();
      expect(find.text('＋ でジャンルを作成（最大${Limits.genre}個）'), findsOneWidget);

      app.setPro(true);
      await tester.pumpAndSettle();

      const proCap = Limits.genre + Limits.proBonusGenre;
      expect(find.text('＋ でジャンルを作成（最大$proCap個）'), findsOneWidget);
      expect(find.text('ジャンル  0/$proCap'), findsOneWidget);
    });
  });

  group('自動処理の永続化', () {
    test('自動追放の結果は保存され、読み直しても追放通知は再送されない', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await Store.open();
      final notifier = CountingNotificationService();
      final app = AppState(store: store, notifier: notifier);
      await app.load();

      app.addToBox('stale');
      final t = byTitle(app, TaskStatus.box, 'stale');
      app.move(t, TaskStatus.today);
      t.consecutiveUnfinishedDays = 3;

      app.runMaintenance();
      expect(t.status, TaskStatus.later);
      expect(notifier.banished, 1);

      // 同じ保存データから読み直す。追放済みなので通知は増えない。
      final app2 = AppState(store: store, notifier: notifier);
      await app2.load();
      expect(app2.count(TaskStatus.later), 1);
      expect(app2.count(TaskStatus.today), 0);
      expect(notifier.banished, 1);
    });

    test('LATER が満杯なら追放待ちになり、通知は繰り返されない', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await Store.open();
      final notifier = CountingNotificationService();
      final app = AppState(store: store, notifier: notifier);
      await app.load();

      fill(app, TaskStatus.later, Limits.later, 'later');
      final t = fill(app, TaskStatus.today, 1, 'stale').single;
      t.consecutiveUnfinishedDays = 3;

      app.runMaintenance();
      expect(t.status, TaskStatus.today);
      expect(t.pendingAutoMoveToLater, isTrue);
      expect(notifier.banished, 0);

      app.runMaintenance();
      expect(t.pendingAutoMoveToLater, isTrue);
      expect(notifier.banished, 0);
    });

    test('TODAY へ戻すと追放待ちは解除される', () async {
      final app = await newState();
      fill(app, TaskStatus.later, Limits.later, 'later');
      final t = fill(app, TaskStatus.today, 1, 'stale').single;
      t.consecutiveUnfinishedDays = 3;
      app.runMaintenance();
      expect(t.pendingAutoMoveToLater, isTrue);

      // LATER を 1 件空けてから TODAY へ入れ直す。
      app.complete(byTitle(app, TaskStatus.later, 'later0'));
      app.move(t, TaskStatus.later);
      app.move(t, TaskStatus.today);

      expect(t.pendingAutoMoveToLater, isFalse);
      expect(t.consecutiveUnfinishedDays, 0);
    });
  });

  group('保存データの肥大化を防ぐ', () {
    test('保持期間を過ぎた完了タスクは破棄される', () async {
      final app = await newState();
      app.addToBox('old');
      app.addToBox('recent');
      final old = byTitle(app, TaskStatus.box, 'old');
      final recent = byTitle(app, TaskStatus.box, 'recent');
      app.complete(old);
      app.complete(recent);

      old.completedAt = DateTime.now()
          .subtract(const Duration(days: AppState.archiveRetentionDays + 1));

      app.runMaintenance();

      final json = app.exportJson();
      expect(json.contains('"old"'), isFalse, reason: '保持期間切れは消える');
      expect(json.contains('"recent"'), isTrue, reason: '最近の完了は残る');
    });
  });

  group('入力の検証', () {
    test('空文字は BOX に追加されず false が返る', () async {
      final app = await newState();
      expect(app.addToBox('   '), isFalse);
      expect(app.count(TaskStatus.box), 0);
    });

    test('空白だけのメモは null として保存される', () async {
      final app = await newState();
      app.addToBox('x');
      final t = byTitle(app, TaskStatus.box, 'x');

      app.setMemo(t, '   ');
      expect(t.memo, isNull);

      app.setMemo(t, '  買い物リスト  ');
      expect(t.memo, '買い物リスト');
    });

    test('version が int でないバックアップは拒否される', () async {
      final app = await newState();
      app.addToBox('既存');

      final err = app.importJson('{"version":"2","tasks":[],"genres":[]}');
      expect(err, isNotNull, reason: '文字列の version は互換性チェックをすり抜けない');
      expect(app.count(TaskStatus.box), 1, reason: '既存データは壊れない');
    });

    test('renameGenre は空名と重複名を拒否する', () async {
      final app = await newState();
      expect(app.addGenre('仕事', 0xFF0000FF), isNull);
      expect(app.addGenre('私用', 0xFF00FF00), isNull);
      final g = app.genres.firstWhere((x) => x.name == '私用');

      expect(app.renameGenre(g, '仕事'), isNotNull, reason: '重複名は拒否');
      expect(app.renameGenre(g, '   '), isNotNull, reason: '空名は拒否');
      expect(g.name, '私用', reason: '拒否時は変更されない');

      // 自分自身と同じ名前への改名は重複ではない。
      expect(app.renameGenre(g, '私用'), isNull);
      expect(app.renameGenre(g, '趣味'), isNull);
      expect(g.name, '趣味');
    });
  });
}

/// 追放通知の回数を数えるスタブ。
class CountingNotificationService extends StubNotificationService {
  int banished = 0;

  @override
  Future<void> notifyBanishedToLater(String title) async {
    banished++;
  }
}
