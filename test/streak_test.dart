import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/state/app_state.dart';
import 'package:dolimit/util/day_clock.dart';

Future<AppState> newState() async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final app = AppState(store: store, notifier: StubNotificationService());
  await app.load();
  return app;
}

void moveToToday(AppState app, String title) {
  app.addToBox(title);
  final t = app.tasksIn(TaskStatus.box).firstWhere((t) => t.title == title);
  app.move(t, TaskStatus.today);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('決着ストリーク', () {
    test('TODAYを完了し切ると決着日として記録されストリーク1', () async {
      final app = await newState();
      moveToToday(app, 't');
      expect(app.currentStreak, 0);

      app.complete(app.tasksIn(TaskStatus.today).single);

      expect(app.todayUnfinished, 0);
      expect(app.clearedToday, isTrue);
      expect(app.currentStreak, 1);
    });

    test('昨日決着していれば翌日の決着で2連続', () async {
      final app = await newState();
      app.settings.streak = 1;
      app.settings.lastClearedDay =
          DayClock.startOfDay(DateTime.now().subtract(const Duration(days: 1)));

      moveToToday(app, 't');
      app.complete(app.tasksIn(TaskStatus.today).single);

      expect(app.currentStreak, 2);
    });

    test('今日1件も完了していなければ決着に数えない', () async {
      final app = await newState();
      moveToToday(app, 't');
      // 完了ではなく LATER へ逃がす → TODAY は空でも決着ではない。
      app.move(app.tasksIn(TaskStatus.today).single, TaskStatus.later);

      expect(app.todayUnfinished, 0);
      expect(app.clearedToday, isFalse);
      expect(app.currentStreak, 0);
    });

    test('決着は1日1回だけ数える', () async {
      final app = await newState();
      moveToToday(app, 'a');
      moveToToday(app, 'b');

      app.complete(app.tasksIn(TaskStatus.today).first); // まだ1件残る
      expect(app.currentStreak, 0);
      app.complete(app.tasksIn(TaskStatus.today).single); // 0件に → 決着
      expect(app.currentStreak, 1);

      // 同じ日にもう1件やってもストリークは増えない。
      moveToToday(app, 'c');
      app.complete(app.tasksIn(TaskStatus.today).single);
      expect(app.currentStreak, 1);
    });

    test('連続が途切れると currentStreak は 0', () async {
      final app = await newState();
      app.settings.streak = 5;
      app.settings.lastClearedDay =
          DayClock.startOfDay(DateTime.now().subtract(const Duration(days: 3)));

      expect(app.currentStreak, 0);
    });

    test('ストリークは保存され、読み直しても続く', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await Store.open();
      final app = AppState(store: store, notifier: StubNotificationService());
      await app.load();
      moveToToday(app, 't');
      app.complete(app.tasksIn(TaskStatus.today).single);
      expect(app.currentStreak, 1);

      final reloaded = AppState(store: store, notifier: StubNotificationService());
      await reloaded.load();
      expect(reloaded.currentStreak, 1);
      expect(reloaded.clearedToday, isTrue);
    });
  });
}
