import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 「BOX 8/15」のような数字中心ヘッダー
class CountHeader extends StatelessWidget {
  final String title;
  final int count;
  final int capacity;
  final Color accent;
  const CountHeader({
    super.key,
    required this.title,
    required this.count,
    required this.capacity,
    this.accent = AppTheme.ink,
  });

  bool get isFull => count >= capacity;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 34, fontWeight: FontWeight.w900, color: accent)),
        const SizedBox(width: 8),
        Text('$count/$capacity',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isFull ? AppTheme.todayAccent : AppTheme.sub,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }
}
