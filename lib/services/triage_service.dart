/// Boundary between the Dalili UI and whatever produces triage results.
///
/// The UI only ever talks to [TriageService]. Swap [FakeTriageService] for a
/// real implementation (rules engine + on-device model) without touching the
/// screen.
library;

import 'package:dalili_triage/triage/triage_result.dart';

export 'package:dalili_triage/triage/triage_result.dart' show Outcome;

/// What the screen needs to render one triage run.
class TriageView {
  final Outcome outcome;
  final String explanation;
  final String? citationText;
  final String? citationDoc;
  final String? citationSection;
  final int? citationPage;
  final List<String> followUpQuestions;
  final String? reason;

  const TriageView({
    required this.outcome,
    required this.explanation,
    this.citationText,
    this.citationDoc,
    this.citationSection,
    this.citationPage,
    this.followUpQuestions = const <String>[],
    this.reason,
  });

  bool get hasCitation => citationDoc != null || citationText != null;
}

abstract class TriageService {
  /// Runs triage on free text. [language] is `'en'` or `'sw'`.
  Future<TriageView> run(String text, String language);
}

/// Canned, keyword-driven results for UI development and tests.
///
/// All text is placeholder. It makes no clinical claims.
class FakeTriageService implements TriageService {
  final Duration delay;

  const FakeTriageService({this.delay = const Duration(milliseconds: 600)});

  static const _fakeDoc = 'PLACEHOLDER Guideline (fake)';

  @override
  Future<TriageView> run(String text, String language) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final t = text.toLowerCase();

    if (t.contains('urgent')) {
      return const TriageView(
        outcome: Outcome.urgentReferral,
        explanation:
            '[FAKE] Placeholder explanation for an urgent referral result.',
        reason: '[FAKE] Matched keyword "urgent".',
        citationDoc: _fakeDoc,
        citationSection: 'Section 0.1 (placeholder)',
        citationPage: 1,
        citationText:
            'Lorem ipsum placeholder passage. This is not real guidance and '
            'exists only to exercise the citation card.',
      );
    }
    if (t.contains('home')) {
      return const TriageView(
        outcome: Outcome.homeCare,
        explanation: '[FAKE] Placeholder explanation for a home care result.',
        reason: '[FAKE] Matched keyword "home".',
        citationDoc: _fakeDoc,
        citationSection: 'Section 0.2 (placeholder)',
        citationPage: 2,
        citationText:
            'Dolor sit amet placeholder passage. Not real guidance.',
      );
    }
    if (t.contains('more')) {
      // Once the follow-up answers are appended, resolve to a decision so the
      // follow-up loop can be exercised end to end.
      if (t.contains('answers:')) {
        return const TriageView(
          outcome: Outcome.referOrTreatAtClinic,
          explanation:
              '[FAKE] Placeholder explanation after follow-up answers.',
          reason: '[FAKE] Follow-up answers received.',
          citationDoc: _fakeDoc,
          citationSection: 'Section 0.3 (placeholder)',
          citationPage: 3,
          citationText: 'Consectetur placeholder passage. Not real guidance.',
        );
      }
      return const TriageView(
        outcome: Outcome.needsMoreInfo,
        explanation: '[FAKE] More information is needed (placeholder).',
        reason: '[FAKE] Matched keyword "more".',
        followUpQuestions: [
          '[FAKE] Placeholder question A?',
          '[FAKE] Placeholder question B?',
        ],
      );
    }
    return const TriageView(
      outcome: Outcome.outOfScope,
      explanation:
          '[FAKE] This input is outside the scope of the placeholder guide.',
      reason: '[FAKE] No keyword matched. Try "urgent", "home" or "more".',
    );
  }
}
