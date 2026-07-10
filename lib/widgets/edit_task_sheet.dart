import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// タスク名（とメモ）の編集
class EditTaskSheet extends StatefulWidget {
  final TaskItem task;
  const EditTaskSheet({super.key, required this.task});

  static Future<void> present(BuildContext context, TaskItem task) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => EditTaskSheet(task: task),
    );
  }

  @override
  State<EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<EditTaskSheet> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _memo = TextEditingController(text: widget.task.memo ?? '');

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom + 16, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 6),
          const Text('編集', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'タスク名'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memo,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(labelText: 'メモ（任意）'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.ink),
              onPressed: () {
                // 空欄のまま保存すると setTitle が黙って無視するので、
                // 「保存した」と誤解させないようここで止める。
                if (_title.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('タスク名を入力してください')));
                  return;
                }
                final app = context.read<AppState>();
                app.setTitle(widget.task, _title.text);
                app.setMemo(widget.task, _memo.text);
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}
