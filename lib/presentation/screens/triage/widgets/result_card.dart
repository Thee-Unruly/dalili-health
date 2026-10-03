import 'package:flutter/material.dart';

import '../../../../services/triage_service.dart';

/// Colour, icon and text label for each outcome. Colour is never the only
/// signal: every banner also carries an icon and a written label.
class OutcomeStyle {
  final Color background;
  final Color foreground;
  final IconData icon;
  final String label;

  const OutcomeStyle(this.background, this.foreground, this.icon, this.label);

  static OutcomeStyle of(Outcome outcome) => switch (outcome) {
    Outcome.urgentReferral => const OutcomeStyle(
      Color(0xFFB71C1C),
      Colors.white,
      Icons.warning_amber_rounded,
      'URGENT REFERRAL',
    ),
    Outcome.referOrTreatAtClinic => const OutcomeStyle(
      Color(0xFFE65100),
      Colors.white,
      Icons.local_hospital,
      'REFER OR TREAT AT CLINIC',
    ),
    Outcome.homeCare => const OutcomeStyle(
      Color(0xFF1B5E20),
      Colors.white,
      Icons.home,
      'HOME CARE',
    ),
    Outcome.needsMoreInfo => const OutcomeStyle(
      Color(0xFF0D47A1),
      Colors.white,
      Icons.help_outline,
      'NEEDS MORE INFORMATION',
    ),
    Outcome.outOfScope => const OutcomeStyle(
      Color(0xFF424242),
      Colors.white,
      Icons.block,
      'OUT OF SCOPE',
    ),
  };
}

class ResultCard extends StatelessWidget {
  final TriageView view;

  const ResultCard({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final style = OutcomeStyle.of(view.outcome);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      key: const Key('resultCard'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: style.background, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            label: 'Result: ${style.label}',
            excludeSemantics: true,
            child: Container(
              color: style.background,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(style.icon, color: style.foreground, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      style.label,
                      style: textTheme.titleLarge?.copyWith(
                        color: style.foreground,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(view.explanation, style: textTheme.bodyLarge),
                if (view.reason != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Why: ${view.reason}',
                    style: textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
