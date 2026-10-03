import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../models/chat_message.dart';
import '../../../models/document.dart';
import '../../../providers/session_provider.dart';
import '../../../providers/document_provider.dart';
import '../../../providers/offline_model_provider.dart';
import '../../../providers/settings_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/language_sheet.dart';
import 'widgets/chat_history_sheet.dart';

class TutorScreen extends StatefulWidget {
  const TutorScreen({super.key});

  @override
  State<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends State<TutorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  Language _language = Language.english;
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(SessionProvider session, DocumentProvider docs, bool socratic, String text) {
    session.sendMessage(
      text,
      docProvider: docs,
      socratic: socratic,
      language: _language.fullName,
    );
    _scrollToBottom();
  }

  void _showDocPicker(BuildContext context, SessionProvider session, DocumentProvider docs) {
    if (docs.documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No documents yet — upload one from the Library tab first.'),
          backgroundColor: AppColors.surface,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Study Document',
                    style: AppTypography.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (session.activeDocumentId != null)
                    TextButton.icon(
                      onPressed: () {
                        session.clearActiveDocument();
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(TablerIcons.x, size: 14, color: AppColors.pdfFg),
                      label: Text(
                        'Deselect',
                        style: AppTypography.inter(fontSize: 12, color: AppColors.pdfFg),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.documents.length,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 0.5),
                  itemBuilder: (_, i) {
                    final doc = docs.documents[i];
                    final isSelected = doc.id == session.activeDocumentId;
                    return ListTile(
                      leading: Icon(
                        _iconForType(doc.type),
                        color: isSelected ? AppColors.accent : AppColors.textMuted,
                      ),
                      title: Text(
                        doc.name,
                        style: AppTypography.inter(
                          fontSize: 13,
                          color: isSelected ? AppColors.accent : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        doc.isProcessed ? '${doc.sizeLabel} · Ready for AI' : 'Processing…',
                        style: AppTypography.inter(fontSize: 11, color: AppColors.textMuted),
                      ),
                      trailing: isSelected ? const Icon(TablerIcons.check, color: AppColors.accent, size: 18) : null,
                      onTap: () {
                        session.setActiveDocument(doc.id, doc.name);
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(DocType type) {
    switch (type) {
      case DocType.pdf:
        return TablerIcons.file_type_pdf;
      case DocType.pptx:
        return TablerIcons.file_type_ppt;
      case DocType.docx:
        return TablerIcons.file_type_docx;
      default:
        return TablerIcons.file_text;
    }
  }

  void _openCitation(CitationRef citation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${citation.docName} p.${citation.page}'),
        backgroundColor: AppColors.surface,
      ),
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

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final docs = context.watch<DocumentProvider>();
    final modelProvider = context.watch<OfflineModelProvider>();
    final settings = context.watch<SettingsProvider>();

    if (session.chatMessages.length != _lastMessageCount) {
      _lastMessageCount = session.chatMessages.length;
      _scrollToBottom();
    }

    final activeDoc = session.activeDocumentId == null
        ? null
        : docs.documents.where((d) => d.id == session.activeDocumentId).firstOrNull;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgPrimary,
      drawer: _buildHistoryDrawer(context, session),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Clean header bar with History Drawer toggle
            _buildHeader(context, session, modelProvider),

            if (!modelProvider.hasActiveModel)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.pdfBg,
                child: Text(
                  'No model loaded — go to Settings to download and activate one.',
                  style: AppTypography.inter(fontSize: 11, color: AppColors.pdfFg),
                ),
              ),

            // Document & Socratic Quick Bar
            _buildControlBar(context, session, docs, activeDoc, settings),

            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: session.chatMessages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final msg = session.chatMessages[index];
                  final isStreaming = session.isGenerating &&
                      index == session.chatMessages.length - 1 &&
                      msg.role == MessageRole.ai;
                  return ChatBubble(
                    message: msg,
                    isStreaming: isStreaming,
                    onCitationTap: msg.citation != null ? () => _openCitation(msg.citation!) : null,
                  );
                },
              ),
            ),
            ChatInputBar(
              onSend: (text) => _handleSend(session, docs, settings.socraticMode, text),
              onStop: () => session.stopGeneration(),
              isTyping: session.isGenerating,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SessionProvider session, OfflineModelProvider modelProvider) {
    final activeModelName = modelProvider.activeModel?.name ?? 'No Model Active';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // History Drawer Menu Trigger
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(TablerIcons.layout_sidebar, size: 22, color: AppColors.accent),
            tooltip: 'Chat History Sidebar',
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Tutor',
                style: AppTypography.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                activeModelName,
                style: AppTypography.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Previous Chats History button with count
          IconButton(
            onPressed: () => ChatHistorySheet.show(context),
            icon: const Icon(TablerIcons.history, size: 20, color: AppColors.textMuted),
            tooltip: 'Previous Chats (${session.sessions.length})',
          ),
          // New Chat button
          IconButton(
            onPressed: () {
              context.read<SessionProvider>().startNewSession();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Started new chat. Previous chat saved.'),
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'History',
                    textColor: AppColors.accent,
                    onPressed: () => ChatHistorySheet.show(context),
                  ),
                ),
              );
            },
            icon: const Icon(TablerIcons.plus, size: 20, color: AppColors.accent),
            tooltip: 'New Chat Session',
          ),
          const SizedBox(width: 4),
          // Language selection chip button
          GestureDetector(
            onTap: () => LanguageSheet.show(
              context,
              current: _language,
              onSelected: (l) => setState(() => _language = l),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(TablerIcons.language, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    _language.label,
                    style: AppTypography.inter(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(
    BuildContext context,
    SessionProvider session,
    DocumentProvider docs,
    Document? activeDoc,
    SettingsProvider settings,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Select Document Chip
          Expanded(
            child: GestureDetector(
              onTap: () => _showDocPicker(context, session, docs),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: activeDoc != null ? AppColors.accent.withValues(alpha: 0.12) : AppColors.surface,
                  border: Border.all(
                    color: activeDoc != null ? AppColors.accent : AppColors.border,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      activeDoc != null ? _iconForType(activeDoc.type) : TablerIcons.file_plus,
                      size: 14,
                      color: activeDoc != null ? AppColors.accent : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        activeDoc != null ? activeDoc.name : 'Select Document to Study…',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: activeDoc != null ? AppColors.accent : AppColors.textMuted,
                        ),
                      ),
                    ),
                    Icon(
                      TablerIcons.chevron_down,
                      size: 14,
                      color: activeDoc != null ? AppColors.accent : AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Socratic Mode Pill Toggle
          GestureDetector(
            onTap: () => settings.toggleSocraticMode(!settings.socraticMode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: settings.socraticMode ? AppColors.greenBg : AppColors.surface,
                border: Border.all(
                  color: settings.socraticMode ? AppColors.greenBorder : AppColors.border,
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    TablerIcons.school,
                    size: 14,
                    color: settings.socraticMode ? AppColors.green : AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    settings.socraticMode ? 'Socratic' : 'Direct',
                    style: AppTypography.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: settings.socraticMode ? AppColors.green : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Chat History pill
          if (session.sessions.isNotEmpty) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => ChatHistorySheet.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border, width: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(TablerIcons.history, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'History (${session.sessions.length})',
                      style: AppTypography.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// History sidebar drawer for fast, intuitive conversation browsing
  Widget _buildHistoryDrawer(BuildContext context, SessionProvider session) {
    return Drawer(
      backgroundColor: AppColors.bgPrimary,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(TablerIcons.history, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chat History',
                          style: AppTypography.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${session.sessions.length} conversations',
                          style: AppTypography.inter(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.x, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    session.startNewSession();
                  },
                  icon: const Icon(TablerIcons.plus, size: 16),
                  label: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 16),
            Expanded(
              child: session.sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(TablerIcons.message_circle_off, size: 36, color: AppColors.textMuted),
                          const SizedBox(height: 10),
                          Text('No past chats yet', style: AppTypography.spaceGrotesk(fontSize: 14, color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: session.sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, idx) {
                        final s = session.sessions[idx];
                        final isActive = s.id == session.currentSessionId;

                        return InkWell(
                          onTap: () {
                            session.switchSession(s.id);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.accent.withValues(alpha: 0.1) : AppColors.surface,
                              border: Border.all(
                                color: isActive ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
                                width: isActive ? 1.0 : 0.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isActive ? TablerIcons.message_dots : TablerIcons.message_2,
                                  size: 16,
                                  color: isActive ? AppColors.accent : AppColors.textMuted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.title,
                                        style: AppTypography.spaceGrotesk(
                                          fontSize: 13,
                                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            _formatTimestamp(s.updatedAt),
                                            style: AppTypography.inter(fontSize: 9.5, color: AppColors.textMuted),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text('•', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${s.messages.length} msgs',
                                            style: AppTypography.inter(fontSize: 9.5, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(TablerIcons.trash, size: 14, color: AppColors.textMuted),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => session.deleteSession(s.id),
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
      ),
    );
  }
}
