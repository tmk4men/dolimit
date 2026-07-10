// 課金（Pro 購入）の抽象。
//
// Web ビルドでは in_app_purchase（dart:io 依存）を除外する。
import 'purchase_factory_stub.dart'
    if (dart.library.io) 'purchase_factory_native.dart' as impl;

enum PurchaseOutcome { purchased, restored, unavailable, cancelled, error }

class PurchaseResult {
  final PurchaseOutcome outcome;
  final String? message;
  const PurchaseResult(this.outcome, [this.message]);

  bool get unlocked =>
      outcome == PurchaseOutcome.purchased || outcome == PurchaseOutcome.restored;
}

abstract class PurchaseService {
  /// ストアに登録する商品 ID（非消費型）。
  /// App Store Connect / Google Play Console 側でこの ID を作成する。
  static const String proProductId = 'dolimit_pro';

  /// 課金が利用可能か（ストア接続・商品取得可否）。
  Future<bool> isAvailable();

  /// Pro を購入する。
  Future<PurchaseResult> buyPro();

  /// 購入を復元する。
  Future<PurchaseResult> restore();

  /// 使い終わったらストリーム購読を解除する。
  void dispose();

  /// 環境に応じた実装を返す（Web=Stub / ネイティブ=Store）。
  static PurchaseService create() => impl.createPurchaseService();
}

/// 未接続環境（Web など）向けのスタブ。購入は行わず「準備中」を返す。
class StubPurchaseService implements PurchaseService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<PurchaseResult> buyPro() async =>
      const PurchaseResult(PurchaseOutcome.unavailable, '課金は準備中です');

  @override
  Future<PurchaseResult> restore() async =>
      const PurchaseResult(PurchaseOutcome.unavailable, '課金は準備中です');

  @override
  void dispose() {}
}
