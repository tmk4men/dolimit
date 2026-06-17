import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/store.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.open();
  final notifier = NotificationService.create();
  final appState = AppState(store: store, notifier: notifier);
  await appState.load();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const DoLimitApp(),
    ),
  );
}
