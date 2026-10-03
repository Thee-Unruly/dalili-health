import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../models/document.dart';

class FileUtils {
  FileUtils._();

  static Color getIconBg(DocType type) {
    switch (type) {
      case DocType.pdf:   return AppColors.pdfBg;
      case DocType.pptx:  return AppColors.pptxBg;
      case DocType.docx:  return AppColors.docxBg;
      default:            return AppColors.bgElevated;
    }
  }

  static Color getIconFg(DocType type) {
    switch (type) {
      case DocType.pdf:   return AppColors.pdfColor;
      case DocType.pptx:  return AppColors.pptxColor;
      case DocType.docx:  return AppColors.docxColor;
      default:            return AppColors.indigo;
    }
  }

  static IconData getIcon(DocType type) {
    switch (type) {
      case DocType.pdf:   return Icons.picture_as_pdf_rounded;
      case DocType.pptx:  return Icons.slideshow_rounded;
      case DocType.docx:  return Icons.description_rounded;
      case DocType.image: return Icons.image_rounded;
      default:            return Icons.insert_drive_file_rounded;
    }
  }

  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    double doubleBytes = bytes.toDouble();
    int suffixIndex = 0;
    while (doubleBytes >= 1024 && suffixIndex < suffixes.length - 1) {
      doubleBytes /= 1024;
      suffixIndex++;
    }
    return '${doubleBytes.toStringAsFixed(decimals)} ${suffixes[suffixIndex]}';
  }
}
