import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/services/purchase_service.dart';
import 'package:dolimit/services/speech_service.dart';
import 'package:dolimit/state/app_state.dart';
import 'package:dolimit/util/limits.dart';
import 'package:dolimit/widgets/add_task_sheet.dart';
import 'package:dolimit/widgets/boost_sheet.dart';

/// 任意の結果を返す課金スタブ。products で「どの商品か」も表せる。
class FakePurchaseService implements PurchaseService {
  FakePurchaseService({required this.buyResult, PurchaseResult? restoreResult})
      : restoreResult = restoreResult ??
            const PurchaseResult(PurchaseOutcome.unavailable, '復元できる購入がありません');

  final PurchaseResult buyResult;
  final PurchaseResult restoreResult;
  int buyCount = 0;
  int restoreCount = 0;
  int disposeCount = 0;

  @override
  Future<void> init() async {}

  @override
  set onUnlocked(void Function(String productId)? handler) {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String?> priceOf(String productId) async => null;

  @override
  Future<PurchaseResult> buyPro() async {
    buyCount++;
    return buyResult;
  }

  @override
  Future<PurchaseResult> buyBoost() async {
    buyCount++;
    return buyResult;
  }

  @override
  Future<PurchaseResult> restore() async {
    restoreCount++;
    return restoreResult;
  }

  @override
  void dispose() => disposeCount++;
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

  group('ブースト（¥100 買い切り）の枠拡張', () {
    test('購入すると各箱の実効上限が恒久的に広がる', () async {
      final app = await newState();
      expect(app.isBoosted, isFalse);
      expect(app.capacityFor(TaskStatus.box), Limits.box);

      app.setBoost(true);

      expect(app.isBoosted, isTrue);
      expect(app.capacityFor(TaskStatus.box), Limits.box + Limits.boostBonusBox);
      expect(app.capacityFor(TaskStatus.today), Limits.today + Limits.boostBonusToday);
      expect(app.capacityFor(TaskStatus.later), Limits.later + Limits.boostBonusLater);
      expect(app.genreCap, Limits.genre, reason: 'ジャンルはブースト対象外');
    });

    test('Pro とブーストは重ねがけできる', () async {
      final app = await newState();
      app.setPro(true);
      app.setBoost(true);

      expect(app.capacityFor(TaskStatus.box),
          Limits.box + Limits.proBonusBox + Limits.boostBonusBox);
    });

    test('ブースト中は基本上限を超えて追加できる', () async {
      final app = await newState();
      for (var i = 0; i < Limits.box; i++) {
        expect(app.addToBox('t$i'), isTrue);
      }
      expect(app.addToBox('overflow'), isFalse);

      app.setBoost(true);

      for (var i = 0; i < Limits.boostBonusBox; i++) {
        expect(app.addToBox('boost$i'), isTrue);
      }
      expect(app.addToBox('overflow2'), isFalse, reason: '広げた上限も守る');
      expect(app.count(TaskStatus.box), Limits.box + Limits.boostBonusBox);
    });

    test('ブーストは保存され、読み直しても続く', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await Store.open();
      final app = AppState(store: store, notifier: StubNotificationService());
      await app.load();
      app.setBoost(true);

      final reloaded = AppState(store: store, notifier: StubNotificationService());
      await reloaded.load();

      expect(reloaded.isBoosted, isTrue);
      expect(reloaded.capacityFor(TaskStatus.box), Limits.box + Limits.boostBonusBox);
    });

    test('解除しても上限超過ぶんの既存タスクは消えない', () async {
      final app = await newState();
      app.setBoost(true);
      for (var i = 0; i < Limits.box + Limits.boostBonusBox; i++) {
        app.addToBox('t$i');
      }

      app.setBoost(false);
      app.runMaintenance();

      expect(app.count(TaskStatus.box), Limits.box + Limits.boostBonusBox);
      expect(app.isFull(TaskStatus.box), isTrue, reason: '追加はできない');
      expect(app.addToBox('もう入らない'), isFalse);
    });
  });

  group('ブースト購入シート（UI）', () {
    Future<void> pumpSheet(
        WidgetTester tester, AppState app, FakePurchaseService purchase) async {
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(home: Scaffold(body: BoostSheet(service: purchase))),
      ));
      await tester.pump();
    }

