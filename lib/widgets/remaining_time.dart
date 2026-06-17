import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../util/day_clock.dart';

/// 今日の残り時間。30 秒ごとに更新し、夜に近づくほど赤くなる。
class RemainingTime extends StatefulWidget {
  final double fontSize;
  final bool showLabel;
  final bool pill;
  const RemainingTime({super.key, this.fontSize = 16, this.showLabel = true, this.pill = true});

  @override
  State<RemainingTime> createState() => _RemainingTimeState();
}

class _RemainingTimeState extends State<RemainingTime> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = DayClock.remainingHours();
    final color = AppTheme.remainingColor(hours);
    final soft = AppTheme.remainingSoft(hours);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bolt, size: widget.fontSize + 2, color: color),
        const SizedBox(width: 5),
        Text(
          widget.showLabel
              ? '今日の残り ${DayClock.remainingString()}'
              : DayClock.remainingString(),
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.2,
            fontFeatures: kTabular,
          ),
        ),
      ],
    );

    if (!widget.pill) return content;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: soft, borderRadius: AppTheme.radiusPill),
      child: content,
    );
  }
}
