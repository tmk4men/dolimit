import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart' show appNavigatorKey;
import '../models/enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import 'boost_sheet.dart';
import 'pro_sheet.dart';
import 'ui_kit.dart';

/// 上限に当たったことを知らせつつ、「枠を増やす」導線を添えたスナックバー。
///
/// Pro・ブーストの両方が解放済みなら導線は出さず、ただ知らせるだけにする
/// （それ以上増やせないため）。呼び出し元でシートを閉じた直後でも動くよう、
/// アプリのルート Navigator の context を使う。
void showCapacityFullSnack(BuildContext context, TaskStatus target) {
  final ctx = appNavigatorKey.currentContext ?? context;
  final app = ctx.read<AppState>();
  final canUpgrade = !(app.isPro && app.isBoosted);
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(Limits.fullMessage(target)),
    action: canUpgrade
        ? SnackBarAction(label: '枠を増やす', onPressed: showUpgradeSheet)
        : null,
  ));
}

/// 「枠を増やす」ハブ。ブースト(¥100・恒久)と Pro を並べて選ばせる。
/// どこからでも呼べるようルート Navigator の context を使う。
void showUpgradeSheet() {
  final ctx = appNavigatorKey.currentContext;
  if (ctx == null) return;
  showModalBottomSheet(
    context: ctx,
    backgroundColor: ctx.c.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _UpgradeSheet(),
  );
}

class _UpgradeSheet extends StatelessWidget {
  const _UpgradeSheet();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 8),
          const Text('枠を増やす',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('広告なし。買い切りだけ。',
              style: TextStyle(fontSize: 13, color: context.c.sub)),
          const SizedBox(height: 14),
          if (!app.isBoosted)
            _Option(
              icon: Icons.bolt,
              title: 'ブースト ¥100（買い切り）',
              subtitle:
                  'BOX+${Limits.boostBonusBox} / TODAY+${Limits.boostBonusToday} / LATER+${Limits.boostBonusLater} を恒久追加',
              onTap: () => _openThen(context, BoostSheet.present),
            ),
          if (!app.isBoosted) const SizedBox(height: 10),
          _Option(
            icon: Icons.workspace_premium,
            title: app.isPro ? 'Pro（解除済み）' : 'Pro（買い切り）',
            subtitle: 'BOX/TODAY/LATER/ジャンルの上限をさらに拡張',
            onTap: app.isPro ? null : () => _openThen(context, ProSheet.present),
          ),
        ],
      ),
    );
  }

  /// このハブを閉じてから、選んだ購入シートを開く。
  void _openThen(
      BuildContext context, Future<void> Function(BuildContext) present) {
    Navigator.pop(context);
    final c = appNavigatorKey.currentContext;
    if (c != null) present(c);
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      color: context.c.fill,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: context.c.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: context.c.sub)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: context.c.sub, size: 20),
        ],
      ),
    );
  }
}
