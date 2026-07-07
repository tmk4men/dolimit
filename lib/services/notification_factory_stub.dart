import 'notification_service.dart';

/// Web（dart:io 不可）向けのファクトリ。ネイティブプラグインを一切参照しない。
NotificationService createNotificationService() => StubNotificationService();
