import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:denizen_ai/denizen_ai.dart' hide ChatMessage;
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../core/utils/text_sanitizer.dart';
import 'document_provider.dart';

class SessionProvider with ChangeNotifier {
  final DenizenAI _denizen = DenizenAI();
  DenizenRagSession? _activeRagSession;
  DenizenSession? _activeStandardSession;

  final List<ChatSession> _sessions = [];
  String _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

  List<ChatMessage> _chatMessages = [];
  bool _isGenerating = false;
  bool _isOffline = true;
  String? _activeDocumentId;
  String _activeSessionTitle = 'Socratic Tutor';
  String _activeSessionMeta = 'Offline · EN';

  late Box _sessionBox;
  bool _isInitialized = false;

  List<ChatMessage> get chatMessages => _chatMessages;
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  String get currentSessionId => _currentSessionId;
  bool get isGenerating => _isGenerating;
  bool get isOffline => _isOffline;
  String get activeSessionTitle => _activeSessionTitle;
  String get activeSessionMeta => _activeSessionMeta;
  String? get activeDocumentId => _activeDocumentId;

  DenizenSession? get _activeSession =>
      _activeRagSession ?? _activeStandardSession;

  void stopGeneration() {
    if (_isGenerating) {
      _denizen.engine.stopGeneration();
      _isGenerating = false;
      _saveSession();
      notifyListeners();
    }
  }

  // ─── Init ────────────────────────────────────────────────────

  Future<void> init() async {
    _sessionBox = await Hive.openBox('tutor_sessions');
    _loadSession();
    _initDenizenSession();
    _isInitialized = true;
    notifyListeners();
  }

  void _initDenizenSession({
    bool socratic = true,
    String language = 'English',
  }) {
    final systemPrompt = socratic
        ? 'You are Dalili, an offline guideline assistant for trained community health workers. Answer only from the guideline passages provided, explain the steps clearly, and say so if the passages do not cover the question. Do not diagnose. Respond in $language.'
        : 'You are Dalili, an offline guideline assistant for trained community health workers. Answer only from the guideline passages provided, briefly. If they do not cover the question, say so. Do not diagnose. Respond in $language.';

    if (_activeDocumentId != null) {
      try {
        final embeddingProvider = TFLiteEmbeddingProvider();
        final storageService = VectorStorageService();
        _activeRagSession = _denizen.createRagSession(
          embeddingProvider: embeddingProvider,
          storageService: storageService,
          baseSystemPrompt: systemPrompt,
          maxTokens: 512,
        );
        _activeStandardSession = null;
        return;
      } catch (e) {
        debugPrint(
            '⚠️ RAG session init failed, falling back to standard session: $e');
      }
    }

    _activeStandardSession = _denizen.createSession(
      systemPrompt: systemPrompt,
      maxTokens: 512,
    );
    _activeRagSession = null;
  }

  ChatMessage _createWelcomeMessage() {
    return ChatMessage(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.ai,
      content:
          "Hello! I'm your Socratic tutor powered by Denizen AI. Upload a document from your Library and ask me anything — I'll guide you through it step-by-step!",
      timestamp: DateTime.now(),
    );
  }

