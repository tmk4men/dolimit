import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/services/speech_service.dart';
import 'package:dolimit/state/app_state.dart';
import 'package:dolimit/widgets/add_task_sheet.dart';

Future<AppState> newState() async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final app = AppState(store: store, notifier: StubNotificationService());
  await app.load();
  return app;
}

/// 追加シートを開き、キーボード（viewInsets）を出した状態にする。
Future<void> pumpSheet(WidgetTester tester, AppState app,
    {required TaskStatus target, required double keyboardLogical}) async {
  // 論理 360x800 の端末を想定。
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = const Size(360 * dpr, 800 * dpr);

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>.value(value: app),
      Provider<SpeechService>(create: (_) => const StubSpeechService()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AddTaskSheet.present(context, target: target),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  // ソフトキーボードが出た状態を再現する。
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardLogical * dpr);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('追加シート：キーボードで入力欄が隠れない', () {
    for (final target in [TaskStatus.box, TaskStatus.today, TaskStatus.later]) {
      testWidgets('$target：入力欄がキーボードの上に見える', (tester) async {
        addTearDown(tester.view.reset);
        final app = await newState();

        const keyboard = 300.0; // 論理px
        await pumpSheet(tester, app, target: target, keyboardLogical: keyboard);

        final field = find.byType(TextField);
        expect(field, findsOneWidget);

        final rect = tester.getRect(field);
        const screenH = 800.0;
        const keyboardTop = screenH - keyboard; // = 500

        // 入力欄の下端がキーボードの上端より上にある＝隠れていない。
        expect(rect.bottom, lessThanOrEqualTo(keyboardTop),
            reason: '入力欄の下端($rect.bottom)がキーボード上端($keyboardTop)より下＝隠れている');
        // 画面上端からも外れていない（上に飛びすぎていない）。
        expect(rect.top, greaterThanOrEqualTo(0.0),
            reason: '入力欄が画面上端より上へ押し出されている');
      });
    }

    testWidgets('小さい画面（横向き相当）でも入力欄が見える', (tester) async {
      addTearDown(tester.view.reset);
      final app = await newState();

      // 画面高が低く、キーボードが大きめで内容が確実にはみ出す状況。
      // ここで reverse:true だと下端（追加ボタン側）が優先され、
      // 入力欄が上へクリップされて見えなくなる。
      const dpr = 3.0;
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = const Size(360 * dpr, 360 * dpr);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: app),
          Provider<SpeechService>(create: (_) => const StubSpeechService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AddTaskSheet.present(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      const keyboard = 280.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * dpr);
      await tester.pumpAndSettle();

      final field = find.byType(TextField);
      expect(field, findsOneWidget);

      final rect = tester.getRect(field);
      const screenH = 360.0;
      const keyboardTop = screenH - keyboard; // = 80
      // フォーカス中の入力欄がキーボードの上に収まっている。
      expect(rect.bottom, lessThanOrEqualTo(keyboardTop),
          reason: '狭い画面で入力欄がキーボードに隠れている');
      expect(rect.top, greaterThanOrEqualTo(0.0),
          reason: '狭い画面で入力欄が画面上端より上へ出ている');
    });
  });
}
