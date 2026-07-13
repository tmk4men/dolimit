import 'package:flutter/material.dart';

/// ライト/ダークで切り替わる色トークン。`context.c.ink` のように参照する。
/// 形（角丸）・影・ジャンル色は明暗共通なので [AppTheme] 側に据え置く。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color ink; // 主要テキスト
  final Color ink2; // 副次テキスト
  final Color sub; // 補助テキスト
  final Color line; // ヘアライン
  final Color bg; // 画面背景
  final Color card; // カード面・シート・ナビ
  final Color fill; // 入力欄など
  final Color boxAccent;
  final Color boxSoft;
  final Color todayAccent;
  final Color todaySoft;
  final Color laterAccent;
  final Color laterSoft;

  const AppColors({
    required this.ink,
    required this.ink2,
    required this.sub,
    required this.line,
    required this.bg,
    required this.card,
    required this.fill,
    required this.boxAccent,
    required this.boxSoft,
    required this.todayAccent,
    required this.todaySoft,
    required this.laterAccent,
    required this.laterSoft,
  });

  // ゆるいトーン：生成りの地に、暖かいコーラルとくすみティール。
  // アクセントはテキストにも使うので可読性を確保した少し深めの色にしている。
  static const light = AppColors(
    ink: Color(0xFF4A443E), // やわらかい茶グレー
    ink2: Color(0xFF7A736A),
    sub: Color(0xFFA99E8D),
    line: Color(0xFFEDE6DA),
    bg: Color(0xFFFAF6EF), // 生成り・クリーム
    card: Color(0xFFFFFDF8),
    fill: Color(0xFFF1EBE1),
    boxAccent: Color(0xFFA99E8D),
    boxSoft: Color(0xFFEFE7DB),
    todayAccent: Color(0xFFDC6A4B), // 暖かいコーラル/テラコッタ
    todaySoft: Color(0xFFFBE7DE),
    laterAccent: Color(0xFF3F8F86), // くすみティール
    laterSoft: Color(0xFFE2F0ED),
  );

  static const dark = AppColors(
    ink: Color(0xFFECE5D9),
    ink2: Color(0xFFB9AF9E),
    sub: Color(0xFF8B8171),
    line: Color(0xFF302A20),
    bg: Color(0xFF16130E), // 暖かい黒
    card: Color(0xFF201C15),
    fill: Color(0xFF2A251D),
    boxAccent: Color(0xFF8B8171),
    boxSoft: Color(0xFF262019),
    todayAccent: Color(0xFFF0906E),
    todaySoft: Color(0xFF33221A),
    laterAccent: Color(0xFF74B8AF),
    laterSoft: Color(0xFF1B2A27),
  );

  @override
  AppColors copyWith({
    Color? ink,
    Color? ink2,
    Color? sub,
    Color? line,
    Color? bg,
    Color? card,
    Color? fill,
    Color? boxAccent,
    Color? boxSoft,
    Color? todayAccent,
    Color? todaySoft,
    Color? laterAccent,
    Color? laterSoft,
  }) =>
      AppColors(
        ink: ink ?? this.ink,
        ink2: ink2 ?? this.ink2,
        sub: sub ?? this.sub,
        line: line ?? this.line,
        bg: bg ?? this.bg,
        card: card ?? this.card,
        fill: fill ?? this.fill,
        boxAccent: boxAccent ?? this.boxAccent,
        boxSoft: boxSoft ?? this.boxSoft,
        todayAccent: todayAccent ?? this.todayAccent,
        todaySoft: todaySoft ?? this.todaySoft,
        laterAccent: laterAccent ?? this.laterAccent,
        laterSoft: laterSoft ?? this.laterSoft,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      sub: Color.lerp(sub, other.sub, t)!,
      line: Color.lerp(line, other.line, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      boxAccent: Color.lerp(boxAccent, other.boxAccent, t)!,
      boxSoft: Color.lerp(boxSoft, other.boxSoft, t)!,
      todayAccent: Color.lerp(todayAccent, other.todayAccent, t)!,
      todaySoft: Color.lerp(todaySoft, other.todaySoft, t)!,
      laterAccent: Color.lerp(laterAccent, other.laterAccent, t)!,
      laterSoft: Color.lerp(laterSoft, other.laterSoft, t)!,
    );
  }
}

