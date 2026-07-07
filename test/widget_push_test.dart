import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/services/widget_service.dart';
import 'package:dolimit/state/app_state.dart';

/// update() の呼び出しを記録するテスト用ウィジェットサービス。
class FakeWidgetService implements WidgetService {
  int calls = 0;
  int lastCount = -1;
  List<String> lastTitles = const [];

  @override
  Future<void> init() async {}

  @override
  Future<void> update({required int todayCount, required List<String> topTitles}) async {
    calls++;
    lastCount = todayCount;
    lastTitles = topTitles;
  }
}

Future<(AppState, FakeWidgetService)> newState() async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final widget = FakeWidgetService();
  final app = AppState(
    store: store,
    notifier: StubNotificationService(),
    widgets: widget,
  );
  await app.load();
  return (app, widget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TODAY の変化がウィジェットへ反映される（件数と上位タイトル）', () async {
    final (app, widget) = await newState();

    app.addToBox('a');
    app.addToBox('b');
    app.addToBox('c');
    final box = app.tasksIn(TaskStatus.box);
    app.move(box[0], TaskStatus.today);
    app.move(box[1], TaskStatus.today);
    app.move(box[2], TaskStatus.today);

    expect(widget.lastCount, 3);
    expect(widget.lastTitles, ['a', 'b', 'c']);
    expect(widget.calls, greaterThan(0));
  });

  test('完了するとウィジェットの件数が減る', () async {
    final (app, widget) = await newState();
    app.addToBox('x');
    final t = app.tasksIn(TaskStatus.box).first;
    app.move(t, TaskStatus.today);
    expect(widget.lastCount, 1);
    app.complete(t);
    expect(widget.lastCount, 0);
  });

  test('widgets 未指定でも例外なく動作する', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final app = AppState(store: store, notifier: StubNotificationService());
    await app.load();
    app.addToBox('a');
    expect(app.count(TaskStatus.box), 1);
  });
}
