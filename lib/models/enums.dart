/// タスクが入っている箱 / 状態
enum TaskStatus { box, today, later, done, deleted }

/// タスクの追加元
enum TaskSource { manual, voice, widget }

/// 事前通知のオフセット単位
enum ReminderOffsetUnit {
  minute,
  hour,
  day;

  String get label => switch (this) {
        ReminderOffsetUnit.minute => '分前',
        ReminderOffsetUnit.hour => '時間前',
        ReminderOffsetUnit.day => '日前',
      };

  Duration get unit => switch (this) {
        ReminderOffsetUnit.minute => const Duration(minutes: 1),
        ReminderOffsetUnit.hour => const Duration(hours: 1),
        ReminderOffsetUnit.day => const Duration(days: 1),
      };
}

T enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
