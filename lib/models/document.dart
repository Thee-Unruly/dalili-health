enum DocType { pdf, pptx, docx, image, other }

extension DocTypeExt on DocType {
  // NOTE: no custom `name` getter here on purpose. Dart enums have had a
  // built-in `.name` instance member since 2.15 (DocType.image.name ==
  // 'image'), and instance members always win over extension members with
  // the same name — so a `name` getter on this extension would be silently
  // unreachable. Use the built-in `doc.type.name` wherever you need the
  // raw identifier (e.g. for filter-key comparisons); use `.extension`
  // below only for the display badge text.

  /// Display-only badge text (e.g. shown in a document card / chip).
  /// Do NOT use this for category-filter comparisons — it doesn't map
  /// 1:1 to the enum's own identifiers (IMG != image, FILE != other).
  String get extension {
    switch (this) {
      case DocType.pdf:   return 'PDF';
      case DocType.pptx:  return 'PPTX';
      case DocType.docx:  return 'DOCX';
      case DocType.image: return 'IMG';
      case DocType.other: return 'FILE';
    }
  }

  static DocType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PDF':   return DocType.pdf;
      case 'PPTX':  return DocType.pptx;
      case 'DOCX':  return DocType.docx;
      case 'IMG':   return DocType.image;
      default:      return DocType.other;
    }
  }
}

class Document {
  final String id;
  final String name;
  final DocType type;
  final int sizeBytes;
  final DateTime addedAt;

  final int? pageCount;
  final int? flashcardCount;
  final String? filePath;
  final String? extractedText;
  final List<String> chunks;
  final bool isProcessed;

  /// True once every chunk has been embedded and upserted into sqlite-vec.
  /// Distinct from isProcessed (text extracted + chunked — always fast)
  /// vs isIndexed (vectors computed — may be deferred on low-tier devices).
  final bool isIndexed;

  const Document({
    required this.id,
    required this.name,
    required this.type,
    required this.sizeBytes,
    required this.addedAt,
    this.pageCount,
    this.flashcardCount,
    this.filePath,
    this.extractedText,
    this.chunks = const [],
    this.isProcessed = false,
    this.isIndexed = false,
  });

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get processingStatus {
    if (filePath == null) return 'Not imported';
    if (!isProcessed) return 'Processing...';
    if (chunks.isEmpty) return 'No text found';
    if (isIndexed) return '${chunks.length} chunks indexed';
    return '${chunks.length} chunks ready';
  }

  Document copyWith({
    String? id,
    String? name,
    DocType? type,
    int? sizeBytes,
    DateTime? addedAt,
    int? pageCount,
    int? flashcardCount,
    String? filePath,
    String? extractedText,
    List<String>? chunks,
    bool? isProcessed,
    bool? isIndexed,
  }) {
    return Document(
      id:             id             ?? this.id,
      name:           name           ?? this.name,
      type:           type           ?? this.type,
      sizeBytes:      sizeBytes      ?? this.sizeBytes,
      addedAt:        addedAt        ?? this.addedAt,
      pageCount:      pageCount      ?? this.pageCount,
      flashcardCount: flashcardCount ?? this.flashcardCount,
      filePath:       filePath       ?? this.filePath,
      extractedText:  extractedText  ?? this.extractedText,
      chunks:         chunks         ?? this.chunks,
      isProcessed:    isProcessed    ?? this.isProcessed,
      isIndexed:      isIndexed      ?? this.isIndexed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id':             id,
      'name':           name,
      'type':           type.extension,
      'sizeBytes':      sizeBytes,
      'addedAt':        addedAt.toIso8601String(),
      'pageCount':      pageCount,
      'flashcardCount': flashcardCount,
      'filePath':       filePath,
      'extractedText':  extractedText,
      'chunks':         chunks,
      'isProcessed':    isProcessed,
      'isIndexed':      isIndexed,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    int safeInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    int? safeIntNullable(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString());
    }

    DateTime safeDate(dynamic v) {
      try {
        return DateTime.parse(v as String);
      } catch (_) {
        return DateTime.now();
      }
    }

    return Document(
      id:             (map['id'] ?? '').toString(),
      name:           (map['name'] ?? 'Untitled').toString(),
      type:           DocTypeExt.fromString((map['type'] ?? 'other').toString()),
      sizeBytes:      safeInt(map['sizeBytes']),
      addedAt:        safeDate(map['addedAt']),
      pageCount:      safeIntNullable(map['pageCount']),
      flashcardCount: safeIntNullable(map['flashcardCount']),
      filePath:       map['filePath']?.toString(),
      extractedText:  map['extractedText']?.toString(),
      chunks:         List<String>.from((map['chunks'] ?? []).map((e) => e?.toString() ?? '')),
      isProcessed:    map['isProcessed'] == true,
      isIndexed:      map['isIndexed'] == true,
    );
  }
}