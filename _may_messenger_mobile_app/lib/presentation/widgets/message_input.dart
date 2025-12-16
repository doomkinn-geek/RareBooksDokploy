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
  Offset _dragOffset = Offset.zero;
  AnimationController? _scaleController;
  AnimationController? _slideController;
  bool _showCancelHint = false;
  bool _showLockHint = false;
  
  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _slideController = AnimationController(
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
    _slideController?.dispose();
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
          _dragOffset = Offset.zero;
        });

        _scaleController?.forward();
        _slideController?.forward();

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
    if (_recordingState != RecordingState.recording) return;
    
    await _stopRecording();
    _scaleController?.reverse();
    _slideController?.reverse();
    
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      widget.onSendAudio(_audioPath!);
    }
    
    setState(() {
      _recordingState = RecordingState.idle;
      _audioPath = null;
      _recordDuration = Duration.zero;
      _dragOffset = Offset.zero;
      _showCancelHint = false;
      _showLockHint = false;
    });
  }

  Future<void> _cancelRecording() async {
    await _stopRecording();
    _scaleController?.reverse();
    _slideController?.reverse();
    
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      await File(_audioPath!).delete();
    }
    
    setState(() {
      _recordingState = RecordingState.idle;
      _audioPath = null;
      _recordDuration = Duration.zero;
      _dragOffset = Offset.zero;
      _showCancelHint = false;
      _showLockHint = false;
    });
  }

  void _lockRecording() {
    _scaleController?.reverse();
    _slideController?.reverse();
    setState(() {
      _recordingState = RecordingState.locked;
      _dragOffset = Offset.zero;
      _showCancelHint = false;
      _showLockHint = false;
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
            if (_recordingState != RecordingState.recording) return;
            
            setState(() {
              _dragOffset = Offset(
                details.localOffsetFromOrigin.dx,
                details.localOffsetFromOrigin.dy,
              );
              
              // Show hints based on drag direction
              _showCancelHint = _dragOffset.dx < -50;
              _showLockHint = _dragOffset.dy < -50;
            });
            
            // Lock if dragged up more than 100px
            if (_dragOffset.dy < -100) {
              _lockRecording();
            }
            // Cancel if dragged left more than 150px
            else if (_dragOffset.dx < -150) {
              _cancelRecording();
            }
          },
          onLongPressEnd: (_) {
            if (_recordingState == RecordingState.recording) {
              // Send if not cancelled
              if (_dragOffset.dx > -150) {
                _sendAudio();
              }
            }
          },
          onLongPressCancel: () {
            if (_recordingState == RecordingState.recording) {
              _cancelRecording();
            }
          },
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.3).animate(
              CurvedAnimation(
                parent: _scaleController!,
                curve: Curves.elasticOut,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: _recordingState == RecordingState.recording
                  ? BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Icon(
                Icons.mic,
                size: 28,
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

    return Stack(
      alignment: Alignment.center,
      children: [
        // Main recording UI
        Row(
          children: [
            // Cancel indicator (left)
            AnimatedOpacity(
              opacity: _showCancelHint ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.delete_outline,
                  color: _showCancelHint ? Colors.red : Colors.grey,
                  size: 28,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Recording timer with red dot
            Expanded(
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset.zero,
                  end: Offset(_dragOffset.dx / 200, 0),
                ).animate(_slideController!),
                child: Row(
                  children: [
                    // Animated red dot
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      onEnd: () {
                        // Restart animation for blinking effect
                        if (mounted && _recordingState == RecordingState.recording) {
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '◀ Отмена',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        // Lock indicator (top)
        Positioned(
          top: -60,
          child: AnimatedOpacity(
            opacity: _showLockHint ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 150),
            child: Column(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: _showLockHint 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.grey,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.arrow_upward,
                  color: _showLockHint 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.grey,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  'Вверх',
                  style: TextStyle(
                    fontSize: 10,
                    color: _showLockHint 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


