import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../models/chat_session.dart';
import '../../../../providers/session_provider.dart';

class ChatHistorySheet extends StatelessWidget {
  const ChatHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ChatHistorySheet(),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  void _confirmDelete(BuildContext context, SessionProvider provider, ChatSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Conversation?',
          style: AppTypography.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${session.title}"? This cannot be undone.',
          style: AppTypography.inter(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.inter(color: AppColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.pdfFg,
            ),
            onPressed: () {
              provider.deleteSession(session.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conversation deleted'),
                  duration: Duration(seconds: 2),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final sessions = sessionProvider.sessions;
    final currentId = sessionProvider.currentSessionId;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (sheetContext, scrollController) {
        return SafeArea(
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        TablerIcons.history,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Previous Chats',
                          style: AppTypography.spaceGrotesk(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${sessions.length} ${sessions.length == 1 ? "conversation" : "conversations"} saved',
                          style: AppTypography.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        sessionProvider.startNewSession();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Started fresh chat session'),
                            duration: Duration(seconds: 2),
                            backgroundColor: AppColors.surface,
                          ),
                        );
                      },
                      icon: const Icon(TablerIcons.plus, size: 16),
                      label: Text(
                        'New Chat',
                        style: AppTypography.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppColors.border, height: 16),

              // Sessions list
              Expanded(
                child: sessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              TablerIcons.message_circle_off,
                              size: 44,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No previous conversations',
                              style: AppTypography.spaceGrotesk(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Start asking questions and your chat history will appear here.',
                              textAlign: TextAlign.center,
                              style: AppTypography.inter(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final s = sessions[index];
                          final isActive = s.id == currentId;

                          return InkWell(
                            onTap: () {
                              sessionProvider.switchSession(s.id);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.accent.withValues(alpha: 0.1)
                                    : AppColors.surface,
                                border: Border.all(
                                  color: isActive
                                      ? AppColors.accent.withValues(alpha: 0.4)
                                      : AppColors.border,
                                  width: isActive ? 1.2 : 0.5,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.accent.withValues(alpha: 0.2)
                                          : AppColors.bgPrimary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isActive
                                          ? TablerIcons.message_dots
                                          : TablerIcons.message_2,
                                      size: 16,
                                      color: isActive
                                          ? AppColors.accent
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                s.title,
                                                style: AppTypography.spaceGrotesk(
                                                  fontSize: 14,
                                                  fontWeight: isActive
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  color: isActive
                                                      ? AppColors.textPrimary
                                                      : AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isActive) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accent,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'ACTIVE',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          s.previewText,
                                          style: AppTypography.inter(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              TablerIcons.clock,
                                              size: 12,
                                              color: AppColors.textMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatTimestamp(s.updatedAt),
                                              style: AppTypography.inter(
                                                fontSize: 10,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                            if (s.activeDocumentName != null) ...[
                                              const SizedBox(width: 8),
                                              const Text('•',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.textMuted)),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      TablerIcons.file_text,
                                                      size: 12,
                                                      color: AppColors.accent,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        s.activeDocumentName!,
                                                        style: AppTypography.inter(
                                                          fontSize: 10,
                                                          color: AppColors.accent,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.bgPrimary,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${s.messages.length} ${s.messages.length == 1 ? "msg" : "msgs"}',
                                                style: AppTypography.inter(
                                                  fontSize: 10,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(TablerIcons.trash,
                                        size: 16, color: AppColors.textMuted),
                                    tooltip: 'Delete Chat',
                                    onPressed: () => _confirmDelete(
                                        context, sessionProvider, s),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
