import 'widget_service.dart';

/// Web（dart:io 不可）向けのファクトリ。home_widget を参照しない。
WidgetService createWidgetService() => const StubWidgetService();
