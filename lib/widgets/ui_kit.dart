import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 押すと軽く沈むカード（少しゲーム感のある操作感）
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color; // null なら現在テーマのカード色
  final List<BoxShadow> shadow;
  final BorderRadius radius;
  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.shadow = AppTheme.cardShadow,
    this.radius = AppTheme.radiusCard,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.color ?? context.c.card,
            borderRadius: widget.radius,
            boxShadow: _down ? AppTheme.cardShadow.take(1).toList() : widget.shadow,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 残量バー（count/cap）。満杯に近づくと赤。
class CapacityBar extends StatelessWidget {
  final int count;
  final int capacity;
  final Color color;
  final double height;
  const CapacityBar({
    super.key,
    required this.count,
    required this.capacity,
    required this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = capacity == 0 ? 0.0 : (count / capacity).clamp(0.0, 1.0);
    final full = count >= capacity;
    final fillColor = full ? context.c.todayAccent : color;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: context.c.line),
          LayoutBuilder(
            builder: (_, c) => AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              height: height,
              width: c.maxWidth * ratio,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// BOX / TODAY / LATER 共通の大見出しヘッダー
class ScreenHeader extends StatelessWidget {
  final String title;
  final int count;
  final int capacity;
  final Color? barColor;
  final String? caption; // 下の短い一言
  final Color? captionColor;
  final Widget? trailing; // 残り時間など
  final Widget? action; // 右端のメニューなど
  const ScreenHeader({
    super.key,
    required this.title,
    required this.count,
    required this.capacity,
    this.barColor,
    this.caption,
    this.captionColor,
    this.trailing,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final full = count >= capacity;
    // 満杯が近いときだけ「/上限」とバーで警告する。普段は件数だけ見せて軽くする。
    final nearFull = isNearCapacity(count, capacity);
    final bar = barColor ?? context.c.ink2;
    final capColor = captionColor ?? context.c.sub;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: context.c.ink)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: full ? context.c.todaySoft : context.c.boxSoft,
                  borderRadius: AppTheme.radiusPill,
                ),
                child: Text('$count/$capacity',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: full ? context.c.todayAccent : context.c.ink2,
                        fontFeatures: kTabular)),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
              if (action != null) ...[
                const SizedBox(width: 4),
                action!,
              ],
            ],
          ),
          if (nearFull) ...[
            const SizedBox(height: 10),
            CapacityBar(count: count, capacity: capacity, color: bar),
          ],
          if (caption != null) ...[
            SizedBox(height: nearFull ? 8 : 10),
            Text(caption!, style: TextStyle(fontSize: 12.5, color: capColor)),
          ],
        ],
      ),
    );
  }
}

/// 満杯が近いか（上限の 80% 以上）。普段は件数だけ、近づいたらバー＋色で警告する
/// 判断に共通で使う。
bool isNearCapacity(int count, int capacity) =>
    capacity > 0 && count / capacity >= 0.8;

/// 小さなラベルピル
class AccentPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;
  const AccentPill(this.text, {super.key, required this.color, required this.background, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 10 : 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: AppTheme.radiusPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// ボトムシート上部のつまみ
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(color: context.c.line, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

/// セクション見出し（Settings など）
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w800, color: context.c.sub, letterSpacing: 1.2)),
    );
  }
}

/// 空状態（線画アイコン＋短文）
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: context.c.boxSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: context.c.sub),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.c.ink)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: context.c.sub)),
            ],
          ],
        ),
      ),
    );
  }
}
