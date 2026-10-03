/// Text sanitizer utilities for cleaning model output across Dalili.
/// Strips special tokens, ChatML tags, thinking blocks, and raw markdown symbols
/// for clean Text-To-Speech (TTS) voice reading and plain-text copying.
class TextSanitizer {
  /// Strips special characters, tokenizer artifacts, and raw markdown symbols
  /// so voice synthesizers don't read out symbols like "hash hash", "asterisk", etc.
  static String cleanOutput(String raw) {
    if (raw.isEmpty) return raw;

    String text = raw;

    // 1. Strip full reasoning/thinking blocks first (both completed and in-progress streaming)
    text = text.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<think>(?:(?!<\/think>)[\s\S])*', caseSensitive: false), '');

    // 2. Strip ChatML, special tokens, tokenizer tags, and any stray thinking tags
    text = text.replaceAll(
      RegExp(r'<\|(?:im_start|im_end|endoftext|user|assistant|system|extra_\d+)[^>]*\|?>',
          caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<\/?(?:s|s0|inst|sys|think)[^>]*>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\[\/?(?:INST|SYS)\]', caseSensitive: false),
      '',
    );

    // 3. Strip code block markers while preserving content
    text = text.replaceAll(RegExp(r'```[a-zA-Z0-9_\-]*'), '');
    text = text.replaceAll('```', '');
    text = text.replaceAll('`', '');

    // 4. Clean markdown links [Title](url) -> Title
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
      (match) => match.group(1) ?? '',
    );

    // 5. Strip markdown headings (e.g. "### Summary" -> "Summary" and inline hashes)
    text = text.replaceAll(RegExp(r'^[ \t]*#{1,6}[ \t]*', multiLine: true), '');
    text = text.replaceAll('#', '');

    // 6. Strip bullet symbols at line beginnings or following colons (- bullet -> bullet)
    text = text.replaceAll(RegExp(r'(?:^|[ \t]+|:\s*)[-+*•][ \t]+', multiLine: true), ' ');

    // 7. Strip inline bold/italic markers (*, **, _, __, ~, ~~)
    text = text.replaceAll(RegExp(r'[*_~\[\]\\]'), '');
    text = text.replaceAll(RegExp(r'[✦✓❌⚠•▪▫★☆●○◆◇►◄▶▼▲|]'), '');
    text = text.replaceAll(RegExp(r'^[ \t]*>[ \t]*', multiLine: true), '');
    text = text.replaceAll('>', '');

    // 8. Collapse excessive line breaks and multiple spaces
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r'[ \t]+$', multiLine: true), '');

    return text.trim();
  }
}