/// `context.c.ink` で現在のテーマの色トークンを引く。拡張が無い場面（テスト等）は
/// ライトにフォールバックして落ちないようにする。
extension AppColorsContext on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

/// デザイントークン。生成り基調のゆるいトーン。TODAY はコーラル、LATER はティール。
/// 実際の描画は `context.c.<token>`（[AppColors]）を使う。以下の静的値は参考。
class AppTheme {
  // ---- ニュートラル ----
  static const Color ink = Color(0xFF4A443E);
  static const Color ink2 = Color(0xFF7A736A);
  static const Color sub = Color(0xFFA99E8D);
  static const Color line = Color(0xFFEDE6DA);
  static const Color bg = Color(0xFFFAF6EF);
  static const Color card = Color(0xFFFFFDF8);
  static const Color fill = Color(0xFFF1EBE1);

  // ---- アクセント（箱ごと）----
  static const Color boxAccent = Color(0xFFA99E8D);
  static const Color boxSoft = Color(0xFFEFE7DB);

  static const Color todayAccent = Color(0xFFDC6A4B); // コーラル
  static const Color todaySoft = Color(0xFFFBE7DE);

  static const Color laterAccent = Color(0xFF3F8F86); // ティール
  static const Color laterSoft = Color(0xFFE2F0ED);

  // ---- 形 ----
  static const double cardRadius = 24;
  static const double spacing = 16;

  static const BorderRadius radiusCard = BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius radiusSheet = BorderRadius.vertical(top: Radius.circular(28));
  static const BorderRadius radiusPill = BorderRadius.all(Radius.circular(999));

  // ---- 影（暖かく、ふんわり）----
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F5A4B38), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x14705B42), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> floatShadow = [
    BoxShadow(color: Color(0x226B5230), blurRadius: 26, offset: Offset(0, 12)),
  ];

  static ThemeData light() => _build(Brightness.light, AppColors.light);
  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.light.ink,
      brightness: brightness,
    ).copyWith(
      primary: c.ink,
      surface: c.card,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      splashFactory: InkSparkle.splashFactory,
      extensions: [c],
    );

    // スナックバーの文字色は背景（反転面）に対して読める側を選ぶ。
    final onSnack = brightness == Brightness.light ? Colors.white : c.bg;

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: c.ink,
        titleTextStyle: TextStyle(color: c.ink, fontSize: 18, fontWeight: FontWeight.w800),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.card,
        elevation: 0,
        height: 64,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 24, color: selected ? c.ink : c.sub);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? c.ink : c.sub,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: radiusSheet),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: TextStyle(color: onSnack, fontWeight: FontWeight.w600),
        actionTextColor: onSnack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  /// 残り時間の色。夜に近づくほど赤くなる。通常色はテーマに合わせる。
  static Color remainingColor(double hoursLeft, AppColors c) {
    if (hoursLeft < 1) return const Color(0xFFD90000); // 強い赤
    if (hoursLeft < 3) return c.todayAccent; // 赤
    if (hoursLeft < 6) return const Color(0xFFF2870E); // オレンジ
    return c.ink; // 通常
  }

  static Color remainingSoft(double hoursLeft, AppColors c) {
    if (hoursLeft < 3) return c.todaySoft;
    if (hoursLeft < 6) return const Color(0xFFFFF0DC);
    return c.boxSoft;
  }

  /// ジャンル候補色
  static const List<int> genrePalette = [
    0xFF5B6470, 0xFFC0392B, 0xFF2E7D9A, 0xFF2E7D32,
    0xFF8E44AD, 0xFFD68910, 0xFF16A085, 0xFF34495E,
  ];
}

/// 数字表示用（等幅）
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];
