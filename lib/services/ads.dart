// バナー広告（AdMob）。Web ビルドでは google_mobile_ads（dart:io 依存）を
// 除外する。speech / purchase と同じ条件付きインポートの流儀。
import 'package:flutter/widgets.dart';

import 'ads_stub.dart' if (dart.library.io) 'ads_native.dart' as impl;

/// 広告 SDK の初期化。ネイティブのみ実体があり、Web は no-op。
/// 何度呼んでも初期化は一度だけ走る。
Future<void> initAds() => impl.initAds();

/// 画面下部に置く控えめなバナー。
///
/// - Web / 未対応環境・読込前・失敗時は高さ 0（何も描かない）。
/// - Pro 判定は呼び出し側で行う（Pro のときはこのウィジェット自体を作らない）。
class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) => impl.buildAdBanner(context);
}
