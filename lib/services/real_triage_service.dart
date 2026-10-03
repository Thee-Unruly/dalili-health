import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:denizen_ai/denizen_ai.dart' as denizen;
import 'package:flutter/services.dart';

import 'package:dalili_triage/triage/rules_engine.dart';
import 'package:dalili_triage/triage/symptom_set.dart';
import 'package:dalili_triage/triage/triage_result.dart';
import 'guideline_index.dart';
import 'triage_service.dart';
import 'offline_ai_service.dart' as local_ai;

/// The real on-device triage pipeline for Dalili.
///
/// Workflow:
/// 1. LLM extracts symptoms from text -> JSON.
/// 2. RulesEngine evaluates symptoms -> Outcome + RuleID.
/// 3. GuidelineIndex finds relevant passage for RuleID/Outcome.
/// 4. LLM explains the result using the passage.
class RealTriageService implements TriageService {
  final local_ai.OfflineAIService aiService;
  final GuidelineIndex guidelineIndex;

  RealTriageService({
    required this.aiService,
    required this.guidelineIndex,
  });

  @override
  Future<TriageView> run(String text, String language) async {
    try {
      // 1. Extract symptoms using on-device LLM
      final symptomMap = await _extractSymptoms(text, language);
      if (symptomMap == null) {
        return TriageView(
          outcome: Outcome.outOfScope,
          explanation: 'I could not identify any health signs from your notes. Please be more specific.',
          reason: 'LLM failed to extract structured symptoms.',
        );
      }

      final symptoms = SymptomSet.fromMap(symptomMap);

      // 2. Run Deterministic Rules Engine
      final rulesJson = await rootBundle.loadString('assets/guidelines/imci_rules.json');
      final engine = RulesEngine.fromJsonString(rulesJson);
      final result = engine.evaluate(symptoms);

      // 3. Grounding: Search for the passage
      // If we have a rule match, we use the rule's sourceDoc. Otherwise, search based on the outcome.
      final query = result.reason;
      final hits = guidelineIndex.search(query);
      final bestHit = hits.isNotEmpty ? hits.first : null;

      // 4. Final Explanation via LLM
      final explanation = await _generateExplanation(
        outcome: result.outcome,
        reason: result.reason,
        passage: bestHit?.chunk.text,
        language: language,
      );

      return TriageView(
        outcome: result.outcome,
        explanation: explanation,
        citationDoc: bestHit?.chunk.doc,
        citationSection: bestHit?.chunk.section,
        citationPage: bestHit?.chunk.page,
        citationText: bestHit?.chunk.text,
        followUpQuestions: result.missingFields?.map((f) => 'What is the status of $f?').toList() ?? [],
        reason: result.reason,
      );
    } catch (e) {
      debugPrint('Triage Pipeline Error: $e');
      return TriageView(
        outcome: Outcome.outOfScope,
        explanation: 'An internal error occurred during triage. Please try again.',
        reason: 'Exception: $e',
      );
    }
  }

  Future<Map<String, dynamic>?> _extractSymptoms(String text, String language) async {
    final systemPrompt = '''
You are a clinical data extractor. Extract symptoms from health worker notes into JSON.
Fields: ageMonths (int), feverDays (int), coughOrDifficultyBreathing (bool), breathsPerMinute (int), 
unableToDrinkOrBreastfeed (bool), vomitsEverything (bool), convulsions (bool), 
lethargicOrUnconscious (bool), chestIndrawing (bool), stridorWhenCalm (bool), 
diarrhoeaDays (int), bloodInStool (bool).
Only include fields explicitly mentioned. Use null for unknown.
''';

    return await aiService.generateJson(
      prompt: 'Extract symptoms from these notes: "$text" (Language: $language)',
      systemPrompt: systemPrompt,
    );
  }

  Future<String> _generateExplanation(
    {
      required Outcome outcome,
      required String reason,
      String? passage,
      required String language,
    }) async {
      final systemPrompt = 'You are a health assistant. Explain the triage result clearly and concisely in $language.';
      final prompt = '''
Triage Result: $outcome
Reason: $reason
Supporting Guideline: ${passage ?? 'No specific passage found.'}

Explain why this action is recommended based on the guideline. Be direct and supportive.
''';

      return await aiService.generateResponse(
        prompt: prompt,
        systemPrompt: systemPrompt,
      );
    }
}
