import 'dart:convert';
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

  List<TaskItem> loadTasks() {
    final s = prefs.getString(_kTasks);
    if (s == null) return [];
    final list = jsonDecode(s) as List;
    return list.map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveTasks(List<TaskItem> tasks) async {
    await prefs.setString(_kTasks, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  List<Genre> loadGenres() {
    final s = prefs.getString(_kGenres);
    if (s == null) return [];
    final list = jsonDecode(s) as List;
    return list.map((e) => Genre.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveGenres(List<Genre> genres) async {
    await prefs.setString(_kGenres, jsonEncode(genres.map((g) => g.toJson()).toList()));
  }

  AppSettings loadSettings() {
    final s = prefs.getString(_kSettings);
    if (s == null) return AppSettings();
    return AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }
}
