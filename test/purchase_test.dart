import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/services/purchase_service.dart';
import 'package:dolimit/state/app_state.dart';
import 'package:dolimit/util/limits.dart';
import 'package:dolimit/widgets/pro_sheet.dart';

/// 任意の結果を返す課金スタブ。
class FakePurchaseService implements PurchaseService {
  FakePurchaseService({required this.buyResult, PurchaseResult? restoreResult})
      : restoreResult =
            restoreResult ?? const PurchaseResult(PurchaseOutcome.unavailable, '復元できる購入がありません');

  final PurchaseResult buyResult;
  final PurchaseResult restoreResult;
  int buyCount = 0;
  int restoreCount = 0;
  int disposeCount = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<PurchaseResult> buyPro() async {
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

  Future<void> pumpSheet(
      WidgetTester tester, AppState app, FakePurchaseService purchase) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(home: Scaffold(body: ProSheet(service: purchase))),
    ));
    await tester.pump();
  }

  group('PurchaseResult', () {
    test('purchased と restored だけが解除扱い', () {
      expect(const PurchaseResult(PurchaseOutcome.purchased).unlocked, isTrue);
      expect(const PurchaseResult(PurchaseOutcome.restored).unlocked, isTrue);
      expect(const PurchaseResult(PurchaseOutcome.cancelled).unlocked, isFalse);
      expect(const PurchaseResult(PurchaseOutcome.unavailable).unlocked, isFalse);
      expect(const PurchaseResult(PurchaseOutcome.error).unlocked, isFalse);
    });
  });

  group('Pro シート', () {
    testWidgets('購入に成功すると Pro が解除され永続化される', (tester) async {
      final app = await newState();
      final purchase =
          FakePurchaseService(buyResult: const PurchaseResult(PurchaseOutcome.purchased));
      await pumpSheet(tester, app, purchase);

      expect(app.isPro, isFalse);
      expect(app.capacityFor(TaskStatus.box), Limits.box);

      await tester.tap(find.text('Proを購入'));
      await tester.pumpAndSettle();

      expect(purchase.buyCount, 1);
      expect(app.isPro, isTrue);
      expect(app.capacityFor(TaskStatus.box), Limits.box + Limits.proBonusBox);
      expect(app.genreCap, Limits.genre + Limits.proBonusGenre);

      // 保存されているので読み直しても Pro のまま。
      final reloaded = AppState(store: app.store, notifier: StubNotificationService());
      await reloaded.load();
      expect(reloaded.isPro, isTrue);
    });

    testWidgets('復元に成功しても Pro が解除される', (tester) async {
      final app = await newState();
      final purchase = FakePurchaseService(
        buyResult: const PurchaseResult(PurchaseOutcome.error),
        restoreResult: const PurchaseResult(PurchaseOutcome.restored),
      );
      await pumpSheet(tester, app, purchase);

      await tester.tap(find.text('購入を復元'));
      await tester.pumpAndSettle();

      expect(purchase.restoreCount, 1);
      expect(app.isPro, isTrue);
    });

    testWidgets('中止すると Pro にならず、理由が表示される', (tester) async {
      final app = await newState();
      final purchase = FakePurchaseService(
          buyResult: const PurchaseResult(PurchaseOutcome.cancelled, '購入を中止しました'));
      await pumpSheet(tester, app, purchase);

      await tester.tap(find.text('Proを購入'));
      await tester.pump();

      expect(app.isPro, isFalse);
      expect(find.text('購入を中止しました'), findsOneWidget);
      // ボタンは再び押せる状態に戻る。
      expect(find.text('Proを購入'), findsOneWidget);
    });

    testWidgets('ストア未接続なら理由を出して Pro にしない', (tester) async {
      final app = await newState();
      final purchase = FakePurchaseService(
          buyResult: const PurchaseResult(PurchaseOutcome.unavailable, 'ストアに接続できません'));
      await pumpSheet(tester, app, purchase);

      await tester.tap(find.text('Proを購入'));
      await tester.pump();

      expect(app.isPro, isFalse);
      expect(find.text('ストアに接続できません'), findsOneWidget);
    });

    testWidgets('復元対象が無ければ理由を出す', (tester) async {
      final app = await newState();
      final purchase =
          FakePurchaseService(buyResult: const PurchaseResult(PurchaseOutcome.error));
      await pumpSheet(tester, app, purchase);

      await tester.tap(find.text('購入を復元'));
      await tester.pump();

      expect(app.isPro, isFalse);
      expect(find.text('復元できる購入がありません'), findsOneWidget);
    });

    testWidgets('Pro 解除済みなら購入ボタンを出さない', (tester) async {
      final app = await newState();
      app.setPro(true);
      final purchase =
          FakePurchaseService(buyResult: const PurchaseResult(PurchaseOutcome.purchased));
      await pumpSheet(tester, app, purchase);

      expect(find.text('Proを購入'), findsNothing);
      expect(find.text('解除済み'), findsOneWidget);
    });

    testWidgets('注入した実装は ProSheet が破棄しない', (tester) async {
      final app = await newState();
      final purchase =
          FakePurchaseService(buyResult: const PurchaseResult(PurchaseOutcome.purchased));
      await pumpSheet(tester, app, purchase);

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      expect(purchase.disposeCount, 0, reason: '所有していないものは破棄しない');
    });
  });

  group('スタブ実装（Web / 未接続）', () {
    test('常に「準備中」を返し、解除しない', () async {
      final stub = StubPurchaseService();
      expect(await stub.isAvailable(), isFalse);

      final buy = await stub.buyPro();
      expect(buy.unlocked, isFalse);
      expect(buy.message, '課金は準備中です');

      final restore = await stub.restore();
      expect(restore.unlocked, isFalse);
    });
  });
}
