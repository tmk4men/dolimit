import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/store.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'services/speech_service.dart';
import 'services/widget_service.dart';
import 'state/app_navigation.dart';
import 'state/app_state.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.open();
  final notifier = NotificationService.create();
  await notifier.init();
  final widgets = WidgetService.create();
  await widgets.init();
  final appState = AppState(store: store, notifier: notifier, widgets: widgets);
  await appState.load();

  // 課金は起動時に接続を温め、リスナーを張っておく。こうしないと、シートを
  // 開いて即購入したときにストア未接続で失敗したり、前回の中断トランザクションを
  // 取りこぼして「課金したのに解放されない」事故が起きる。解放は購入シートの
  // 開閉に依らず、ここで受けて必ず AppState に反映する。
  final purchase = PurchaseService.create();
  purchase.onUnlocked = (productId) {
    if (productId == PurchaseService.proProductId) {
      appState.setPro(true);
    } else if (productId == PurchaseService.boostProductId) {
      appState.setBoost(true);
    }
  };
  await purchase.init();

  // 通知が既定ONなのに権限未取得で鳴らない問題を防ぐため、起動時に権限を要求する。
  // Web ではスタブが true を返すだけの no-op。
  if (appState.settings.notificationsEnabled) {
    await notifier.requestPermission();
    // 権限取得後に定時リマインドを貼り直す
    await notifier.rescheduleDailyReminders(appState.settings);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider(create: (_) => AppNavigation()),
        Provider<SpeechService>(create: (_) => SpeechService.create()),
        Provider<PurchaseService>.value(value: purchase),
      ],
      child: const DoLimitApp(),
    ),
  );
}
