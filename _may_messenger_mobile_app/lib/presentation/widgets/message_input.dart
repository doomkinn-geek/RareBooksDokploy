import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'audio_recorder_widget.dart';
import '../providers/signalr_provider.dart';
import '../../data/models/message_model.dart';

enum RecordingState { idle, recording, locked }
enum HapticType { light, medium, heavy, selection }

class MessageInput extends ConsumerStatefulWidget {
  final String chatId;
  final bool isSending;
  final Function(String) onSendMessage;
  final Function(String) onSendAudio;
  final Function(String) onSendImage;
  final Function(String filePath, String fileName)? onSendFile;
  
  // Reply mode
  final Message? replyToMessage;
  final VoidCallback? onCancelReply;
  
  // Edit mode
  final Message? editingMessage;
  final VoidCallback? onCancelEdit;
  final Function(String messageId, String newContent)? onSaveEdit;

  const MessageInput({
    super.key,
    required this.chatId,
    required this.isSending,
    required this.onSendMessage,
    required this.onSendAudio,
    required this.onSendImage,
    this.onSendFile,
    this.replyToMessage,
    this.onCancelReply,
    this.editingMessage,
    this.onCancelEdit,
    this.onSaveEdit,
  });

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FocusNode _textFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  
  RecordingState _recordingState = RecordingState.idle;
  String? _audioPath;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  DateTime? _recordingStartTime; // Track when recording started
  Offset _dragOffset = Offset.zero;
  Offset? _initialGlobalPosition; // Use GLOBAL position for correct gesture detection
  AnimationController? _scaleController;
  AnimationController? _slideController;
  bool _showCancelHint = false;
  bool _showLockHint = false;
  bool _hasText = false; // Track if text field has content
  Timer? _typingTimer;
  bool _isCurrentlyTyping = false;
  bool _showEmojiPicker = false; // Track emoji picker visibility
  
  // Cached values for instant recording start
  Directory? _tempDir;
  bool _hasMicPermission = false;
  bool _isInitializingRecording = false; // Prevent double-tap issues
  
  // New animation controllers for Telegram-style recording UI
  AnimationController? _pulseController; // Pulsing ring around mic button
  AnimationController? _arrowController; // Arrow bounce animation
  AnimationController? _cancelTextController; // Cancel text pulse animation
  Animation<double>? _pulseAnimation;
  Animation<double>? _pulseOpacityAnimation;
  Animation<double>? _arrowAnimation;
  Animation<double>? _cancelTextAnimation;
  Animation<double>? _cancelTextOffsetAnimation;
  
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
    
    // Pulsing ring animation (scale 1.0 -> 1.15 -> 1.0, opacity 0.6 -> 0.2 -> 0.6)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
    _pulseOpacityAnimation = Tween<double>(begin: 0.6, end: 0.2).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
    
