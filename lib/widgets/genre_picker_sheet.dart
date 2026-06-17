import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// タスクに紐づけるジャンルを 1 つ選ぶ（なしも可）
class GenrePickerSheet extends StatelessWidget {
  final TaskItem task;
  const GenrePickerSheet({super.key, required this.task});

  static Future<void> present(BuildContext context, TaskItem task) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('ジャンル', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('ジャンルは Settings で作成できます。',
                  style: TextStyle(fontSize: 13, color: AppTheme.sub)),
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
          : const Icon(Icons.block, color: AppTheme.sub, size: 18),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, color: AppTheme.ink) : null,
      onTap: onTap,
    );
  }
}
