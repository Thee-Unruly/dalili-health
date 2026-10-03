import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../providers/document_provider.dart';
import 'widgets/document_card.dart';

// NEW: AI workspace screen (you will implement next)
import 'document_workspace_screen.dart';
import 'widgets/file_action_sheet.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildSearchBar(context, docProvider),
            const SizedBox(height: 14),
            _buildCategoryChips(context, docProvider),
            const SizedBox(height: 16),
            Expanded(
              child: _buildDocumentList(context, docProvider),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _simulateUpload(context, docProvider),
        backgroundColor: AppColors.accent,
        label: Text(
          'Upload Doc',
          style: AppTypography.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        icon: const Icon(TablerIcons.plus, color: Colors.white, size: 16),
      ),
    );
  }

  // ================= SEARCH =================
  Widget _buildSearchBar(BuildContext context, DocumentProvider provider) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(TablerIcons.search,
                color: AppColors.textMuted, size: 18),
          ),
          Expanded(
            child: TextField(
              style: AppTypography.inter(
                  fontSize: 13, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search offline files...',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) => provider.setSearchQuery(val),
            ),
          ),
        ],
      ),
    );
  }

  // ================= FILTERS =================
  Widget _buildCategoryChips(
      BuildContext context, DocumentProvider provider) {
    final categories = ['all', 'pdf', 'pptx', 'docx'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = provider.selectedCategory == cat;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => provider.setSelectedCategory(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.iconBg
                      : AppColors.surface,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.border,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cat.toUpperCase(),
                  style: AppTypography.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================= DOCUMENT LIST =================
  Widget _buildDocumentList(
      BuildContext context, DocumentProvider provider) {
    final docs = provider.documents;

    if (docs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.file_off,
                size: 36, color: AppColors.border),
            SizedBox(height: 12),
            Text(
              'No matching offline files found',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];

        return GestureDetector(
          onTap: () => _openDocumentWorkspace(context, doc),
          onLongPress: () => _showDocumentActions(context, doc),
          child: DocumentCard(doc: doc),
        );
      },
    );
  }

  // ================= DOCUMENT ACTIONS =================
  void _showDocumentActions(BuildContext context, doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FileActionSheet(doc: doc),
    );
  }

  // ================= OPEN WORKSPACE =================
  void _openDocumentWorkspace(BuildContext context, doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentWorkspaceScreen(
          document: doc,
          mode: "reader",
        ),
      ),
    );
  }

  // ================= UPLOAD DOCUMENT =================
  void _simulateUpload(BuildContext context, DocumentProvider provider) async {
    await provider.pickAndUploadDocument();
    if (context.mounted && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: AppColors.pdfBg,
        ),
      );
    }
  }
}