import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'notification_route.dart';
import 'widget_service.dart';

/// home_widget を使ってホーム画面ウィジェットへデータを渡す。
///
/// ネイティブ側（Android: AppWidgetProvider / iOS: WidgetKit）は
/// `native_widget_reference/` の参考実装を各プラットフォームに組み込む必要がある。
class NativeWidgetService implements WidgetService {
  // iOS の App Group（WidgetKit と共有）。実際の値に合わせて変更する。
  static const String _iosAppGroupId = 'group.dolimit.widget';
  // ネイティブ側のウィジェット名（プロバイダ/ウィジェットの識別子）。
  static const String _androidProvider = 'DoLimitWidgetProvider';
  static const String _iosWidget = 'DoLimitWidget';

  // 共有データのキー（ネイティブ側と一致させる）。
  static const String _keyCount = 'today_count';
  static const String _keyTitles = 'today_titles';
  static const String _keyUpdatedAt = 'updated_at';

  final StreamController<String> _taps = StreamController<String>.broadcast();
  StreamSubscription<Uri?>? _clicks;

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_iosAppGroupId);
    } catch (e) {
      debugPrint('NativeWidgetService: setAppGroupId failed: $e');
    }
    try {
      // ウィジェットのタップ（アプリが生きている間）。
      _clicks = HomeWidget.widgetClicked.listen((uri) {
        final payload = _payloadFrom(uri);
        if (payload != null) _taps.add(payload);
      });
    } catch (e) {
      debugPrint('NativeWidgetService: widgetClicked listen failed: $e');
    }
  }

  @override
  Future<String?> initialTapPayload() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      return _payloadFrom(uri);
    } catch (e) {
      debugPrint('NativeWidgetService: initiallyLaunchedFromHomeWidget failed: $e');
      return null;
    }
  }

  /// ネイティブ側は `dolimit://today` のような URI を投げてくる。
  /// host が無い形（`dolimit:today`）も拾えるよう path も見る。
  static String? _payloadFrom(Uri? uri) {
    if (uri == null) return null;
    final host = uri.host;
    if (host.isNotEmpty) return host;
    final path = uri.path.replaceAll('/', '');
    if (path.isNotEmpty) return path;
    // 引数が無いタップは TODAY を開く（ウィジェットは TODAY を映すため）。
    return NotificationPayload.today;
  }

  void dispose() {
    _clicks?.cancel();
    _taps.close();
  }

  @override
  Future<void> update(
      {required int todayCount, required List<String> topTitles}) async {
    try {
      await HomeWidget.saveWidgetData<int>(_keyCount, todayCount);
      await HomeWidget.saveWidgetData<String>(_keyTitles, topTitles.join('\n'));
      await HomeWidget.saveWidgetData<String>(
          _keyUpdatedAt, DateTime.now().toIso8601String());
      await HomeWidget.updateWidget(
        name: _androidProvider,
        androidName: _androidProvider,
        iOSName: _iosWidget,
      );
    } catch (e) {
      debugPrint('NativeWidgetService: update failed: $e');
    }
  }
}
