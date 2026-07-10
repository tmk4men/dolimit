import 'purchase_service.dart';
import 'store_purchase_service.dart';

/// Android/iOS 向けのファクトリ。
PurchaseService createPurchaseService() => StorePurchaseService();
