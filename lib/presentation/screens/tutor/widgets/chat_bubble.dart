import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:denizen_ai/denizen_ai.dart' hide ChatMessage;
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../models/chat_message.dart';
import '../../../../core/utils/text_sanitizer.dart';
import '../../../widgets/app_markdown_text.dart';
import 'citation_card.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final VoidCallback? onCitationTap;

  const ChatBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onCitationTap,
  });

  static final DenizenVoiceSession _voiceSession = DenizenVoiceSession();

  Future<void> _speak(String text) async {
    await _voiceSession.speak(TextSanitizer.cleanOutput(text));
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: TextSanitizer.cleanOutput(text)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied response to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.indigo.withValues(alpha: 0.18),
            border: Border.all(color: AppColors.indigo.withValues(alpha: 0.3), width: 0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            message.content,
            style: AppTypography.inter(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    // AI Response Bubble — Identical to AI Research Bubble Aesthetic
    return Container(
      margin: const EdgeInsets.only(right: 24, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: const Icon(
              TablerIcons.sparkles,
              size: 16,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Dalili',
                      style: AppTypography.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    if (!isStreaming && message.content.isNotEmpty) ...[
                      IconButton(
                        onPressed: () => _speak(message.content),
                        icon: const Icon(TablerIcons.volume, size: 16, color: AppColors.accent),
                        tooltip: 'Read Aloud',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _copyToClipboard(context, message.content),
                        icon: const Icon(TablerIcons.copy, size: 16, color: AppColors.textMuted),
                        tooltip: 'Copy',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border, width: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.content.isEmpty && isStreaming)
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Thinking…',
                              style: AppTypography.inter(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        )
                      else
                        AppMarkdownText(message.content),
                      if (message.citation != null) ...[
                        const SizedBox(height: 10),
                        CitationCard(
                          citation: message.citation!,
                          onTap: onCitationTap,
                        ),
                      ],
                      if (message.generationSeconds != null && !isStreaming) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, size: 12, color: Colors.teal.shade300),
                            const SizedBox(width: 4),
                            Text(
                              'Generated in ${message.generationSeconds!.toStringAsFixed(1)}s',
                              style: AppTypography.caption.copyWith(
                                color: Colors.teal.shade300,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}