import 'speech_service.dart';

/// Web（dart:io 不可）向けのファクトリ。speech_to_text を参照しない。
SpeechService createSpeechService() => const StubSpeechService();
