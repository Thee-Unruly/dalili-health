import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dalili_health/services/guideline_index.dart';

// Clearly fake fixture chunks; no clinical content.
String _row(String doc, int page, String section, String text) => jsonEncode({
  'doc': doc,
  'title': 'Fixture Doc $doc',
  'page': page,
  'section': section,
  'text': text,
});

void main() {
  final index = GuidelineIndex.fromJsonl([
    _row('a', 3, 'Alpha section', 'zebra marker appears alongside quokka marker'),
    _row('a', 4, 'Beta section', 'only quokka here with plenty of other filler words'),
    '',
    _row('b', 9, 'Gamma section', 'unrelated filler about pangolin'),
  ]);

  test('ranks the chunk matching more query terms first and keeps its page', () {
    final hits = index.search('zebra quokka');
    expect(hits, isNotEmpty);
    expect(hits.first.chunk.page, 3);
    expect(hits.first.chunk.citation, 'Fixture Doc a, p. 3');
    expect(hits.first.coverage, 1.0);
    expect(hits.length, 2); // pangolin chunk matches nothing
  });

  test('returns nothing when no query term matches', () {
    expect(index.search('armadillo'), isEmpty);
    expect(index.search('the and of'), isEmpty); // stopwords only
  });

  test('blank JSONL lines are skipped', () {
    expect(index.chunks.length, 3);
  });
}
