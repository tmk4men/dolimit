import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:dolimit/services/purchase_service.dart';
import 'package:dolimit/services/store_purchase_service.dart';

/// StoreKit 2 の挙動を再現できる InAppPurchase の偽物。
///
/// ここで押さえたいのは、審査リジェクト(2.1(b))の原因になった経路:
/// - 商品取得が散発的に空を返す
/// - 購入開始が storekit2_failed_to_fetch_product で落ちる
/// - restored が pendingCompletePurchase=false で届く
class FakeIap implements InAppPurchase {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  /// 商品取得を空で返す残り回数（Sandbox の散発的な失敗の再現）。
  int emptyQueries = 0;
  int queryCount = 0;

  /// buyNonConsumable が投げる例外と、その残り回数。
  Object? buyThrows;
  int buyThrowTimes = 0;

  final List<String> bought = <String>[];
  final List<String> completed = <String>[];
  int restoreCount = 0;

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
      Set<String> identifiers) async {
    queryCount++;
    if (emptyQueries > 0) {
      emptyQueries--;
      // プラグインは例外ではなく「空リスト＋notFoundIDs」で返してくる。
      return ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: identifiers.toList());
    }
    return ProductDetailsResponse(
      productDetails: identifiers.map(_product).toList(),
      notFoundIDs: const <String>[],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    if (buyThrowTimes > 0) {
      buyThrowTimes--;
      throw buyThrows!;
    }
    bought.add(purchaseParam.productDetails.id);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.productID);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProductDetails _product(String id) => ProductDetails(
      id: id,
      title: id,
      description: id,
      price: '¥100',
      rawPrice: 100,
      currencyCode: 'JPY',
    );

PurchaseDetails _details(String id, PurchaseStatus status,
    {bool pendingComplete = false}) {
  final details = PurchaseDetails(
    purchaseID: '1',
    productID: id,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: '',
      source: 'app_store',
    ),
    transactionDate: null,
    status: status,
  );
  details.pendingCompletePurchase = pendingComplete;
  return details;
}

/// リトライのバックオフ（700ms * 試行回数）を跨いで待つ。
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 900));

void main() {
  test('商品取得が一度空でも、試し直して購入に進む', () async {
    // 審査で出た storekit2_failed_to_fetch_product と同じ根っこ。ここを一発勝負に
    // すると「商品が見つかりません」で終わり、購入のリトライまで届かない。
    final iap = FakeIap()..emptyQueries = 1;
    final service = StorePurchaseService(iap: iap, isStoreKit: true);
    addTearDown(service.dispose);

    final result = service.buyPro();
    await _settle();

    expect(iap.queryCount, 2, reason: '空の1回で諦めず引き直す');
    expect(iap.bought, <String>[PurchaseService.proProductId],
        reason: '取得できたら購入に進む');

    iap.emit([_details(PurchaseService.proProductId, PurchaseStatus.purchased)]);
    expect((await result).outcome, PurchaseOutcome.purchased);
  });

  test('storekit2_failed_to_fetch_product は試し直す', () async {
    final iap = FakeIap()
      ..buyThrows = PlatformException(
          code: 'storekit2_failed_to_fetch_product',
          message: 'Storekit has failed to fetch this product.')
      ..buyThrowTimes = 1;
    final service = StorePurchaseService(iap: iap, isStoreKit: true);
    addTearDown(service.dispose);

    final result = service.buyBoost();
    await _settle();

    expect(iap.bought, <String>[PurchaseService.boostProductId],
        reason: '1回落ちても諦めない（レビュアーが踏んだのはこれ）');

    iap.emit([_details(PurchaseService.boostProductId, PurchaseStatus.purchased)]);
    expect((await result).outcome, PurchaseOutcome.purchased);
  });

  test('ブーストのトランザクションが Pro の購入待ちを解決しない', () async {
    final iap = FakeIap();
    final service = StorePurchaseService(iap: iap, isStoreKit: true);
    addTearDown(service.dispose);
    final unlocked = <String>[];
    service.onUnlocked = unlocked.add;

    final pro = service.buyPro();
    var proSettled = false;
    unawaited(pro.then((_) => proSettled = true));
    await pumpEventQueue();

    // 前回セッションの残りのブーストが流れてくる。
    iap.emit([_details(PurchaseService.boostProductId, PurchaseStatus.purchased)]);
    await pumpEventQueue();

    expect(unlocked, <String>[PurchaseService.boostProductId],
        reason: 'ブースト自体は解放される');
    expect(proSettled, isFalse,
        reason: 'Pro の待ちを別商品の結果で解決してはいけない');

    iap.emit([_details(PurchaseService.proProductId, PurchaseStatus.purchased)]);
    final result = await pro;
    expect(result.outcome, PurchaseOutcome.purchased);
    expect(result.covers(PurchaseService.proProductId), isTrue);
  });

  test('restored も完了させる（SK2 は pendingCompletePurchase を false で返す）',
      () async {
    final iap = FakeIap();
    final service = StorePurchaseService(iap: iap, isStoreKit: true);
    addTearDown(service.dispose);
    final unlocked = <String>[];
    service.onUnlocked = unlocked.add;

    final restore = service.restore();
    await pumpEventQueue();
    iap.emit([
      _details(PurchaseService.proProductId, PurchaseStatus.restored,
          pendingComplete: false),
    ]);

    final result = await restore;
    expect(result.outcome, PurchaseOutcome.restored);
    expect(unlocked, <String>[PurchaseService.proProductId]);
    expect(iap.completed, <String>[PurchaseService.proProductId],
        reason: '完了させないと未完了が残り、以後この商品の購入が duplicate で弾かれる');
  });

  test('商品が本当に無いときは、試し直したうえで諦める', () async {
    final iap = FakeIap()..emptyQueries = 99;
    final service = StorePurchaseService(iap: iap, isStoreKit: true);
    addTearDown(service.dispose);

    final result = await service.buyPro();

    expect(result.outcome, PurchaseOutcome.unavailable);
    expect(iap.queryCount, 3, reason: '3回試して打ち切る（無限に粘らない）');
    expect(iap.bought, isEmpty);
  });
}
