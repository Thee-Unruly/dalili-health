import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../models/chat_message.dart';

class ModelLangControls extends StatelessWidget {
  final ModelMode selectedModel;
  final Language selectedLanguage;
  final bool socraticMode;
  final ValueChanged<ModelMode> onModelChanged;
  final VoidCallback onLanguageTap;

  const ModelLangControls({
    super.key,
    required this.selectedModel,
    required this.selectedLanguage,
    required this.socraticMode,
    required this.onModelChanged,
    required this.onLanguageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModelPill(
          label: ModelMode.power.label,
          active: selectedModel == ModelMode.power,
          onTap: () => onModelChanged(ModelMode.power),
        ),
        const SizedBox(width: 8),
        _ModelPill(
          label: ModelMode.lite.label,
          active: selectedModel == ModelMode.lite,
          onTap: () => onModelChanged(ModelMode.lite),
        ),
        const SizedBox(width: 8),
        _LangPill(
          language: selectedLanguage,
          onTap: onLanguageTap,
        ),
        const Spacer(),
        if (socraticMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.onlineBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.onlineBorder, width: 0.5),
            ),
            child: Text(
              'Socratic on',
              style: AppTypography.caption.copyWith(
                color: AppColors.online,
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }
}

class _ModelPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModelPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.bgElevated : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.indigo : AppColors.bgBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.memory_rounded,
              size: 12,
              color: active ? AppColors.indigo : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: active ? AppColors.indigo : AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  final Language language;
  final VoidCallback onTap;

  const _LangPill({required this.language, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.violet, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate_rounded, size: 12, color: AppColors.violet),
            const SizedBox(width: 4),
            Text(
              'EN → ${language.label}',
              style: AppTypography.label.copyWith(
                color: AppColors.violet,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}