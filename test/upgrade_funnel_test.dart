import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/app.dart' show appNavigatorKey;
import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/services/speech_service.dart';
import 'package:dolimit/state/app_state.dart';
import 'package:dolimit/widgets/upgrade.dart';

Future<AppState> newState() async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final app = AppState(store: store, notifier: StubNotificationService());
  await app.load();
  return app;
}

Future<void> pumpTrigger(WidgetTester tester, AppState app) async {
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>.value(value: app),
      Provider<SpeechService>(create: (_) => const StubSpeechService()),
    ],
    child: MaterialApp(
      navigatorKey: appNavigatorKey,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showCapacityFullSnack(context, TaskStatus.today),
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('満杯スナックバーに「枠を増やす」導線が出て、押すとPro/ブーストを選べる',
      (tester) async {
    final app = await newState();
    await pumpTrigger(tester, app);

    await tester.tap(find.text('trigger'));
    await tester.pump(); // スナックバー生成
    await tester.pump(const Duration(milliseconds: 800)); // 登場アニメ完了

    expect(find.text('TODAY、そろそろいっぱい'),
        findsOneWidget);
    expect(find.text('枠を増やす'), findsOneWidget);

    await tester.tap(find.text('枠を増やす'));
    await tester.pumpAndSettle(); // ハブシート表示

    expect(find.text('ブースト ¥100（買い切り）'), findsOneWidget);
    expect(find.text('Pro ¥500（買い切り）'), findsOneWidget);
  });

  testWidgets('Pro もブーストも購入済みなら「枠を増やす」は出さない', (tester) async {
    final app = await newState();
    app.setPro(true);
    app.setBoost(true);
    await pumpTrigger(tester, app);

    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(find.text('枠を増やす'), findsNothing,
        reason: 'これ以上増やせないので導線は出さない');
  });

  testWidgets('ブースト購入済みならハブに Pro だけ出る', (tester) async {
    final app = await newState();
    app.setBoost(true);
    await pumpTrigger(tester, app);

    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('枠を増やす'));
    await tester.pumpAndSettle();

    expect(find.text('ブースト ¥100（買い切り）'), findsNothing);
    expect(find.text('Pro ¥500（買い切り）'), findsOneWidget);
  });
}
