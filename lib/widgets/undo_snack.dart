import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// 直前の操作（完了・削除・移動）を取り消せるスナックバーを出す。
/// スワイプ仕分けや完了を、誤操作を恐れず思い切りやれるようにするため。
void showUndoSnack(BuildContext context, String message) {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 3),
    action: SnackBarAction(
      label: '元に戻す',
      onPressed: app.undoLast,
    ),
  ));
}

/// 取り消し不要の短い通知（追加・購入・入力エラーなど）。
///
/// 必ず直前のスナックバーを消してから出す。連続操作でキューに溜まって
/// 「消えずに残り続ける」ように見えるのを防ぎ、短時間で自動的に消える。
void showToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(milliseconds: 2200),
  ));
}
