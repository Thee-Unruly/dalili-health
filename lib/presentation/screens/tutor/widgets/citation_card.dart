import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../models/chat_message.dart';

class CitationCard extends StatelessWidget {
  final CitationRef citation;
  final VoidCallback? onTap;

  const CitationCard({
    super.key,
    required this.citation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF101420),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.bgBorder, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 14, color: AppColors.indigo),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${citation.docName} · p.${citation.page} — "${citation.excerpt}"',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textDim),
          ],
        ),
      ),
    );
  }
}