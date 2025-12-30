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
import 'audio_recorder_widget.dart';
import '../providers/signalr_provider.dart';

enum RecordingState { idle, recording, locked }
enum HapticType { light, medium, heavy, selection }

// Пороговые значения для жестов (в dp, конвертируются в пиксели)
const double _cancelThreshold = 55.0; // ~20-30dp
const double _lockThreshold = 55.0; // ~20-30dp

class MessageInput extends ConsumerStatefulWidget {
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
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FocusNode _textFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  
  RecordingState _recordingState = RecordingState.idle;
  String? _audioPath;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  Timer? _amplitudeTimer;
  DateTime? _recordingStartTime;
  Offset _dragOffset = Offset.zero;
  Offset? _initialPointerPosition;
  AnimationController? _scaleController;
  AnimationController? _pulseController;
  AnimationController? _slideController;
  bool _showCancelHint = false;
  bool _showLockHint = false;
  bool _hasText = false;
  Timer? _typingTimer;
  bool _isCurrentlyTyping = false;
  bool _showEmojiPicker = false;
  double _amplitude = 0.0; // Для waveform/pulsating ring
  bool _microphonePermissionGranted = false;
  bool _isPointerDown = false; // Отслеживание нажатия
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Быстрые анимации для мгновенного фидбека (16-32ms визуальный отклик)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    
    // Запрашиваем разрешения заранее
    _requestMicrophonePermission();
    
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _textFocusNode.dispose();
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _typingTimer?.cancel();
    if (_isCurrentlyTyping) {
      _sendTypingIndicator(false);
    }
    _audioRecorder.dispose();
    _scaleController?.dispose();
    _pulseController?.dispose();
    _slideController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Обработка прерываний (входящий звонок, сворачивание приложения)
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_recordingState == RecordingState.recording || 
          _recordingState == RecordingState.locked) {
        _cancelRecording();
      }
    }
  }

  /// Запрашивает разрешение микрофона заранее
  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      setState(() {
        _microphonePermissionGranted = true;
      });
    } else if (status.isDenied) {
      // Запрашиваем разрешение заранее, но не навязчиво
      final result = await Permission.microphone.request();
      setState(() {
        _microphonePermissionGranted = result.isGranted;
      });
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

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !widget.isSending) {
      widget.onSendMessage(text);
      _textController.clear();
    }
  }

  /// Начинает запись немедленно при touch down (< 100ms latency)
  Future<void> _startRecording() async {
    // Мгновенный визуальный фидбек и haptic на touch down (до проверки разрешений)
    _triggerHaptic(HapticType.light);
    _scaleController?.forward();
    
    // Немедленно обновляем состояние для визуального фидбека
    setState(() {
      _recordDuration = Duration.zero;
      _recordingStartTime = DateTime.now();
      _amplitude = 0.0;
    });

    // Проверяем разрешение (должно быть уже запрошено заранее)
    if (!_microphonePermissionGranted) {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          // Откатываем изменения, если разрешение не предоставлено
          _scaleController?.reverse();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Требуется разрешение на использование микрофона'),
              ),
            );
            setState(() {
              _recordingState = RecordingState.idle;
              _isPointerDown = false;
              _recordDuration = Duration.zero;
              _recordingStartTime = null;
            });
          }
          return;
        }
        setState(() {
          _microphonePermissionGranted = true;
        });
      } else {
        setState(() {
          _microphonePermissionGranted = true;
        });
      }
    }

    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final audioPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        // Старт записи без задержек
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
        });

        _slideController?.forward();
        _pulseController?.repeat(reverse: true); // Запускаем пульсацию во время записи

        // Таймер для отображения длительности (обновление каждые 100ms для плавности)
        _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (mounted && _recordingStartTime != null) {
            setState(() {
              _recordDuration = DateTime.now().difference(_recordingStartTime!);
            });
          }
        });

        // Таймер для получения уровня сигнала (waveform)
        _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
          if (mounted && _recordingState == RecordingState.recording) {
            try {
              final amplitude = await _audioRecorder.getAmplitude();
              if (mounted) {
                setState(() {
                  // Нормализуем амплитуду (обычно -160 до 0 dB)
                  _amplitude = (amplitude.current + 160) / 160.0; // 0.0 - 1.0
                  _amplitude = _amplitude.clamp(0.0, 1.0);
                });
              }
            } catch (e) {
              // Игнорируем ошибки получения амплитуды
            }
          }
        });
      } else {
        // Нет разрешения после проверки - откатываем
        _scaleController?.reverse();
        _slideController?.reverse();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Требуется разрешение на использование микрофона'),
            ),
          );
          setState(() {
            _recordingState = RecordingState.idle;
            _isPointerDown = false;
            _recordDuration = Duration.zero;
            _recordingStartTime = null;
          });
        }
      }
    } catch (e) {
      // Откатываем состояние при ошибке
      _scaleController?.reverse();
      _slideController?.reverse();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка записи: $e')),
        );
        setState(() {
          _recordingState = RecordingState.idle;
          _isPointerDown = false;
          _recordDuration = Duration.zero;
          _recordingStartTime = null;
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController?.stop(); // Останавливаем пульсацию
    await _audioRecorder.stop();
    setState(() {
      _amplitude = 0.0;
    });
  }

  Future<void> _sendAudio() async {
    if (_recordingState != RecordingState.recording && 
        _recordingState != RecordingState.locked) return;
    
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
      _recordingStartTime = null;
      _dragOffset = Offset.zero;
      _initialPointerPosition = null;
      _showCancelHint = false;
      _showLockHint = false;
      _isPointerDown = false;
    });
  }

  Future<void> _cancelRecording() async {
    // Haptic feedback on cancel
    _triggerHaptic(HapticType.heavy);
    
    await _stopRecording();
    _scaleController?.reverse();
    _slideController?.reverse();
    
    // Немедленно удаляем временный файл
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      try {
        await File(_audioPath!).delete();
      } catch (e) {
        // Игнорируем ошибки удаления
      }
    }
    
    setState(() {
      _recordingState = RecordingState.idle;
      _audioPath = null;
      _recordDuration = Duration.zero;
      _recordingStartTime = null;
      _dragOffset = Offset.zero;
      _initialPointerPosition = null;
      _showCancelHint = false;
      _showLockHint = false;
      _isPointerDown = false;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            onPointerDown: (event) {
              if (_recordingState == RecordingState.idle && !_hasText) {
                // Сохраняем начальную позицию и немедленно начинаем запись
                _initialPointerPosition = event.localPosition;
                _isPointerDown = true;
                
                // Мгновенный старт записи на touch down (не на long press!)
                _startRecording();
              }
            },
            onPointerMove: _recordingState == RecordingState.recording && _isPointerDown
                ? (event) {
                    if (_initialPointerPosition != null) {
                      // Вычисляем смещение от начальной позиции (уже в логических пикселях/dp)
                      final offset = Offset(
                        event.localPosition.dx - _initialPointerPosition!.dx,
                        event.localPosition.dy - _initialPointerPosition!.dy,
                      );
                      
                      setState(() {
                        _dragOffset = offset;
                        
                        // Пороги для подсказок (чуть меньше порогов активации)
                        _showCancelHint = offset.dx < -_cancelThreshold * 0.6;
                        _showLockHint = offset.dy < -_lockThreshold * 0.6;
                      });
                      
                      // Активация жестов при достижении порогов
                      if (offset.dy < -_lockThreshold) {
                        _lockRecording();
                      } else if (offset.dx < -_cancelThreshold) {
                        _cancelRecording();
                      }
                    }
                  }
                : null,
            onPointerUp: (event) {
              _isPointerDown = false;
              
              if (_recordingState == RecordingState.recording) {
                // Если не было отмены или блокировки, отправляем
                if (_dragOffset.dx > -_cancelThreshold && 
                    _dragOffset.dy > -_lockThreshold) {
                  _sendAudio();
                } else {
                  // Уже отменено жестом, просто очищаем
                  _initialPointerPosition = null;
                }
              } else {
                // Pointer up без записи, очищаем
                _initialPointerPosition = null;
              }
            },
            onPointerCancel: (event) {
              // Отмена жеста (например, системное прерывание)
              _isPointerDown = false;
              if (_recordingState == RecordingState.recording) {
                _cancelRecording();
              }
              _initialPointerPosition = null;
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
            // Кнопка микрофона с минимальным размером 48x48dp для touch target
            Semantics(
              label: 'Кнопка записи голосового сообщения',
              button: true,
              child: Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.all(4),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                    CurvedAnimation(
                      parent: _scaleController!,
                      curve: Curves.easeOut,
                    ),
                  ),
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
    
    // Вычисляем позицию микрофона на основе жеста (offset уже в логических пикселях)
    final micOffsetX = _dragOffset.dx.clamp(-_cancelThreshold, 0.0);
    final micOffsetY = _dragOffset.dy.clamp(-_lockThreshold, 0.0);

    return SizedBox(
      height: 56, // Фиксированная высота для соответствия обычному UI
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Основной UI записи (фиксированная позиция)
          Row(
            children: [
              const SizedBox(width: 16),
              
              // Красная точка с пульсацией (индикатор записи)
              AnimatedBuilder(
                animation: _pulseController!,
                builder: (context, child) {
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.6 * (0.5 + _pulseController!.value * 0.5)),
                          blurRadius: 6 + _pulseController!.value * 4,
                          spreadRadius: 2 + _pulseController!.value * 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(width: 12),
              
              // Таймер записи (мм:сс)
              Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Waveform / Pulsating ring (визуализация уровня сигнала)
              AnimatedBuilder(
                animation: _pulseController!,
                builder: (context, child) {
                  // Используем амплитуду для создания waveform эффекта
                  final pulseScale = 0.8 + (_amplitude * 0.4) + (_pulseController!.value * 0.2);
                  return Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(
                          0.3 + (_amplitude * 0.7),
                        ),
                        width: 2 * pulseScale,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 8 * (0.5 + _amplitude * 0.5),
                        height: 8 * (0.5 + _amplitude * 0.5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(
                            0.5 + (_amplitude * 0.5),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const Spacer(),
              
              // Подсказка жестов
              AnimatedOpacity(
                opacity: _showCancelHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Text(
                  'Смахни влево — отмена',
                  style: TextStyle(
                    fontSize: 14,
                    color: _showCancelHint ? Colors.red : Colors.grey[600],
                  ),
                ),
              ),
              
              if (!_showCancelHint && _showLockHint)
                AnimatedOpacity(
                  opacity: _showLockHint ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    'Вверх — блокировка',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              
              const SizedBox(width: 80), // Место для кнопки микрофона
            ],
          ),
          
          // Индикатор блокировки (над UI)
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
          
          // Кнопка микрофона (движется с жестом)
          Positioned(
            right: 8 - micOffsetX,
            bottom: 0 - micOffsetY,
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
        ],
      ),
    );
  }
}


