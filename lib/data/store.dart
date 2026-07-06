import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/genre.dart';
import '../models/app_settings.dart';

/// ローカル保存。Web/Android/iOS 共通で shared_preferences に JSON を保存。
/// データは少量（上限あり）なので軽量なこの方式で十分。
class Store {
  static const _kTasks = 'tasks_v1';
  static const _kGenres = 'genres_v1';
  static const _kSettings = 'settings_v1';

  final SharedPreferences prefs;
  Store(this.prefs);

  static Future<Store> open() async {
    final p = await SharedPreferences.getInstance();
    return Store(p);
  }

  /// 保存データが壊れていても起動不能にせず、読めた分だけ返す。
  /// リストや個々の要素が不正な場合はスキップする。
  List<T> _loadList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final s = prefs.getString(key);
    if (s == null) return [];
    try {
      final decoded = jsonDecode(s);
      if (decoded is! List) return [];
      final out = <T>[];
      for (final e in decoded) {
        if (e is! Map<String, dynamic>) continue;
        try {
          out.add(fromJson(e));
        } catch (err) {
          debugPrint('Store: skipped a corrupt item in $key: $err');
        }
      }
      return out;
    } catch (err) {
      debugPrint('Store: failed to parse $key, ignoring: $err');
      return [];
    }
  }

  List<TaskItem> loadTasks() => _loadList(_kTasks, TaskItem.fromJson);

  Future<void> saveTasks(List<TaskItem> tasks) async {
    await prefs.setString(_kTasks, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  List<Genre> loadGenres() => _loadList(_kGenres, Genre.fromJson);

  Future<void> saveGenres(List<Genre> genres) async {
    await prefs.setString(_kGenres, jsonEncode(genres.map((g) => g.toJson()).toList()));
  }

  AppSettings loadSettings() {
    final s = prefs.getString(_kSettings);
    if (s == null) return AppSettings();
    try {
      final decoded = jsonDecode(s);
      if (decoded is! Map<String, dynamic>) return AppSettings();
      return AppSettings.fromJson(decoded);
    } catch (err) {
      debugPrint('Store: failed to parse settings, using defaults: $err');
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }
}
