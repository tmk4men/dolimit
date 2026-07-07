import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('非Pro時は基本上限、Pro時は拡張上限になる', () async {
    final app = await newState();
    expect(app.isPro, isFalse);
    expect(app.capacityFor(TaskStatus.box), Limits.box);
    expect(app.capacityFor(TaskStatus.today), Limits.today);
    expect(app.capacityFor(TaskStatus.later), Limits.later);
    expect(app.genreCap, Limits.genre);

    app.setPro(true);
    expect(app.isPro, isTrue);
    expect(app.capacityFor(TaskStatus.box), Limits.box + Limits.proBonusBox);
    expect(app.capacityFor(TaskStatus.today), Limits.today + Limits.proBonusToday);
    expect(app.capacityFor(TaskStatus.later), Limits.later + Limits.proBonusLater);
    expect(app.genreCap, Limits.genre + Limits.proBonusGenre);
  });

  test('Pro にすると BOX へ基本上限を超えて追加できる', () async {
    final app = await newState();
    for (var i = 0; i < Limits.box; i++) {
      expect(app.addToBox('t$i'), isTrue);
    }
    // 非Proは基本上限で止まる
    expect(app.addToBox('overflow'), isFalse);

    app.setPro(true);
    // Pro で拡張ぶんは追加できる
    expect(app.addToBox('pro1'), isTrue);
    expect(app.count(TaskStatus.box), Limits.box + 1);
    // 拡張上限まで
    for (var i = 1; i < Limits.proBonusBox; i++) {
      expect(app.addToBox('pro_more$i'), isTrue);
    }
    expect(app.count(TaskStatus.box), Limits.box + Limits.proBonusBox);
    // 拡張上限を超えたら止まる
    expect(app.addToBox('pro_overflow'), isFalse);
  });

  test('setPro は永続化される', () async {
    final app = await newState();
    app.setPro(true);
    expect(app.settings.isPro, isTrue);
  });

  test('Pro を解除すると基本上限に戻る', () async {
    final app = await newState();
    app.setPro(true);
    app.setPro(false);
    expect(app.capacityFor(TaskStatus.box), Limits.box);
    expect(app.genreCap, Limits.genre);
  });
}
