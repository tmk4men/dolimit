import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../models/genre.dart';
import '../models/enums.dart';
import '../models/app_settings.dart';
import '../data/store.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import '../util/day_clock.dart';

const _uuid = Uuid();

/// アプリ全体の状態とロジック。provider で配布する。
class AppState extends ChangeNotifier {
  /// バックアップJSONのスキーマ版。互換性チェックに使う。
  static const int backupVersion = 1;

  /// 完了・削除したタスクを保存データに残す日数。過ぎたら破棄する。
  /// 上限があるアプリの保存データが無制限に膨らまないようにするため。
  static const int archiveRetentionDays = 30;

  final Store store;
  final NotificationService notifier;

  /// ホーム画面ウィジェットへのデータ供給。テストなどでは省略可（null=無効）。
  final WidgetService? widgets;

  List<TaskItem> _tasks = [];
  List<Genre> _genres = [];
  late AppSettings settings;

  AppState({required this.store, required this.notifier, this.widgets});

  // ===== 起動 =====

  Future<void> load() async {
    _tasks = store.loadTasks();
    _genres = store.loadGenres();
    settings = store.loadSettings();
    runMaintenance();
    await notifier.rescheduleDailyReminders(settings);
    // 端末再起動で OS 側の予約が消えても、次回起動で貼り直す。
    _rescheduleLaterReminders();
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

  /// 通知タップなど、id だけ分かっている場面から引く。見つからなければ null。
  TaskItem? taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Genre? genreById(String? id) {
    if (id == null) return null;
    for (final g in _genres) {
      if (g.id == id) return g;
    }
    return null;
  }

  bool get isPro => settings.isPro;

  /// 広告ブーストが有効か。
  bool get isBoosted {
    final until = settings.boostUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  /// ブーストの残り時間。無効なら null。
  Duration? get boostRemaining {
    final until = settings.boostUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  /// 広告視聴の報酬として一時的に枠を広げる。
  /// すでに有効なら、そのときの期限からさらに延長する。
  void grantAdBoost() {
    final now = DateTime.now();
    final from = isBoosted ? settings.boostUntil! : now;
    settings.boostUntil = from.add(Limits.adBoostDuration);
    _persistSettings();
    notifyListeners();
  }

  /// Pro とブーストを加味した実効上限（BOX/TODAY/LATER）。上限なしの状態は null。
  int? capacityFor(TaskStatus status) {
    final base = Limits.capacityFor(status);
    if (base == null) return null;
    return base +
        (isPro ? Limits.proBonusFor(status) : 0) +
        (isBoosted ? Limits.adBoostFor(status) : 0);
  }

  /// Pro を加味したジャンル上限。
  int get genreCap => Limits.genre + (isPro ? Limits.proBonusGenre : 0);

  bool isFull(TaskStatus status) {
    final cap = capacityFor(status);
    return cap != null && count(status) >= cap;
  }

  /// Pro 状態を切り替えて永続化する（購入成功・復元・開発用解除から呼ぶ）。
  void setPro(bool value) {
    if (settings.isPro == value) return;
    settings.isPro = value;
    _persistSettings();
    notifyListeners();
  }

  // ===== 追加 =====

  /// BOX へ追加。空文字・満杯なら false。
  bool addToBox(String title, {TaskSource source = TaskSource.manual}) {
    final t = title.trim();
    if (t.isEmpty) return false;
    if (isFull(TaskStatus.box)) return false;
    _tasks.add(TaskItem(id: _uuid.v4(), title: t, status: TaskStatus.box, source: source));
    _persistAndRefresh();
    return true;
  }

  // ===== 移動 =====

  /// 移動を試みる。満杯なら false。
  bool move(TaskItem task, TaskStatus target) {
    final cap = capacityFor(target);
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
      task.consecutiveUnfinishedDays = 0; // TODAY に入り直したら未完了日数はリセット
      task.todayAddedCount += 1;
      final maxOrder = tasksIn(TaskStatus.today)
          .fold<int>(0, (m, t) => t.todayOrder > m ? t.todayOrder : m);
      task.todayOrder = maxOrder + 1;
      task.pendingMoveToToday = false;
      task.pendingAutoMoveToLater = false;
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
    final m = memo?.trim();
    task.memo = (m == null || m.isEmpty) ? null : m;
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

  /// LATER の事前通知を貼り直す。開始日のみ指定のタスクは
  /// [AppSettings.laterAutoMove] を基準時刻に使うため、設定が変わったら
  /// 予約もやり直す必要がある。
  void _rescheduleLaterReminders() {
    for (final t in _tasks.where((t) => t.status == TaskStatus.later)) {
      _scheduleReminder(t);
    }
  }

  void _scheduleReminder(TaskItem task) {
    notifier.cancelLaterReminder(task.id);
    final base = effectiveStartDate(task);
    // 通知を切っているなら予約しない。切っても LATER 通知だけ鳴り続けるのを防ぐ。
    if (!task.reminderEnabled || base == null || !settings.notificationsEnabled) {
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

  /// 自動処理をまとめて実行する。起動時・復帰時・1分ごとに呼ばれる。
  ///
  /// 状態が変わったときだけ保存し、購読者へ通知する。保存しないと、
  /// 自動追放の結果が失われて起動のたびに追放通知が再送されてしまう。
  void runMaintenance() {
    final now = DateTime.now();
    var changed = _rollOverDay(now);
    changed = _autoMoveDueLater(now) || changed;
    changed = _autoBanishStaleToday(now) || changed;
    changed = _purgeArchived(now) || changed;
    if (changed) _persistTasks();

    // ブーストの失効は tasks ではなく settings 側の変更。
    final boostExpired = _expireBoost(now);
    _refreshBadge();
    if (changed || boostExpired) notifyListeners();
  }

  /// 期限切れの広告ブーストを片付ける。上限表示が戻る。
  bool _expireBoost(DateTime now) {
    final until = settings.boostUntil;
    if (until == null || until.isAfter(now)) return false;
    settings.boostUntil = null;
    _persistSettings();
    return true;
  }

  bool _rollOverDay(DateTime now) {
    final today = DayClock.startOfDay(now);
    var changed = false;
    for (final t in _tasks.where((t) => t.status == TaskStatus.today)) {
      final last = t.lastTodayDate;
      if (last == null) {
        t.lastTodayDate = today;
        changed = true;
        continue;
      }
      final days = DayClock.daysBetween(last, now);
      // 日付が変わった＝その日 TODAY で完了できなかった。
      // 経過日数ぶん「連続未完了日数」を加算し、当日ぶんの状態をリセット。
      // 1日1回だけ増える（同日に何度 runMaintenance されても days<1 で不変）。
      if (days >= 1) {
        t.consecutiveUnfinishedDays += days;
        t.snoozeCountToday = 0;
        t.lastTodayDate = today;
        changed = true;
      }
    }
    return changed;
  }

  bool _autoMoveDueLater(DateTime now) {
    var changed = false;
    for (final t in _tasks.where((t) => t.status == TaskStatus.later && t.autoMoveToToday).toList()) {
      final due = effectiveStartDate(t);
      if (due == null || due.isAfter(now)) continue;
      if (count(TaskStatus.today) >= capacityFor(TaskStatus.today)!) {
        if (!t.pendingMoveToToday) {
          t.pendingMoveToToday = true;
          notifier.notifyTodayFull(t.title);
          changed = true;
        }
        continue;
      }
      _apply(t, TaskStatus.today);
      t.lastAutoMovedAt = now;
      notifier.cancelLaterReminder(t.id);
      notifier.notifyMovedToToday(t.title);
      changed = true;
    }
    return changed;
  }

  bool _autoBanishStaleToday(DateTime now) {
    var changed = false;
    for (final t in _tasks.where((t) => t.status == TaskStatus.today && t.consecutiveUnfinishedDays >= 3).toList()) {
      if (count(TaskStatus.later) >= capacityFor(TaskStatus.later)!) {
        if (!t.pendingAutoMoveToLater) {
          t.pendingAutoMoveToLater = true; // 追放待ち（TODAY 画面に表示される）
          changed = true;
        }
        continue;
      }
      t.status = TaskStatus.later;
      t.consecutiveUnfinishedDays = 0;
      t.lastAutoMovedAt = now;
      t.pendingAutoMoveToLater = false;
      t.updatedAt = now;
      notifier.notifyBanishedToLater(t.title);
      changed = true;
    }
    return changed;
  }

  /// 完了・削除から [archiveRetentionDays] 日を過ぎたタスクを保存データから消す。
  bool _purgeArchived(DateTime now) {
    final before = _tasks.length;
    _tasks.removeWhere((t) {
      if (t.status != TaskStatus.done && t.status != TaskStatus.deleted) return false;
      final at = t.completedAt ?? t.deletedAt ?? t.updatedAt;
      return DayClock.daysBetween(at, now) >= archiveRetentionDays;
    });
    return _tasks.length != before;
  }

  // ===== 今日の精算 =====

  /// まだ今日の精算が済んでいない TODAY のタスク。
  /// 「明日もTODAY」はタスクを TODAY に残すので、精算済みかどうかは
  /// [TaskItem.lastSweptAt] が今日かどうかで判定する。これを見ないと
  /// 精算画面が同じタスクを出し続けて先へ進めなくなる。
  List<TaskItem> get pendingSettlement {
    final now = DateTime.now();
    return tasksIn(TaskStatus.today)
        .where((t) => !DayClock.isSameDay(t.lastSweptAt, now))
        .toList();
  }

  void settleKeepInToday(TaskItem task) {
    // 未完了日数の加算は日跨ぎ (_rollOverDay) が一元管理する。
    // ここで足すと精算＋翌朝ロールオーバーで二重加算になるため足さない。
    task.snoozeCountToday = 0;
    task.lastSweptAt = DateTime.now();
    task.updatedAt = DateTime.now();
    _persistAndRefresh();
  }

  /// 精算で LATER へ戻す。LATER が満杯なら何もせず false。
  bool settleMoveToLater(TaskItem task) {
    if (count(TaskStatus.later) >= capacityFor(TaskStatus.later)!) return false;
    task.status = TaskStatus.later;
    task.consecutiveUnfinishedDays = 0;
    task.pendingAutoMoveToLater = false;
    task.lastSweptAt = DateTime.now();
    task.updatedAt = DateTime.now();
    _persistAndRefresh();
    return true;
  }

  // ===== ジャンル =====

  /// 戻り値: null=成功 / メッセージ=失敗理由
  String? addGenre(String name, int colorValue) {
    final t = name.trim();
    if (t.isEmpty) return '名前を入力してください';
    if (_genres.length >= genreCap) return 'ジャンルは最大$genreCap個までです';
    if (_genres.any((g) => g.name == t)) return '同じ名前があります';
    final now = DateTime.now();
    _genres.add(Genre(id: _uuid.v4(), name: t, colorValue: colorValue, createdAt: now, updatedAt: now));
    _persistGenres();
    notifyListeners();
    return null;
  }

  /// 戻り値: null=成功 / メッセージ=失敗理由
  String? renameGenre(Genre g, String name) {
    final t = name.trim();
    if (t.isEmpty) return '名前を入力してください';
    if (_genres.any((x) => x.id != g.id && x.name == t)) return '同じ名前があります';
    g.name = t;
    g.updatedAt = DateTime.now();
    _persistGenres();
    notifyListeners();
    return null;
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
    final wasEnabled = settings.notificationsEnabled;
    final wasAutoMove = settings.laterAutoMove;

    update(settings);
    _persistSettings();
    notifier.rescheduleDailyReminders(settings);

    // 通知の ON/OFF と自動移動時刻は、どちらも LATER の事前通知の予約内容を変える。
    final autoMoveChanged = settings.laterAutoMove.hour != wasAutoMove.hour ||
        settings.laterAutoMove.minute != wasAutoMove.minute;
    if (settings.notificationsEnabled != wasEnabled || autoMoveChanged) {
      _rescheduleLaterReminders();
      _persistTasks();
    }

    _refreshBadge();
    notifyListeners();
  }

  // ===== バックアップ =====

  String exportJson() {
    final map = {
      'version': backupVersion,
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
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return 'バックアップの形式が正しくありません。';
      }
      final map = decoded;

      // version が int 以外なら壊れている。素通しさせると互換性チェックを
      // すり抜けて未知の形式を読み込んでしまう。
      final version = map['version'] ?? 1;
      if (version is! int) {
        return 'バックアップの形式が正しくありません。';
      }
      if (version > backupVersion) {
        return 'より新しいバージョンのバックアップです。アプリを更新してください。';
      }
      if (map['tasks'] is! List || map['genres'] is! List) {
        return 'バックアップの形式が正しくありません。';
      }

      // まずローカル変数へ完全にパースする。途中で失敗しても
      // 既存データ (_tasks/_genres/settings) は壊さない。
      final tasks = (map['tasks'] as List)
          .whereType<Map<String, dynamic>>()
          .map(TaskItem.fromJson)
          .toList();
      var genres = (map['genres'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Genre.fromJson)
          .toList();
      final newSettings = map['settings'] != null
          ? AppSettings.fromJson(map['settings'] as Map<String, dynamic>)
          : settings;
      // ジャンル上限を超える分は切り捨て（上限厳守）。取り込む設定の Pro 状態で判定。
      final importGenreCap =
          Limits.genre + (newSettings.isPro ? Limits.proBonusGenre : 0);
      if (genres.length > importGenreCap) {
        genres = genres.sublist(0, importGenreCap);
      }

      // 全て成功したのでまとめて反映。
      // 置き換えで消えるタスクの予約通知を先に取り消す。放置すると
      // 存在しないタスクの「まもなく開始」通知が鳴る。
      _cancelAllLaterReminders();
      _tasks = tasks;
      _genres = genres;
      settings = newSettings;
      // 取り込んだ LATER タスクの予約を貼り直す。
      _rescheduleLaterReminders();
      _persistTasks();
      _persistGenres();
      _persistSettings();
      runMaintenance();
      notifyListeners();
      return null;
    } catch (e) {
      return '読み込みに失敗しました: $e';
    }
  }

  void deleteAll() {
    _cancelAllLaterReminders();
    _tasks = [];
    _genres = [];
    _persistTasks();
    _persistGenres();
    _refreshBadge();
    notifyListeners();
  }

  void _cancelAllLaterReminders() {
    for (final t in _tasks) {
      notifier.cancelLaterReminder(t.id);
    }
  }

  // ===== 内部 =====

  /// 保存は待たずに投げるが、失敗を黙って捨てない。
  void _guard(Future<void> save, String what) {
    save.catchError((Object e) => debugPrint('AppState: failed to save $what: $e'));
  }

  void _persistTasks() => _guard(store.saveTasks(_tasks), 'tasks');
  void _persistGenres() => _guard(store.saveGenres(_genres), 'genres');
  void _persistSettings() => _guard(store.saveSettings(settings), 'settings');

  void _persistAndRefresh() {
    _persistTasks();
    _refreshBadge();
    notifyListeners();
  }

  void _refreshBadge() {
    // バッジは常時ON（設定で消せない仕様）。
    notifier.applyBadge(todayUnfinished, enabled: true);
    _refreshWidget();
  }

  void _refreshWidget() {
    final w = widgets;
    if (w == null) return;
    final titles = tasksIn(TaskStatus.today).take(3).map((t) => t.title).toList();
    w.update(todayCount: todayUnfinished, topTitles: titles);
  }
}
