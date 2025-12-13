import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_recorder_widget.dart';

class MessageInput extends StatefulWidget {
  final String chatId;
  final bool isSending;
  final Function(String) onSendMessage;
  final Function(String) onSendAudio;

  const MessageInput({
    super.key,
    required this.chatId,
    required this.isSending,
    required this.onSendMessage,
    required this.onSendAudio,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _textController = TextEditingController();
  bool _isRecording = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      setState(() {
        _isRecording = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Требуется разрешение на использование микрофона'),
          ),
        );
      }
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !widget.isSending) {
      widget.onSendMessage(text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return AudioRecorderWidget(
        onSend: (audioPath) {
          widget.onSendAudio(audioPath);
          setState(() {
            _isRecording = false;
          });
        },
        onCancel: () {
          setState(() {
            _isRecording = false;
          });
        },
      );
    }

    return SafeArea(
      bottom: true,
      child: Container(
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Сообщение',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.isSending ? null : _sendMessage,
            icon: widget.isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            color: Theme.of(context).colorScheme.primary,
          ),
          IconButton(
            onPressed: _requestMicrophonePermission,
            icon: const Icon(Icons.mic),
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    ),
    );
  }
}


