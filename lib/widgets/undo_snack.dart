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
    duration: const Duration(seconds: 4),
    action: SnackBarAction(
      label: '元に戻す',
      textColor: Colors.white,
      onPressed: app.undoLast,
    ),
  ));
}
