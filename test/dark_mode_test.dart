import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/app.dart';
import 'package:dolimit/data/store.dart';
import 'package:dolimit/services/ad_service.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/services/speech_service.dart';
import 'package:dolimit/state/app_navigation.dart';
import 'package:dolimit/state/app_state.dart';

Future<AppState> newState() async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final app = AppState(store: store, notifier: StubNotificationService());
  await app.load();
  app.updateSettings((s) => s.onboardingDone = true);
  return app;
}

Widget wrap(AppState app) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: app),
        ChangeNotifierProvider(create: (_) => AppNavigation()),
        Provider<SpeechService>(create: (_) => SpeechService.create()),
        Provider<RewardedAdService>(create: (_) => RewardedAdService.create()),
      ],
      child: const DoLimitApp(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('外観テーマ', () {
    test('appearance が themeMode に対応する', () async {
      final app = await newState();
      expect(app.themeMode, ThemeMode.system);
      app.setAppearance('dark');
      expect(app.themeMode, ThemeMode.dark);
      app.setAppearance('light');
      expect(app.themeMode, ThemeMode.light);
    });

    testWidgets('ダーク指定でも主要画面がクラッシュせず描画できる', (tester) async {
      final app = await newState();
      app.setAppearance('dark');

      await tester.pumpWidget(wrap(app));
      await tester.pumpAndSettle();

      expect(find.text('TODAYは空です'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ライト指定でも描画できる', (tester) async {
      final app = await newState();
      app.setAppearance('light');

      await tester.pumpWidget(wrap(app));
      await tester.pumpAndSettle();

      expect(find.text('TODAYは空です'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
