import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_recorder_widget.dart';

enum RecordingState { idle, recording, locked }

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

class _MessageInputState extends State<MessageInput> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  RecordingState _recordingState = RecordingState.idle;
  String? _audioPath;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  double _dragOffset = 0;
  AnimationController? _scaleController;
  
  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _timer?.cancel();
    _audioRecorder.dispose();
    _scaleController?.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !widget.isSending) {
      widget.onSendMessage(text);
      _textController.clear();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Требуется разрешение на использование микрофона'),
            ),
          );
        }
        return;
      }
    }

    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final audioPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: audioPath,
        );

        setState(() {
          _recordingState = RecordingState.recording;
          _audioPath = audioPath;
          _recordDuration = Duration.zero;
        });

        _scaleController?.forward();

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordDuration = Duration(seconds: timer.tick);
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка записи: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await _audioRecorder.stop();
  }

  Future<void> _sendAudio() async {
    await _stopRecording();
    _scaleController?.reverse();
    
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      widget.onSendAudio(_audioPath!);
    }
    
    setState(() {
      _recordingState = RecordingState.idle;
      _audioPath = null;
      _recordDuration = Duration.zero;
      _dragOffset = 0;
    });
  }

  Future<void> _cancelRecording() async {
    await _stopRecording();
    _scaleController?.reverse();
    
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      await File(_audioPath!).delete();
    }
    
    setState(() {
      _recordingState = RecordingState.idle;
      _audioPath = null;
      _recordDuration = Duration.zero;
      _dragOffset = 0;
    });
  }

  void _lockRecording() {
    setState(() {
      _recordingState = RecordingState.locked;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show full AudioRecorderWidget when recording is locked
    if (_recordingState == RecordingState.locked) {
      return AudioRecorderWidget(
        onSend: (audioPath) {
          widget.onSendAudio(audioPath);
          setState(() {
            _recordingState = RecordingState.idle;
          });
        },
        onCancel: () {
          setState(() {
            _recordingState = RecordingState.idle;
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
        child: _recordingState == RecordingState.recording
            ? _buildRecordingUI()
            : _buildNormalUI(),
      ),
    );
  }

  Widget _buildNormalUI() {
    return Row(
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
        GestureDetector(
          onLongPressStart: (_) => _startRecording(),
          onLongPressMoveUpdate: (details) {
            setState(() {
              _dragOffset = details.localPosition.dx;
            });
            // Lock recording if dragged left more than 100px
            if (_dragOffset < -100) {
              _lockRecording();
            }
          },
          onLongPressEnd: (_) {
            if (_recordingState == RecordingState.recording) {
              _sendAudio();
            }
          },
          onLongPressCancel: () {
            if (_recordingState == RecordingState.recording) {
              _cancelRecording();
            }
          },
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.2).animate(
              CurvedAnimation(
                parent: _scaleController!,
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.mic,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingUI() {
    final minutes = _recordDuration.inMinutes;
    final seconds = _recordDuration.inSeconds % 60;

    return Row(
      children: [
        IconButton(
          onPressed: _cancelRecording,
          icon: const Icon(Icons.delete),
          color: Colors.red,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                  ),
                  Text(
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '← Сдвиньте для блокировки',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48), // Space for balance
      ],
    );
  }
}


