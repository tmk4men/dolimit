/// 時・分のペア
class TimeOfDayPref {
  final int hour;
  final int minute;
  const TimeOfDayPref(this.hour, this.minute);

  String get label => '$hour:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {'h': hour, 'm': minute};
  factory TimeOfDayPref.fromJson(Map<String, dynamic> j) =>
      TimeOfDayPref((j['h'] ?? 0) as int, (j['m'] ?? 0) as int);
}

/// 通知・バッジ・各種時刻の設定
class AppSettings {
  bool notificationsEnabled;
  bool badgeEnabled;
  bool onboardingDone;
  bool isPro; // Pro 購入済みなら true（上限が拡張される）

  /// 広告視聴で得た一時的な枠拡張の期限。null または過去なら無効。
  DateTime? boostUntil;

  TimeOfDayPref morning;
  TimeOfDayPref midday;
  TimeOfDayPref settlement;
  TimeOfDayPref laterAutoMove;

  /// 連続で TODAY を決着させた日数（ストリーク）。
  int streak;

  /// 最後に「決着」した日（当日の 0:00）。null なら未達成。
  DateTime? lastClearedDay;

  /// 外観テーマ。'system' | 'light' | 'dark'。
  String appearance;

  AppSettings({
    this.notificationsEnabled = true,
    this.badgeEnabled = true,
    this.onboardingDone = false,
    this.isPro = false,
    this.boostUntil,
    this.morning = const TimeOfDayPref(8, 0),
    this.midday = const TimeOfDayPref(15, 0),
    this.settlement = const TimeOfDayPref(22, 30),
    this.laterAutoMove = const TimeOfDayPref(7, 0),
    this.streak = 0,
    this.lastClearedDay,
    this.appearance = 'system',
  });

  Map<String, dynamic> toJson() => {
        'notificationsEnabled': notificationsEnabled,
        'badgeEnabled': badgeEnabled,
        'onboardingDone': onboardingDone,
        'isPro': isPro,
        'boostUntil': boostUntil?.toIso8601String(),
        'morning': morning.toJson(),
        'midday': midday.toJson(),
        'settlement': settlement.toJson(),
        'laterAutoMove': laterAutoMove.toJson(),
        'streak': streak,
        'lastClearedDay': lastClearedDay?.toIso8601String(),
        'appearance': appearance,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        notificationsEnabled: (j['notificationsEnabled'] ?? true) as bool,
        badgeEnabled: (j['badgeEnabled'] ?? true) as bool,
        onboardingDone: (j['onboardingDone'] ?? false) as bool,
        isPro: (j['isPro'] ?? false) as bool,
        boostUntil: j['boostUntil'] == null
            ? null
            : DateTime.parse(j['boostUntil'] as String),
        morning: j['morning'] != null
            ? TimeOfDayPref.fromJson(j['morning'] as Map<String, dynamic>)
            : const TimeOfDayPref(8, 0),
        midday: j['midday'] != null
            ? TimeOfDayPref.fromJson(j['midday'] as Map<String, dynamic>)
            : const TimeOfDayPref(15, 0),
        settlement: j['settlement'] != null
            ? TimeOfDayPref.fromJson(j['settlement'] as Map<String, dynamic>)
            : const TimeOfDayPref(22, 30),
        laterAutoMove: j['laterAutoMove'] != null
            ? TimeOfDayPref.fromJson(j['laterAutoMove'] as Map<String, dynamic>)
            : const TimeOfDayPref(7, 0),
        streak: (j['streak'] ?? 0) as int,
        lastClearedDay: j['lastClearedDay'] == null
            ? null
            : DateTime.parse(j['lastClearedDay'] as String),
        appearance: (j['appearance'] ?? 'system') as String,
      );
}
