import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalili_health/presentation/screens/triage/triage_screen.dart';
import 'package:dalili_health/services/triage_service.dart';

void main() {
  testWidgets('keyword + Submit shows a result card and a source card', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TriageScreen(service: FakeTriageService(delay: Duration.zero)),
      ),
    );

    expect(
      find.text('Decision support for trained health workers. Not a diagnosis.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('caseInput')), 'urgent case');
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resultCard')), findsOneWidget);
    expect(find.text('URGENT REFERRAL'), findsOneWidget);

    // The source card sits below the fold in the default test viewport.
    await tester.scrollUntilVisible(
      find.byKey(const Key('sourceCard')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('sourceCard')), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
  });
}
