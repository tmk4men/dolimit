import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

bool _initStarted = false;

/// SDK 初期化は一度だけ。runApp 前に待つと起動が遅い環境で止まって見えるため、
/// 呼び出し側は await せず投げっぱなしにしてよい。
Future<void> initAds() async {
  if (_initStarted) return;
  _initStarted = true;
  await MobileAds.instance.initialize();
}

Widget buildAdBanner(BuildContext context) => const _NativeBanner();

/// 使用する広告ユニット ID。
///
/// - デバッグ中は必ず Google のテスト ID を使う（自分の本番ユニットを叩くと
///   無効なトラフィックとして AdMob 停止の対象になる）。
/// - iOS の本番はやっとこのバナーユニット。
/// - Android の本番ユニットはまだ未発行。発行したらここへ差し替える。
///   それまではテスト ID のまま（実収益なし・ポリシー安全）。
String _bannerUnitId() {
  if (kDebugMode) {
    return Platform.isIOS
        ? 'ca-app-pub-3940256099942544/2934735716' // iOS テストバナー
        : 'ca-app-pub-3940256099942544/6300978111'; // Android テストバナー
  }
  if (Platform.isIOS) {
    return 'ca-app-pub-2783540275927131/4693613965'; // 本番: やっとこ iOS バナー
  }
  // Android 本番ユニットが未発行のため、当面テスト ID。
  return 'ca-app-pub-3940256099942544/6300978111';
}

class _NativeBanner extends StatefulWidget {
  const _NativeBanner();

  @override
  State<_NativeBanner> createState() => _NativeBannerState();
}

class _NativeBannerState extends State<_NativeBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 幅が確定してから 1 回だけ読み込む。
    if (_ad == null) _load();
  }

  Future<void> _load() async {
    final width = MediaQuery.of(context).size.width.truncate();
    // 画面幅にフィットするアンカー型アダプティブバナー。
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait, width);
    if (size == null || !mounted) return;
    final ad = BannerAd(
      size: size,
      adUnitId: _bannerUnitId(),
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        // 失敗時は破棄して高さ 0 のまま。UI を邪魔しない。
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    // 読込前・失敗時は場所を取らない（レイアウトのガタつきも防ぐ）。
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: ad.size.height.toDouble(),
        child: Center(
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
