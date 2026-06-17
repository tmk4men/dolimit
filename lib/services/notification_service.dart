import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';

/// 通知・バッジの抽象。広告は一切出さない。
///
/// Web デモでは [StubNotificationService]（no-op）を使う。
/// Android/iOS リリース時に flutter_local_notifications / flutter_app_badger を用いた
/// 実装に差し替える（TODO 参照）。
abstract class NotificationService {
  Future<bool> requestPermission();
  Future<void> rescheduleDailyReminders(AppSettings settings);
  Future<void> scheduleLaterReminder({required String taskId, required String title, required DateTime at});
  Future<void> cancelLaterReminder(String taskId);
  Future<void> notifyMovedToToday(String title);
  Future<void> notifyTodayFull(String title);
  Future<void> notifyBanishedToLater(String title);

  /// アプリアイコンバッジ = TODAY 未完了数（0 で非表示）
  Future<void> applyBadge(int todayUnfinished, {required bool enabled});

  /// 環境に応じた実装を返す
  static NotificationService create() {
    // TODO: !kIsWeb のとき NativeNotificationService() を返す（Android/iOS）
    if (kIsWeb) return StubNotificationService();
    return StubNotificationService();
  }
}

/// Web / 未実装環境向けの no-op 実装
class StubNotificationService implements NotificationService {
  @override
  Future<bool> requestPermission() async {
    // Web デモでは常に許可済み扱い（実通知は出さない）
    return true;
  }

  @override
  Future<void> rescheduleDailyReminders(AppSettings settings) async {}

  @override
  Future<void> scheduleLaterReminder({required String taskId, required String title, required DateTime at}) async {}

  @override
  Future<void> cancelLaterReminder(String taskId) async {}

  @override
  Future<void> notifyMovedToToday(String title) async {}

  @override
  Future<void> notifyTodayFull(String title) async {}

  @override
  Future<void> notifyBanishedToLater(String title) async {}

  @override
  Future<void> applyBadge(int todayUnfinished, {required bool enabled}) async {}
}

/* =============================================================
TODO（Android/iOS リリース時）: 実装例

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

class NativeNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  // initialize(), zonedSchedule() で朝/日中/夜の精算を毎日通知、
  // LATER 開始前通知・自動移動/自動追放の即時通知を実装。
  // applyBadge() は FlutterAppBadger.updateBadgeCount / removeBadge。
}
============================================================= */
