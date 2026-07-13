import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/purchase_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import 'ui_kit.dart';

/// 「ブーストで枠を増やす」導線。¥100 の買い切りで、BOX/TODAY/LATER の上限を
/// 恒久的に少し広げる。Pro と重ねがけできる。
///
/// 実際のストア購入は [PurchaseService] のスタブを差し替えるまで「準備中」を返す。
class BoostSheet extends StatefulWidget {
  /// テスト用に差し替える。省略時は環境に応じた実装を作る。
  final PurchaseService? service;

  const BoostSheet({super.key, this.service});

  static Future<void> present(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const BoostSheet(),
    );
  }

  @override
  State<BoostSheet> createState() => _BoostSheetState();
}

class _BoostSheetState extends State<BoostSheet> {
  late final PurchaseService _purchase = widget.service ?? PurchaseService.create();
  bool _busy = false;

  @override
  void dispose() {
    // 自前で作った実装だけ後始末する。注入されたものは所有していない。
    if (widget.service == null) _purchase.dispose();
    super.dispose();
  }

  Future<void> _run(Future<PurchaseResult> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await action();
    if (!mounted) return;
    if (result.unlocked && result.covers(PurchaseService.boostProductId)) {
      app.setBoost(true);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('ブーストを購入しました')));
      return;
    }
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(result.message ?? '購入できませんでした')));
  }

  @override
  Widget build(BuildContext context) {
    final owned = context.select<AppState, bool>((s) => s.isBoosted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.bolt, color: context.c.ink),
              const SizedBox(width: 8),
              const Text('ブーストで枠を増やす',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const Spacer(),
              if (owned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: context.c.ink, borderRadius: AppTheme.radiusPill),
                  child: const Text('購入済み',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text('¥100 の買い切り。ずっと枠が広がります。',
              style: TextStyle(fontSize: 13, color: context.c.sub)),
          const SizedBox(height: 14),
          _row('BOX', Limits.box, Limits.box + Limits.boostBonusBox),
          _row('TODAY', Limits.today, Limits.today + Limits.boostBonusToday),
          _row('LATER', Limits.later, Limits.later + Limits.boostBonusLater),
          const SizedBox(height: 16),
          if (!owned) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.c.ink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _busy ? null : () => _run(_purchase.buyBoost),
                child: _busy
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('¥100で購入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => _run(_purchase.restore),
                child: const Text('購入を復元'),
              ),
            ),
            // 開発用: リリースビルド(kDebugMode=false)では表示されない。
            if (kDebugMode)
              Center(
                child: TextButton(
                  onPressed: () {
                    context.read<AppState>().setBoost(true);
                    Navigator.pop(context);
                  },
                  child: Text('開発用: ブーストを付与（debug）',
                      style: TextStyle(color: context.c.sub)),
                ),
              ),
          ] else if (kDebugMode)
            Center(
              child: TextButton(
                onPressed: () => context.read<AppState>().setBoost(false),
                child: Text('開発用: ブーストを解除して戻す（debug）',
                    style: TextStyle(color: context.c.sub)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, int base, int boosted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w800, color: context.c.ink2)),
          ),
          Text('$base', style: TextStyle(color: context.c.sub)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: context.c.sub),
          ),
          Text('$boosted',
              style: TextStyle(fontWeight: FontWeight.w900, color: context.c.ink)),
        ],
      ),
    );
  }
}
