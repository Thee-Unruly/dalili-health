import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:denizen_ai/denizen_ai.dart' hide OfflineAIService, DocumentIngestionService;
import '../services/offline_ai_service.dart';
import '../src/rag/device_tier.dart';
import '../src/rag/document_ingestion_service.dart';

import '../models/document.dart';

class _ExtractTaskArgs {
  final String path;
  final int typeIndex;
  final int chunkWords;
  final int maxChunks;
  // Pre-extracted text from main thread (Syncfusion can't run in isolate)
  final String? preExtractedText;
  _ExtractTaskArgs(this.path, this.typeIndex, this.chunkWords, this.maxChunks, {this.preExtractedText});
}

class _ExtractTaskResult {
  final String text;
  final List<String> chunks;
  final int? pageCount;
  _ExtractTaskResult(this.text, this.chunks, this.pageCount);
}

/// NOTE: swap the raw-byte PDF regex extraction for a real parser
/// (e.g. syncfusion_flutter_pdf's PdfDocument.extractText()) here.
/// Kept as a placeholder signature since that's a separate, larger change
/// (new dependency, license check) from the tiering/isolate work below.
///
/// NOTE: _ExtractTaskArgs.typeIndex is passed in but currently unused inside
/// this function — extraction branches on file content only. It's dead
/// plumbing left for the Syncfusion PDF wiring, where pdf/docx/txt routing
/// will need to live. Don't remove it until that work is done.
String _extractPdfRegexFast(List<int> bytes) {
  final rawStr = String.fromCharCodes(bytes);
  final sb = StringBuffer();

  final tjRegex = RegExp(r'\(([^)]+)\)\s*Tj', multiLine: true);
  for (final m in tjRegex.allMatches(rawStr)) {
    final g = m.group(1);
    if (g != null && g.trim().isNotEmpty) {
      sb.writeln(g.trim());
    }
  }

  final arrayTjRegex = RegExp(r'\[\s*(((?:\([^)]+\)\s*|-?\d+\s*)+))\]\s*TJ', multiLine: true);
  for (final m in arrayTjRegex.allMatches(rawStr)) {
    final rawGroup = m.group(1) ?? '';
    final innerRegex = RegExp(r'\(([^)]+)\)');
    for (final inner in innerRegex.allMatches(rawGroup)) {
      final text = inner.group(1);
      if (text != null && text.trim().isNotEmpty) {
        sb.write(text.trim());
        sb.write(' ');
      }
    }
    sb.writeln();
  }

  if (sb.length < 50) {
    return _extractPrintableAscii(bytes);
  }

  return sb.toString();
}

String _extractPrintableAscii(List<int> bytes) {
  final rawStr = String.fromCharCodes(bytes);
  final asciiRegex = RegExp(r"[A-Za-z0-9\s.,!?:;()'-]{4,}");
  final sb = StringBuffer();

  for (final m in asciiRegex.allMatches(rawStr)) {
    final s = m.group(0)!.trim();
    if (s.length >= 4 &&
        !s.startsWith('/Font') &&
        !s.startsWith('/ProcSet') &&
        !s.startsWith('/Type') &&
        !s.startsWith('/Catalog') &&
        !s.startsWith('/Pages')) {
      sb.writeln(s);
    }
  }

  return sb.toString();
}

