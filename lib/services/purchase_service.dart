// 課金（Pro 購入）の抽象。
//
// Web ビルドでは in_app_purchase（dart:io 依存）を除外する。
import 'purchase_factory_stub.dart'
    if (dart.library.io) 'purchase_factory_native.dart' as impl;

enum PurchaseOutcome { purchased, restored, unavailable, cancelled, error }

class PurchaseResult {
  final PurchaseOutcome outcome;
  final String? message;

  /// この結果に関わる商品 ID の集合。購入なら 1 件、復元なら復元された全件。
  /// 空のときは「どの商品かを問わない」（テスト・スタブ用）扱いにする。
  final Set<String> products;

  const PurchaseResult(this.outcome, [this.message, this.products = const {}]);

  bool get unlocked =>
      outcome == PurchaseOutcome.purchased || outcome == PurchaseOutcome.restored;

  /// この結果が [productId] に当てはまるか。products が空なら常に当てはまる。
  bool covers(String productId) =>
      products.isEmpty || products.contains(productId);
}

abstract class PurchaseService {
  /// ストアに登録する商品 ID（いずれも非消費型）。
  /// App Store Connect / Google Play Console 側でこの ID を作成する。
  static const String proProductId = 'dolimit_pro';

  /// ブースト（¥100 の買い切り。BOX/TODAY/LATER の枠を恒久的に少し広げる）。
  static const String boostProductId = 'dolimit_boost';

  /// アプリ起動時に一度呼ぶ。ストア接続を温め、商品情報を事前取得し、
  /// 前回セッションで中断した未処理トランザクションを処理できる状態にする。
  /// これを起動時に済ませておくことで「開いて即購入」でのラグ・失敗を防ぐ。
  Future<void> init();

  /// 購入／復元で商品が解放されたとき（起動時に届く中断トランザクション含む）に
  /// 呼ばれるハンドラ。購入シートが閉じていても確実に権利を付与するために使う。
  set onUnlocked(void Function(String productId)? handler);

  /// 課金が利用可能か（ストア接続・商品取得可否）。
  Future<bool> isAvailable();

  /// 商品のローカライズ価格文字列（例: "¥100"）。取得できなければ null。
  Future<String?> priceOf(String productId);

  /// Pro を購入する。
  Future<PurchaseResult> buyPro();

  /// ブースト（¥100）を購入する。
  Future<PurchaseResult> buyBoost();

  /// 購入を復元する（Pro・ブーストの両方が対象）。
  Future<PurchaseResult> restore();

  /// 使い終わったらストリーム購読を解除する。
  void dispose();

  /// 環境に応じた実装を返す（Web=Stub / ネイティブ=Store）。
  static PurchaseService create() => impl.createPurchaseService();
}

/// 未接続環境（Web など）向けのスタブ。購入は行わず「準備中」を返す。
class StubPurchaseService implements PurchaseService {
  @override
  Future<void> init() async {}

  @override
  set onUnlocked(void Function(String productId)? handler) {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> priceOf(String productId) async => null;

  @override
  Future<PurchaseResult> buyPro() async =>
      const PurchaseResult(PurchaseOutcome.unavailable, '課金は準備中です');

  @override
  Future<PurchaseResult> buyBoost() async =>
      const PurchaseResult(PurchaseOutcome.unavailable, '課金は準備中です');

  @override
  Future<PurchaseResult> restore() async =>
      const PurchaseResult(PurchaseOutcome.unavailable, '課金は準備中です');

  @override
  void dispose() {}
}
