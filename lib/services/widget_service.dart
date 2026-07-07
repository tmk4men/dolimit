// ホーム画面ウィジェットへのデータ供給。表示自体はネイティブ実装が担う。
//
// Web ビルドでは home_widget（dart:io 依存）を除外する。
import 'widget_factory_stub.dart'
    if (dart.library.io) 'widget_factory_native.dart' as impl;

/// ホーム画面ウィジェットに「TODAY 未完了数」と「上位タスク名」を渡す。
///
/// - Web / 未対応環境では [StubWidgetService]（no-op）
/// - Android/iOS では `NativeWidgetService`（home_widget）
abstract class WidgetService {
  /// iOS の App Group 設定など。起動時に一度呼ぶ。
  Future<void> init();

  /// ウィジェットの表示内容を更新する。
  Future<void> update({required int todayCount, required List<String> topTitles});

  static WidgetService create() => impl.createWidgetService();
}

/// Web / 未対応環境向けの no-op 実装
class StubWidgetService implements WidgetService {
  const StubWidgetService();

  @override
  Future<void> init() async {}

  @override
  Future<void> update({required int todayCount, required List<String> topTitles}) async {}
}
