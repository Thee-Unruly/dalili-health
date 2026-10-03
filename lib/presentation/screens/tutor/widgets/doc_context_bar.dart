import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../models/document.dart';

class DocContextBar extends StatelessWidget {
  final Document? activeDoc;
  final VoidCallback onChangeTap;

  const DocContextBar({
    super.key,
    required this.activeDoc,
    required this.onChangeTap,
  });

  IconData _iconForType(DocType type) {
    switch (type) {
      case DocType.pdf:   return Icons.picture_as_pdf_rounded;
      case DocType.pptx:  return Icons.slideshow_rounded;
      case DocType.docx:  return Icons.description_rounded;
      default:            return Icons.insert_drive_file_rounded;
    }
  }

  Color _colorForType(DocType type) {
    switch (type) {
      case DocType.pdf:   return AppColors.pdfColor;
      case DocType.pptx:  return AppColors.pptxColor;
      case DocType.docx:  return AppColors.docxColor;
      default:            return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bgBorder, width: 0.5),
      ),
      child: Row(
        children: [
          if (activeDoc != null) ...[
            Icon(
              _iconForType(activeDoc!.type),
              size: 16,
              color: _colorForType(activeDoc!.type),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                activeDoc!.name,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else ...[
            const Icon(Icons.folder_open_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No document selected',
                style: AppTypography.bodySm.copyWith(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onChangeTap,
            child: Text(
              activeDoc != null ? 'Change' : 'Select',
              style: AppTypography.label.copyWith(
                color: AppColors.indigo,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}