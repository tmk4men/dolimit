import 'speech_service.dart';
import 'native_speech_service.dart';

/// Android/iOS 向けのファクトリ。
SpeechService createSpeechService() => NativeSpeechService();
