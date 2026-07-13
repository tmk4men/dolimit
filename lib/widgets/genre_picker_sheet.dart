import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// タスクに紐づけるジャンルを 1 つ選ぶ（なしも可）
class GenrePickerSheet extends StatelessWidget {
  final TaskItem task;
  const GenrePickerSheet({super.key, required this.task});

  static Future<void> present(BuildContext context, TaskItem task) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: context.c.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => GenrePickerSheet(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final genres = app.genres;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Text('ジャンル', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          _row(context, app, label: 'ジャンルなし', dot: null, selected: task.genreId == null, onTap: () {
            app.setGenre(task, null);
            Navigator.pop(context);
          }),
          for (final g in genres)
            _row(context, app, label: g.name, dot: g.color, selected: task.genreId == g.id, onTap: () {
              app.setGenre(task, g.id);
              Navigator.pop(context);
            }),
          if (genres.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('ジャンルは設定から作れます。',
                  style: TextStyle(fontSize: 13, color: context.c.sub)),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppState app,
      {required String label, Color? dot, required bool selected, required VoidCallback onTap}) {
    return ListTile(
      leading: dot != null
          ? Container(width: 14, height: 14, decoration: BoxDecoration(color: dot, shape: BoxShape.circle))
          : Icon(Icons.block, color: context.c.sub, size: 18),
      title: Text(label),
      trailing: selected ? Icon(Icons.check, color: context.c.ink) : null,
      onTap: onTap,
    );
  }
}
