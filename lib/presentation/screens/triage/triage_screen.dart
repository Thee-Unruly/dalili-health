import 'package:flutter/material.dart';

import '../../../services/triage_service.dart';
import 'widgets/source_card.dart';
import 'widgets/result_card.dart';
import 'widgets/status_strip.dart';

enum _Phase { idle, loading, result, followUp, error }

enum _Answer { yes, no, unknown }

extension on _Answer {
  String get label => switch (this) {
    _Answer.yes => 'Yes',
    _Answer.no => 'No',
    _Answer.unknown => 'Unknown',
  };
}

/// The single Dalili screen: describe the case, get an action and its source.
class TriageScreen extends StatefulWidget {
  final TriageService service;
  final String modelName;

  const TriageScreen({
    super.key,
    required this.service,
    this.modelName = 'Fake (no model)',
  });

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  static const _minTarget = Size(48, 48);

  final _controller = TextEditingController();

  _Phase _phase = _Phase.idle;
  String _language = 'en';
  TriageView? _view;
  String? _error;
  Duration? _lastLatency;

  /// Text submitted for the current case, kept so follow-up answers can be
  /// appended to it.
  String _submitted = '';
  final Map<int, _Answer> _answers = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(String text) async {
    if (text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.loading;
      _submitted = text;
      _error = null;
    });
    final sw = Stopwatch()..start();
    try {
      final view = await widget.service.run(text, _language);
      if (!mounted) return;
      setState(() {
        _lastLatency = sw.elapsed;
        _view = view;
        _answers.clear();
        _phase = view.outcome == Outcome.needsMoreInfo &&
                view.followUpQuestions.isNotEmpty
            ? _Phase.followUp
            : _Phase.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _phase = _Phase.error;
      });
    }
  }

  void _continueWithAnswers() {
    final questions = _view!.followUpQuestions;
    final buffer = StringBuffer(_submitted)..write('\n\nAnswers:');
    for (var i = 0; i < questions.length; i++) {
      buffer.write('\n- ${questions[i]} ${_answers[i]!.label}');
    }
    _run(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase == _Phase.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Dalili')),
      body: Column(
        children: [
          StatusStrip(
            modelName: widget.modelName,
            lastTimeToFirstToken: _lastLatency,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _languageToggle(),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('caseInput'),
                  controller: _controller,
                  enabled: !busy,
                  minLines: 3,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Describe the patient',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('submitButton'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        onPressed: busy ? null : () => _run(_controller.text),
                        icon: const Icon(Icons.send),
                        label: const Text('Submit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 56),
                      ),
                      onPressed: null,
                      icon: const Icon(Icons.mic_off),
                      label: const Text('Voice (coming soon)'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._body(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _Footer(),
    );
  }

  Widget _languageToggle() {
    return SegmentedButton<String>(
      style: SegmentedButton.styleFrom(minimumSize: _minTarget),
      segments: const [
        ButtonSegment(value: 'en', label: Text('English')),
        ButtonSegment(value: 'sw', label: Text('Kiswahili')),
      ],
      selected: {_language},
      onSelectionChanged: _phase == _Phase.loading
          ? null
          : (s) => setState(() => _language = s.first),
    );
  }

  List<Widget> _body() {
    switch (_phase) {
      case _Phase.idle:
        return const [
          Text(
            'Enter a description and press Submit.',
            style: TextStyle(fontSize: 16),
          ),
        ];
      case _Phase.loading:
        return const [
          Row(
            children: [
              SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(width: 16),
              Text('Working offline...', style: TextStyle(fontSize: 18)),
            ],
          ),
        ];
      case _Phase.error:
        return [
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.error_outline, size: 32),
              title: const Text('Something went wrong'),
              subtitle: Text(_error ?? 'Unknown error'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => _run(_submitted),
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ];
      case _Phase.result:
        final v = _view!;
        return [
          ResultCard(view: v),
          if (v.hasCitation) ...[
            const SizedBox(height: 12),
            SourceCard(
              document: v.citationDoc,
              section: v.citationSection,
              page: v.citationPage,
              passage: v.citationText,
            ),
          ],
        ];
      case _Phase.followUp:
        final v = _view!;
        final allAnswered = _answers.length == v.followUpQuestions.length;
        return [
          ResultCard(view: v),
          const SizedBox(height: 12),
          for (var i = 0; i < v.followUpQuestions.length; i++)
            _followUpRow(i, v.followUpQuestions[i]),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('continueButton'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontSize: 18),
            ),
            onPressed: allAnswered ? _continueWithAnswers : null,
            icon: const Icon(Icons.arrow_forward),
            label: Text(allAnswered ? 'Continue' : 'Answer all questions'),
          ),
        ];
    }
  }

  Widget _followUpRow(int index, String question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final a in _Answer.values)
                ChoiceChip(
                  label: Text(a.label, style: const TextStyle(fontSize: 16)),
                  selected: _answers[index] == a,
                  // A tick icon marks the selection, not just colour.
                  showCheckmark: true,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onSelected: (_) => setState(() => _answers[index] = a),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.inverseSurface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: scheme.onInverseSurface),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Decision support for trained health workers. '
                  'Not a diagnosis.',
                  style: TextStyle(
                    color: scheme.onInverseSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
