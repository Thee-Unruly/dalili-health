import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// Rich Markdown Text Renderer for Dalili.
/// Converts Markdown formatting (headers, bold, italic, lists, code blocks, quotes)
/// into beautiful, native Flutter widgets without showing raw `#`, `**`, `*`, or `_` symbols.
class AppMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final bool isUser;

  const AppMarkdownText(
    this.text, {
    super.key,
    this.baseStyle,
    this.isUser = false,
  });

  /// Cleans raw model tokens (thinking tags, ChatML tokens) before formatting
  static String preprocessText(String raw) {
    if (raw.isEmpty) return raw;
    String clean = raw;
    // Strip ChatML and tokenizer tokens
    clean = clean.replaceAll(
      RegExp(r'<\|(?:im_start|im_end|endoftext|user|assistant|system|extra_\d+)[^>]*\|?>',
          caseSensitive: false),
      '',
    );
    clean = clean.replaceAll(
      RegExp(r'<\/?(?:s|s0|inst|sys)[^>]*>', caseSensitive: false),
      '',
    );
    clean = clean.replaceAll(
      RegExp(r'\[\/?(?:INST|SYS)\]', caseSensitive: false),
      '',
    );
    // Strip thinking blocks
    clean = clean.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'<think>(?:(?!<\/think>)[\s\S])*', caseSensitive: false), '');
    return clean.trim();
  }

  @override
  Widget build(BuildContext context) {
    final clean = preprocessText(text);
    if (clean.isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultStyle = baseStyle ??
        AppTypography.inter(
          fontSize: 14,
          color: isUser ? Colors.white : AppColors.textPrimary,
          height: 1.5,
        );

    final blocks = _parseBlocks(clean);

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: blocks.map((b) => _buildBlockWidget(b, defaultStyle)).toList(),
      ),
    );
  }

  Widget _buildBlockWidget(_MarkdownBlock block, TextStyle defaultStyle) {
    switch (block.type) {
      case _BlockType.h1:
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text.rich(
            TextSpan(children: _parseInlineFormatting(block.content, defaultStyle)),
            style: AppTypography.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        );

      case _BlockType.h2:
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text.rich(
            TextSpan(children: _parseInlineFormatting(block.content, defaultStyle)),
            style: AppTypography.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        );

      case _BlockType.h3:
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text.rich(
            TextSpan(children: _parseInlineFormatting(block.content, defaultStyle)),
            style: AppTypography.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
              height: 1.4,
            ),
          ),
        );

      case _BlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 8),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _parseInlineFormatting(block.content, defaultStyle)),
                  style: defaultStyle,
                ),
              ),
            ],
          ),
        );

      case _BlockType.numbered:
        return Padding(
          padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '${block.number}.',
                  style: defaultStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _parseInlineFormatting(block.content, defaultStyle)),
                  style: defaultStyle,
                ),
              ),
            ],
          ),
        );

      case _BlockType.codeBlock:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF141720),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: SelectableText(
            block.content,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: Color(0xFF7DD3FC),
              height: 1.4,
            ),
          ),
        );

      case _BlockType.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.accent, width: 3),
            ),
          ),
          child: Text.rich(
            TextSpan(children: _parseInlineFormatting(block.content, defaultStyle)),
            style: defaultStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        );

      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(children: _parseInlineFormatting(block.content, defaultStyle)),
            style: defaultStyle,
          ),
        );
    }
  }

  List<_MarkdownBlock> _parseBlocks(String text) {
    final List<_MarkdownBlock> blocks = [];
    final lines = text.split('\n');
    bool inCodeBlock = false;
    final List<String> codeLines = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Check code block fence
      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          // Close code block
          blocks.add(_MarkdownBlock(
            type: _BlockType.codeBlock,
            content: codeLines.join('\n'),
          ));
          codeLines.clear();
          inCodeBlock = false;
        } else {
          // Open code block
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeLines.add(line);
        continue;
      }

      if (trimmed.isEmpty) {
        continue;
      }

      // Headers (#, ##, ###)
      if (trimmed.startsWith('###')) {
        blocks.add(_MarkdownBlock(
          type: _BlockType.h3,
          content: trimmed.replaceFirst(RegExp(r'^###\s*'), ''),
        ));
      } else if (trimmed.startsWith('##')) {
        blocks.add(_MarkdownBlock(
          type: _BlockType.h2,
          content: trimmed.replaceFirst(RegExp(r'^##\s*'), ''),
        ));
      } else if (trimmed.startsWith('#')) {
        blocks.add(_MarkdownBlock(
          type: _BlockType.h1,
          content: trimmed.replaceFirst(RegExp(r'^#\s*'), ''),
        ));
      }
      // Blockquotes (> quote)
      else if (trimmed.startsWith('>')) {
        blocks.add(_MarkdownBlock(
          type: _BlockType.quote,
          content: trimmed.replaceFirst(RegExp(r'^>\s*'), ''),
        ));
      }
      // Numbered lists (e.g. 1. item, 2. item)
      else if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        final match = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
        if (match != null) {
          blocks.add(_MarkdownBlock(
            type: _BlockType.numbered,
            number: int.tryParse(match.group(1) ?? '1') ?? 1,
            content: match.group(2) ?? '',
          ));
        } else {
          blocks.add(_MarkdownBlock(
            type: _BlockType.paragraph,
            content: trimmed,
          ));
        }
      }
      // Bullet lists (- item, * item, + item, • item)
      else if (trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('+ ') ||
          trimmed.startsWith('• ')) {
        blocks.add(_MarkdownBlock(
          type: _BlockType.bullet,
          content: trimmed.replaceFirst(RegExp(r'^[-*+•]\s*'), ''),
        ));
      }
      // Regular paragraph
      else {
        blocks.add(_MarkdownBlock(
          type: _BlockType.paragraph,
          content: trimmed,
        ));
      }
    }

    // Flush any open code block
    if (inCodeBlock && codeLines.isNotEmpty) {
      blocks.add(_MarkdownBlock(
        type: _BlockType.codeBlock,
        content: codeLines.join('\n'),
      ));
    }

    return blocks;
  }

  /// Parses inline bold (**text** or __text__), italic (*text* or _text_), and inline code (`code`)
  List<TextSpan> _parseInlineFormatting(String text, TextStyle baseStyle) {
    if (text.isEmpty) return [];

    final List<TextSpan> spans = [];

    // Regex matching:
    // 1. `inline code`
    // 2. ***bold italic***
    // 3. **bold** or __bold__
    // 4. *italic* or _italic_
    final inlineRegex = RegExp(
      r'(`(?<codeText>[^`]+)`)'
      r'|(\*\*\*(?<boldItalicText>[^*]+)\*\*\*)'
      r'|(\*\*(?<boldText1>[^*]+)\*\*|__(?<boldText2>[^_]+)__)'
      r'|(\*(?<italicText1>[^*]+)\*|_(?<italicText2>[^_]+)_)',
    );

    int currentIndex = 0;

    for (final match in inlineRegex.allMatches(text)) {
      // Add preceding plain text
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: baseStyle,
        ));
      }

      final codeText = match.namedGroup('codeText');
      final boldItalicText = match.namedGroup('boldItalicText');
      final boldText = match.namedGroup('boldText1') ?? match.namedGroup('boldText2');
      final italicText = match.namedGroup('italicText1') ?? match.namedGroup('italicText2');

      if (codeText != null) {
        spans.add(TextSpan(
          text: ' $codeText ',
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: 12.5,
            color: const Color(0xFF7DD3FC),
            backgroundColor: const Color(0xFF1E2433),
          ),
        ));
      } else if (boldItalicText != null) {
        spans.add(TextSpan(
          text: boldItalicText,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: isUser ? Colors.white : AppColors.textPrimary,
          ),
        ));
      } else if (boldText != null) {
        spans.add(TextSpan(
          text: boldText,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: isUser ? Colors.white : AppColors.textPrimary,
          ),
        ));
      } else if (italicText != null) {
        spans.add(TextSpan(
          text: italicText,
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
            color: isUser ? Colors.white : AppColors.textSecondary,
          ),
        ));
      }

      currentIndex = match.end;
    }

    // Add remaining plain text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: baseStyle,
      ));
    }

    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }
}

enum _BlockType { h1, h2, h3, paragraph, bullet, numbered, codeBlock, quote }

class _MarkdownBlock {
  final _BlockType type;
  final String content;
  final int number;

  _MarkdownBlock({
    required this.type,
    required this.content,
    this.number = 1,
  });
}