    testWidgets('購入に成功するとブーストが付与され永続化される', (tester) async {
      final app = await newState();
      final purchase = FakePurchaseService(
          buyResult: const PurchaseResult(
              PurchaseOutcome.purchased, null, {PurchaseService.boostProductId}));
      await pumpSheet(tester, app, purchase);

      expect(app.isBoosted, isFalse);

      await tester.tap(find.text('¥100で購入'));
      await tester.pumpAndSettle();

      expect(purchase.buyCount, 1);
      expect(app.isBoosted, isTrue);
      expect(app.capacityFor(TaskStatus.box), Limits.box + Limits.boostBonusBox);

      final reloaded = AppState(store: app.store, notifier: StubNotificationService());
      await reloaded.load();
      expect(reloaded.isBoosted, isTrue);
    });

    testWidgets('復元に成功してもブーストが付与される', (tester) async {
      final app = await newState();
      final purchase = FakePurchaseService(
        buyResult: const PurchaseResult(PurchaseOutcome.error),
        restoreResult: const PurchaseResult(
            PurchaseOutcome.restored, null, {PurchaseService.boostProductId}),
      );
      await pumpSheet(tester, app, purchase);

      await tester.tap(find.text('購入を復元'));
      await tester.pumpAndSettle();

      expect(purchase.restoreCount, 1);
      expect(app.isBoosted, isTrue);
    });

    testWidgets('Pro だけを復元してもブーストは付与されない', (tester) async {
      final app = await newState();
      final purchase = FakePurchaseService(
        buyResult: const PurchaseResult(PurchaseOutcome.error),
        restoreResult: const PurchaseResult(
            PurchaseOutcome.restored, null, {PurchaseService.proProductId}),
      );
      await pumpSheet(tester, app, purchase);

      await tester.tap(find.text('購入を復元'));
      await tester.pumpAndSettle();

      expect(app.isBoosted, isFalse, reason: '別商品の復元では付与しない');
    });

    testWidgets('中止するとブーストにならず、理由が表示される', (tester) async {
      final app = await newState();
      final purchase = FakePurchaseService(
          buyResult: const PurchaseResult(PurchaseOutcome.cancelled, '購入を中止しました'));
      await pumpSheet(tester, app, purchase);

      await tester.tap(find.text('¥100で購入'));
      await tester.pump();

      expect(app.isBoosted, isFalse);
      expect(find.text('購入を中止しました'), findsOneWidget);
      expect(find.text('¥100で購入'), findsOneWidget);
    });

    testWidgets('購入済みなら購入ボタンを出さない', (tester) async {
      final app = await newState();
      app.setBoost(true);
      final purchase = FakePurchaseService(
          buyResult: const PurchaseResult(PurchaseOutcome.purchased));
      await pumpSheet(tester, app, purchase);

      expect(find.text('¥100で購入'), findsNothing);
      expect(find.text('購入済み'), findsOneWidget);
    });
  });

  group('BOX 満杯ダイアログからの導線（UI）', () {
    Future<void> pumpFullBox(WidgetTester tester, AppState app) async {
      // 実効上限（ブースト購入済みなら広がっている）まで埋めて満杯にする。
      for (var i = 0; i < app.capacityFor(TaskStatus.box)!; i++) {
        app.addToBox('t$i');
      }
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
    }

    testWidgets('満杯だと警告に ¥100 ブーストの導線が出る', (tester) async {
      final app = await newState();
      await pumpFullBox(tester, app);

      expect(find.text('BOX、そろそろいっぱい'), findsOneWidget);
      expect(find.text('¥100で枠を増やす（+${Limits.boostBonusBox}）'), findsOneWidget);
      expect(find.text('Proで枠を増やす'), findsOneWidget);
    });

    testWidgets('ブースト購入済みなら ¥100 の導線は出ない', (tester) async {
      final app = await newState();
      app.setBoost(true);
      await pumpFullBox(tester, app);

      expect(find.text('BOX、そろそろいっぱい'), findsOneWidget);
      expect(find.text('¥100で枠を増やす（+${Limits.boostBonusBox}）'), findsNothing);
      expect(find.text('Proで枠を増やす'), findsOneWidget);
    });
  });
}