  void _loadSession() {
    _sessions.clear();
    final storedSessions = _sessionBox.get('sessions');

    if (storedSessions != null) {
      final list = List<Map>.from(storedSessions);
      for (final raw in list) {
        try {
          _sessions.add(ChatSession.fromMap(raw));
        } catch (e) {
          debugPrint('⚠️ Error parsing session: $e');
        }
      }
    }

    // Migration from legacy single-session storage
    if (_sessions.isEmpty) {
      final storedLegacy = _sessionBox.get('messages');
      List<ChatMessage> legacyMessages = [];
      if (storedLegacy != null) {
        final list = List<Map>.from(storedLegacy);
        legacyMessages = list.map((e) {
          return ChatMessage(
            id: e['id']?.toString() ?? '',
            role: e['role'] == 'user' ? MessageRole.user : MessageRole.ai,
            content: e['content']?.toString() ?? '',
            timestamp: e['timestamp'] != null
                ? DateTime.tryParse(e['timestamp'].toString()) ?? DateTime.now()
                : DateTime.now(),
            generationSeconds: e['generationSeconds'] != null
                ? (e['generationSeconds'] as num).toDouble()
                : null,
          );
        }).toList();
      }

      if (legacyMessages.isEmpty) {
        legacyMessages = [_createWelcomeMessage()];
      }

      final initialSession = ChatSession(
        id: 'session_${DateTime.now().millisecondsSinceEpoch}',
        title: _sessionBox.get('activeSessionTitle') ?? 'Socratic Tutor',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        activeDocumentId: _sessionBox.get('activeDocumentId'),
        messages: legacyMessages,
      );
      _sessions.add(initialSession);
    }

    // Ensure sessions sorted most recent first
    _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final savedCurrentId = _sessionBox.get('currentSessionId')?.toString();
    ChatSession active = _sessions.first;
    if (savedCurrentId != null) {
      final found = _sessions.where((s) => s.id == savedCurrentId).firstOrNull;
      if (found != null) {
        active = found;
      }
    }

    _currentSessionId = active.id;
    _chatMessages = List.from(active.messages);
    _activeDocumentId = active.activeDocumentId;
    _activeSessionTitle = active.title;
    _activeSessionMeta = 'Offline · EN';
  }

  void _saveSession() {
    final idx = _sessions.indexWhere((s) => s.id == _currentSessionId);
    final updatedSession = ChatSession(
      id: _currentSessionId,
      title: _activeSessionTitle,
      createdAt: idx != -1 ? _sessions[idx].createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
      activeDocumentId: _activeDocumentId,
      activeDocumentName:
          _activeSessionTitle != 'Socratic Tutor' ? _activeSessionTitle : null,
      messages: List.from(_chatMessages),
    );

    if (idx != -1) {
      _sessions[idx] = updatedSession;
    } else {
      _sessions.insert(0, updatedSession);
    }
    _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _sessionBox.put('sessions', _sessions.map((s) => s.toMap()).toList());
    _sessionBox.put('currentSessionId', _currentSessionId);

    // Also sync legacy keys for backwards compatibility
    final legacyList = _chatMessages.map((m) => {
          'id': m.id,
          'role': m.role == MessageRole.user ? 'user' : 'ai',
          'content': m.content,
          'timestamp': m.timestamp.toIso8601String(),
          if (m.generationSeconds != null)
            'generationSeconds': m.generationSeconds,
        }).toList();
    _sessionBox.put('messages', legacyList);
    _sessionBox.put('activeDocumentId', _activeDocumentId);
    _sessionBox.put('activeSessionTitle', _activeSessionTitle);
  }

  // ─── Session Switching & Creation ────────────────────────────

  void startNewSession({String? title}) {
    stopGeneration();
    _saveSession();

    final newId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _currentSessionId = newId;
    _chatMessages = [_createWelcomeMessage()];
    _activeDocumentId = null;
    _activeSessionTitle = title ?? 'Socratic Tutor';
    _activeSessionMeta = 'Offline · EN';

    _initDenizenSession();
    _saveSession();
    notifyListeners();
  }

  void switchSession(String sessionId) {
    if (sessionId == _currentSessionId) return;
    stopGeneration();
    _saveSession();

    final target = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (target == null) return;

    _currentSessionId = target.id;
    _chatMessages = List.from(target.messages);
    _activeDocumentId = target.activeDocumentId;
    _activeSessionTitle = target.title;
    _activeSessionMeta = 'Offline · EN';

    _initDenizenSession();
    _sessionBox.put('currentSessionId', _currentSessionId);
    notifyListeners();
  }

  void deleteSession(String sessionId) {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_sessions.isEmpty) {
      startNewSession();
      return;
    }

