import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_recorder_widget.dart';
import 'image_picker_buttons.dart';

enum RecordingState { idle, recording, locked }
enum HapticType { light, medium, heavy, selection }

class MessageInput extends StatefulWidget {
  final String chatId;
  final bool isSending;
  final Function(String) onSendMessage;
  final Function(String) onSendAudio;
  final Function(String) onSendImage;

  const MessageInput({
    super.key,
    required this.chatId,
    required this.isSending,
    required this.onSendMessage,
    required this.onSendAudio,
    required this.onSendImage,
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
  Offset? _initialPointerPosition;
  AnimationController? _scaleController;
  AnimationController? _slideController;
  bool _showCancelHint = false;
  bool _showLockHint = false;
  bool _hasText = false; // Track if text field has content
  
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
    
    // Listen to text changes to toggle send/mic button
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (_hasText != hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
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

    // Haptic feedback on start
    _triggerHaptic(HapticType.medium);

    try {
      if (await _audioRecorder.hasPermission()) {
        // Cancel existing timer if any
        _timer?.cancel();
        _timer = null;
        
        // Reset duration BEFORE starting to avoid showing old value
        setState(() {
          _recordDuration = Duration.zero;
        });

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
          _dragOffset = Offset.zero;
          // Don't reset _initialPointerPosition as it was set by onPointerDown
        });

        _scaleController?.forward();
        _slideController?.forward();

        // Start fresh timer from zero
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
    _timer = null; // Reset timer to avoid reusing old tick values
    await _audioRecorder.stop();
  }

  Future<void> _sendAudio() async {
    if (_recordingState != RecordingState.recording) return;
    
    // Haptic feedback on send
    _triggerHaptic(HapticType.light);
    
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
      _initialPointerPosition = null;
      _showCancelHint = false;
      _showLockHint = false;
    });
  }

  Future<void> _cancelRecording() async {
    // Haptic feedback on cancel
    _triggerHaptic(HapticType.heavy);
    
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
      _initialPointerPosition = null;
      _showCancelHint = false;
      _showLockHint = false;
    });
  }

  void _lockRecording() {
    // Haptic feedback on lock
    _triggerHaptic(HapticType.medium);
    
    _scaleController?.reverse();
    _slideController?.reverse();
    setState(() {
      _recordingState = RecordingState.locked;
      _dragOffset = Offset.zero;
      _initialPointerPosition = null;
      _showCancelHint = false;
      _showLockHint = false;
    });
  }

  /// Trigger haptic feedback based on type
  void _triggerHaptic(HapticType type) {
    switch (type) {
      case HapticType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show full AudioRecorderWidget when recording is locked
    if (_recordingState == RecordingState.locked) {
      return SafeArea(
        bottom: true,
        child: AudioRecorderWidget(
          audioRecorder: _audioRecorder,
          audioPath: _audioPath,
          initialDuration: _recordDuration,
          onSend: (audioPath) {
            widget.onSendAudio(audioPath);
            setState(() {
              _recordingState = RecordingState.idle;
              _audioPath = null;
              _recordDuration = Duration.zero;
            });
          },
          onCancel: () {
            if (_audioPath != null && File(_audioPath!).existsSync()) {
              File(_audioPath!).delete();
            }
            setState(() {
              _recordingState = RecordingState.idle;
              _audioPath = null;
              _recordDuration = Duration.zero;
            });
          },
        ),
      );
    }

    return SafeArea(
      bottom: true,
      child: Container(
          padding: const EdgeInsets.all(8),
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
          clipBehavior: Clip.none,
          child: Listener(
            onPointerDown: (event) {
              if (_recordingState == RecordingState.idle) {
                // Save initial position when starting to press
                _initialPointerPosition = event.localPosition;
              }
            },
            onPointerMove: _recordingState == RecordingState.recording
                ? (event) {
                    if (_initialPointerPosition != null) {
                      setState(() {
                        // Calculate offset from the initial press position
                        _dragOffset = Offset(
                          event.localPosition.dx - _initialPointerPosition!.dx,
                          event.localPosition.dy - _initialPointerPosition!.dy,
                        );
                        
                        _showCancelHint = _dragOffset.dx < -50;
                        _showLockHint = _dragOffset.dy < -50;
                      });
                      
                      if (_dragOffset.dy < -100) {
                        _lockRecording();
                      } else if (_dragOffset.dx < -150) {
                        _cancelRecording();
                      }
                    }
                  }
                : null,
            onPointerUp: (event) {
              if (_recordingState == RecordingState.recording) {
                if (_dragOffset.dx > -150 && _dragOffset.dy > -100) {
                  _sendAudio();
                } else {
                  // Already cancelled by swipe, just clean up
                  _initialPointerPosition = null;
                }
              } else {
                // Pointer up without recording, just clean up
                _initialPointerPosition = null;
              }
            },
            child: _recordingState == RecordingState.recording
                ? _buildRecordingUI()
                : _buildNormalUI(),
          ),
        ),
    );
  }

  Widget _buildNormalUI() {
    return SizedBox(
      height: 56, // Fixed height to match recording UI
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image picker buttons
          ImagePickerButtons(
            onImageSelected: (imagePath) {
              widget.onSendImage(imagePath);
            },
          ),
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
          // Show send button if text exists, otherwise show mic button
          if (_hasText)
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
            )
          else
            GestureDetector(
              onLongPressStart: (details) {
                _startRecording();
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
      ),
    );
  }

  Widget _buildRecordingUI() {
    final minutes = _recordDuration.inMinutes;
    final seconds = _recordDuration.inSeconds % 60;
    
    // Calculate mic position based on drag
    final micOffsetX = _dragOffset.dx.clamp(-150.0, 0.0);
    final micOffsetY = _dragOffset.dy.clamp(-100.0, 0.0);

    return SizedBox(
      height: 56, // Fixed height to match normal UI
      child: Stack(
        clipBehavior: Clip.none, // Allow overflow
        children: [
        // Main recording UI (fixed position)
        Row(
          children: [
            const SizedBox(width: 16),
            
            // Red dot with blink animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
              onEnd: () {
                if (mounted && _recordingState == RecordingState.recording) {
                  setState(() {});
                }
              },
            ),
            
            const SizedBox(width: 12),
            
            // Timer
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const Spacer(),
            
            // Cancel hint text
            AnimatedOpacity(
              opacity: _showCancelHint ? 1.0 : 0.7,
              duration: const Duration(milliseconds: 150),
              child: Text(
                'Влево — отмена',
                style: TextStyle(
                  fontSize: 14,
                  color: _showCancelHint ? Colors.red : Colors.grey[600],
                ),
              ),
            ),
            
            const SizedBox(width: 80), // Space for mic button
          ],
        ),
        
        // Lock indicator (top, above the UI)
        Positioned(
          right: 30,
          bottom: 70,
          child: AnimatedOpacity(
            opacity: _showLockHint ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_open,
                  color: _showLockHint 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.grey,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 2,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _showLockHint 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.grey,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Microphone button (moves with drag)
        Positioned(
          right: 8 - micOffsetX, // Invert X for correct direction
          bottom: 0 - micOffsetY, // Invert Y for correct direction
          child: Transform.translate(
            offset: Offset.zero,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}


