import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import 'pro_sheet.dart';
import 'ui_kit.dart';

/// ＋ から開くタスク追加シート。入力はタスク名のみ。必ず BOX へ。
/// 音声: A案（端末の音声入力キーボードを使えるテキストフィールドにフォーカス）。
class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  /// BOX 満杯時はシートを出さずアラート、空きがあれば表示。
  /// [onSort] は「仕分ける」押下時（BOX タブへ切替）に呼ぶ。
  static Future<void> present(BuildContext context, {VoidCallback? onSort}) async {
    final app = context.read<AppState>();
    if (app.isFull(TaskStatus.box)) {
      await _showBoxFullAlert(context, onSort);
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const AddTaskSheet(),
    );
  }

  static Future<void> _showBoxFullAlert(BuildContext context, VoidCallback? onSort) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('BOXがいっぱいです'),
        content: const Text('15個たまっています。先に仕分けてください。'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); onSort?.call(); },
            child: const Text('仕分ける'),
          ),
          TextButton(
            onPressed: () => _comingSoon(ctx),
            child: const Text('広告で一時的に+5'), // TODO: 広告SDK
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); ProSheet.present(context); },
            child: const Text('Proで枠を増やす'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
  }

  static void _comingSoon(BuildContext ctx) {
    Navigator.pop(ctx);
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('今後実装予定')));
  }

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _usedVoice = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    // 空欄なら閉じも通知もせず、入力を促す。
    if (_controller.text.trim().isEmpty) {
      _focus.requestFocus();
      return;
    }
    final app = context.read<AppState>();
    final ok = app.addToBox(_controller.text, source: _usedVoice ? TaskSource.voice : TaskSource.manual);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
        content: Text(ok ? 'BOXに追加しました' : Limits.fullMessage(TaskStatus.box))));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom, left: 20, right: 20, top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 6),
          const Text('BOXに追加', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: 'やることを入力',
                    filled: true,
                    fillColor: AppTheme.fill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  // A案: 端末の音声入力キーボードへフォーカス（source=voice 扱い）
                  // TODO: 音声認識(speech_to_text)によるフル実装
                  setState(() => _usedVoice = true);
                  _focus.requestFocus();
                },
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _usedVoice ? AppTheme.ink : AppTheme.fill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.mic_none_rounded,
                      color: _usedVoice ? Colors.white : AppTheme.ink2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('BOXに入れる。左右で仕分ける。TODAYで決着。',
              style: TextStyle(fontSize: 12.5, color: AppTheme.sub)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _add,
              child: const Text('追加', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
