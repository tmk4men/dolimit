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

/// 認識結果をテストから流し込める音声スタブ。
class FakeSpeechService implements SpeechService {
  FakeSpeechService({required bool available}) : _available = available;

  final bool _available;
  bool _listening = false;
  int cancelCount = 0;
  int stopCount = 0;

  void Function(SpeechResult)? _onResult;
  void Function()? _onDone;

  @override
  Future<bool> init() async => _available;

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _listening;

  @override
  Future<void> start({
    required void Function(SpeechResult result) onResult,
    void Function()? onDone,
  }) async {
    if (!_available) return;
    _listening = true;
    _onResult = onResult;
    _onDone = onDone;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    _listening = false;
  }

  /// 認識エンジンからの結果を模擬する。
  void emit(String text, {bool isFinal = false}) =>
      _onResult?.call(SpeechResult(text, isFinal: isFinal));

  void finish() {
    _listening = false;
    _onDone?.call();
  }
}

Future<AppState> newState() async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final app = AppState(store: store, notifier: StubNotificationService());
  await app.load();
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSheet(
      WidgetTester tester, AppState app, FakeSpeechService speech) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: app),
        Provider<SpeechService>.value(value: speech),
      ],
      child: const MaterialApp(home: Scaffold(body: AddTaskSheet())),
    ));
    await tester.pump(); // init() の Future を解決させる
  }

  group('音声入力が使える端末', () {
    testWidgets('マイクを押すと聞き取り、結果が入力欄に入る', (tester) async {
      final app = await newState();
      final speech = FakeSpeechService(available: true);
      await pumpSheet(tester, app, speech);

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump();

      expect(speech.isListening, isTrue);
      expect(find.text('聞き取っています… もう一度押すと確定します'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      speech.emit('歯医者を');
      await tester.pump();
      expect(find.text('歯医者を'), findsOneWidget);

      // 途中経過は置き換わる（積み重ならない）
      speech.emit('歯医者を予約する', isFinal: true);
      await tester.pump();
      expect(find.text('歯医者を予約する'), findsOneWidget);
      expect(find.text('歯医者を'), findsNothing);
    });

    testWidgets('もう一度押すと停止する', (tester) async {
      final app = await newState();
      final speech = FakeSpeechService(available: true);
      await pumpSheet(tester, app, speech);

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();

      expect(speech.stopCount, 1);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('認識が自分で終わるとボタンが戻る', (tester) async {
      final app = await newState();
      final speech = FakeSpeechService(available: true);
      await pumpSheet(tester, app, speech);

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump();
      speech.finish();
      await tester.pump();

      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('既存の入力があると認識結果は後ろに足される', (tester) async {
      final app = await newState();
      final speech = FakeSpeechService(available: true);
      await pumpSheet(tester, app, speech);

      await tester.enterText(find.byType(TextField), '明日');
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump();
      speech.emit('歯医者へ行く');
      await tester.pump();

      expect(find.text('明日 歯医者へ行く'), findsOneWidget);
    });

    testWidgets('音声で入力したタスクは source=voice で保存される', (tester) async {
      final app = await newState();
      final speech = FakeSpeechService(available: true);
      await pumpSheet(tester, app, speech);

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump();
      speech.emit('読書10分', isFinal: true);
      await tester.pump();
      speech.finish();
      await tester.pump();

      await tester.tap(find.text('追加'));
      await tester.pump();

      final t = app.tasksIn(TaskStatus.box).single;
      expect(t.title, '読書10分');
      expect(t.source, TaskSource.voice);
    });

    testWidgets('聞き取り中にシートを閉じるとマイクを離す', (tester) async {
      final app = await newState();
      final speech = FakeSpeechService(available: true);
      await pumpSheet(tester, app, speech);

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump();
      expect(speech.isListening, isTrue);

      // シートを破棄する
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      expect(speech.cancelCount, greaterThan(0));
      expect(speech.isListening, isFalse);
    });
  });

  group('音声入力が使えない端末', () {
    testWidgets('聞き取りは始まらず、キーボードへフォールバックする', (tester) async {
      final app = await newState();
      final speech = FakeSpeechService(available: false);
      await pumpSheet(tester, app, speech);

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump();

      expect(speech.isListening, isFalse);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      expect(find.text('聞き取っています… もう一度押すと確定します'), findsNothing);

      // 手入力した内容は source=voice 扱いで保存される（従来の A 案）
      await tester.enterText(find.byType(TextField), '手入力');
      await tester.tap(find.text('追加'));
      await tester.pump();

      final t = app.tasksIn(TaskStatus.box).single;
      expect(t.source, TaskSource.voice);
    });
  });
}
