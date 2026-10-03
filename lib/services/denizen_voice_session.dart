import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'offline_audio_service.dart';
import 'dart:io';

/// A session specifically designed for voice interactions (Speech-to-Text & Text-to-Speech).
class DenizenVoiceSession {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final String _systemPrompt;
  bool _isRecording = false;

  DenizenVoiceSession({String? systemPrompt})
      : _systemPrompt = systemPrompt ?? 'You are a helpful voice assistant.' {
    OfflineAudioService.instance.initTts();
  }

  /// System prompt configured for this voice session.
  String get systemPrompt => _systemPrompt;

  bool get isRecording => _isRecording;

  /// Speak text out loud using system Text-to-Speech (flutter_tts)
  Future<void> speak(String text) async {
    await OfflineAudioService.instance.speak(text);
  }

  /// Stop current Text-to-Speech playback
  Future<void> stopSpeaking() async {
    await OfflineAudioService.instance.stopSpeaking();
  }

  /// Start live system speech recognition (Speech-to-Text)
  /// Accumulates across pauses and updates full transcript.
  Future<void> startListening({
    required Function(String text) onResult,
    String initialText = '',
    Function(bool isListening)? onListeningChanged,
    Duration pauseFor = const Duration(seconds: 10),
    Duration listenFor = const Duration(minutes: 5),
  }) async {
    _isRecording = true;
    await OfflineAudioService.instance.startListening(
      onResult: (text, isFinal) => onResult(text),
      initialText: initialText,
      onListeningChanged: (listening) {
        _isRecording = listening;
        onListeningChanged?.call(listening);
      },
      pauseFor: pauseFor,
      listenFor: listenFor,
    );
  }

  /// Stop live system speech recognition
  Future<void> stopListening() async {
    _isRecording = false;
    await OfflineAudioService.instance.stopListening();
  }

  /// Start recording audio from the microphone to WAV
  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'denizen_voice_temp.wav');
      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 16 * 16000,
        ),
        path: path,
      );
      _isRecording = true;
    } else {
      throw Exception('Microphone permission denied.');
    }
  }

  /// Stop recording and transcribe the audio (using Whisper if loaded)
  Future<String> stopAndTranscribe() async {
    if (!_isRecording) return "";
    
    final path = await _audioRecorder.stop();
    _isRecording = false;
    
    if (path != null && await File(path).exists()) {
      final transcription = await OfflineAudioService.instance.transcribeAudio(path);
      return transcription;
    }
    
    return "Error: No audio recorded.";
  }

  /// Transcribe a pre-existing audio file
  Future<String> transcribeFile(String filePath) async {
    return await OfflineAudioService.instance.transcribeAudio(filePath);
  }
}
