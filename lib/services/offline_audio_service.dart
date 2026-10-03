import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

/// Service for audio transcription (system speech-to-text / Whisper) and text-to-speech (flutter_tts).
class OfflineAudioService {
  static final OfflineAudioService _instance = OfflineAudioService._internal();
  static OfflineAudioService get instance => _instance;

  factory OfflineAudioService() => _instance;

  OfflineAudioService._internal();

  Whisper? _whisper;
  bool _isWhisperLoaded = false;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isSpeechInitialized = false;

  bool get isWhisperLoaded => _isWhisperLoaded;
  bool get isSpeechInitialized => _isSpeechInitialized;

  /// Initialize system Text-to-Speech (flutter_tts)
  Future<void> initTts() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('❌ Failed to initialize FlutterTts: $e');
    }
  }

  /// Speak text out loud using system TTS engine (flutter_tts)
  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      if (text.isNotEmpty) {
        await _tts.speak(text);
      }
    } catch (e) {
      debugPrint('❌ TTS Speak Error: $e');
    }
  }

  /// Stop current TTS playback
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('❌ TTS Stop Error: $e');
    }
  }

  String _accumulatedText = '';
  String _currentUtterance = '';

  /// Initialize native system speech recognition (speech_to_text)
  Future<bool> initSpeech({Function(bool isListening)? onListeningChanged}) async {
    if (_isSpeechInitialized) return true;
    try {
      _isSpeechInitialized = await _speech.initialize(
        onError: (val) {
          debugPrint('STT Error: $val');
          onListeningChanged?.call(false);
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'notListening' || status == 'done') {
            onListeningChanged?.call(false);
          }
        },
      );
      return _isSpeechInitialized;
    } catch (e) {
      debugPrint('❌ Speech to Text init failed: $e');
      return false;
    }
  }

  /// Listen to speech from the microphone using system Speech-to-Text
  Future<void> startListening({
    required Function(String recognizedText, bool isFinal) onResult,
    String initialText = '',
    Function(bool isListening)? onListeningChanged,
    Duration pauseFor = const Duration(seconds: 10),
    Duration listenFor = const Duration(minutes: 5),
  }) async {
    bool available = await initSpeech(onListeningChanged: onListeningChanged);
    if (available) {
      _accumulatedText = initialText.trim();
      _currentUtterance = '';

      await _speech.listen(
        onResult: (result) {
          _currentUtterance = result.recognizedWords.trim();

          String full;
          if (_accumulatedText.isEmpty) {
            full = _currentUtterance;
          } else if (_currentUtterance.isEmpty) {
            full = _accumulatedText;
          } else {
            full = '$_accumulatedText $_currentUtterance';
          }

          if (result.finalResult && _currentUtterance.isNotEmpty) {
            _accumulatedText = full;
            _currentUtterance = '';
          }

          onResult(full, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          listenFor: listenFor,
          pauseFor: pauseFor,
        ),
      );
    } else {
      onResult("Speech recognition not available on device.", true);
      onListeningChanged?.call(false);
    }
  }

  /// Stop listening to microphone
  Future<void> stopListening() async {
    _accumulatedText = '';
    _currentUtterance = '';
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Load a Whisper GGML model from device storage if using offline Whisper file
  Future<bool> loadWhisperModel({WhisperModel modelType = WhisperModel.base, String? modelDir}) async {
    try {
      _whisper = Whisper(model: modelType, modelDir: modelDir);
      _isWhisperLoaded = true;
      debugPrint('✅ Whisper model initialized for ${modelType.modelName}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to load Whisper model: $e');
      _isWhisperLoaded = false;
      return false;
    }
  }

  /// Transcribe a 16kHz WAV file using Whisper if loaded
  Future<String> transcribeAudio(String audioFilePath) async {
    if (!_isWhisperLoaded || _whisper == null) {
      return "Whisper model not loaded. Use system speech-to-text instead.";
    }

    try {
      debugPrint('🎙️ Transcribing audio file: $audioFilePath');
      final result = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioFilePath,
          language: "en",
          isTranslate: false,
          isNoTimestamps: true,
        ),
      );
      
      return result.text;
    } catch (e) {
      debugPrint('❌ Transcription error: $e');
      return "Error during transcription: $e";
    }
  }
}
