import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../models/document.dart';
import '../../../../providers/document_provider.dart';
import '../../../../providers/session_provider.dart';
import '../../../../providers/navigation_provider.dart';
import '../document_workspace_screen.dart';

class FileActionSheet extends StatelessWidget {
  final Document doc;

  const FileActionSheet({
    required this.doc,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context, listen: false);
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                Icon(
                  FileUtils.getIcon(doc.type),
                  color: FileUtils.getIconFg(doc.type),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    doc.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Size: ${doc.sizeLabel} · Offline storage',
              style: AppTypography.inter(fontSize: 12, color: AppColors.textMuted),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.border, height: 0.5),
            ),

            // Open & Read action
            _buildOption(
              icon: TablerIcons.book,
              label: 'Open & Read Document',
              color: AppColors.accent,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentWorkspaceScreen(document: doc),
                  ),
                );
              },
            ),

            // Use in Tutor action
            _buildOption(
              icon: TablerIcons.brain,
              label: 'Set as Socratic Context',
              color: AppColors.accent,
              onTap: () {
                sessionProvider.setActiveDocument(doc.id, doc.name);
                Navigator.pop(context);
                navProvider.setIndex(1); // switch to Ask tab
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Socratic tutor loaded with: ${doc.name}'),
                    backgroundColor: AppColors.surface,
                  ),
                );
              },
            ),

            // Delete action
            _buildOption(
              icon: TablerIcons.trash,
              label: 'Delete Document (Clear Offline Storage)',
              color: AppColors.pdfFg,
              onTap: () {
                docProvider.removeDocument(doc.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed ${doc.name} from local storage'),
                    backgroundColor: AppColors.surface,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: AppTypography.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}
