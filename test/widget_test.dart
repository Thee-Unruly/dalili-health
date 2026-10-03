import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:dalili_health/presentation/navigation/main_shell.dart';
import 'package:dalili_health/providers/navigation_provider.dart';
import 'package:dalili_health/providers/session_provider.dart';
import 'package:dalili_health/providers/document_provider.dart';
import 'package:dalili_health/providers/settings_provider.dart';
import 'package:dalili_health/providers/offline_model_provider.dart';
import 'package:dalili_health/presentation/widgets/app_markdown_text.dart';
import 'package:dalili_health/core/utils/text_sanitizer.dart';

void main() {
  testWidgets('Smoke test for Dalili with Denizen AI integration', (WidgetTester tester) async {
    final navProvider = NavigationProvider();
    final docProvider = DocumentProvider();
    final modelProvider = OfflineModelProvider();
    final sessionProvider = SessionProvider();
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: navProvider),
          ChangeNotifierProvider.value(value: docProvider),
          ChangeNotifierProvider.value(value: modelProvider),
          ChangeNotifierProvider.value(value: sessionProvider),
          ChangeNotifierProvider.value(value: settingsProvider),
        ],
        child: const MaterialApp(
          home: MainShell(),
        ),
      ),
    );

    await tester.pump();

    // Verify the bottom navigation shows only the health tabs
    expect(find.text('Triage'), findsWidgets);
    expect(find.text('Ask'), findsWidgets);
    expect(find.text('Guidelines'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('CodeLab'), findsNothing);
  });

  test('Denizen AI models catalog lookup test', () {
    final models = DefaultOfflineModels.getMedicalModels();
    expect(models.isNotEmpty, isTrue);
  });

  testWidgets('AppMarkdownText renders headers and formatted markdown without raw symbols', (WidgetTester tester) async {
    const rawMarkdown = '''
### Key Diagnosis
**Oral Rehydration Therapy** is the primary treatment.
- Give *zinc supplements* daily
1. First step: assess hydration
```
print("ORS dosage: 50ml/kg")
```
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppMarkdownText(rawMarkdown),
        ),
      ),
    );

    await tester.pump();

    // Verify header rendered without ###
    expect(find.textContaining('Key Diagnosis'), findsOneWidget);
    expect(find.textContaining('###'), findsNothing);

    // Verify bold rendered without **
    expect(find.textContaining('Oral Rehydration Therapy'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
  });

  test('TextSanitizer cleans markdown and tokens for TTS', () {
    const raw = '<think>Let me reason</think>### Summary\n**Treatment:** - Give ORS';
    final cleaned = TextSanitizer.cleanOutput(raw);
    expect(cleaned.contains('<think>'), isFalse);
    expect(cleaned.contains('###'), isFalse);
    expect(cleaned.contains('**'), isFalse);
    expect(cleaned, equals('Summary\nTreatment: Give ORS'));
  });
}
