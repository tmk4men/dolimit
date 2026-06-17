import 'package:flutter/material.dart';

/// 白 / 黒 / グレー基調。TODAY の残り時間だけ赤、LATER だけ青を使う。
class AppTheme {
  static const Color ink = Color(0xFF111111);
  static const Color sub = Color(0xFF8A8A8E);
  static const Color line = Color(0x33000000);

  static const Color boxAccent = Color(0xFF8A8A8E);
  static const Color todayAccent = Color(0xFFEB4D3B); // 赤〜オレンジ
  static const Color laterAccent = Color(0xFF337BEB); // 青

  static const double cardRadius = 18;
  static const double spacing = 16;

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        brightness: Brightness.light,
      ).copyWith(primary: ink, surface: const Color(0xFFF6F6F7)),
      scaffoldBackgroundColor: const Color(0xFFF2F2F4),
      fontFamily: 'Hiragino Sans',
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: ink,
      ),
      cardColor: Colors.white,
    );
  }

  /// 残り時間の色。夜に近づくほど赤くなる。
  static Color remainingColor(double hoursLeft) {
    if (hoursLeft < 1) return const Color(0xFFD90000); // 強い赤
    if (hoursLeft < 3) return todayAccent; // 赤
    if (hoursLeft < 6) return const Color(0xFFF2A100); // オレンジ
    return ink; // 通常
  }

  /// ジャンル候補色（モノクロ基調を崩さない範囲の彩度）
  static const List<int> genrePalette = [
    0xFF5B6470, 0xFFC0392B, 0xFF2E7D9A, 0xFF2E7D32,
    0xFF8E44AD, 0xFFD68910, 0xFF16A085, 0xFF34495E,
  ];
}
