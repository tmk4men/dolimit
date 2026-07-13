import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/speech_service.dart';
import '../state/app_state.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';
import 'boost_sheet.dart';
import 'pro_sheet.dart';
import 'ui_kit.dart';

/// ＋ から開くタスク追加シート。入力はタスク名のみ。
///
/// 開いていたタブに応じて追加先が決まる：TODAY タブなら TODAY、LATER タブなら
/// LATER、BOX タブなら BOX へ入る（[target]）。
///
/// 音声入力は端末の音声認識（[SpeechService]）を使う。認識が使えない
/// 端末では、キーボードの音声入力ボタンを使えるようフォーカスするだけに
/// フォールバックする。
class AddTaskSheet extends StatefulWidget {
  /// 追加先の枠。開いていたタブから決まる。
  final TaskStatus target;
  const AddTaskSheet({super.key, this.target = TaskStatus.box});

  /// 満杯時はシートを出さずに知らせる。空きがあれば表示。
  /// [onSort] は BOX 満杯アラートの「仕分ける」押下時（BOX タブへ切替）に呼ぶ。
  static Future<void> present(BuildContext context,
      {TaskStatus target = TaskStatus.box, VoidCallback? onSort}) async {
    final app = context.read<AppState>();
    if (app.isFull(target)) {
      if (target == TaskStatus.box) {
        await _showBoxFullAlert(context, onSort);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Limits.fullMessage(target))));
      }
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => AddTaskSheet(target: target),
    );
  }

  static Future<void> _showBoxFullAlert(
      BuildContext context, VoidCallback? onSort) {
    final cap = context.read<AppState>().capacityFor(TaskStatus.box)!;
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('BOXがいっぱいです'),
        content: Text('$cap個たまっています。先に仕分けてください。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onSort?.call();
            },
            child: const Text('仕分ける'),
          ),
          // ブースト（¥100 の買い切り）は購入前だけ出す。
          if (!context.read<AppState>().isBoosted)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                BoostSheet.present(context);
              },
              child: Text('¥100で枠を増やす（+${Limits.boostBonusBox}）'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ProSheet.present(context);
            },
            child: const Text('Proで枠を増やす'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
  }

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _usedVoice = false;

  late final SpeechService _speech = context.read<SpeechService>();
  bool _speechReady = false;
  bool _listening = false;

  /// 認識開始時点の入力内容。認識結果はこの後ろに足す。
  String _textBeforeListening = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _speech.init().then((ok) {
      if (mounted) setState(() => _speechReady = ok);
    });
  }

  @override
  void dispose() {
    // 認識しっぱなしでシートを閉じてもマイクを離す。
    _speech.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// マイクの ON/OFF。認識が使えない端末ではキーボードへフォールバック。
  Future<void> _toggleMic() async {
    if (!_speechReady) {
      // 端末の音声入力キーボードへ誘導する（従来の挙動）。
      setState(() => _usedVoice = true);
      _focus.requestFocus();
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    _textBeforeListening = _controller.text;
    setState(() {
      _usedVoice = true;
      _listening = true;
    });
    // 認識中はキーボードを引っ込めて、声に集中させる。
    _focus.unfocus();

    await _speech.start(
      onResult: (r) {
        if (!mounted) return;
        final joined = _textBeforeListening.isEmpty
            ? r.text
            : '$_textBeforeListening ${r.text}';
        _controller.value = TextEditingValue(
          text: joined,
          selection: TextSelection.collapsed(offset: joined.length),
        );
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  void _add() {
    // 空欄なら閉じも通知もせず、入力を促す。
    if (_controller.text.trim().isEmpty) {
      _focus.requestFocus();
      return;
    }
    final app = context.read<AppState>();
    final target = widget.target;
    final ok = app.add(_controller.text, target,
        source: _usedVoice ? TaskSource.voice : TaskSource.manual);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
        content: Text(ok
            ? '${_label(target)}に追加しました'
            : Limits.fullMessage(target))));
  }

  /// 追加先の枠名（画面文言用）。
  static String _label(TaskStatus target) => switch (target) {
        TaskStatus.today => 'TODAY',
        TaskStatus.later => 'LATER',
        _ => 'BOX',
      };

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    // キーボードで領域が縮んでも入力欄が隠れないようスクロール可能にする。
    // padding の bottom にキーボード高さを足して、シート全体をその上へ乗せる。
    // reverse は使わない：内容が溢れたときは上（タイトル・入力欄）を残し、
    // フォーカス中の入力欄はフレームワークが自動で見える位置へ送る。
    return Padding(
      padding: EdgeInsets.only(bottom: bottom, left: 20, right: 20, top: 6),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 6),
            Text('${_label(widget.target)}に追加',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      hintText: 'やることを入力',
                      filled: true,
                      fillColor: context.c.fill,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleMic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _listening
                          ? context.c.todayAccent
                          : (_usedVoice ? context.c.ink : context.c.fill),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                      color: _listening
                          ? Colors.white
                          : (_usedVoice ? context.c.bg : context.c.ink2),
                    ),
                  ),
                ),
              ],
            ),
            // 認識中だけ状態を出す。ふだんは説明文を出さず、すっきりさせる。
            if (_listening) ...[
              const SizedBox(height: 12),
              Text(
                '聞き取っています… もう一度押すと確定します',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.c.todayAccent),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.c.ink,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _add,
                child: const Text('追加',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
