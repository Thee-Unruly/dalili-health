import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:denizen_ai/denizen_ai.dart';

/// Educational AI Service powered by the on-device Denizen AI Engine.
/// Provides high-level educational inference workflows (Socratic tutoring,
/// structured summarization, flashcard generation, study plans, research reports, and exam grading).
class OfflineAIService {
  static final OfflineAIService _instance = OfflineAIService._internal();
  static OfflineAIService get instance => _instance;
  OfflineAIService._internal();

  final DenizenAI _denizen = DenizenAI();

  // ─── Local Vector RAG Engine ─────────────────────────────────
  final TFLiteEmbeddingProvider _embeddingProvider = TFLiteEmbeddingProvider();
  final VectorStorageService _storageService = VectorStorageService();
  late final DocumentIngestionService _ingestionService =
      DocumentIngestionService(_embeddingProvider, _storageService);
  bool _isRagInitialized = false;

  TFLiteEmbeddingProvider get embeddingProvider => _embeddingProvider;
  VectorStorageService get storageService => _storageService;
  DocumentIngestionService get ingestionService => _ingestionService;
  bool get isRagInitialized => _isRagInitialized;

  bool get isModelLoaded => _denizen.isModelLoaded;
  OfflineModel? get loadedModel => _denizen.engine.loadedModel;
  String? get loadedModelPath => _denizen.engine.loadedModelPath;

  // ─── Lifecycle ───────────────────────────────────────────────

  Future<void> initialize() async {
    await initializeRag();
  }

  Future<void> initializeRag() async {
    if (_isRagInitialized) return;
    try {
      await _embeddingProvider.initialize();
      if (!_storageService.isInitialized) {
        await _storageService.initialize();
      }
      _isRagInitialized = true;
      debugPrint('✅ OfflineAIService TFLite RAG Engine initialized successfully!');
    } catch (e) {
      debugPrint('⚠️ OfflineAIService RAG init notice: $e');
    }
  }

  Future<bool> loadModel({
    required String modelPath,
    required OfflineModel model,
    dynamic contextParams,
  }) async {
    return _denizen.engine.loadModel(
      modelPath: modelPath,
      model: model,
      contextParams: contextParams,
    );
  }

  Future<void> unloadModel() async {
    await _denizen.engine.unloadModel();
  }

  // ─── Generation Primitives ───────────────────────────────────

