import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_service.dart';

/// speech_to_text による音声認識。
///
/// 権限が無い・認識エンジンが無い端末では [isAvailable] が false になり、
/// 呼び出し側はキーボードの音声入力へフォールバックする。
class NativeSpeechService implements SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _initialized = false;
  bool _available = false;

  /// 沈黙がこれだけ続いたら確定する。
  static const Duration _pauseFor = Duration(seconds: 3);

  /// 1 回の認識の上限。長押しっぱなしでも止まる。
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
      _available = await _speech.initialize(
        onError: (e) => debugPrint('NativeSpeechService: ${e.errorMsg}'),
        // debugLogging は既定 false。ここでは何も購読しない。
      );
    } catch (e) {
      debugPrint('NativeSpeechService: initialize failed: $e');
      _available = false;
    }
    return _available;
  }

  @override
  Future<void> start({
    required void Function(SpeechResult result) onResult,
    void Function()? onDone,
  }) async {
    if (!await init()) return;
    if (_speech.isListening) return;

    var finished = false;
    void finish() {
      if (finished) return;
      finished = true;
      onDone?.call();
    }

    try {
      await _speech.listen(
        onResult: (r) => onResult(
            SpeechResult(r.recognizedWords, isFinal: r.finalResult)),
        listenFor: _listenFor,
        pauseFor: _pauseFor,
        localeId: 'ja_JP',
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      // listen は即座に返る。停止は statusListener で拾う。
      _speech.statusListener = (status) {
        if (status == 'done' || status == 'notListening') finish();
      };
    } catch (e) {
      debugPrint('NativeSpeechService: listen failed: $e');
      finish();
    }
  }

  @override
  Future<void> stop() async {
    if (!_speech.isListening) return;
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    if (!_speech.isListening) return;
    await _speech.cancel();
  }
}
