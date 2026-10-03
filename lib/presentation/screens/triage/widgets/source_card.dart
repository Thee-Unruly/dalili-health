import 'package:flutter/material.dart';

/// Shows where a result comes from: document, section, page, and the quoted
/// passage (collapsed by default).
class SourceCard extends StatelessWidget {
  final String? document;
  final String? section;
  final int? page;
  final String? passage;

  const SourceCard({
    super.key,
    this.document,
    this.section,
    this.page,
    this.passage,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final location = [
      if (section != null) section!,
      if (page != null) 'Page $page',
    ].join(' · ');

    return Card(
      key: const Key('sourceCard'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Source',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(document ?? 'Unknown document', style: textTheme.bodyLarge),
            if (location.isNotEmpty)
              Text(location, style: textTheme.bodyMedium),
            if (passage != null)
              Theme(
                // Drop the ExpansionTile's default divider lines.
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  minTileHeight: 48,
                  title: const Text('Show quoted passage'),
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Text(
                        '“$passage”',
                        style: textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
