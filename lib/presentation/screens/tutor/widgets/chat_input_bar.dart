import 'package:flutter/material.dart';
import 'package:denizen_ai/denizen_ai.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback? onStop;
  final bool isTyping;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.onStop,
    this.isTyping = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final DenizenVoiceSession _voiceSession = DenizenVoiceSession();
  bool _hasText = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _voiceSession.stopListening();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _voiceSession.stopListening();
      if (mounted) setState(() => _isListening = false);
    } else {
      if (mounted) setState(() => _isListening = true);
      try {
        await _voiceSession.startListening(
          initialText: _controller.text,
          onListeningChanged: (listening) {
            if (mounted) setState(() => _isListening = listening);
          },
          onResult: (text) {
            if (mounted && text.isNotEmpty) {
              setState(() {
                _controller.text = text;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
              });
            }
          },
        );
      } catch (e) {
        if (mounted) setState(() => _isListening = false);
      }
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isTyping) return;
    if (_isListening) {
      _voiceSession.stopListening();
      _isListening = false;
    }
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(
          top: BorderSide(color: AppColors.bgCard, width: 0.5),
        ),
      ),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isListening
                ? AppColors.accent
                : _hasText
                    ? AppColors.indigo.withValues(alpha: 0.4)
                    : AppColors.bgBorder,
            width: _isListening ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.newline,
                style: AppTypography.bodyMd.copyWith(fontSize: 14),
                cursorColor: AppColors.indigo,
                decoration: InputDecoration(
                  hintText: _isListening ? 'Listening to speech...' : 'Ask anything...',
                  hintStyle: AppTypography.bodyMd.copyWith(
                    color: _isListening ? AppColors.accent : AppColors.textDim,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _toggleListening,
              icon: Icon(
                _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                size: 20,
                color: _isListening ? AppColors.accent : AppColors.textDim,
              ),
              tooltip: _isListening ? 'Stop Listening' : 'Voice Input',
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isTyping
                    ? Colors.redAccent.withValues(alpha: 0.85)
                    : _hasText
                        ? AppColors.indigo
                        : AppColors.bgBorder,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: widget.isTyping ? widget.onStop : (_hasText ? _send : null),
                icon: Icon(
                  widget.isTyping ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                  size: widget.isTyping ? 20 : 18,
                  color: widget.isTyping || _hasText
                      ? Colors.white
                      : AppColors.textDim,
                ),
                tooltip: widget.isTyping ? 'Stop Generation' : 'Send Message',
              ),
            ),
          ],
        ),
      ),
    );
  }
}