import 'notification_service.dart';
import 'native_notification_service.dart';

/// Android/iOS/デスクトップ向けのファクトリ。
NotificationService createNotificationService() => NativeNotificationService();
