import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/genre.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// ジャンル管理（アプリ全体で最大 5 個）
class GenreManagementScreen extends StatelessWidget {
  const GenreManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final genres = app.genres;

    return Scaffold(
      appBar: AppBar(title: Text('ジャンル  ${genres.length}/${app.genreCap}')),
      floatingActionButton: genres.length >= app.genreCap
          ? null
          : FloatingActionButton(
              backgroundColor: context.c.ink,
              foregroundColor: context.c.bg,
              shape: const CircleBorder(),
              onPressed: () => _editDialog(context, app, null),
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        child: genres.isEmpty
            ? Center(
                child: Text('＋ でジャンルを作成（最大${app.genreCap}個）',
                    style: TextStyle(color: context.c.sub)))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final g in genres)
                    Card(
                      color: context.c.card,
                      elevation: 0,
                      child: ListTile(
                        leading: Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(color: g.color, shape: BoxShape.circle)),
                        title: Text(g.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _editDialog(context, app, g)),
                            IconButton(
                                icon: Icon(Icons.delete, size: 20, color: context.c.todayAccent),
                                onPressed: () => _confirmDelete(context, app, g)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  void _editDialog(BuildContext context, AppState app, Genre? existing) {
    final controller = TextEditingController(text: existing?.name ?? '');
    int color = existing?.colorValue ?? app.suggestedGenreColor();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'ジャンルを追加' : 'ジャンルを編集'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(labelText: '名前')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [
                  for (final c in AppTheme.genrePalette)
                    GestureDetector(
                      onTap: () => setState(() => color = c),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: color == c ? context.c.ink : Colors.transparent, width: 3),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.c.ink),
              onPressed: () {
                if (existing == null) {
                  final err = app.addGenre(controller.text, color);
                  if (err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    return;
                  }
                } else {
                  final err = app.renameGenre(existing, controller.text);
                  if (err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    return;
                  }
                  app.setGenreColor(existing, color);
                }
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  void _confirmDelete(BuildContext context, AppState app, Genre g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「${g.name}」を削除'),
        content: const Text('紐づくタスクはジャンルなしに戻ります。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
          TextButton(
            onPressed: () { app.deleteGenre(g); Navigator.pop(ctx); },
            child: Text('削除', style: TextStyle(color: context.c.todayAccent)),
          ),
        ],
      ),
    );
  }
}
