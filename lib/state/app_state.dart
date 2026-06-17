import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../models/genre.dart';
import '../models/enums.dart';
import '../models/app_settings.dart';
import '../data/store.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import '../util/day_clock.dart';

const _uuid = Uuid();

/// アプリ全体の状態とロジック。provider で配布する。
class AppState extends ChangeNotifier {
  final Store store;
  final NotificationService notifier;

  List<TaskItem> _tasks = [];
  List<Genre> _genres = [];
  late AppSettings settings;

  AppState({required this.store, required this.notifier});

  // ===== 起動 =====

  Future<void> load() async {
    _tasks = store.loadTasks();
    _genres = store.loadGenres();
    settings = store.loadSettings();
    runMaintenance();
    await notifier.rescheduleDailyReminders(settings);
    notifyListeners();
  }

  // ===== 参照 =====

  List<TaskItem> tasksIn(TaskStatus status) {
    final list = _tasks.where((t) => t.status == status).toList();
    if (status == TaskStatus.today) {
      list.sort((a, b) => a.todayOrder != b.todayOrder
          ? a.todayOrder.compareTo(b.todayOrder)
          : a.createdAt.compareTo(b.createdAt));
    } else {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return list;
  }

  int count(TaskStatus status) => _tasks.where((t) => t.status == status).length;

  /// TODAY 未完了数（= バッジ）
  int get todayUnfinished => count(TaskStatus.today);

  List<Genre> get genres {
    final g = [..._genres];
    g.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return g;
  }

  Genre? genreById(String? id) {
    if (id == null) return null;
    for (final g in _genres) {
      if (g.id == id) return g;
    }
    return null;
  }

  bool isFull(TaskStatus status) {
    final cap = Limits.capacityFor(status);
    return cap != null && count(status) >= cap;
  }

  // ===== 追加 =====

  /// BOX へ追加。満杯なら false。
  bool addToBox(String title, {TaskSource source = TaskSource.manual}) {
    final t = title.trim();
    if (t.isEmpty) return true;
    if (isFull(TaskStatus.box)) return false;
    _tasks.add(TaskItem(id: _uuid.v4(), title: t, status: TaskStatus.box, source: source));
    _persistAndRefresh();
    return true;
  }

  // ===== 移動 =====

  /// 移動を試みる。満杯なら false。
  bool move(TaskItem task, TaskStatus target) {
    final cap = Limits.capacityFor(target);
    if (cap != null && count(target) >= cap) return false;
    _apply(task, target);
    _persistAndRefresh();
    return true;
  }

  void _apply(TaskItem task, TaskStatus target) {
    task.status = target;
    task.updatedAt = DateTime.now();
    if (target == TaskStatus.today) {
      task.movedToTodayAt = DateTime.now();
      task.lastTodayDate = DayClock.startOfDay();
      task.todayAddedCount += 1;
      final maxOrder = tasksIn(TaskStatus.today)
          .fold<int>(0, (m, t) => t.todayOrder > m ? t.todayOrder : m);
      task.todayOrder = maxOrder + 1;
      task.pendingMoveToToday = false;
    } else if (target == TaskStatus.later) {
      task.pendingAutoMoveToLater = false;
    }
  }

  // ===== 完了 / 削除 / 編集 =====

  void complete(TaskItem task) {
    task.status = TaskStatus.done;
    task.completedAt = DateTime.now();
    task.updatedAt = DateTime.now();
    task.consecutiveUnfinishedDays = 0;
    notifier.cancelLaterReminder(task.id);
    _persistAndRefresh();
  }

  void deleteTask(TaskItem task) {
    task.status = TaskStatus.deleted;
    task.deletedAt = DateTime.now();
    task.updatedAt = DateTime.now();
    notifier.cancelLaterReminder(task.id);
    _persistAndRefresh();
  }

  void setTitle(TaskItem task, String title) {
    final t = title.trim();
    if (t.isEmpty) return;
    task.title = t;
    task.updatedAt = DateTime.now();
    _persistAndRefresh();
  }

  void setMemo(TaskItem task, String? memo) {
    task.memo = (memo == null || memo.isEmpty) ? null : memo;
    task.updatedAt = DateTime.now();
    _persistAndRefresh();
  }

  void setGenre(TaskItem task, String? genreId) {
    task.genreId = genreId;
    task.updatedAt = DateTime.now();
    _persistAndRefresh();
  }

  // ===== TODAY 並び替え =====

  void reorderToday(int oldIndex, int newIndex) {
    final list = tasksIn(TaskStatus.today);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (var i = 0; i < list.length; i++) {
      list[i].todayOrder = i;
    }
    _persistAndRefresh();
  }

  // ===== LATER 設定 =====

  void configureLater(
    TaskItem task, {
    required DateTime? startAt,
    required bool startDateOnly,
    required bool autoMove,
    required bool reminderEnabled,
    int? reminderOffsetValue,
    ReminderOffsetUnit? reminderOffsetUnit,
  }) {
    task.startAt = startAt;
    task.startDateOnly = startDateOnly;
    task.autoMoveToToday = autoMove;
    task.reminderEnabled = reminderEnabled;
    task.reminderOffsetValue = reminderOffsetValue;
    task.reminderOffsetUnit = reminderOffsetUnit;
    task.updatedAt = DateTime.now();
    _scheduleReminder(task);
    _persistAndRefresh();
  }

  DateTime? effectiveStartDate(TaskItem task) {
    if (task.startAt == null) return null;
    if (task.startDateOnly) {
      final t = settings.laterAutoMove;
      final d = task.startAt!;
      return DateTime(d.year, d.month, d.day, t.hour, t.minute);
    }
    return task.startAt;
  }

  void _scheduleReminder(TaskItem task) {
    notifier.cancelLaterReminder(task.id);
    final base = effectiveStartDate(task);
    if (!task.reminderEnabled || base == null) {
      task.reminderAt = null;
      return;
    }
    final offset = Duration(
      seconds: (task.reminderOffsetValue ?? 0) *
          (task.reminderOffsetUnit?.unit.inSeconds ?? 60),
    );
    final fireAt = base.subtract(offset);
    task.reminderAt = fireAt;
    notifier.scheduleLaterReminder(taskId: task.id, title: task.title, at: fireAt);
  }

  // ===== 自動処理エンジン =====

  void runMaintenance() {
    final now = DateTime.now();
    _rollOverDay(now);
    _autoMoveDueLater(now);
    _autoBanishStaleToday(now);
    _refreshBadge();
  }

  void _rollOverDay(DateTime now) {
    for (final t in _tasks.where((t) => t.status == TaskStatus.today)) {
      if (!DayClock.isSameDay(t.lastTodayDate, now)) {
        t.lastTodayDate = DayClock.startOfDay(now);
      }
    }
  }

  void _autoMoveDueLater(DateTime now) {
    for (final t in _tasks.where((t) => t.status == TaskStatus.later && t.autoMoveToToday).toList()) {
      final due = effectiveStartDate(t);
      if (due == null || due.isAfter(now)) continue;
      if (count(TaskStatus.today) >= Limits.today) {
        if (!t.pendingMoveToToday) {
          t.pendingMoveToToday = true;
          notifier.notifyTodayFull(t.title);
        }
        continue;
      }
      _apply(t, TaskStatus.today);
      t.lastAutoMovedAt = now;
      notifier.cancelLaterReminder(t.id);
      notifier.notifyMovedToToday(t.title);
    }
  }

  void _autoBanishStaleToday(DateTime now) {
    for (final t in _tasks.where((t) => t.status == TaskStatus.today && t.consecutiveUnfinishedDays >= 3).toList()) {
      if (count(TaskStatus.later) >= Limits.later) {
        t.pendingAutoMoveToLater = true; // 追放待ち
        continue;
      }
      t.status = TaskStatus.later;
      t.consecutiveUnfinishedDays = 0;
      t.lastAutoMovedAt = now;
      t.pendingAutoMoveToLater = false;
      t.updatedAt = now;
      notifier.notifyBanishedToLater(t.title);
    }
  }

  // ===== 今日の精算 =====

  void settleKeepInToday(TaskItem task) {
    task.consecutiveUnfinishedDays += 1;
    task.snoozeCountToday = 0;
    task.lastSweptAt = DateTime.now();
    task.updatedAt = DateTime.now();
    _persistAndRefresh();
  }

  void settleMoveToLater(TaskItem task) {
    if (count(TaskStatus.later) >= Limits.later) {
      task.pendingAutoMoveToLater = true;
    } else {
      task.status = TaskStatus.later;
      task.consecutiveUnfinishedDays = 0;
      task.pendingAutoMoveToLater = false;
    }
    task.lastSweptAt = DateTime.now();
    task.updatedAt = DateTime.now();
    _persistAndRefresh();
  }

  // ===== ジャンル =====

  /// 戻り値: null=成功 / メッセージ=失敗理由
  String? addGenre(String name, int colorValue) {
    final t = name.trim();
    if (t.isEmpty) return '名前を入力してください';
    if (_genres.length >= Limits.genre) return 'ジャンルは最大${Limits.genre}個までです';
    if (_genres.any((g) => g.name == t)) return '同じ名前があります';
    final now = DateTime.now();
    _genres.add(Genre(id: _uuid.v4(), name: t, colorValue: colorValue, createdAt: now, updatedAt: now));
    _persistGenres();
    notifyListeners();
    return null;
  }

  void renameGenre(Genre g, String name) {
    g.name = name.trim();
    g.updatedAt = DateTime.now();
    _persistGenres();
    notifyListeners();
  }

  void setGenreColor(Genre g, int colorValue) {
    g.colorValue = colorValue;
    g.updatedAt = DateTime.now();
    _persistGenres();
    notifyListeners();
  }

  void deleteGenre(Genre g) {
    for (final t in _tasks.where((t) => t.genreId == g.id)) {
      t.genreId = null;
    }
    _genres.removeWhere((x) => x.id == g.id);
    _persistGenres();
    _persistTasks();
    notifyListeners();
  }

  int suggestedGenreColor() {
    final used = _genres.map((g) => g.colorValue).toSet();
    for (final c in AppTheme.genrePalette) {
      if (!used.contains(c)) return c;
    }
    return AppTheme.genrePalette.first;
  }

  // ===== 設定 =====

  void updateSettings(void Function(AppSettings s) update) {
    update(settings);
    store.saveSettings(settings);
    notifier.rescheduleDailyReminders(settings);
    _refreshBadge();
    notifyListeners();
  }

  // ===== バックアップ =====

  String exportJson() {
    final map = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': _tasks.map((t) => t.toJson()).toList(),
      'genres': _genres.map((g) => g.toJson()).toList(),
      'settings': settings.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// 戻り値: null=成功 / メッセージ=失敗
  String? importJson(String text) {
    try {
      final map = jsonDecode(text) as Map<String, dynamic>;
      _tasks = (map['tasks'] as List).map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList();
      _genres = (map['genres'] as List).map((e) => Genre.fromJson(e as Map<String, dynamic>)).toList();
      if (map['settings'] != null) {
        settings = AppSettings.fromJson(map['settings'] as Map<String, dynamic>);
      }
      _persistTasks();
      _persistGenres();
      store.saveSettings(settings);
      runMaintenance();
      notifyListeners();
      return null;
    } catch (e) {
      return '読み込みに失敗しました: $e';
    }
  }

  void deleteAll() {
    _tasks = [];
    _genres = [];
    _persistTasks();
    _persistGenres();
    _refreshBadge();
    notifyListeners();
  }

  // ===== 内部 =====

  void _persistTasks() => store.saveTasks(_tasks);
  void _persistGenres() => store.saveGenres(_genres);

  void _persistAndRefresh() {
    _persistTasks();
    _refreshBadge();
    notifyListeners();
  }

  void _refreshBadge() {
    notifier.applyBadge(todayUnfinished, enabled: settings.badgeEnabled);
  }
}