    if (_currentSessionId == sessionId) {
      switchSession(_sessions.first.id);
    } else {
      _sessionBox.put('sessions', _sessions.map((s) => s.toMap()).toList());
      notifyListeners();
    }
  }

  // ─── Document Selection ──────────────────────────────────────

  void setActiveDocument(String documentId, String documentName) {
    _activeDocumentId = documentId;
    _activeSessionTitle = documentName;
    _activeSessionMeta = 'Offline · EN';
    _initDenizenSession();
    _saveSession();
    notifyListeners();
  }

  void clearActiveDocument() {
    _activeDocumentId = null;
    _activeSessionTitle = 'Socratic Tutor';
    _activeSessionMeta = 'Offline · EN';
    _initDenizenSession();
    _saveSession();
    notifyListeners();
  }

  // ─── Send Message ────────────────────────────────────────────

  Future<void> sendMessage(
    String text, {
    required DocumentProvider docProvider,
    bool socratic = true,
    String language = 'the same language the student uses',
  }) async {
    final cleanText = text
        .replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F]'), ' ')
        .trim();
    if (cleanText.isEmpty) return;
    if (_isGenerating) return;

    if (!_isInitialized) await init();
    if (_activeSession == null) {
      _initDenizenSession(socratic: socratic, language: language);
    }

    // Add user message and show generating state immediately
    _chatMessages.add(ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.user,
      content: cleanText,
      timestamp: DateTime.now(),
    ));
    _isGenerating = true;

    // Derive an intuitive session title from the first question
    if (_activeSessionTitle == 'Socratic Tutor') {
      final titleCandidate = cleanText.length > 36
          ? '${cleanText.substring(0, 36).trim()}…'
          : cleanText;
      _activeSessionTitle = titleCandidate;
    }
    notifyListeners();

    if (!_denizen.isModelLoaded) {
      _chatMessages.add(ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_ai',
        role: MessageRole.ai,
        content:
            'No model loaded. Please go to Settings to download and activate a model first.',
        timestamp: DateTime.now(),
      ));
      _isGenerating = false;
      _saveSession();
      notifyListeners();
      return;
    }

    // Retrieve RAG chunks if an active document is selected
    List<String> chunks = [];
    if (_activeDocumentId != null) {
      try {
        chunks =
            await docProvider.getRelevantChunks(_activeDocumentId!, cleanText);
      } catch (e) {
        debugPrint('⚠️ RAG chunk retrieval error (non-fatal): $e');
      }
    }

    // Add empty placeholder for streaming AI response
    _chatMessages.add(ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_ai',
      role: MessageRole.ai,
      content: '',
      timestamp: DateTime.now(),
    ));
    notifyListeners();

    final sw = Stopwatch()..start();
    final buffer = StringBuffer();

    try {
      final stream = _activeSession!.streamChat(
        cleanText,
        directChunks: chunks.isNotEmpty ? chunks : null,
      );

      await for (final token in stream) {
        buffer.write(token);
        _updateLastMessage(TextSanitizer.cleanOutput(buffer.toString()));
      }

      sw.stop();
      final sec = sw.elapsedMilliseconds / 1000.0;
      _updateLastMessage(TextSanitizer.cleanOutput(buffer.toString()), generationSeconds: sec);
    } catch (e) {
      sw.stop();
      debugPrint('❌ Tutor streaming error: $e');
      final errorText = buffer.isNotEmpty
          ? '${buffer.toString()}\n\n*(Error: $e)*'
          : 'Sorry, an error occurred during inference: $e';
      _updateLastMessage(errorText);
    } finally {
      _isGenerating = false;
      _saveSession();
      notifyListeners();
    }
  }

  void _updateLastMessage(String content, {double? generationSeconds}) {
    if (_chatMessages.isEmpty) return;
    final last = _chatMessages.last;
    _chatMessages[_chatMessages.length - 1] = ChatMessage(
      id: last.id,
      role: last.role,
      content: content,
      timestamp: last.timestamp,
      language: last.language,
      model: last.model,
      citation: last.citation,
      generationSeconds: generationSeconds ?? last.generationSeconds,
    );
    notifyListeners();
  }

  // ─── Status & Management ─────────────────────────────────────

  void toggleOffline() {
    _isOffline = !_isOffline;
    notifyListeners();
  }

  void clearChat() {
    stopGeneration();
    _initDenizenSession();
    _chatMessages = [
      ChatMessage(
        id: 'welcome',
        role: MessageRole.ai,
        content:
            'Session reset. Socratic tutor is ready. What would you like to explore?',
        timestamp: DateTime.now(),
      ),
    ];
    _saveSession();
    notifyListeners();
  }

  void updateActiveSession(String title, String meta) {
    _activeSessionTitle = title;
    _activeSessionMeta = meta;
    notifyListeners();
  }
}
