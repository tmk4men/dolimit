import 'dart:async';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_settings.dart';
import 'notification_route.dart';
import 'notification_service.dart';

/// Android / iOS 向けの通知・バッジ実装。
///
/// - 毎日の定時リマインド（朝・日中・夜の精算）
/// - LATER 開始前のワンショット通知
/// - 自動移動 / 満杯 / 自動追放の即時通知
/// - アプリアイコンバッジ（TODAY 未完了数）
class NativeNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  final StreamController<String> _taps = StreamController<String>.broadcast();

  @override
  Stream<String> get taps => _taps.stream;

  // 固定 ID（毎日のリマインドは reschedule で貼り替えるため固定）
  static const int _idMorning = 1;
  static const int _idMidday = 2;
  static const int _idSettlement = 3;

  // 即時通知は [1000, 91000) を使う。LATER 予約通知（100000 以上）と
  // 範囲が重ならないようにして、予約を上書きしないようにする。
  static const int _idInstantBase = 1000;
  static const int _idInstantSpan = 90000;
  int _instantSeq = 0;

  // LATER リマインドは taskId から安定した正の ID を導出する
  int _laterId(String taskId) => 100000 + (taskId.hashCode & 0x3fffffff);

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'dolimit_main',
    'DoLimit リマインド',
    channelDescription: '今日やる枠のリマインドと自動処理のお知らせ',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('NativeNotificationService: local timezone fallback: $e');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      // 権限は requestPermission() で明示的に要求する
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _taps.add(payload);
      },
    );
    _ready = true;
  }

  @override
  Future<String?> initialTapPayload() async {
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  /// テストや hot restart 用。通常は破棄しない。
  void dispose() => _taps.close();

  @override
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? true;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  @override
  Future<void> rescheduleDailyReminders(AppSettings settings) async {
    await init();
    // まず定時リマインドを全キャンセル
    await _plugin.cancel(_idMorning);
    await _plugin.cancel(_idMidday);
    await _plugin.cancel(_idSettlement);
    if (!settings.notificationsEnabled) return;

    await _scheduleDaily(_idMorning, settings.morning.hour,
        settings.morning.minute, '今日やることを確認しましょう',
        'BOX と TODAY を見返して、今日の一手を決めましょう。',
        NotificationPayload.box);
    await _scheduleDaily(_idMidday, settings.midday.hour,
        settings.midday.minute, 'TODAY の進み具合は？',
        '午後です。残りの TODAY を片付けていきましょう。',
        NotificationPayload.today);
    await _scheduleDaily(_idSettlement, settings.settlement.hour,
        settings.settlement.minute, '今日の精算をしましょう',
        '未完了の TODAY を「明日も／LATER／完了／削除」で精算します。',
        NotificationPayload.settlement);
  }

  Future<void> _scheduleDaily(int id, int hour, int minute, String title,
      String body, String payload) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOf(hour, minute),
      _details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // 毎日同時刻に繰り返す
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  @override
  Future<void> scheduleLaterReminder(
      {required String taskId,
      required String title,
      required DateTime at}) async {
    await init();
    final id = _laterId(taskId);
    await _plugin.cancel(id);
    final when = tz.TZDateTime.from(at, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return; // 過去は予約しない
    await _plugin.zonedSchedule(
      id,
      'まもなく開始: $title',
      'LATER のタスクの開始時刻が近づいています。',
      when,
      _details,
      payload: NotificationPayload.task(taskId),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelLaterReminder(String taskId) async {
    await init();
    await _plugin.cancel(_laterId(taskId));
  }

  @override
  Future<void> notifyMovedToToday(String title) => _showInstant(
      'TODAY へ移動しました', '「$title」を TODAY に移しました。', NotificationPayload.today);

  @override
  Future<void> notifyTodayFull(String title) => _showInstant('TODAY が満杯です',
      '「$title」を移動できません。TODAY を整理してください。', NotificationPayload.today);

  @override
  Future<void> notifyBanishedToLater(String title) => _showInstant(
      'LATER へ戻しました',
      '「$title」は3日連続で未完了のため LATER に戻しました。',
      NotificationPayload.later);

  Future<void> _showInstant(String title, String body, String payload) async {
    await init();
    // ワンショット。連番を回して直近の通知どうしの衝突だけ避ける。
    final id = _idInstantBase + (_instantSeq++ % _idInstantSpan);
    await _plugin.show(id, title, body, _details, payload: payload);
  }

  @override
  Future<void> applyBadge(int todayUnfinished, {required bool enabled}) async {
    try {
      if (!await AppBadgePlus.isSupported()) return;
      // count 0 でバッジ非表示
      final count = (!enabled || todayUnfinished < 0) ? 0 : todayUnfinished;
      await AppBadgePlus.updateBadge(count);
    } catch (e) {
      debugPrint('NativeNotificationService: badge unsupported: $e');
    }
  }
}
