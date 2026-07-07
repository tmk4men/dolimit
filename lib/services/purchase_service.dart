/// 課金（Pro 購入）の抽象。実際のストア購入は各プラットフォームの
/// in_app_purchase + ストア Console 設定で差し替える（現状はスタブ）。
enum PurchaseOutcome { purchased, restored, unavailable, cancelled, error }

class PurchaseResult {
  final PurchaseOutcome outcome;
  final String? message;
  const PurchaseResult(this.outcome, [this.message]);

  bool get unlocked =>
      outcome == PurchaseOutcome.purchased || outcome == PurchaseOutcome.restored;
}

abstract class PurchaseService {
  /// 課金が利用可能か（ストア接続・商品取得可否）。
  Future<bool> isAvailable();

  /// Pro を購入する。
  Future<PurchaseResult> buyPro();

  /// 購入を復元する。
  Future<PurchaseResult> restore();

  /// 現状はスタブ。実ストア接続時に差し替える。
  static PurchaseService create() => StubPurchaseService();
}

/// 未接続環境向けのスタブ。購入は行わず「準備中」を返す。
///
/// TODO(リリース): in_app_purchase を用いた実装に差し替える。
/// - InAppPurchase.instance.queryProductDetails({'dolimit_pro'})
/// - buyNonConsumable / purchaseStream の購読で完了検知 → AppState.setPro(true)
/// - restorePurchases() → 復元時も setPro(true)
class StubPurchaseService implements PurchaseService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<PurchaseResult> buyPro() async =>
      const PurchaseResult(PurchaseOutcome.unavailable, '課金は準備中です');

  @override
  Future<PurchaseResult> restore() async =>
      const PurchaseResult(PurchaseOutcome.unavailable, '課金は準備中です');
}
