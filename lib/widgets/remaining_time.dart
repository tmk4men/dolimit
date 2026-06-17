import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../util/day_clock.dart';

/// 今日の残り時間。1 秒ごとに更新し、夜に近づくほど赤くなる。
class RemainingTime extends StatefulWidget {
  final double fontSize;
  final bool showLabel;
  const RemainingTime({super.key, this.fontSize = 16, this.showLabel = true});

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
    final color = AppTheme.remainingColor(DayClock.remainingHours());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: widget.fontSize + 2, color: color),
        const SizedBox(width: 6),
        Text(
          widget.showLabel
              ? '今日の残り ${DayClock.remainingString()}'
              : DayClock.remainingString(),
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