// Runs in a background compute() isolate — NO platform channels allowed here.
// Syncfusion must be called on the main thread before dispatching.
_ExtractTaskResult _isolateExtractTask(_ExtractTaskArgs args) {
  try {
    String text = '';

    // Use pre-extracted text if provided (PDF via Syncfusion on main thread)
    if (args.preExtractedText != null && args.preExtractedText!.trim().isNotEmpty) {
      text = args.preExtractedText!;
    } else {
      // Non-PDF plain text files — safe to read and decode in isolate
      final file = File(args.path);
      if (!file.existsSync()) return _ExtractTaskResult('', [], null);

      final bytes = file.readAsBytesSync();
      final ext = args.path.split('.').last.toLowerCase();

      if (ext == 'pdf') {
        // Syncfusion failed on main thread — try fast regex fallback
        text = _extractPdfRegexFast(bytes);
      } else {
        try {
          text = String.fromCharCodes(bytes).trim();
        } catch (_) {
          text = _extractPrintableAscii(bytes);
        }
      }
    }

    if (text.trim().isEmpty) {
      final fileName = args.path.split('/').last.split('\\').last;
      text = 'Document titled "$fileName". Document imported into Dalili.';
    }

    final sanitized = DocumentProvider.sanitizeText(text);

    // Tier-dependent chunking: window size matching performance tier
    final words = sanitized.split(RegExp(r'\s+'));
    final List<String> chunks = [];
    int start = 0;
    final chunkSize = args.chunkWords;
    final overlap = (chunkSize * 0.15).round();

    while (start < words.length) {
      final end = (start + chunkSize).clamp(0, words.length);
      chunks.add(words.sublist(start, end).join(' '));
      if (end == words.length) break;
      start += chunkSize - overlap;
      if (chunks.length >= args.maxChunks) break;
    }

    return _ExtractTaskResult(sanitized, chunks, null);
  } catch (e) {
    debugPrint('Extraction error: $e');
    return _ExtractTaskResult('', [], null);
  }
}

class DocumentProvider with ChangeNotifier {
  List<Document> _documents = [];
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _isLoading = false;
  String? _error;

  late Box _documentBox;
  final DocumentIngestionService _ingestionService = DocumentIngestionService();

