import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/state/app_state.dart';
import 'package:dolimit/util/day_clock.dart';
import 'package:dolimit/util/limits.dart';

Future<AppState> newState() async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final app = AppState(store: store, notifier: StubNotificationService());
  await app.load();
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('上限（プロダクト中心思想）', () {
    test('BOX は上限を超えて追加できない', () async {
      final app = await newState();
      for (var i = 0; i < Limits.box; i++) {
        expect(app.addToBox('t$i'), isTrue);
      }
      expect(app.count(TaskStatus.box), Limits.box);
      // 上限超過は false（追加されない）
      expect(app.addToBox('overflow'), isFalse);
      expect(app.count(TaskStatus.box), Limits.box);
    });

    test('TODAY が満杯なら move は失敗する', () async {
      final app = await newState();
      // BOX を上限まで埋めてから TODAY を満杯にする
      for (var i = 0; i < Limits.box; i++) {
        app.addToBox('t$i');
      }
      final box = app.tasksIn(TaskStatus.box);
      for (var i = 0; i < Limits.today; i++) {
        expect(app.move(box[i], TaskStatus.today), isTrue);
      }
      expect(app.count(TaskStatus.today), Limits.today);
      // 11 件目は入らない
      expect(app.move(box[Limits.today], TaskStatus.today), isFalse);
      expect(box[Limits.today].status, TaskStatus.box);
    });
  });

  group('LATER 自動移動', () {
    test('開始日が到来した LATER は runMaintenance で TODAY へ移る', () async {
      final app = await newState();
      app.addToBox('later task');
      final t = app.tasksIn(TaskStatus.box).first;
      app.move(t, TaskStatus.later);
      app.configureLater(
        t,
        startAt: DateTime.now().subtract(const Duration(hours: 1)),
        startDateOnly: false,
        autoMove: true,
        reminderEnabled: false,
      );
      app.runMaintenance();
      expect(t.status, TaskStatus.today);
    });

    test('開始日が未来なら移動しない', () async {
      final app = await newState();
      app.addToBox('later task');
      final t = app.tasksIn(TaskStatus.box).first;
      app.move(t, TaskStatus.later);
      app.configureLater(
        t,
        startAt: DateTime.now().add(const Duration(days: 1)),
        startDateOnly: false,
        autoMove: true,
        reminderEnabled: false,
      );
      app.runMaintenance();
      expect(t.status, TaskStatus.later);
    });
  });

  group('3日連続未完了の自動追放（回帰テスト）', () {
    test('精算しなくても日跨ぎ3回で LATER へ追放される', () async {
      final app = await newState();
      app.addToBox('stale');
      final t = app.tasksIn(TaskStatus.box).first;
      app.move(t, TaskStatus.today);
      expect(t.consecutiveUnfinishedDays, 0);

      // 「昨日が最後の TODAY 日」を3回作って日跨ぎを再現する
      for (var i = 0; i < 3; i++) {
        t.lastTodayDate =
            DayClock.startOfDay().subtract(const Duration(days: 1));
        app.runMaintenance();
      }
      expect(t.status, TaskStatus.later);
    });

    test('同日に何度 runMaintenance しても未完了日数は増えない', () async {
      final app = await newState();
      app.addToBox('x');
      final t = app.tasksIn(TaskStatus.box).first;
      app.move(t, TaskStatus.today);
      final before = t.consecutiveUnfinishedDays;
      app.runMaintenance();
      app.runMaintenance();
      expect(t.consecutiveUnfinishedDays, before);
      expect(t.status, TaskStatus.today);
    });

    test('精算（明日もTODAY）は未完了日数を二重加算しない', () async {
      final app = await newState();
      app.addToBox('x');
      final t = app.tasksIn(TaskStatus.box).first;
      app.move(t, TaskStatus.today);
      // 1日分の日跨ぎ
      t.lastTodayDate = DayClock.startOfDay().subtract(const Duration(days: 1));
      app.runMaintenance();
      final afterRollover = t.consecutiveUnfinishedDays; // 1
      // 同じ日に精算しても増えない
      app.settleKeepInToday(t);
      expect(t.consecutiveUnfinishedDays, afterRollover);
    });

    test('完了すると未完了日数はリセットされる', () async {
      final app = await newState();
      app.addToBox('x');
      final t = app.tasksIn(TaskStatus.box).first;
      app.move(t, TaskStatus.today);
      t.lastTodayDate = DayClock.startOfDay().subtract(const Duration(days: 2));
      app.runMaintenance();
      expect(t.consecutiveUnfinishedDays, 2);
      app.complete(t);
      expect(t.consecutiveUnfinishedDays, 0);
      expect(t.status, TaskStatus.done);
    });
  });

  group('バックアップの取り込み（堅牢化）', () {
    test('新しいバージョンのバックアップは拒否する', () async {
      final app = await newState();
      final err = app.importJson(
          '{"version":${AppState.backupVersion + 1},"tasks":[],"genres":[]}');
      expect(err, isNotNull);
    });

    test('壊れた JSON でも既存データを破壊しない', () async {
      final app = await newState();
      app.addToBox('keep me');
      final err = app.importJson('{ not valid json ');
      expect(err, isNotNull);
      // 既存タスクは残っている
      expect(app.count(TaskStatus.box), 1);
    });

    test('ジャンル上限を超える取り込みは切り捨てられる', () async {
      final app = await newState();
      Map<String, dynamic> g(int i) => {
            'id': 'g$i',
            'name': 'n$i',
            'colorValue': 0xFF000000,
            'createdAt': '2026-01-01T00:00:00.000',
            'updatedAt': '2026-01-01T00:00:00.000',
          };
      final payload = jsonEncode({
        'version': AppState.backupVersion,
        'tasks': [],
        'genres': List.generate(Limits.genre + 3, g),
      });
      final err = app.importJson(payload);
      expect(err, isNull);
      expect(app.genres.length, Limits.genre);
    });

    test('export → import で往復できる', () async {
      final app = await newState();
      app.addToBox('a');
      app.addToBox('b');
      final json = app.exportJson();

      final app2 = await newState();
      final err = app2.importJson(json);
      expect(err, isNull);
      expect(app2.count(TaskStatus.box), 2);
    });
  });

  group('Store の防御的読み込み', () {
    test('壊れた保存データは空として読み込む', () async {
      SharedPreferences.setMockInitialValues({
        'tasks_v1': 'this is not json {{{',
        'genres_v1': '{"unexpected":"shape"}',
      });
      final store = await Store.open();
      expect(store.loadTasks(), isEmpty);
      expect(store.loadGenres(), isEmpty);
      // settings は既定値にフォールバック
      expect(store.loadSettings().badgeEnabled, isTrue);
    });

    test('一部の要素だけ壊れていても読める分は読む', () async {
      SharedPreferences.setMockInitialValues({
        'tasks_v1': jsonEncode([
          {'id': '1', 'title': 'ok', 'status': 'box'},
          {'broken': true}, // id/title 無し → スキップ
        ]),
      });
      final store = await Store.open();
      final tasks = store.loadTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, 'ok');
    });
  });
}
