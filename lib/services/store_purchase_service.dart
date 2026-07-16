import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import 'purchase_service.dart';

/// in_app_purchase による実際のストア購入（Android / iOS）。
///
/// ストア側の設定が必要:
/// - Google Play Console / App Store Connect で非消費型の商品
///   [PurchaseService.proProductId] を作成する
/// - Android は Play Billing、iOS は StoreKit が自動で組み込まれる
///
/// **iOS は StoreKit 2 で動く**（in_app_purchase_storekit 0.4.10 の既定）。
/// SK1 と挙動が違い、以下の設計はその差から来ている:
/// - 未処理トランザクションは購読開始時に流れて**こない**。起動時に
///   [SK2Transaction.unfinishedTransactions] で自分で回収する必要がある。
/// - `restored` の `pendingCompletePurchase` は常に false。これを信じると
///   復元分が永久に完了せず、以後その商品の購入が duplicate 扱いで弾かれる。
/// - 購入のたびにネイティブ側が商品を取り直す。こちらが渡した ProductDetails は
///   使われないので、事前キャッシュは購入の失敗を防いでくれない。
///
/// 購入結果は [InAppPurchase.purchaseStream] に非同期で流れてくるため、
/// buyPro / restore はその到着を待って結果を返す。
class StorePurchaseService implements PurchaseService {
  StorePurchaseService({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance {
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) => _failAll('購入処理に失敗しました: $e'),
    );
  }

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 進行中の購入。商品 ID ごとに持つ。1 本の Completer を共有すると、別商品の
  /// トランザクション（前回セッションの残りなど）が届いたときに、無関係な購入の
  /// 待ちをその結果で解決してしまう。
  final Map<String, Completer<PurchaseResult>> _buys = {};

  /// 進行中の復元。復元は商品を指定しないので 1 本でよい。
  Completer<PurchaseResult>? _restore;

  /// 商品情報のキャッシュ（価格表示用）。
  ///
  /// 購入の成否には効かない: iOS(SK2) はネイティブ側で商品を取り直すため。
  final Map<String, ProductDetails> _products = {};

  /// 購入／復元で商品が解放されたときのハンドラ（起動時の回収分含む）。
  void Function(String productId)? _onUnlocked;

  @override
  set onUnlocked(void Function(String productId)? handler) =>
      _onUnlocked = handler;

  /// 支払いシートの操作を待つ上限。これを超えたら諦めて UI を戻す。
  static const Duration _purchaseTimeout = Duration(minutes: 10);

  /// 復元は端末とストアの往復だけなので短くてよい。
  static const Duration _restoreTimeout = Duration(seconds: 30);

  /// ストアへの問い合わせの上限。起動や UI を無限に引っ張らせない。
  static const Duration _storeTimeout = Duration(seconds: 10);

  /// 支払い開始の試行回数（Sandbox の商品取得は散発的に失敗する）。
  static const int _buyAttempts = 3;

  static const Duration _retryBackoff = Duration(milliseconds: 700);

  static const Set<String> _knownProducts = {
    PurchaseService.proProductId,
    PurchaseService.boostProductId,
  };

  @override
  Future<void> init() async {
    try {
      if (await _iap.isAvailable().timeout(_storeTimeout)) {
        final resp = await _iap
            .queryProductDetails(_knownProducts)
            .timeout(_storeTimeout);
        for (final p in resp.productDetails) {
          _products[p.id] = p;
        }
      }
    } catch (e) {
      debugPrint('StorePurchaseService: init failed: $e');
    }
    // 中断した購入の回収。SK2 では purchaseStream に流れてこないので明示的に引く。
    // これを怠ると「課金したのに解放されない」まま未完了が残り続け、以後その商品の
    // 購入が毎回 duplicate で弾かれる（アカウント単位なので再インストールでも直らない）。
    await _drainUnfinished();
  }

