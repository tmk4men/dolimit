import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ad_service.dart';
import '../state/app_state.dart';

/// 報酬型広告を見せて、視聴し切ったら枠を広げる。
/// 設定画面と BOX 満杯ダイアログの両方から使う。
Future<void> watchAdForBoost(BuildContext context) async {
  final app = context.read<AppState>();
  final ads = context.read<RewardedAdService>();
  final messenger = ScaffoldMessenger.of(context);

  final message = await redeemAdBoost(ads, app.grantAdBoost);
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// ブーストの状態を表す一行。設定画面の副題に使う。
String adBoostSubtitle(AppState app) {
  final left = app.boostRemaining;
  if (left == null) return '24時間だけ BOX+5 / TODAY+2 / LATER+5';
  final hours = left.inHours;
  final minutes = left.inMinutes.remainder(60);
  return '拡張中 — 残り $hours時間$minutes分';
}
