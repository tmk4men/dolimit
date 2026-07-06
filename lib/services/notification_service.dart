import '../models/app_settings.dart';

// Web ビルドではネイティブプラグイン（dart:io 依存）をコンパイル対象から除外する。
// dart.library.io は Android/iOS/デスクトップで true、Web で false。
import 'notification_factory_stub.dart'
    if (dart.library.io) 'notification_factory_native.dart' as impl;

/// 通知・バッジの抽象。広告は一切出さない。
///
/// Web デモでは [StubNotificationService]（no-op）、
/// Android/iOS では `NativeNotificationService`（flutter_local_notifications /
/// flutter_app_badger）を使う。実装の選択は条件付きインポートで行う。
abstract class NotificationService {
  /// プラグイン初期化・タイムゾーン設定など。起動時に一度呼ぶ。
  Future<void> init();

  Future<bool> requestPermission();
  Future<void> rescheduleDailyReminders(AppSettings settings);
  Future<void> scheduleLaterReminder({required String taskId, required String title, required DateTime at});
  Future<void> cancelLaterReminder(String taskId);
  Future<void> notifyMovedToToday(String title);
  Future<void> notifyTodayFull(String title);
  Future<void> notifyBanishedToLater(String title);

  /// アプリアイコンバッジ = TODAY 未完了数（0 で非表示）
  Future<void> applyBadge(int todayUnfinished, {required bool enabled});

  /// 環境に応じた実装を返す（Web=Stub / ネイティブ=Native）。
  static NotificationService create() => impl.createNotificationService();
}

/// Web / 未実装環境向けの no-op 実装
class StubNotificationService implements NotificationService {
  @override
  Future<void> init() async {}

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
