import 'purchase_service.dart';

/// Web（dart:io 不可）向けのファクトリ。in_app_purchase を参照しない。
PurchaseService createPurchaseService() => StubPurchaseService();
