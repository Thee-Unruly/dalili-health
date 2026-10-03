enum MessageRole { user, ai }

enum Language { english, swahili, french }

extension LanguageExt on Language {
  String get label {
    switch (this) {
      case Language.english:  return 'EN';
      case Language.swahili:  return 'SW';
      case Language.french:   return 'FR';
    }
  }

  String get fullName {
    switch (this) {
      case Language.english:  return 'English';
      case Language.swahili:  return 'Kiswahili';
      case Language.french:   return 'Français';
    }
  }
}

enum ModelMode { lite, power }

extension ModelModeExt on ModelMode {
  String get label {
    switch (this) {
      case ModelMode.lite:  return '1B Lite';
      case ModelMode.power: return '3B Power';
    }
  }
}

class CitationRef {
  final String docName;
  final int page;
  final String excerpt;

  const CitationRef({
    required this.docName,
    required this.page,
    required this.excerpt,
  });
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final Language? language;
  final ModelMode? model;
  final CitationRef? citation;
  final double? generationSeconds;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.language,
    this.model,
    this.citation,
    this.generationSeconds,
  });
}