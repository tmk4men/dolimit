import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_service.dart';

/// speech_to_text による音声認識。
///
/// 権限が無い・認識エンジンが無い端末では [isAvailable] が false になり、
/// 呼び出し側はキーボードの音声入力へフォールバックする。
class NativeSpeechService implements SpeechService {
  NativeSpeechService({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;

  bool _initialized = false;
  bool _available = false;

  /// 進行中の認識の終了通知。終わったら null に戻す。
  void Function()? _onDone;

  /// 沈黙がこれだけ続いたら確定する。
  static const Duration _pauseFor = Duration(seconds: 3);

  /// 1 回の認識の上限。押しっぱなしでも止まる。
  static const Duration _listenFor = Duration(seconds: 30);

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> init() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      // ステータス・エラーの購読は initialize で済ませる。listen() の後に
      // 代入すると、待機中に飛んでくる通知を取りこぼす。
      _available = await _speech.initialize(
        onStatus: _handleStatus,
        onError: (e) {
          debugPrint('NativeSpeechService: ${e.errorMsg}');
          _finish();
        },
      );
    } catch (e) {
      debugPrint('NativeSpeechService: initialize failed: $e');
      _available = false;
    }
    return _available;
  }

  /// `done` は「結果を出し切った」合図。`notListening` はマイクを離しただけで
  /// まだ確定結果が来ていない可能性があるため、終了とはみなさない。
  void _handleStatus(String status) {
    if (status == stt.SpeechToText.doneStatus) _finish();
  }

  void _finish() {
    final callback = _onDone;
    _onDone = null;
    callback?.call();
  }

  @override
  Future<void> start({
    required void Function(SpeechResult result) onResult,
    void Function()? onDone,
  }) async {
    if (!await init()) return;
    if (_speech.isListening) return;

    _onDone = onDone;
    try {
      // listen() の listenFor / pauseFor / localeId 引数は非推奨。
      // すべて SpeechListenOptions 側に寄せる。
      await _speech.listen(
        onResult: (r) =>
            onResult(SpeechResult(r.recognizedWords, isFinal: r.finalResult)),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
          listenFor: _listenFor,
          pauseFor: _pauseFor,
          localeId: 'ja_JP',
        ),
      );
    } catch (e) {
      debugPrint('NativeSpeechService: listen failed: $e');
      _finish();
    }
  }

  @override
  Future<void> stop() async {
    if (!_speech.isListening) return;
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    // 結果を捨てるので、待っている側にも終わりを伝える。
    _onDone = null;
    if (!_speech.isListening) return;
    await _speech.cancel();
  }
}