  // Computed once at app launch, then reused for every upload/query decision.
  DeviceTier _cachedDeviceTier = DeviceTier.mid;
  DeviceTier get cachedDeviceTier => _cachedDeviceTier;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  List<Document> get documents {
    return _documents.where((doc) {
      final matchesSearch = doc.name.toLowerCase().contains(_searchQuery.toLowerCase());
      // FIX: was doc.type.extension.toLowerCase() — .extension is display
      // badge text ('IMG', 'FILE') that doesn't map 1:1 onto category ids
      // like 'image'/'other'. .name is the enum's built-in identifier and
      // matches all five DocType values correctly.
      final matchesCategory = _selectedCategory == 'all' ||
          doc.type.name == _selectedCategory.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<Document> get recentUploads {
    final sorted = List<Document>.from(_documents);
    sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return sorted.take(3).toList();
  }

  TFLiteEmbeddingProvider get embeddingProvider => OfflineAIService.instance.embeddingProvider;
  VectorStorageService get storageService => OfflineAIService.instance.storageService;
  bool get isRagReady => OfflineAIService.instance.isRagInitialized;

  // ─────────────────────────────────────────────
  // Init
  // ─────────────────────────────────────────────

  Future<void> init() async {
    _documentBox = await Hive.openBox('documents');
    _loadFromHive();
    await OfflineAIService.instance.initializeRag();
    await _detectAndCacheDeviceTier();
  }

  Future<void> _detectAndCacheDeviceTier() async {
    try {
      final sw = Stopwatch()..start();
      await embeddingProvider.embed('benchmark warmup string');
      sw.stop();

      if (sw.elapsedMilliseconds > 350) {
        _cachedDeviceTier = DeviceTier.low;
      } else if (sw.elapsedMilliseconds > 120) {
        _cachedDeviceTier = DeviceTier.mid;
      } else {
        _cachedDeviceTier = DeviceTier.high;
      }
    } catch (e) {
      _cachedDeviceTier = DeviceTier.mid; // safe default if benchmark fails
    }
    debugPrint('📱 Device tier cached at launch: $_cachedDeviceTier');
  }

  void _loadFromHive() {
    final stored = _documentBox.values.toList();
    _documents = stored
        .map((e) {
          try {
            return Document.fromMap(Map<String, dynamic>.from(e));
          } catch (err) {
            debugPrint('⚠️ Skipping corrupt document entry: $err');
            return null;
          }
        })
        .whereType<Document>()
        .toList();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Upload
  // ─────────────────────────────────────────────

  Future<void> pickAndUploadDocument() async {
    _error = null;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    if (pickedFile.path == null || !File(pickedFile.path!).existsSync()) {
      _error = 'Unable to read selected file';
      notifyListeners();
      return;
    }

    final extension = (pickedFile.extension ?? '').toLowerCase();
    DocType type = DocType.other;
    if (extension == 'pdf') type = DocType.pdf;
    if (extension == 'docx') type = DocType.docx;

    final originalPath = pickedFile.path!;

    final doc = Document(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      name: pickedFile.name,
      type: type,
      sizeBytes: pickedFile.size,
      addedAt: DateTime.now(),
      filePath: originalPath,
      isProcessed: false,
      isIndexed: false,
      chunks: const [],
    );

    // Instant UI update — extraction/embedding happen after this returns.
    _documents.add(doc);
    _saveToHive(doc);
    notifyListeners();

    _copyAndProcessInBackground(doc, originalPath, pickedFile.name);
  }

  Future<void> _copyAndProcessInBackground(
    Document doc,
    String sourcePath,
    String name,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docDir = Directory('${appDir.path}/documents');
      await docDir.create(recursive: true);

      final safeName = name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final savedPath = '${docDir.path}/$safeName';

      final src = File(sourcePath);
      final dest = File(savedPath);
      if (src.path != dest.path) {
        await src.openRead().pipe(dest.openWrite());
      }

      final docWithSavedPath = doc.copyWith(filePath: savedPath);
      await _processDocument(docWithSavedPath);
    } catch (e) {
      debugPrint('Background copy/process notice: $e');
      await _processDocument(doc);
    }
  }

  Future<void> _processDocument(Document doc) async {
    if (doc.filePath == null) return;
    _setLoading(true);

    try {
      final config = DeviceTierConfig.forTier(_cachedDeviceTier);
      final filePath = doc.filePath!;
      final ext = filePath.split('.').last.toLowerCase();

      // ── Step 1: Extract text on main thread (Syncfusion uses platform channels)
      String? preExtractedText;
      if (ext == 'pdf') {
        try {
          final bytes = await File(filePath).readAsBytes();
          final pdfDoc = PdfDocument(inputBytes: bytes);
          preExtractedText = PdfTextExtractor(pdfDoc).extractText();
          pdfDoc.dispose();
          debugPrint('✅ Syncfusion PDF extraction: ${preExtractedText.length} chars');
        } catch (e) {
          debugPrint('⚠️ Syncfusion main-thread PDF extraction failed: $e — will use regex fallback in isolate');
        }
      }

      // ── Step 2: Dispatch chunking to background isolate (text-only, no platform channels)
      final res = await compute(
        _isolateExtractTask,
        _ExtractTaskArgs(
          filePath,
          doc.type.index,
          config.chunkWords,
          config.maxChunks,
          preExtractedText: preExtractedText,
        ),
      );

      if (res.text.isEmpty) {
        _error = 'Could not extract text from ${doc.name}';
        _setLoading(false);
        return;
      }

      final updated = doc.copyWith(
        extractedText: res.text,
        chunks: res.chunks,
        pageCount: res.pageCount,
        isProcessed: true,
      );

      final index = _documents.indexWhere((d) => d.id == doc.id);
      if (index != -1) _documents[index] = updated;
      _saveToHive(updated);
      notifyListeners();

      _dispatchIngestion(updated, config);
    } catch (e) {
      _error = 'Processing failed: $e';
    }

    _setLoading(false);
  }

  /// Tier decides whether embedding happens now (background queue) or is
  /// deferred until the document is actually queried — this is the
  /// load-bearing branch, not just a config value.
  void _dispatchIngestion(Document doc, DeviceTierConfig config) {
    if (config.deferIngestion) {
      debugPrint('⚡ ${_cachedDeviceTier.name} tier: deferring embedding for ${doc.name}');
      return;
    }
    _enqueueIngestion(doc);
  }

  void _enqueueIngestion(Document doc) {
    _ingestionService.enqueue(doc.id, doc.chunks, _cachedDeviceTier, (docId) {
      final idx = _documents.indexWhere((d) => d.id == docId);
      if (idx == -1) return; // deleted mid-ingest; nothing to update
      _documents[idx] = _documents[idx].copyWith(isIndexed: true);
      _saveToHive(_documents[idx]);
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────────
  // Sanitization
  // ─────────────────────────────────────────────

  static String sanitizeText(String text) {
    if (text.isEmpty) return '';
    final buffer = StringBuffer();
    for (final char in text.runes) {
      if ((char >= 32 && char <= 0xD7FF) ||
          (char >= 0xE000 && char <= 0xFFFD) ||
          (char >= 0x10000 && char <= 0x10FFFF) ||
          char == 10 || char == 13 || char == 9) {
        buffer.writeCharCode(char);
      }
    }
    return buffer.toString();
  }

  // ─────────────────────────────────────────────
  // Retrieval — dual path: vector search, BM25-style lexical fallback
  // ─────────────────────────────────────────────

  Future<List<String>> getRelevantChunks(
    String docId,
    String query, {
    int topK = 3,
  }) async {
    final doc = _documents.firstWhere(
      (d) => d.id == docId,
      orElse: () => throw Exception('Document not found'),
    );
    if (doc.chunks.isEmpty) return [];

    if (doc.isIndexed && isRagReady) {
      try {
        final queryVector = await embeddingProvider.embed(query);
        // NOTE: storageService.search() is synchronous — it executes a
        // prepared sqlite statement and returns List<Map<String,dynamic>>
        // directly. No await needed or valid here.
        final vectorResults = storageService.search(queryVector, limit: topK * 2);

        final retrieved = <String>[];
        for (final item in vectorResults) {
          final text = item['text_content'] as String?;
          if (text != null && text.isNotEmpty) retrieved.add(text);
          if (retrieved.length >= topK) break;
        }
        if (retrieved.isNotEmpty) return _capByLength(retrieved);
      } catch (e) {
        debugPrint('⚠️ Vector search failed, falling back to lexical: $e');
      }
    }

    return _lexicalFallback(doc.chunks, query, topK);
  }

  Future<List<MapEntry<Document, List<String>>>> findRelevantAcrossLibrary(
    String query, {
    int topKPerDoc = 2,
    int maxDocs = 3,
  }) async {
    final results = <MapEntry<Document, List<String>>>[];

    for (final doc in _documents) {
      if (!doc.isProcessed || doc.chunks.isEmpty) continue;
      final chunks = await getRelevantChunks(doc.id, query, topK: topKPerDoc);
      if (chunks.isNotEmpty) results.add(MapEntry(doc, chunks));
    }

    results.sort((a, b) => b.value.length.compareTo(a.value.length));
    return results.take(maxDocs).toList();
  }

  List<String> _lexicalFallback(List<String> chunks, String query, int topK) {
    if (chunks.isEmpty) return [];
    final queryWords = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();

    if (queryWords.isEmpty) {
      return _capByLength(chunks.take(topK).toList());
    }

    final scored = chunks.map((chunk) {
      final chunkWords = chunk.toLowerCase().split(RegExp(r'\s+')).toSet();
      final intersection = queryWords.intersection(chunkWords);
      return MapEntry(chunk, intersection.length);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final matched = scored.where((e) => e.value > 0).map((e) => e.key).take(topK).toList();
    if (matched.isNotEmpty) {
      return _capByLength(matched);
    }
    return _capByLength(chunks.take(topK).toList());
  }

  List<String> _capByLength(List<String> chunks, {int maxChars = 1800}) {
    final selected = <String>[];
    int currentLength = 0;
    for (final chunk in chunks) {
      if (currentLength + chunk.length > maxChars && selected.isNotEmpty) break;
      selected.add(chunk);
      currentLength += chunk.length;
    }
    return selected;
  }

  // ─────────────────────────────────────────────
  // Persistence / removal
  // ─────────────────────────────────────────────

  void _saveToHive(Document doc) {
    _documentBox.put(doc.id, doc.toMap());
  }

  Future<void> removeDocument(String id) async {
    // 1. Cancel any in-flight/queued ingestion and purge active worker tasks
    await _ingestionService.cancelIngestion(id);

    // 2. Delete from vector store by title — works whether the doc was
    //    indexed in this session, a previous session, or never indexed.
    try {
      if (isRagReady) {
        storageService.deleteDocumentByTitle(id);
      }
    } catch (e) {
      debugPrint('Notice: vector store delete error for $id: $e');
    }

    _documents.removeWhere((doc) => doc.id == id);
    _documentBox.delete(id);
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // UI helpers
  // ─────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}