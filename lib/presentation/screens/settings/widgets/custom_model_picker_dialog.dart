import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../providers/offline_model_provider.dart';

class CustomModelPickerDialog extends StatefulWidget {
  final VoidCallback? onModelSelected;

  const CustomModelPickerDialog({super.key, this.onModelSelected});

  @override
  State<CustomModelPickerDialog> createState() =>
      _CustomModelPickerDialogState();
}

class _CustomModelPickerDialogState extends State<CustomModelPickerDialog> {
  bool _isPicking = false;
  String? _selectedFilePath;
  String? _fileName;
  double? _fileSizeMB;

  Future<void> _pickModelFile() async {
    try {
      setState(() => _isPicking = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select GGUF Model File',
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;

        if (!path.toLowerCase().endsWith('.gguf')) {
          if (mounted) {
            setState(() => _isPicking = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select a valid .gguf model file.'),
                backgroundColor: AppColors.surface,
              ),
            );
          }
          return;
        }

        final file = File(path);
        final size = await file.length();

        if (mounted) {
          setState(() {
            _selectedFilePath = path;
            _fileName = file.uri.pathSegments.last;
            _fileSizeMB = size / (1024 * 1024);
            _isPicking = false;
          });
        }
      } else {
        if (mounted) setState(() => _isPicking = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPicking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    }
  }

  Future<void> _confirmAndLoad(BuildContext context) async {
    if (_selectedFilePath == null) return;
    final file = File(_selectedFilePath!);
    final provider = context.read<OfflineModelProvider>();

    final success = await provider.loadCustomModelFromFile(file);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Loaded ${_fileName ?? "model"} successfully!'),
            backgroundColor: AppColors.greenBorder,
          ),
        );
        widget.onModelSelected?.call();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.error ?? 'Failed to load model file into memory.',
            ),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelProvider = context.watch<OfflineModelProvider>();
    final isLoading = modelProvider.isContextLoading;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    TablerIcons.file_import,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Load Custom GGUF',
                  style: AppTypography.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Select any quantised GGUF model from device storage or SD card (e.g. Qwen, MedGemma, Llama, Gemma).',
              style: AppTypography.inter(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (_selectedFilePath != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(
                      TablerIcons.cpu,
                      color: AppColors.accent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fileName ?? 'Model File',
                            style: AppTypography.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(_fileSizeMB ?? 0).toStringAsFixed(1)} MB · Ready to load',
                            style: AppTypography.caption.copyWith(
                              color: Colors.teal.shade300,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        TablerIcons.trash,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() {
                                _selectedFilePath = null;
                                _fileName = null;
                                _fileSizeMB = null;
                              });
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedFilePath == null)
              OutlinedButton.icon(
                onPressed: _isPicking || isLoading ? null : _pickModelFile,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isPicking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : const Icon(TablerIcons.folder_open, size: 18),
                label: Text(
                  _isPicking ? 'Browsing…' : 'Browse Files (.gguf)',
                  style: AppTypography.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (isLoading) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      modelProvider.downloadStatusText,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTypography.inter(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selectedFilePath != null && !isLoading
                      ? () => _confirmAndLoad(context)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Load Into Engine',
                    style: AppTypography.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