  Stream<String> generateResponseStream({
    required String prompt,
    required String systemPrompt,
    int maxTokens = 512,
    double temperature = 0.2,
    double topP = 0.9,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async* {
    if (!_denizen.isModelLoaded) {
      throw Exception('No GGUF AI model loaded. Please activate a model in Settings.');
    }

    final session = _denizen.createSession(
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
    );

    final stream = session.streamChat(prompt);

    await for (final token in stream) {
      yield token;
    }
  }

  /// Creates a dedicated vision session for multimodal reasoning
  DenizenVisionSession createVisionSession({String? systemPrompt}) {
    return DenizenVisionSession(
      systemPrompt: systemPrompt ??
          'You are a brilliant academic research assistant with visual reasoning capabilities. '
          'Analyze photos of textbook diagrams, science experiments, math formulas, historical maps, and documents accurately in clear markdown.',
      aiService: _denizen.engine,
    );
  }

  /// Generate streaming vision response from raw image bytes and user question
  Stream<String> generateVisionStream({
    required Uint8List imageBytes,
    required String prompt,
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.2,
  }) async* {
    if (!_denizen.isModelLoaded) {
      throw Exception('No GGUF AI model loaded. Please activate a vision model in Settings.');
    }
    if (_denizen.engine.loadedMmprojPath == null) {
      throw Exception('Loaded model is not a multimodal vision model. Please activate LFM2.5-VL in Settings.');
    }

    final session = createVisionSession(systemPrompt: systemPrompt);
    yield* session.streamChat(
      imageBytes: imageBytes,
      message: prompt,
      maxTokens: maxTokens,
      temperature: temperature,
    );
  }

  Future<String> generateResponse({
    required String prompt,
    required String systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async {
    if (!_denizen.isModelLoaded) {
      throw Exception('No GGUF AI model loaded. Please activate a model in Settings.');
    }

    final session = _denizen.createSession(
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
    );

    return await session.chat(prompt);
  }

  // ─── JSON Generation (Structured Output) ─────────────────────

  Future<Map<String, dynamic>?> generateJson({
    required String prompt,
    required String systemPrompt,
    int maxTokens = 800,
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final raw = await generateResponse(
          prompt: prompt,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens,
          temperature: 0.2,
        );

        final cleaned = _extractJson(raw);
        if (cleaned != null) {
          return jsonDecode(cleaned) as Map<String, dynamic>;
        }
        debugPrint('⚠️ JSON parse failed attempt $attempt — retrying');
      } catch (e) {
        debugPrint('⚠️ JSON generation error attempt $attempt: $e');
      }
    }
    debugPrint('❌ JSON generation failed after $maxRetries retries');
    return null;
  }

  String? _extractJson(String raw) {
    String cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final firstBrace = cleaned.indexOf('{');
    final firstBracket = cleaned.indexOf('[');

    if (firstBracket != -1 && (firstBrace == -1 || firstBracket < firstBrace)) {
      final lastBracket = cleaned.lastIndexOf(']');
      if (lastBracket > firstBracket) {
        final candidate = cleaned.substring(firstBracket, lastBracket + 1);
        if (candidate.startsWith('[') && candidate.endsWith(']')) {
          return '{"flashcards": $candidate}';
        }
        return candidate;
      }
    }

    if (firstBrace != -1) {
      final lastBrace = cleaned.lastIndexOf('}');
      if (lastBrace > firstBrace) {
        return cleaned.substring(firstBrace, lastBrace + 1);
      }
    }

    return null;
  }

  // ─── Educational Workflows ───────────────────────────────────

  /// Summarize study chunks into structured JSON notes
  Future<Map<String, dynamic>?> summarizeChunks(List<String> chunks) async {
    final context = chunks.join('\n\n---\n\n');

    final jsonResult = await generateJson(
      systemPrompt:
          'You are an expert study assistant. You help students understand '
          'academic material clearly and concisely. Respond in valid JSON format.',
      prompt: '''
Analyze the following study material and return a JSON object:
{
  "title": "short topic title",
  "summary": "2-3 sentence overview",
  "key_concepts": ["concept 1", "concept 2", "concept 3"],
  "exam_focus": ["important point 1", "important point 2"],
  "notes": ["detailed note 1", "detailed note 2"]
}

Study material:
$context
''',
      maxTokens: 600,
    );

    if (jsonResult != null) return jsonResult;

    // Fallback: If JSON decoding fails, request plain text from LLM and format into structured output
    try {
      final rawText = await generateResponse(
        prompt: 'Summarize the core topics and key takeaways from this study material in clear bullet points:\n\n$context',
        systemPrompt: 'You are a concise academic tutor.',
        maxTokens: 500,
      );

      final lines = rawText.split('\n').where((l) => l.trim().isNotEmpty).toList();
      return {
        'title': 'AI Generated Summary',
        'summary': lines.isNotEmpty ? lines.first.replaceAll(RegExp(r'^[•\-\*\d\.\s]+'), '') : rawText,
        'key_concepts': lines.skip(1).take(4).map((l) => l.replaceAll(RegExp(r'^[•\-\*\d\.\s]+'), '')).toList(),
        'notes': [rawText],
      };
    } catch (e) {
      debugPrint('Fallback summary generation failed: $e');
      return null;
    }
  }

  /// Generate flashcards from document material
  Future<List<Map<String, dynamic>>?> generateFlashcards(
    List<String> chunks, {
    int count = 6,
  }) async {
    final context = chunks.join('\n\n---\n\n');

    final result = await generateJson(
      systemPrompt:
          'You are a flashcard generator for students. Create clear question-answer pairs in valid JSON.',
      prompt: '''
Create $count flashcards from this material. Return:
{
  "flashcards": [
    {"q": "question text", "a": "answer text"}
  ]
}

Material:
$context
''',
      maxTokens: 600,
    );

    if (result != null && result['flashcards'] is List) {
      final list = result['flashcards'] as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    // Fallback: Plain text Q&A parsing from LLM
    try {
      final rawText = await generateResponse(
        prompt: 'Create $count flashcard Q&A pairs from this material formatted strictly as:\nQ: [Question]\nA: [Answer]\n\n$context',
        systemPrompt: 'You are a flashcard generator.',
        maxTokens: 500,
      );

      final cards = <Map<String, dynamic>>[];
      final lines = rawText.split('\n');
      String? currentQ;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.toUpperCase().startsWith('Q:')) {
          currentQ = trimmed.substring(2).trim();
        } else if (trimmed.toUpperCase().startsWith('A:') && currentQ != null) {
          final ans = trimmed.substring(2).trim();
          cards.add({'q': currentQ, 'a': ans});
          currentQ = null;
        }
      }

      if (cards.isNotEmpty) return cards;
    } catch (e) {
      debugPrint('Fallback flashcard generation failed: $e');
    }

    return null;
  }

  /// Generate a multi-day study plan
  Future<Map<String, dynamic>?> generateStudyPlan(
    List<String> chunks, {
    int days = 3,
  }) async {
    final context = chunks.take(3).join('\n\n---\n\n');

    final result = await generateJson(
      systemPrompt: 'You are an academic study planner. Return structured JSON study plans.',
      prompt: '''
Create a $days-day study plan for this material. Return:
{
  "plan": [
    {
      "day": 1,
      "focus": "topic name",
      "tasks": ["task 1", "task 2"],
      "duration_minutes": 45
    }
  ],
  "tips": ["study tip 1"]
}

Material:
$context
''',
      maxTokens: 600,
    );

    if (result != null) return result;

    // Fallback: Plain text study plan parsing
    try {
      final rawText = await generateResponse(
        prompt: 'Create a 3-day study plan for this material with daily targets and estimated time:\n\n$context',
        systemPrompt: 'You are an academic study planner.',
        maxTokens: 500,
      );

      return {
        'plan': [
          {'day': 1, 'focus': 'Core Concepts & Definitions', 'tasks': [rawText], 'duration_minutes': 45},
          {'day': 2, 'focus': 'Deep Analysis & Problem Solving', 'tasks': ['Review key formulas & examples'], 'duration_minutes': 45},
          {'day': 3, 'focus': 'Revision & Self-Quiz', 'tasks': ['Test knowledge with active recall'], 'duration_minutes': 30},
        ],
        'tips': ['Break study sessions into 30-minute intervals', 'Test your recall without looking at notes'],
      };
    } catch (e) {
      debugPrint('Fallback study plan failed: $e');
      return null;
    }
  }

  /// Stream Socratic tutoring response with conversation context
  Stream<String> tutorStream({
    required String userMessage,
    required List<String> contextChunks,
    required List<Map<String, String>> history,
    bool socratic = true,
    String language = 'the same language the student uses',
  }) {
    final context = contextChunks.take(2).join('\n\n---\n\n');

    final recentHistory =
        history.length > 6 ? history.sublist(history.length - 6) : history;
    final historyText = recentHistory.map((m) {
      final role = m['role'] == 'user' ? 'Student' : 'Tutor';
      return '$role: ${m["content"]}';
    }).join('\n');

    final prompt = '''
${historyText.isNotEmpty ? "Previous conversation:\n$historyText\n\n" : ""}Student: $userMessage
''';

    final systemPrompt = socratic
        ? 'You are a Socratic tutor helping a student understand their study '
            'material. Never give direct answers — instead ask guiding questions '
            'that help the student think through the problem themselves. '
            'Be encouraging, patient, and concise. Respond in $language. '
            'Use this document as your knowledge base:\n\n$context'
        : 'You are a clear, direct study assistant helping a student understand '
            'their study material. Answer questions plainly, with worked examples '
            'where useful. Be encouraging, patient, and concise. Respond in '
            '$language. Use this document as your knowledge base:\n\n$context';

    return generateResponseStream(
      systemPrompt: systemPrompt,
      prompt: prompt,
      maxTokens: 400,
      temperature: 0.8,
    );
  }

  /// Grade an exam answer against ground truth
  Future<Map<String, dynamic>?> gradeAnswer({
    required String question,
    required String correctAnswer,
    required String studentAnswer,
  }) async {
    return generateJson(
      systemPrompt:
          'You are an exam grader. Grade student answers fairly and provide '
          'constructive feedback. Always respond with valid JSON only.',
      prompt: '''
Grade this student answer:

Question: $question
Correct answer: $correctAnswer
Student answer: $studentAnswer

Return:
{
  "score": 8,
  "max_score": 10,
  "feedback": "explanation of what was right/wrong",
  "correct": true
}
''',
      maxTokens: 300,
    );
  }

  /// Generate a deep research report
  Future<String> generateReport({
    required String topic,
    required String depth,
    required String length,
    required List<String> contextChunks,
  }) async {
    final context = contextChunks.join('\n\n---\n\n');
    final depthGuidance = _getDepthGuidance(depth);
    final lengthGuidance = _getLengthGuidance(length);

    return generateResponse(
      systemPrompt:
          'You are a research expert who writes clear, comprehensive reports. '
          'Your reports are well-structured, accurate, and use the provided '
          'material as the knowledge base. Write in a professional tone.',
      prompt: '''
Write a research report on the following topic:

Topic: $topic
Depth: $depthGuidance
Length: $lengthGuidance

Based on this material:
$context

Structure your report with clear sections including an introduction, main findings, and conclusion.
''',
      maxTokens: _getMaxTokensForLength(length),
      temperature: 0.7,
    );
  }

  String _getDepthGuidance(String depth) {
    switch (depth.toLowerCase()) {
      case 'shallow':
        return 'Surface level overview with basic concepts';
      case 'medium':
        return 'Moderate depth with key points and explanations';
      case 'deep':
        return 'In-depth analysis with detailed explanations and nuances';
      default:
        return 'Moderate depth with key points and explanations';
    }
  }

  String _getLengthGuidance(String length) {
    switch (length.toLowerCase()) {
      case 'short':
        return 'Concise (2-3 pages equivalent)';
      case 'medium':
        return 'Moderate length (4-6 pages equivalent)';
      case 'long':
        return 'Comprehensive (7-10 pages equivalent)';
      default:
        return 'Moderate length (4-6 pages equivalent)';
    }
  }

  int _getMaxTokensForLength(String length) {
    switch (length.toLowerCase()) {
      case 'short':
        return 600;
      case 'medium':
        return 1200;
      case 'long':
        return 2000;
      default:
        return 1200;
    }
  }

  Future<void> stopGeneration() async {
    await _denizen.engine.stopGeneration();
  }

  Future<void> dispose() async {
    await _denizen.engine.dispose();
  }

  bool get isAvailable => Platform.isAndroid && _denizen.isModelLoaded;

  Map<String, dynamic>? getModelInfo() {
    if (!_denizen.isModelLoaded || loadedModel == null) return null;
    return {
      'name': loadedModel!.name,
      'path': loadedModelPath,
      'status': 'loaded',
    };
  }
}