  /// 未完了トランザクションを権利付与して完了させる。完了させた件数を返す。
  /// iOS(StoreKit 2) 専用。Android は Play Billing 側が再送するので何もしない。
  Future<int> _drainUnfinished() async {
    if (!Platform.isIOS) return 0;
    try {
      final txs =
          await SK2Transaction.unfinishedTransactions().timeout(_storeTimeout);
      var finished = 0;
      for (final t in txs) {
        if (!_knownProducts.contains(t.productId)) continue;
        // 先に権利を付与する。finish が失敗しても解放は守る。
        _onUnlocked?.call(t.productId);
        try {
          await SK2Transaction.finish(int.parse(t.id));
          finished++;
        } catch (e) {
          debugPrint('StorePurchaseService: finish failed (${t.productId}): $e');
        }
      }
      if (finished > 0) {
        debugPrint('StorePurchaseService: drained $finished unfinished tx');
      }
      return finished;
    } catch (e) {
      debugPrint('StorePurchaseService: unfinishedTransactions failed: $e');
      return 0;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable().timeout(_storeTimeout);
    } catch (e) {
      debugPrint('StorePurchaseService: isAvailable failed: $e');
      return false;
    }
  }

  @override
  Future<String?> priceOf(String productId) async {
    final cached = _products[productId];
    if (cached != null) return cached.price;
    if (!await isAvailable()) return null;
    final product = await _resolve(productId);
    return product?.price; // ストアのローカライズ価格
  }

  @override
  Future<PurchaseResult> buyPro() => _buy(PurchaseService.proProductId);

  @override
  Future<PurchaseResult> buyBoost() => _buy(PurchaseService.boostProductId);

  Future<PurchaseResult> _buy(String productId) async {
    if (_buys.containsKey(productId) || _restore != null) {
      return const PurchaseResult(PurchaseOutcome.error, '処理中です');
    }

    final product = await _resolve(productId);
    if (product == null) {
      if (!await isAvailable()) {
        return const PurchaseResult(
            PurchaseOutcome.unavailable, 'ストアに接続できません');
      }
      return const PurchaseResult(
          PurchaseOutcome.unavailable, '商品が見つかりません。ストアの設定を確認してください。');
    }

    final completer = Completer<PurchaseResult>();
    _buys[productId] = completer;

    final failure = await _start(product, productId);
    if (failure != null) {
      _buys.remove(productId);
      return failure;
    }

    return completer.future.timeout(_purchaseTimeout, onTimeout: () {
      _buys.remove(productId);
      return const PurchaseResult(PurchaseOutcome.error, '購入がタイムアウトしました');
    });
  }

  /// 商品情報を返す（キャッシュ優先、無ければ取得）。取れなければ null。
  Future<ProductDetails?> _resolve(String productId) async {
    final cached = _products[productId];
    if (cached != null) return cached;
    try {
      final resp =
          await _iap.queryProductDetails({productId}).timeout(_storeTimeout);
      if (resp.productDetails.isEmpty) {
        debugPrint('StorePurchaseService: $productId not found '
            '(error=${resp.error?.message}, notFound=${resp.notFoundIDs})');
        return null;
      }
      final product = resp.productDetails.first;
      _products[productId] = product;
      return product;
    } catch (e) {
      debugPrint('StorePurchaseService: queryProductDetails failed: $e');
      return null;
    }
  }

