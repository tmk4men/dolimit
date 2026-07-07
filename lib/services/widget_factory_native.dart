import 'widget_service.dart';
import 'native_widget_service.dart';

/// Android/iOS 向けのファクトリ。
WidgetService createWidgetService() => NativeWidgetService();