    // Arrow bounce animation (move up 8dp, then down)
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _arrowAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _arrowController!, curve: Curves.easeInOut),
    );
    
    // Cancel text pulse animation (alpha 0.4 -> 1.0 -> 0.4, slight offset)
    _cancelTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _cancelTextAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _cancelTextController!, curve: Curves.easeInOut),
    );
    _cancelTextOffsetAnimation = Tween<double>(begin: 0.0, end: -4.0).animate(
      CurvedAnimation(parent: _cancelTextController!, curve: Curves.easeInOut),
    );
    
    // Listen to text changes to toggle send/mic button and send typing indicator
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (_hasText != hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
      
      // Send typing indicator
      _onTextChanged(hasText);
    });
    
    // Pre-warm recording: cache temp directory and check permission asynchronously
    _preWarmRecording();
  }
  
  /// Pre-initialize recording dependencies for instant start
  /// This runs in background and doesn't block UI
  Future<void> _preWarmRecording() async {
    try {
      // Cache temp directory
      _tempDir = await getTemporaryDirectory();
      
      // Check microphone permission (don't request yet)
      final status = await Permission.microphone.status;
      _hasMicPermission = status.isGranted;
      
      print('[AUDIO_RECORD] Pre-warmed: tempDir=${_tempDir?.path}, hasMicPermission=$_hasMicPermission');
    } catch (e) {
      print('[AUDIO_RECORD] Pre-warm failed: $e');
    }
  }

  void _onTextChanged(bool hasText) {
    // Send typing indicator
    if (hasText && !_isCurrentlyTyping) {
      _sendTypingIndicator(true);
      _isCurrentlyTyping = true;
    }
    
    // Reset timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isCurrentlyTyping) {
        _sendTypingIndicator(false);
        _isCurrentlyTyping = false;
      }
    });
  }
  
  void _sendTypingIndicator(bool isTyping) {
    try {
      final signalRService = ref.read(signalRServiceProvider);
      signalRService.sendTypingIndicator(widget.chatId, isTyping);
    } catch (e) {
      print('[MessageInput] Failed to send typing indicator: $e');
    }
  }
  
  /// Send activity indicator with type (0 = typing text, 1 = recording audio)
  void _sendActivityIndicator(bool isActive, int activityType) {
    try {
      final signalRService = ref.read(signalRServiceProvider);
      signalRService.sendActivityIndicator(widget.chatId, isActive, activityType);
    } catch (e) {
      print('[MessageInput] Failed to send activity indicator: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _timer?.cancel();
    _typingTimer?.cancel();
    if (_isCurrentlyTyping) {
      _sendTypingIndicator(false);
    }
    _audioRecorder.dispose();
    _scaleController?.dispose();
    _slideController?.dispose();
    _pulseController?.dispose();
    _arrowController?.dispose();
    _cancelTextController?.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
      _textFocusNode.requestFocus();
    } else {
      _textFocusNode.unfocus();
      setState(() {
        _showEmojiPicker = true;
      });
    }
  }

  Future<void> _pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      
      if (image != null) {
        widget.onSendImage(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    if (widget.onSendFile == null) return;
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Check file size (20MB limit)
        if (file.size > 20 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Размер файла не должен превышать 20 МБ')),
            );
          }
          return;
        }
        
        if (file.path != null) {
          widget.onSendFile!(file.path!, file.name);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора файла: $e')),
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

  Future<void> _startRecording() async {
    // Prevent double initialization
    if (_isInitializingRecording || _recordingState != RecordingState.idle) {
      return;
    }
    _isInitializingRecording = true;
    
    try {
      // STEP 1: Instant UI update - show recording state immediately
      // This happens BEFORE any async operations
      _triggerHaptic(HapticType.medium);
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final audioPath = '${_tempDir?.path ?? '/tmp'}/audio_$timestamp.m4a';
      
      // Update UI immediately (non-blocking)
      setState(() {
        _recordDuration = Duration.zero;
        _recordingStartTime = DateTime.now();
        _recordingState = RecordingState.recording;
        _audioPath = audioPath;
        _dragOffset = Offset.zero;
      });
      
      // Start animations immediately (non-blocking)
      _scaleController?.forward();
      _slideController?.forward();
      _startRecordingAnimations();
      
      // Send recording indicator to other participants (activityType: 1 = recording audio)
      _sendActivityIndicator(true, 1);
      
      // Start timer immediately (non-blocking)
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted && _recordingStartTime != null) {
          setState(() {
            _recordDuration = DateTime.now().difference(_recordingStartTime!);
          });
        }
      });
      
      // STEP 2: Check/request permission in background
      if (!_hasMicPermission) {
        final status = await Permission.microphone.status;
        if (!status.isGranted) {
          final result = await Permission.microphone.request();
          if (!result.isGranted) {
            // Permission denied - revert UI
            _cancelRecording();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Требуется разрешение на использование микрофона'),
                ),
              );
            }
            return;
          }
          _hasMicPermission = true;
        } else {
          _hasMicPermission = true;
        }
      }
      
      // STEP 3: Ensure temp directory is cached
      _tempDir ??= await getTemporaryDirectory();
      
      // STEP 4: Start actual recording (this is the only potentially slow operation)
      // But UI is already responsive
      if (await _audioRecorder.hasPermission()) {
        // Update path with correct temp directory if it was null before
        final finalPath = '${_tempDir!.path}/audio_$timestamp.m4a';
        _audioPath = finalPath;
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: finalPath,
        );
        print('[AUDIO_RECORD] Recording started at: $finalPath');
      } else {
        throw Exception('No microphone permission');
      }
    } catch (e) {
      print('[AUDIO_RECORD] Failed to start recording: $e');
      // Revert UI state on error
      _cancelRecording();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка записи: $e')),
        );
      }
    } finally {
      _isInitializingRecording = false;
    }
  }
  
  /// Start all recording-related animations
  void _startRecordingAnimations() {
    // Start pulsing ring animation (infinite repeat)
    _pulseController?.repeat(reverse: true);
    
    // Start arrow bounce animation (infinite repeat)
    _arrowController?.repeat(reverse: true);
    
    // Start cancel text pulse animation (infinite repeat)
    _cancelTextController?.repeat(reverse: true);
  }
  
  /// Stop all recording-related animations
  void _stopRecordingAnimations() {
    _pulseController?.stop();
    _pulseController?.reset();
    
    _arrowController?.stop();
    _arrowController?.reset();
    
    _cancelTextController?.stop();
    _cancelTextController?.reset();
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await _audioRecorder.stop();
  }

  Future<void> _sendAudio() async {
    if (_recordingState != RecordingState.recording) return;
    
    // Haptic feedback on send
    _triggerHaptic(HapticType.light);
    
    // Stop recording indicator
    _sendActivityIndicator(false, 1);
    
    await _stopRecording();
    _scaleController?.reverse();
    _slideController?.reverse();
    _stopRecordingAnimations();
    
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      widget.onSendAudio(_audioPath!);
    }
    
    setState(() {
      _recordingState = RecordingState.idle;
      _audioPath = null;
      _recordDuration = Duration.zero;
      _recordingStartTime = null; // Reset start time
      _dragOffset = Offset.zero;
      _initialGlobalPosition = null;
      _showCancelHint = false;
      _showLockHint = false;
    });
  }

  Future<void> _cancelRecording() async {
    // Haptic feedback on cancel
    _triggerHaptic(HapticType.heavy);
    
    // Stop recording indicator
    _sendActivityIndicator(false, 1);
    
    await _stopRecording();
    _scaleController?.reverse();
    _slideController?.reverse();
    _stopRecordingAnimations();
    
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      await File(_audioPath!).delete();
    }
    
    setState(() {
      _recordingState = RecordingState.idle;
      _audioPath = null;
      _recordDuration = Duration.zero;
      _recordingStartTime = null; // Reset start time
      _dragOffset = Offset.zero;
      _initialGlobalPosition = null;
      _showCancelHint = false;
      _showLockHint = false;
    });
  }

  void _lockRecording() {
    // Haptic feedback on lock - use selection for more precise feedback
    _triggerHaptic(HapticType.selection);
    
    _scaleController?.reverse();
    _slideController?.reverse();
    _stopRecordingAnimations();
    
    // IMPORTANT: Stop the timer here - AudioRecorderWidget will create its own
    // The current _recordDuration will be passed as initialDuration
    _timer?.cancel();
    _timer = null;
    
    setState(() {
      _recordingState = RecordingState.locked;
      _dragOffset = Offset.zero;
      _initialGlobalPosition = null;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview
          if (widget.replyToMessage != null)
            _buildReplyPreview(),
          // Edit preview
          if (widget.editingMessage != null)
            _buildEditPreview(),
          Container(
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
            // onPointerDown is handled by the mic button Listener
            // This outer Listener only handles move and up events
            // IMPORTANT: Use event.position (GLOBAL coordinates) for gesture detection
            // because onPointerDown is in mic button's Listener (different local coordinate system)
            onPointerMove: _recordingState == RecordingState.recording
                ? (event) {
                    if (_initialGlobalPosition != null) {
                      setState(() {
                        // Calculate offset from the initial press position using GLOBAL coordinates
                        _dragOffset = Offset(
                          event.position.dx - _initialGlobalPosition!.dx,
                          event.position.dy - _initialGlobalPosition!.dy,
                        );
                        
                        _showCancelHint = _dragOffset.dx < -50;
                        _showLockHint = _dragOffset.dy < -50;
                      });
                      
                      // Check thresholds for lock/cancel gestures
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
                // Check minimum recording duration (500ms)
                // If less than 500ms, it was a tap - cancel the recording
                final recordingDuration = _recordingStartTime != null 
                    ? DateTime.now().difference(_recordingStartTime!) 
                    : Duration.zero;
                
                if (recordingDuration.inMilliseconds < 500) {
                  // Too short - treat as accidental tap, cancel recording
                  _cancelRecording();
                  _initialGlobalPosition = null;
                  return;
                }
                
                if (_dragOffset.dx > -150 && _dragOffset.dy > -100) {
                  _sendAudio();
                } else {
                  // Already cancelled by swipe, just clean up
                  _initialGlobalPosition = null;
                }
              } else {
                // Pointer up without recording, just clean up
                _initialGlobalPosition = null;
              }
            },
            child: _recordingState == RecordingState.recording
                ? _buildRecordingUI()
                : _buildNormalUI(),
          ),
          ),
          // Emoji picker
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                // Only use textEditingController - it handles emoji insertion automatically
                // Removed onEmojiSelected to prevent double insertion
                textEditingController: _textController,
              ),
            ),
        ],
        ),
    );
  }

  Widget _buildNormalUI() {
    return SizedBox(
      height: 56, // Fixed height to match recording UI
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Emoji button (left side)
          IconButton(
            onPressed: _toggleEmojiPicker,
            icon: Icon(
              _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          // Text input field
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _textFocusNode,
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
              onTap: () {
                // Hide emoji picker when tapping text field
                if (_showEmojiPicker) {
                  setState(() {
                    _showEmojiPicker = false;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          // Attachment button (camera/gallery popup)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.attach_file,
              color: Theme.of(context).colorScheme.primary,
            ),
            onSelected: (value) {
              if (value == 'camera') {
                _pickImage(fromCamera: true);
              } else if (value == 'gallery') {
                _pickImage(fromCamera: false);
              } else if (value == 'file') {
                _pickFile();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'camera',
                child: Row(
                  children: [
                    Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    const Text('Камера'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'gallery',
                child: Row(
                  children: [
                    Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    const Text('Галерея'),
                  ],
                ),
              ),
              if (widget.onSendFile != null)
                PopupMenuItem(
                  value: 'file',
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Файл'),
                  ],
                ),
              ),
            ],
          ),
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
            // Use Listener for instant response on pointer down (no delay)
            Listener(
              onPointerDown: (event) {
                // Save initial GLOBAL position BEFORE starting recording
                // This is critical for gesture detection (swipe left/up)
                // MUST use global position because onPointerMove uses global coordinates too
                _initialGlobalPosition = event.position;
                // Start recording INSTANTLY on touch down
                _startRecording();
              },
              child: GestureDetector(
                // onTap is handled by cancelling short recordings in pointerUp
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
            ),
        ],
      ),
    );
  }

  Widget _buildRecordingUI() {
    return SizedBox(
      height: 56, // Fixed height to match normal UI
      child: Stack(
        clipBehavior: Clip.none, // Allow overflow for lock column
        children: [
          // Main recording row with timer
          _buildRecordingRow(),
          
          // Cancel hint (left side, pulsing)
          _buildCancelHint(),
          
          // Lock column (above mic button)
          _buildLockColumn(),
          
          // Microphone button with pulsing ring
          _buildRecordingButton(),
        ],
      ),
    );
  }

  /// Build the main recording row with red dot and timer
  Widget _buildRecordingRow() {
    final minutes = _recordDuration.inMinutes;
    final seconds = _recordDuration.inSeconds % 60;
    
    return Positioned.fill(
      child: Row(
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
          
          const SizedBox(width: 80), // Space for mic button
        ],
      ),
    );
  }

  /// Build the cancel hint with pulsing animation
  Widget _buildCancelHint() {
    return Positioned(
      left: 100,
      top: 0,
      bottom: 0,
      right: 90,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_cancelTextAnimation, _cancelTextOffsetAnimation]),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_cancelTextOffsetAnimation?.value ?? 0.0, 0),
              child: Opacity(
                opacity: _showCancelHint 
                    ? 1.0 
                    : (_cancelTextAnimation?.value ?? 0.4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      size: 16,
                      color: _showCancelHint ? Colors.red : Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Отмена',
                      style: TextStyle(
                        fontSize: 14,
                        color: _showCancelHint ? Colors.red : Colors.grey[500],
                        fontWeight: _showCancelHint ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build the lock column with animated arrow and lock icon
  Widget _buildLockColumn() {
    // Use _showLockHint flag (set when drag exceeds threshold)
    final isNearLock = _showLockHint;
    
    return Positioned(
      right: 20,
      bottom: 70,
      child: AnimatedOpacity(
        opacity: 1.0, // Always visible during recording
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock icon (changes based on proximity)
              AnimatedScale(
                scale: isNearLock ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  isNearLock ? Icons.lock : Icons.lock_open,
                  color: isNearLock 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.grey[400],
                  size: 24,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Animated arrow pointing up
              AnimatedBuilder(
                animation: _arrowAnimation!,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _arrowAnimation?.value ?? 0),
                    child: Opacity(
                      opacity: isNearLock ? 0.3 : 0.7,
                      child: Icon(
                        Icons.keyboard_arrow_up,
                        size: 20,
                        color: Colors.grey[500],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 4),
              
              // Vertical line indicator
              Container(
                width: 2,
                height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      isNearLock 
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                          : Colors.grey.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the microphone button with pulsing ring
  Widget _buildRecordingButton() {
    // Calculate mic position based on drag
    final micOffsetX = _dragOffset.dx.clamp(-150.0, 0.0);
    final micOffsetY = _dragOffset.dy.clamp(-100.0, 0.0);
    
    return Positioned(
      right: 8 - micOffsetX, // Invert X for correct direction
      bottom: 0 - micOffsetY, // Invert Y for correct direction
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring (outer)
            AnimatedBuilder(
              animation: Listenable.merge([_pulseAnimation, _pulseOpacityAnimation]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation?.value ?? 1.0,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(
                          _pulseOpacityAnimation?.value ?? 0.6,
                        ),
                        width: 2.5,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Main mic button
            Container(
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
          ],
        ),
      ),
    );
  }
  
  /// Build reply preview widget
  Widget _buildReplyPreview() {
    final message = widget.replyToMessage!;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.senderName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.getPreviewText(),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onCancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
  
  /// Build edit preview widget
  Widget _buildEditPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Colors.orange,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Редактирование сообщения',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onCancelEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}


