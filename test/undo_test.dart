import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/state/app_state.dart';

Future<AppState> newState() async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final app = AppState(store: store, notifier: StubNotificationService());
  await app.load();
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('取り消し（Undo）', () {
    test('完了を取り消すと TODAY に戻る', () async {
      final app = await newState();
      app.addToBox('t');
      app.move(app.tasksIn(TaskStatus.box).single, TaskStatus.today);
      app.complete(app.tasksIn(TaskStatus.today).single);
      expect(app.count(TaskStatus.today), 0);

      expect(app.undoLast(), isTrue);
      expect(app.count(TaskStatus.today), 1);
      expect(app.tasksIn(TaskStatus.today).single.status, TaskStatus.today);
    });

    test('削除を取り消すと戻る', () async {
      final app = await newState();
      app.addToBox('t');
      app.deleteTask(app.tasksIn(TaskStatus.box).single);
      expect(app.count(TaskStatus.box), 0);

      expect(app.undoLast(), isTrue);
      expect(app.count(TaskStatus.box), 1);
    });

    test('移動を取り消すと元の箱に戻る', () async {
      final app = await newState();
      app.addToBox('t');
      app.move(app.tasksIn(TaskStatus.box).single, TaskStatus.today);
      expect(app.count(TaskStatus.today), 1);

      expect(app.undoLast(), isTrue);
      expect(app.count(TaskStatus.box), 1);
      expect(app.count(TaskStatus.today), 0);
    });

    test('取り消すものが無ければ false', () async {
      final app = await newState();
      expect(app.canUndo, isFalse);
      expect(app.undoLast(), isFalse);
    });

    test('取り消しは一度きり', () async {
      final app = await newState();
      app.addToBox('t');
      app.deleteTask(app.tasksIn(TaskStatus.box).single);
      expect(app.undoLast(), isTrue);
      expect(app.canUndo, isFalse);
      expect(app.undoLast(), isFalse);
    });
  });
}
