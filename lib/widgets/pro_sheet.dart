import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/purchase_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import 'boost_sheet.dart';
import 'ui_kit.dart';

/// 「Proで枠を増やす」導線。購入・復元を行い、成功したら [AppState.setPro] で解除。
/// 実際のストア購入は [PurchaseService] のスタブを差し替えるまで「準備中」を返す。
class ProSheet extends StatefulWidget {
  /// テスト用に差し替える。省略時は環境に応じた実装を作る。
  final PurchaseService? service;

  const ProSheet({super.key, this.service});

  static Future<void> present(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const ProSheet(),
    );
  }

  @override
  State<ProSheet> createState() => _ProSheetState();
}

class _ProSheetState extends State<ProSheet> {
  // 省略時はアプリ起動時に温めた共有インスタンスを使う（都度生成しない＝
  // 接続のラグや中断トランザクション取りこぼしを避ける）。破棄もしない。
  late final PurchaseService _purchase =
      widget.service ?? context.read<PurchaseService>();
  bool _busy = false;
  String? _price; // ストアのローカライズ価格（取得できたら表示）

  @override
  void initState() {
    super.initState();
    _purchase.priceOf(PurchaseService.proProductId).then((p) {
      if (mounted) setState(() => _price = p);
    });
  }

  Future<void> _run(Future<PurchaseResult> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await action();
    if (!mounted) return;
    if (result.unlocked && result.covers(PurchaseService.proProductId)) {
      app.setPro(true);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Proを解除しました')));
      return;
    }
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(result.message ?? '購入できませんでした')));
  }

  @override
  Widget build(BuildContext context) {
    final isPro = context.select<AppState, bool>((s) => s.isPro);
    final isBoosted = context.select<AppState, bool>((s) => s.isBoosted);
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
              Icon(Icons.workspace_premium, color: context.c.ink),
              const SizedBox(width: 8),
              const Text('Proで枠を増やす',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const Spacer(),
              if (isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: context.c.ink, borderRadius: AppTheme.radiusPill),
                  child: const Text('解除済み',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _row('BOX', Limits.box, Limits.box + Limits.proBonusBox),
          _row('TODAY', Limits.today, Limits.today + Limits.proBonusToday),
          _row('LATER', Limits.later, Limits.later + Limits.proBonusLater),
          _row('ジャンル', Limits.genre, Limits.genre + Limits.proBonusGenre),
          const SizedBox(height: 16),
          if (!isPro) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.c.ink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _busy ? null : () => _run(_purchase.buyPro),
                child: _busy
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_price == null ? 'Proを購入' : 'Proを購入（$_price）',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                    context.read<AppState>().setPro(true);
                    Navigator.pop(context);
                  },
                  child: Text('開発用: Proを解除（debug）',
                      style: TextStyle(color: context.c.sub)),
                ),
              ),
          ] else if (kDebugMode)
            Center(
              child: TextButton(
                onPressed: () => context.read<AppState>().setPro(false),
                child: Text('開発用: Pro を解除して戻す（debug）',
                    style: TextStyle(color: context.c.sub)),
              ),
            ),
          // ブーストへの相互リンク（未購入時のみ）。
          if (!isBoosted)
            Center(
              child: TextButton(
                onPressed: () => BoostSheet.present(context),
                child: Text('または ¥100 のブースト（買い切り）で少し増やす',
                    style: TextStyle(color: context.c.sub, fontSize: 12.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, int base, int pro) {
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
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: context.c.sub),
          ),
          Text('$pro',
              style: TextStyle(fontWeight: FontWeight.w900, color: context.c.ink)),
        ],
      ),
    );
  }
}