  /// 支払いを開始する。失敗したときだけ [PurchaseResult] を返す（成功時は null）。
  ///
  /// iOS(SK2) はここで渡した [product] を使わず、ネイティブ側が商品 ID で取り直す。
  /// Sandbox ではこの取得が散発的に失敗する（storekit2_failed_to_fetch_product）ので、
  /// 一度で諦めずに間を置いて試し直す。事前キャッシュではこの経路は守れない。
  Future<PurchaseResult?> _start(
      ProductDetails product, String productId) async {
    for (var attempt = 1;; attempt++) {
      try {
        final started = await _iap.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: product),
        );
        if (started) return null;
        if (attempt >= _buyAttempts) {
          return const PurchaseResult(PurchaseOutcome.error, '購入を開始できませんでした');
        }
      } on PlatformException catch (e) {
        // 同じ商品の未完了トランザクションが残っていると、支払いシートを出す前に
        // 弾かれる。掃除できたなら、それが原因なので即やり直す。
        if (e.code == 'storekit_duplicate_product_object') {
          final drained = await _drainUnfinished();
          if (drained > 0 && attempt < _buyAttempts) continue;
          return PurchaseResult(
              PurchaseOutcome.error, '購入を開始できませんでした: ${e.message ?? e.code}');
        }
        final retryable = e.code == 'storekit2_failed_to_fetch_product' ||
            e.code == 'storekit2_products_error';
        if (!retryable || attempt >= _buyAttempts) {
          return PurchaseResult(
              PurchaseOutcome.error, '購入を開始できませんでした: ${e.message ?? e.code}');
        }
        debugPrint('StorePurchaseService: retry $attempt after ${e.code}');
      } catch (e) {
        return PurchaseResult(PurchaseOutcome.error, '購入を開始できませんでした: $e');
      }
      await Future<void>.delayed(_retryBackoff * attempt);
    }
  }

  @override
  Future<PurchaseResult> restore() async {
    if (_restore != null || _buys.isNotEmpty) {
      return const PurchaseResult(PurchaseOutcome.error, '処理中です');
    }
    if (!await isAvailable()) {
      return const PurchaseResult(PurchaseOutcome.unavailable, 'ストアに接続できません');
    }

    final completer = Completer<PurchaseResult>();
    _restore = completer;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _restore = null;
      return PurchaseResult(PurchaseOutcome.error, '復元に失敗しました: $e');
    }

    // 復元できる購入が無い場合、ストリームには何も流れてこない。
    // 待ち続けても仕方ないのでタイムアウトを「対象なし」として扱う。
    return completer.future.timeout(_restoreTimeout, onTimeout: () {
      _restore = null;
      return const PurchaseResult(PurchaseOutcome.unavailable, '復元できる購入がありません');
    });
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    // 復元は 1 回の更新で複数商品がまとめて届きうるので、集めて 1 度に返す。
    final restored = <String>{};

    for (final p in purchases) {
      if (!_knownProducts.contains(p.productID)) continue;

      // pending は「支払いシート表示中」。まだ何も決まっていない。
      if (p.status == PurchaseStatus.pending) continue;

      // 完了を通知しないとトランザクションが残り続け、以後この商品の購入が
      // duplicate 扱いで弾かれる。SK2 は restored の pendingCompletePurchase を
      // 常に false で返してくるので、そこを信じず状態から判断する。
      final needsFinish = p.pendingCompletePurchase ||
          (Platform.isIOS &&
              (p.status == PurchaseStatus.purchased ||
                  p.status == PurchaseStatus.restored));
      if (needsFinish) {
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          debugPrint('StorePurchaseService: completePurchase failed: $e');
        }
      }

      switch (p.status) {
        case PurchaseStatus.purchased:
          // シートが閉じていても確実に権利を付与する（中断復帰にも効く）。
          _onUnlocked?.call(p.productID);
          _settle(p.productID,
              PurchaseResult(PurchaseOutcome.purchased, null, {p.productID}));
        case PurchaseStatus.restored:
          restored.add(p.productID);
        case PurchaseStatus.canceled:
          _settle(p.productID,
              const PurchaseResult(PurchaseOutcome.cancelled, '購入を中止しました'));
        case PurchaseStatus.error:
          _settle(
              p.productID,
              PurchaseResult(
                  PurchaseOutcome.error, p.error?.message ?? '購入に失敗しました'));
        case PurchaseStatus.pending:
          break;
      }
    }

    if (restored.isNotEmpty) {
      for (final id in restored) {
        _onUnlocked?.call(id);
      }
      final pending = _restore;
      _restore = null;
      if (pending != null && !pending.isCompleted) {
        // メッセージを入れておく。復元した商品がシートの対象外だったとき、
        // UI 側のフォールバック（'購入できませんでした'）が出るのを防ぐ。
        pending.complete(
            PurchaseResult(PurchaseOutcome.restored, '購入を復元しました', restored));
      }
    }
  }

  /// [productId] の購入待ちを解決する。他の商品の待ちには触れない。
  void _settle(String productId, PurchaseResult result) {
    final pending = _buys.remove(productId);
    if (pending != null && !pending.isCompleted) pending.complete(result);
  }

  /// ストリーム自体が壊れたとき。進行中の待ちを全部返して UI を戻す。
  void _failAll(String message) {
    final result = PurchaseResult(PurchaseOutcome.error, message);
    for (final pending in _buys.values.toList()) {
      if (!pending.isCompleted) pending.complete(result);
    }
    _buys.clear();
    final restore = _restore;
    _restore = null;
    if (restore != null && !restore.isCompleted) restore.complete(result);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
