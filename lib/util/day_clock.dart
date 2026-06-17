/// 「今日」の境界・残り時間計算をまとめたヘルパー。
class DayClock {
  static DateTime startOfDay([DateTime? date]) {
    final d = date ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime endOfDay([DateTime? date]) {
    return startOfDay(date).add(const Duration(days: 1));
  }

  static Duration remaining([DateTime? now]) {
    final n = now ?? DateTime.now();
    final r = endOfDay(n).difference(n);
    return r.isNegative ? Duration.zero : r;
  }

  static double remainingHours([DateTime? now]) =>
      remaining(now).inSeconds / 3600.0;

  /// 「6:42」形式
  static String remainingString([DateTime? now]) {
    final total = remaining(now).inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  static bool isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static int daysBetween(DateTime from, DateTime to) {
    return startOfDay(to).difference(startOfDay(from)).inDays;
  }
}
