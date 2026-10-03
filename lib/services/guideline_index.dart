import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// One page-tagged passage of a bundled guideline document.
///
/// Produced by `tool/extract_guidelines.py`. [page] is the PDF page index (what
/// a PDF viewer shows), so every citation can be checked against the source.
class GuidelineChunk {
  final String doc;
  final String title;
  final int page;
  final String section;
  final String text;

  const GuidelineChunk({
    required this.doc,
    required this.title,
    required this.page,
    required this.section,
    required this.text,
  });

  factory GuidelineChunk.fromJson(Map<String, dynamic> json) => GuidelineChunk(
    doc: json['doc'] as String,
    title: json['title'] as String,
    page: json['page'] as int,
    section: (json['section'] as String?) ?? '',
    text: json['text'] as String,
  );

  /// e.g. "WHO IMCI Chart Booklet (2014), p. 8".
  String get citation => '$title, p. $page';
}

class GuidelineHit {
  final GuidelineChunk chunk;

  /// BM25 relevance. Only comparable between hits of the same query.
  final double score;

  /// Fraction of distinct query terms that appear in the chunk (0..1).
  final double coverage;

  const GuidelineHit(this.chunk, this.score, this.coverage);
}

/// In-memory keyword (BM25) index over the bundled guideline chunks.
///
/// Pure Dart: no sqlite-vec, no embeddings, deterministic, and runs in tests.
/// Every hit keeps its document, section and page, so answers can cite them.
class GuidelineIndex {
  static const assetDir = 'assets/guidelines/';

  static const _k1 = 1.2;
  static const _b = 0.75;
  static const _stopwords = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from', 'has',
    'have', 'he', 'her', 'his', 'if', 'in', 'is', 'it', 'its', 'of', 'on',
    'or', 'she', 'that', 'the', 'their', 'there', 'this', 'to', 'was', 'were',
    'what', 'when', 'which', 'who', 'will', 'with', 'you', 'your', 'do',
    'does', 'how', 'should', 'can', 'my', 'me', 'i',
  };

  final List<GuidelineChunk> chunks;
  final List<Map<String, int>> _termFreqs;
  final List<int> _lengths;
  final Map<String, int> _docFreq;
  final double _avgLength;

  GuidelineIndex._(
    this.chunks,
    this._termFreqs,
    this._lengths,
    this._docFreq,
    this._avgLength,
  );

  factory GuidelineIndex(List<GuidelineChunk> chunks) {
    final termFreqs = <Map<String, int>>[];
    final lengths = <int>[];
    final docFreq = <String, int>{};
    for (final c in chunks) {
      final tokens = tokenize('${c.section} ${c.text}');
      final tf = <String, int>{};
      for (final t in tokens) {
        tf[t] = (tf[t] ?? 0) + 1;
      }
      for (final t in tf.keys) {
        docFreq[t] = (docFreq[t] ?? 0) + 1;
      }
      termFreqs.add(tf);
      lengths.add(tokens.length);
    }
    final avg = lengths.isEmpty
        ? 0.0
        : lengths.reduce((a, b) => a + b) / lengths.length;
    return GuidelineIndex._(chunks, termFreqs, lengths, docFreq, avg);
  }

  /// Parses JSON Lines (one chunk per line); blank lines are skipped.
  factory GuidelineIndex.fromJsonl(Iterable<String> lines) => GuidelineIndex([
    for (final line in lines)
      if (line.trim().isNotEmpty)
        GuidelineChunk.fromJson(jsonDecode(line) as Map<String, dynamic>),
  ]);

  /// Loads every `assets/guidelines/*.jsonl` in the bundle.
  static Future<GuidelineIndex> loadFromAssets([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(b);
    final files = manifest
        .listAssets()
        .where((p) => p.startsWith(assetDir) && p.endsWith('.jsonl'))
        .toList()
      ..sort();
    final lines = <String>[];
    for (final f in files) {
      lines.addAll(const LineSplitter().convert(await b.loadString(f)));
    }
    return GuidelineIndex.fromJsonl(lines);
  }

  bool get isEmpty => chunks.isEmpty;

  static List<String> tokenize(String text) => RegExp(r'[a-z0-9]+')
      .allMatches(text.toLowerCase())
      .map((m) => m.group(0)!)
      .where((t) => t.length > 1 && !_stopwords.contains(t))
      .toList();

  /// Top [topK] chunks for [query], best first. Chunks matching no query term
  /// are never returned, so an empty list means "nothing relevant".
  List<GuidelineHit> search(String query, {int topK = 3}) {
    final terms = tokenize(query).toSet();
    if (terms.isEmpty || chunks.isEmpty) return const [];
    final n = chunks.length;

    final hits = <GuidelineHit>[];
    for (var i = 0; i < n; i++) {
      final tf = _termFreqs[i];
      var score = 0.0;
      var matched = 0;
      for (final t in terms) {
        final f = tf[t];
        if (f == null) continue;
        matched++;
        final df = _docFreq[t]!;
        final idf = math.log(1 + (n - df + 0.5) / (df + 0.5));
        final norm = f + _k1 * (1 - _b + _b * _lengths[i] / _avgLength);
        score += idf * f * (_k1 + 1) / norm;
      }
      if (matched > 0) {
        hits.add(GuidelineHit(chunks[i], score, matched / terms.length));
      }
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(topK).toList();
  }
}
