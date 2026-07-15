import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/models/task.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/state/app_state.dart';

/// LATER 事前通知の予約・取り消しを記録するスタブ。
class RecordingNotificationService extends StubNotificationService {
  final scheduled = <String>{};
  final cancelled = <String>[];

  @override
  Future<void> scheduleLaterReminder(
      {required String taskId, required String title, required DateTime at}) async {
    scheduled.add(taskId);
  }

  @override
  Future<void> cancelLaterReminder(String taskId) async {
    cancelled.add(taskId);
    scheduled.remove(taskId);
  }

  void reset() {
    scheduled.clear();
    cancelled.clear();
  }
}

Future<(AppState, RecordingNotificationService)> newState() async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final notifier = RecordingNotificationService();
  final app = AppState(store: store, notifier: notifier);
  await app.load();
  return (app, notifier);
}

/// 明日の開始日と事前通知を設定した LATER タスクを作る。
TaskItem addLaterWithReminder(AppState app, String title, {bool dateOnly = false}) {
  app.addToBox(title);
  final t = app.tasksIn(TaskStatus.box).firstWhere((x) => x.title == title);
  app.move(t, TaskStatus.later);
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  app.configureLater(
    t,
    startAt: dateOnly
        ? DateTime(tomorrow.year, tomorrow.month, tomorrow.day)
        : DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 15, 0),
    startDateOnly: dateOnly,
    autoMove: true,
    reminderEnabled: true,
    reminderOffsetValue: 10,
    reminderOffsetUnit: ReminderOffsetUnit.minute,
  );
  return t;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('全データ削除で予約通知も取り消される', () async {
    final (app, notifier) = await newState();
    final t = addLaterWithReminder(app, 'ゴミ出し');
    expect(notifier.scheduled, contains(t.id));

    app.deleteAll();

    expect(notifier.scheduled, isEmpty, reason: '幽霊通知が残らない');
    expect(notifier.cancelled, contains(t.id));
  });

  test('復元すると古い予約は消え、取り込んだ LATER の予約が貼られる', () async {
    final (app, notifier) = await newState();
    final old = addLaterWithReminder(app, '古いタスク');

    // 別の状態をバックアップとして用意する。
    final (other, _) = await newState();
    final fresh = addLaterWithReminder(other, '新しいタスク');
    final backup = other.exportJson();

    notifier.reset();
    expect(app.importJson(backup), isNull);

    expect(notifier.cancelled, contains(old.id), reason: '消えるタスクの予約は取り消す');
    expect(notifier.scheduled, contains(fresh.id), reason: '取り込んだタスクは予約し直す');
    expect(notifier.scheduled, isNot(contains(old.id)));
  });

  test('通知を OFF にすると LATER の予約も取り消される', () async {
    final (app, notifier) = await newState();
    final t = addLaterWithReminder(app, '通院');
    expect(notifier.scheduled, contains(t.id));

    app.updateSettings((s) => s.notificationsEnabled = false);
    expect(notifier.scheduled, isEmpty);
    expect(t.reminderAt, isNull);

    // ON に戻すと貼り直される。
    app.updateSettings((s) => s.notificationsEnabled = true);
    expect(notifier.scheduled, contains(t.id));
    expect(t.reminderAt, isNotNull);
  });

  test('通知が OFF なら新規の LATER 設定でも予約しない', () async {
    final (app, notifier) = await newState();
    app.updateSettings((s) => s.notificationsEnabled = false);
    notifier.reset();

    final t = addLaterWithReminder(app, '歯医者');
    expect(notifier.scheduled, isEmpty);
    expect(t.reminderEnabled, isTrue, reason: 'ユーザーの意図は保持する');
    expect(t.reminderAt, isNull);
  });

  test('開始日のみのタスクは日付が変わる 0:00 から逆算して予約される', () async {
    final (app, notifier) = await newState();
    final t = addLaterWithReminder(app, '朝の運動', dateOnly: true);

    // 開始日は明日。基準は 0:00（日付が変わる瞬間）で、10分前の予約は前日 23:50。
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final midnight = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final expected = midnight.subtract(const Duration(minutes: 10));
    expect(t.reminderAt, expected);
    expect(notifier.scheduled, contains(t.id));
  });
}
