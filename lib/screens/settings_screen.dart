import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import '../widgets/boost_sheet.dart';
import '../widgets/pro_sheet.dart';
import 'genre_management_screen.dart';

/// メニュー（ハンバーガー）から開く設定ページ。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // 通知
          _section(context, '通知'),
          SwitchListTile(
            activeColor: context.c.ink,
            value: s.notificationsEnabled,
            onChanged: (v) async {
              if (v) await app.notifier.requestPermission();
              app.updateSettings((s) => s.notificationsEnabled = v);
            },
            title: const Text('通知'),
          ),
          _timeTile(context, app, '朝の確認', s.morning, (t) => s.morning = t),
          _timeTile(context, app, '日中リマインド', s.midday, (t) => s.midday = t),
          _timeTile(context, app, '夜の精算', s.settlement, (t) => s.settlement = t),
          _timeTile(context, app, 'LATER自動移動', s.laterAutoMove, (t) => s.laterAutoMove = t),

          // ジャンル
          _section(context, 'ジャンル'),
          ListTile(
            leading: const Icon(Icons.tag),
            title: const Text('ジャンル管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const GenreManagementScreen())),
          ),

          // 外観（システム / ライト / ダーク）
          _section(context, '外観'),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'system', label: Text('システム')),
                ButtonSegment(value: 'light', label: Text('ライト')),
                ButtonSegment(value: 'dark', label: Text('ダーク')),
              ],
              selected: {s.appearance},
              onSelectionChanged: (sel) => app.setAppearance(sel.first),
            ),
          ),

          // 課金（枠拡張）
          _section(context, '枠を増やす'),
          ListTile(
            leading: const Icon(Icons.workspace_premium),
            title: const Text('Proで枠を増やす'),
            subtitle: Text(s.isPro ? '解除済み' : 'BOX/TODAY/LATER/ジャンルの上限を拡張'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ProSheet.present(context),
          ),
          ListTile(
            leading: const Icon(Icons.bolt),
            title: const Text('ブーストで枠を増やす'),
            subtitle: Text(s.boostPurchased
                ? '購入済み'
                : '¥100の買い切り — BOX+${Limits.boostBonusBox} / TODAY+${Limits.boostBonusToday} / LATER+${Limits.boostBonusLater}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => BoostSheet.present(context),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
        child: Text(title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.c.sub, letterSpacing: 1)),
      );

  Widget _timeTile(BuildContext context, AppState app, String label, TimeOfDayPref pref,
      void Function(TimeOfDayPref) assign) {
    return ListTile(
      leading: const Icon(Icons.schedule),
      title: Text(label),
      trailing: Text(pref.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: pref.hour, minute: pref.minute),
        );
        if (picked != null) {
          app.updateSettings((_) => assign(TimeOfDayPref(picked.hour, picked.minute)));
        }
      },
    );
  }
}
