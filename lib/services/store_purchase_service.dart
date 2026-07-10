import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_service.dart';

/// in_app_purchase による実際のストア購入（Android / iOS）。
///
/// ストア側の設定が必要:
/// - Google Play Console / App Store Connect で非消費型の商品
///   [PurchaseService.proProductId] を作成する
/// - Android は Play Billing、iOS は StoreKit が自動で組み込まれる
///
/// 購入結果は [InAppPurchase.purchaseStream] に非同期で流れてくるため、
/// buyPro / restore はその到着を待って結果を返す。
class StorePurchaseService implements PurchaseService {
  StorePurchaseService({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance {
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) =>
          _complete(PurchaseResult(PurchaseOutcome.error, '購入処理に失敗しました: $e')),
    );
  }

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 進行中の購入／復元。ストリームの到着で完了させる。
  Completer<PurchaseResult>? _pending;

  /// 支払いシートの操作を待つ上限。これを超えたら諦めて UI を戻す。
  static const Duration _purchaseTimeout = Duration(minutes: 10);

  /// 復元は端末とストアの往復だけなので短くてよい。
  static const Duration _restoreTimeout = Duration(seconds: 30);

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (e) {
      debugPrint('StorePurchaseService: isAvailable failed: $e');
      return false;
    }
  }

  @override
  Future<PurchaseResult> buyPro() async {
    if (_pending != null) {
      return const PurchaseResult(PurchaseOutcome.error, '処理中です');
    }
    if (!await isAvailable()) {
      return const PurchaseResult(PurchaseOutcome.unavailable, 'ストアに接続できません');
    }

    final ProductDetailsResponse response;
    try {
      response = await _iap.queryProductDetails({PurchaseService.proProductId});
    } catch (e) {
      return PurchaseResult(PurchaseOutcome.error, '商品情報を取得できません: $e');
    }
    if (response.error != null) {
      return PurchaseResult(
          PurchaseOutcome.error, '商品情報を取得できません: ${response.error!.message}');
    }
    if (response.productDetails.isEmpty) {
      return const PurchaseResult(
          PurchaseOutcome.unavailable, '商品が見つかりません。ストアの設定を確認してください。');
    }

    final completer = Completer<PurchaseResult>();
    _pending = completer;
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
      );
      if (!started) {
        _pending = null;
        return const PurchaseResult(PurchaseOutcome.error, '購入を開始できませんでした');
      }
    } catch (e) {
      _pending = null;
      return PurchaseResult(PurchaseOutcome.error, '購入を開始できませんでした: $e');
    }

    return _await(completer, _purchaseTimeout,
        const PurchaseResult(PurchaseOutcome.error, '購入がタイムアウトしました'));
  }

  @override
  Future<PurchaseResult> restore() async {
    if (_pending != null) {
      return const PurchaseResult(PurchaseOutcome.error, '処理中です');
    }
    if (!await isAvailable()) {
      return const PurchaseResult(PurchaseOutcome.unavailable, 'ストアに接続できません');
    }

    final completer = Completer<PurchaseResult>();
    _pending = completer;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _pending = null;
      return PurchaseResult(PurchaseOutcome.error, '復元に失敗しました: $e');
    }

    // 復元できる購入が無い場合、ストリームには何も流れてこない。
    // 待ち続けても仕方ないのでタイムアウトを「対象なし」として扱う。
    return _await(completer, _restoreTimeout,
        const PurchaseResult(PurchaseOutcome.unavailable, '復元できる購入がありません'));
  }

  Future<PurchaseResult> _await(Completer<PurchaseResult> completer,
      Duration timeout, PurchaseResult onTimeout) {
    return completer.future.timeout(timeout, onTimeout: () {
      _pending = null;
      return onTimeout;
    });
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != PurchaseService.proProductId) continue;

      // pending は「支払いシート表示中」。まだ何も決まっていない。
      if (p.status == PurchaseStatus.pending) continue;

      // 完了を通知しないと、同じ購入が起動のたびに再送され続ける。
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          debugPrint('StorePurchaseService: completePurchase failed: $e');
        }
      }

      _complete(switch (p.status) {
        PurchaseStatus.purchased => const PurchaseResult(PurchaseOutcome.purchased),
        PurchaseStatus.restored => const PurchaseResult(PurchaseOutcome.restored),
        PurchaseStatus.canceled => const PurchaseResult(PurchaseOutcome.cancelled, '購入を中止しました'),
        PurchaseStatus.error => PurchaseResult(
            PurchaseOutcome.error, p.error?.message ?? '購入に失敗しました'),
        PurchaseStatus.pending => const PurchaseResult(PurchaseOutcome.error, '不正な状態です'),
      });
    }
  }

  void _complete(PurchaseResult result) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(result);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
