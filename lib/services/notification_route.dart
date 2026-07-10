/// 通知に載せるペイロードと、その解釈。
///
/// 通知をタップしたときにどこを開くかを決める。ペイロードは通知に
/// 埋め込まれて OS 側に保存されるため、書式を変えるときは古い通知が
/// 残っている前提で後方互換に注意する。
library;

/// 通知タップで開く先。
sealed class NotificationTarget {
  const NotificationTarget();
}

/// 今日の精算画面を開く。
class OpenSettlement extends NotificationTarget {
  const OpenSettlement();
  @override
  bool operator ==(Object other) => other is OpenSettlement;
  @override
  int get hashCode => 0;
}

/// 特定の箱（BOX/TODAY/LATER）のタブを開く。
class OpenBox extends NotificationTarget {
  final NotificationBox box;
  const OpenBox(this.box);
  @override
  bool operator ==(Object other) => other is OpenBox && other.box == box;
  @override
  int get hashCode => box.hashCode;
}

/// 特定のタスクを開く。どのタブかは実行時の status で決める。
class OpenTask extends NotificationTarget {
  final String taskId;
  const OpenTask(this.taskId);
  @override
  bool operator ==(Object other) => other is OpenTask && other.taskId == taskId;
  @override
  int get hashCode => taskId.hashCode;
}

enum NotificationBox { box, today, later }

/// 通知ペイロードの定数。通知を作る側と読む側で共有する。
class NotificationPayload {
  static const String settlement = 'settlement';
  static const String today = 'today';
  static const String later = 'later';
  static const String box = 'box';

  /// タスク個別のペイロード。
  static String task(String taskId) => 'task:$taskId';
}

/// ペイロードを解釈する。未知・空なら null（＝何もしない）。
NotificationTarget? parseNotificationPayload(String? payload) {
  if (payload == null) return null;
  final p = payload.trim();
  if (p.isEmpty) return null;

  if (p.startsWith('task:')) {
    final id = p.substring('task:'.length);
    return id.isEmpty ? null : OpenTask(id);
  }

  return switch (p) {
    NotificationPayload.settlement => const OpenSettlement(),
    NotificationPayload.today => const OpenBox(NotificationBox.today),
    NotificationPayload.later => const OpenBox(NotificationBox.later),
    NotificationPayload.box => const OpenBox(NotificationBox.box),
    _ => null,
  };
}
