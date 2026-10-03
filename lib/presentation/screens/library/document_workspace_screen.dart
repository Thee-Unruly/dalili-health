import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../models/document.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/session_provider.dart';

class DocumentWorkspaceScreen extends StatelessWidget {
  final dynamic document;
  final String mode;

  const DocumentWorkspaceScreen({
    super.key,
    required this.document,
    this.mode = 'reader',
  });

  @override
  Widget build(BuildContext context) {
    final doc = document;
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          doc.name ?? 'Document Reader',
          style: AppTypography.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(TablerIcons.brain, color: AppColors.accent, size: 20),
            tooltip: 'Study with AI Tutor',
            onPressed: () {
              sessionProvider.setActiveDocument(doc.id, doc.name);
              navProvider.setIndex(1); // Switch to Ask (guideline chat) tab
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Loaded ${doc.name} into AI Tutor'),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
          ),
        ],
      ),
      body: _buildReaderContent(doc),
    );
  }

  Widget _buildReaderContent(dynamic doc) {
    final filePath = doc.filePath?.toString();
    final isPdf = doc.type == DocType.pdf ||
        (filePath != null && filePath.toLowerCase().endsWith('.pdf')) ||
        (doc.name != null && doc.name.toString().toLowerCase().endsWith('.pdf'));

    if (isPdf && filePath != null && File(filePath).existsSync()) {
      return _PdfReaderView(filePath: filePath, extractedFallback: _safeExtractedText(doc));
    }

    final text = _safeExtractedText(doc);
    final hasText = text.trim().isNotEmpty;

    return Container(
      color: AppColors.bg,
      child: hasText
          ? Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: SelectableText(
                  text,
                  style: AppTypography.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.75,
                  ),
                ),
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(TablerIcons.file_off, color: AppColors.textDim, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No readable text found in this document.',
                    style: AppTypography.inter(fontSize: 13, color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  String _safeExtractedText(dynamic doc) {
    if (doc == null) return '';
    try {
      final raw = doc.extractedText?.toString() ?? '';
      if (raw.trim().isEmpty) {
        final chunkCount = (doc.chunks != null && doc.chunks is List) ? (doc.chunks as List).length : 0;
        return "Document content parsed into $chunkCount indexed knowledge chunks for offline AI reasoning.";
      }
      final buffer = StringBuffer();
      for (final char in raw.runes) {
        if ((char >= 32 && char <= 0xD7FF) ||
            (char >= 0xE000 && char <= 0xFFFD) ||
            (char >= 0x10000 && char <= 0x10FFFF) ||
            char == 10 || char == 13 || char == 9) {
          buffer.writeCharCode(char);
        }
      }
      return buffer.toString();
    } catch (_) {
      return "Document content indexed for offline AI reasoning.";
    }
  }
}

// ════════════════════════════════════════════════════════════
// PDF Reader with Syncfusion PdfViewer + page counter overlay
// ════════════════════════════════════════════════════════════
class _PdfReaderView extends StatefulWidget {
  final String filePath;
  final String? extractedFallback;
  const _PdfReaderView({
    required this.filePath,
    this.extractedFallback,
  });

  @override
  State<_PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends State<_PdfReaderView> {
  final PdfViewerController _pdfController = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _error;
  bool _showTextFallback = false;

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showTextFallback && widget.extractedFallback != null) {
      return Container(
        color: AppColors.bg,
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Text Extract View', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => setState(() => _showTextFallback = false),
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text('Back to PDF', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  widget.extractedFallback!,
                  style: AppTypography.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.75,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_outlined, color: Colors.orange, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Could not render PDF',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (widget.extractedFallback != null && widget.extractedFallback!.trim().isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showTextFallback = true),
                  icon: const Icon(Icons.text_snippet, size: 16),
                  label: const Text('View Extracted Text'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // ── PDF Viewer ─────────────────────────────────────────
        SfPdfViewer.file(
          File(widget.filePath),
          controller: _pdfController,
          pageLayoutMode: PdfPageLayoutMode.continuous,
          scrollDirection: PdfScrollDirection.vertical,
          enableDoubleTapZooming: true,
          onDocumentLoaded: (details) {
            if (mounted) {
              setState(() {
                _totalPages = details.document.pages.count;
                _isLoading = false;
              });
            }
          },
          onPageChanged: (details) {
            if (mounted) {
              setState(() => _currentPage = details.newPageNumber);
            }
          },
          onDocumentLoadFailed: (details) {
            if (mounted) {
              setState(() {
                _error = details.description;
                _isLoading = false;
              });
            }
          },
        ),

        // ── Loading indicator ──────────────────────────────────
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),

        // ── Page counter badge ─────────────────────────────────
        if (!_isLoading && _totalPages > 0)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

        // ── Zoom controls ───────────────────────────────
        if (!_isLoading)
          Positioned(
            bottom: 16,
            left: 16,
            child: Row(
              children: [
                _ZoomButton(
                  icon: Icons.zoom_in,
                  onTap: () => _pdfController.zoomLevel =
                      (_pdfController.zoomLevel + 0.25).clamp(0.75, 3.0),
                ),
                const SizedBox(width: 8),
                _ZoomButton(
                  icon: Icons.zoom_out,
                  onTap: () => _pdfController.zoomLevel =
                      (_pdfController.zoomLevel - 0.25).clamp(0.75, 3.0),
                ),
                if (widget.extractedFallback != null && widget.extractedFallback!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _ZoomButton(
                    icon: Icons.text_snippet,
                    onTap: () => setState(() => _showTextFallback = true),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}