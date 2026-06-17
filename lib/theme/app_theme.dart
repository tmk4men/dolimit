import 'package:flutter/material.dart';

/// デザイントークン。白 / 黒 / グレー基調。TODAY だけ赤、LATER だけ青を使う。
class AppTheme {
  // ---- ニュートラル ----
  static const Color ink = Color(0xFF17181C); // 主要テキスト（ほぼ黒）
  static const Color ink2 = Color(0xFF55575F); // 副次テキスト（濃いグレー）
  static const Color sub = Color(0xFF9395A0); // 補助テキスト
  static const Color line = Color(0xFFEAEBEF); // ヘアライン
  static const Color bg = Color(0xFFF4F5F7); // 画面背景
  static const Color card = Colors.white; // カード面
  static const Color fill = Color(0xFFEFF0F3); // 入力欄など

  // ---- アクセント（箱ごと）----
  static const Color boxAccent = Color(0xFF9A9CA6);
  static const Color boxSoft = Color(0xFFEDEEF1);

  static const Color todayAccent = Color(0xFFF23B30); // 赤
  static const Color todaySoft = Color(0xFFFFE8E5);

  static const Color laterAccent = Color(0xFF2E6BF0); // 青
  static const Color laterSoft = Color(0xFFE6EEFE);

  // ---- 形 ----
  static const double cardRadius = 22;
  static const double spacing = 16;

  static const BorderRadius radiusCard = BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius radiusSheet = BorderRadius.vertical(top: Radius.circular(28));
  static const BorderRadius radiusPill = BorderRadius.all(Radius.circular(999));

  // ---- 影（やわらかく層を作る）----
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> floatShadow = [
    BoxShadow(color: Color(0x26000000), blurRadius: 22, offset: Offset(0, 10)),
  ];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ink,
      brightness: Brightness.light,
    ).copyWith(
      primary: ink,
      surface: card,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: ink,
        titleTextStyle: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 64,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 24, color: selected ? ink : sub);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? ink : sub,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radiusSheet),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  /// 残り時間の色。夜に近づくほど赤くなる。
  static Color remainingColor(double hoursLeft) {
    if (hoursLeft < 1) return const Color(0xFFD90000); // 強い赤
    if (hoursLeft < 3) return todayAccent; // 赤
    if (hoursLeft < 6) return const Color(0xFFF2870E); // オレンジ
    return ink; // 通常
  }

  static Color remainingSoft(double hoursLeft) {
    if (hoursLeft < 3) return todaySoft;
    if (hoursLeft < 6) return const Color(0xFFFFF0DC);
    return boxSoft;
  }

  /// ジャンル候補色
  static const List<int> genrePalette = [
    0xFF5B6470, 0xFFC0392B, 0xFF2E7D9A, 0xFF2E7D32,
    0xFF8E44AD, 0xFFD68910, 0xFF16A085, 0xFF34495E,
  ];
}

/// 数字表示用（等幅）
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];
