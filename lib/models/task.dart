import 'enums.dart';
import '../util/day_clock.dart';

/// アプリの中心となるタスク。BOX / TODAY / LATER を [status] で表す。
class TaskItem {
  final String id;
  String title;
  String? memo;
  TaskStatus status;
  String? genreId;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? completedAt;
  DateTime? deletedAt;

  // TODAY 関連
  DateTime? movedToTodayAt;
  int todayOrder;
  int todayAddedCount;
  int consecutiveUnfinishedDays;
  DateTime? lastTodayDate;
  int snoozeCountToday;
  DateTime? lastRemindedAt;

  // LATER 関連
  DateTime? startAt;
  bool startDateOnly;
  bool reminderEnabled;
  DateTime? reminderAt;
  int? reminderOffsetValue;
  ReminderOffsetUnit? reminderOffsetUnit;
  bool autoMoveToToday;
  bool pendingMoveToToday;

  // その他
  TaskSource source;
  bool pendingAutoMoveToLater;
  DateTime? lastAutoMovedAt;
  DateTime? lastSweptAt;

  TaskItem({
    required this.id,
    required this.title,
    this.memo,
    this.status = TaskStatus.box,
    this.genreId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
    this.deletedAt,
    this.movedToTodayAt,
    this.todayOrder = 0,
    this.todayAddedCount = 0,
    this.consecutiveUnfinishedDays = 0,
    this.lastTodayDate,
    this.snoozeCountToday = 0,
    this.lastRemindedAt,
    this.startAt,
    this.startDateOnly = false,
    this.reminderEnabled = false,
    this.reminderAt,
    this.reminderOffsetValue,
    this.reminderOffsetUnit,
    this.autoMoveToToday = true,
    this.pendingMoveToToday = false,
    this.source = TaskSource.manual,
    this.pendingAutoMoveToLater = false,
    this.lastAutoMovedAt,
    this.lastSweptAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// TODAY 画面に出す「放置日数」表示
  String get ageLabel {
    if (consecutiveUnfinishedDays >= 3) return '3日連続未完了';
    if (movedToTodayAt == null) return '今日追加';
    final days = DayClock.daysBetween(movedToTodayAt!, DateTime.now());
    if (days <= 0) return '今日追加';
    return '放置$days日目';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'memo': memo,
        'status': status.name,
        'genreId': genreId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'movedToTodayAt': movedToTodayAt?.toIso8601String(),
        'todayOrder': todayOrder,
        'todayAddedCount': todayAddedCount,
        'consecutiveUnfinishedDays': consecutiveUnfinishedDays,
        'lastTodayDate': lastTodayDate?.toIso8601String(),
        'snoozeCountToday': snoozeCountToday,
        'lastRemindedAt': lastRemindedAt?.toIso8601String(),
        'startAt': startAt?.toIso8601String(),
        'startDateOnly': startDateOnly,
        'reminderEnabled': reminderEnabled,
        'reminderAt': reminderAt?.toIso8601String(),
        'reminderOffsetValue': reminderOffsetValue,
        'reminderOffsetUnit': reminderOffsetUnit?.name,
        'autoMoveToToday': autoMoveToToday,
        'pendingMoveToToday': pendingMoveToToday,
        'source': source.name,
        'pendingAutoMoveToLater': pendingAutoMoveToLater,
        'lastAutoMovedAt': lastAutoMovedAt?.toIso8601String(),
        'lastSweptAt': lastSweptAt?.toIso8601String(),
      };

  static DateTime? _d(dynamic v) => v == null ? null : DateTime.parse(v as String);

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        title: j['title'] as String,
        memo: j['memo'] as String?,
        status: enumFromName(TaskStatus.values, j['status'] as String?, TaskStatus.box),
        genreId: j['genreId'] as String?,
        createdAt: _d(j['createdAt']),
        updatedAt: _d(j['updatedAt']),
        completedAt: _d(j['completedAt']),
        deletedAt: _d(j['deletedAt']),
        movedToTodayAt: _d(j['movedToTodayAt']),
        todayOrder: (j['todayOrder'] ?? 0) as int,
        todayAddedCount: (j['todayAddedCount'] ?? 0) as int,
        consecutiveUnfinishedDays: (j['consecutiveUnfinishedDays'] ?? 0) as int,
        lastTodayDate: _d(j['lastTodayDate']),
        snoozeCountToday: (j['snoozeCountToday'] ?? 0) as int,
        lastRemindedAt: _d(j['lastRemindedAt']),
        startAt: _d(j['startAt']),
        startDateOnly: (j['startDateOnly'] ?? false) as bool,
        reminderEnabled: (j['reminderEnabled'] ?? false) as bool,
        reminderAt: _d(j['reminderAt']),
        reminderOffsetValue: j['reminderOffsetValue'] as int?,
        reminderOffsetUnit: j['reminderOffsetUnit'] == null
            ? null
            : enumFromName(ReminderOffsetUnit.values, j['reminderOffsetUnit'] as String?, ReminderOffsetUnit.minute),
        autoMoveToToday: (j['autoMoveToToday'] ?? true) as bool,
        pendingMoveToToday: (j['pendingMoveToToday'] ?? false) as bool,
        source: enumFromName(TaskSource.values, j['source'] as String?, TaskSource.manual),
        pendingAutoMoveToLater: (j['pendingAutoMoveToLater'] ?? false) as bool,
        lastAutoMovedAt: _d(j['lastAutoMovedAt']),
        lastSweptAt: _d(j['lastSweptAt']),
      );
}
