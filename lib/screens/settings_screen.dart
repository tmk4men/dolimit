import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pro_sheet.dart';
import 'genre_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        ),

        // 通知
        _section('通知'),
        SwitchListTile(
          activeColor: AppTheme.ink,
          value: s.notificationsEnabled,
          onChanged: (v) async {
            if (v) await app.notifier.requestPermission();
            app.updateSettings((s) => s.notificationsEnabled = v);
          },
          title: const Text('通知を使う'),
          subtitle: const Text('朝・日中・夜の精算・LATER関連のリマインド'),
        ),
        _timeTile(context, app, '朝の確認', s.morning, (t) => s.morning = t),
        _timeTile(context, app, '日中リマインド', s.midday, (t) => s.midday = t),
        _timeTile(context, app, '夜の精算', s.settlement, (t) => s.settlement = t),
        _timeTile(context, app, 'LATER自動移動', s.laterAutoMove, (t) => s.laterAutoMove = t),

        // バッジ
        _section('バッジ'),
        SwitchListTile(
          activeColor: AppTheme.ink,
          value: s.badgeEnabled,
          onChanged: (v) => app.updateSettings((s) => s.badgeEnabled = v),
          title: const Text('アプリアイコンにバッジ'),
          subtitle: const Text('TODAYの未完了数を表示して、見返し忘れを防ぎます。'),
        ),

        // ジャンル
        _section('ジャンル'),
        ListTile(
          leading: const Icon(Icons.tag),
          title: const Text('ジャンル管理'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const GenreManagementScreen())),
        ),

        // データ
        _section('データ'),
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: const Text('データバックアップ'),
          subtitle: const Text('JSONをコピー'),
          onTap: () => _exportDialog(context, app),
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('データ復元'),
          subtitle: const Text('JSONを貼り付けて復元'),
          onTap: () => _importDialog(context, app),
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: AppTheme.todayAccent),
          title: const Text('全データ削除', style: TextStyle(color: AppTheme.todayAccent)),
          onTap: () => _deleteAllDialog(context, app),
        ),

        // Pro / 広告
        _section('Pro / 広告'),
        ListTile(
          leading: const Icon(Icons.workspace_premium),
          title: const Text('Proで枠を増やす'),
          subtitle: Text(s.isPro ? '解除済み' : 'BOX/TODAY/LATER/ジャンルの上限を拡張'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => ProSheet.present(context),
        ),
        ListTile(
          leading: const Icon(Icons.ondemand_video),
          title: const Text('広告で一時的に枠を増やす'),
          onTap: () => _comingSoon(context),
        ),
      ],
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
        child: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.sub, letterSpacing: 1)),
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

  void _exportDialog(BuildContext context, AppState app) {
    final json = app.exportJson();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('バックアップ'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(json, style: const TextStyle(fontSize: 11))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.ink),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('コピーしました')));
            },
            child: const Text('コピー'),
          ),
        ],
      ),
    );
  }

  void _importDialog(BuildContext context, AppState app) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('データ復元'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'バックアップJSONを貼り付け'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.ink),
            onPressed: () {
              final err = app.importJson(controller.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err ?? '復元しました')));
            },
            child: const Text('復元'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _deleteAllDialog(BuildContext context, AppState app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('全データ削除'),
        content: const Text('すべてのタスクとジャンルを削除します。元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
          TextButton(
            onPressed: () { app.deleteAll(); Navigator.pop(ctx); },
            child: const Text('削除', style: TextStyle(color: AppTheme.todayAccent)),
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('今後実装予定'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }
}
