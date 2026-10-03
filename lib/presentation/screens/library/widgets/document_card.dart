import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../models/document.dart';
import 'file_action_sheet.dart';

class DocumentCard extends StatelessWidget {
  final Document doc;

  const DocumentCard({
    required this.doc,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Using doc.type instead of doc.fileType
    final iconBg = FileUtils.getIconBg(doc.type);
    final iconFg = FileUtils.getIconFg(doc.type);
    final icon = FileUtils.getIcon(doc.type);
    final sizeStr = doc.sizeLabel; // Using model's helper
    // Using doc.addedAt instead of doc.uploadTime
    final timeStr = DateUtilsHelper.getRelativeTime(doc.addedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconFg, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sizeStr · $timeStr',
                  style: AppTypography.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.bg,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) => FileActionSheet(doc: doc),
              );
            },
            child: const Icon(
              TablerIcons.dots_vertical,
              color: AppColors.textMuted,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
