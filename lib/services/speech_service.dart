// 音声入力。端末の音声認識で「やること」を書き起こす。
//
// Web ビルドでは speech_to_text（dart:io 依存）を除外する。
import 'speech_factory_stub.dart'
    if (dart.library.io) 'speech_factory_native.dart' as impl;

/// 認識中の途中経過。[isFinal] が true なら確定。
class SpeechResult {
  final String text;
  final bool isFinal;
  const SpeechResult(this.text, {required this.isFinal});
}

/// 音声認識の抽象。
///
/// - Web / 未対応環境では [StubSpeechService]（常に利用不可）
/// - Android/iOS では `NativeSpeechService`（speech_to_text）
///
/// 利用不可のときは呼び出し側がキーボードの音声入力へフォールバックする。
abstract class SpeechService {
  /// 認識エンジンの初期化とマイク権限の要求。使える見込みなら true。
  /// 何度呼んでもよい（初期化は一度だけ走る）。
  Future<bool> init();

  /// 直近の [init] の結果。未初期化なら false。
  bool get isAvailable;

  bool get isListening;

  /// 認識を開始する。[onResult] は途中経過と確定の両方で呼ばれる。
  /// [onDone] は認識が終わった（確定・沈黙・エラー）ときに呼ばれる。
  Future<void> start({
    required void Function(SpeechResult result) onResult,
    void Function()? onDone,
  });

  /// 認識を止めて、それまでの結果を確定させる。
  Future<void> stop();

  /// 認識を破棄する（結果を使わない）。
  Future<void> cancel();

  static SpeechService create() => impl.createSpeechService();
}

/// Web / 未対応環境向け。常に利用不可を返す。
class StubSpeechService implements SpeechService {
  const StubSpeechService();

  @override
  Future<bool> init() async => false;

  @override
  bool get isAvailable => false;

  @override
  bool get isListening => false;

  @override
  Future<void> start({
    required void Function(SpeechResult result) onResult,
    void Function()? onDone,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}
