import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../data/models/message_model.dart';
import '../../data/models/poll_model.dart';
import 'poll_widget.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/global_audio_service.dart';
import '../../core/services/proximity_audio_service.dart';
import '../../core/themes/app_theme.dart';
import '../providers/profile_provider.dart';
import '../providers/contacts_names_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/messages_provider.dart';
import 'fullscreen_image_viewer.dart';
import 'audio_waveform.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final Message message;
  final bool isHighlighted;
  final Function(String messageId)? onReplyTap;
  
  /// List of all image messages in the chat for horizontal swiping in viewer
  final List<Message>? allImageMessages;
  /// Index of this message in the allImageMessages list
  final int imageIndex;

  const MessageBubble({
    super.key,
    required this.message,
    this.isHighlighted = false,
    this.onReplyTap,
    this.allImageMessages,
    this.imageIndex = 0,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  // NOTE: Audio playback moved to GlobalAudioService
  // Local AudioPlayer kept only for preloading duration
  AudioPlayer? _preloadPlayer;
  final _logger = LoggerService();
  bool _isDownloadingAudio = false; // Track audio download state
  bool _hasMarkedAsPlayed = false; // Track if we've already marked as played
  Duration? _cachedDuration; // Cached duration from preload
  Timer? _markAsPlayedTimer; // Debounce timer for mark as played
  Timer? _sendingTimeoutTimer; // Fallback timer for stuck "sending" status
  bool _showRetryForStuck = false; // Show retry button for messages stuck in sending
  String? _localAudioPath; // Cached local path for audio

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.audio) {
      _initAudio();
      _preloadAudioDuration(); // Preload duration for immediate display
    }
    // Start timeout timer for messages in "sending" status
    _startSendingTimeoutCheck();
  }
  
  /// Preload audio duration and download to local storage
  Future<void> _preloadAudioDuration() async {
    // Check if already loaded via GlobalAudioService
    final audioService = ref.read(globalAudioServiceProvider.notifier);
    if (audioService.isCurrentMessage(widget.message.id)) {
      final state = ref.read(globalAudioServiceProvider);
      _cachedDuration = state.duration;
      return;
    }
    
    // Don't preload if already downloading
    if (_isDownloadingAudio) return;
    
    try {
      if (mounted) {
        setState(() {
          _isDownloadingAudio = true;
        });
      }
      
      final audioStorageService = ref.read(audioStorageServiceProvider);
      String? localPath = widget.message.localAudioPath ?? 
                          await audioStorageService.getLocalAudioPath(widget.message.id);
      
      if (localPath != null && await File(localPath).exists()) {
        // Audio already cached locally - get duration using temp player
        _localAudioPath = localPath;
        _preloadPlayer = AudioPlayer();
        final dur = await _preloadPlayer!.setFilePath(localPath);
        _preloadPlayer!.dispose();
        _preloadPlayer = null;
        
        if (mounted) {
          setState(() {
            _cachedDuration = dur;
            _isDownloadingAudio = false;
          });
        }
      } else {
        // Download audio from server
        if (widget.message.filePath != null && widget.message.filePath!.isNotEmpty) {
          final audioUrl = '${ApiConstants.baseUrl}${widget.message.filePath}';
          final messagesNotifier = ref.read(messagesProvider(widget.message.chatId).notifier);
          
          // Download and save locally with progress
          localPath = await audioStorageService.saveAudioLocally(
            widget.message.id, 
            audioUrl,
            onProgress: (progress) {
              messagesNotifier.updateDownloadProgress(widget.message.id, progress);
            },
          );
          
          // Clear download progress
          messagesNotifier.clearDownloadProgress(widget.message.id);
          
          if (localPath != null) {
            _localAudioPath = localPath;
            
            // Get duration using temp player
            _preloadPlayer = AudioPlayer();
            final dur = await _preloadPlayer!.setFilePath(localPath);
            _preloadPlayer!.dispose();
            _preloadPlayer = null;
            
            // Update cache with local path
            final localDataSource = ref.read(localDataSourceProvider);
            await localDataSource.updateMessageLocalAudioPath(
              widget.message.chatId,
              widget.message.id,
              localPath
            );
            
            if (mounted) {
              setState(() {
                _cachedDuration = dur;
                _isDownloadingAudio = false;
              });
            }
          } else {
            // Failed to download
            if (mounted) {
              setState(() {
                _isDownloadingAudio = false;
              });
            }
          }
        } else {
          // No file path - audio was deleted
          if (mounted) {
            setState(() {
              _isDownloadingAudio = false;
            });
          }
        }
      }
    } catch (e) {
      // Error during preload
      print('[AUDIO] Failed to preload duration: $e');
      _preloadPlayer?.dispose();
      _preloadPlayer = null;
      if (mounted) {
        setState(() {
          _isDownloadingAudio = false;
        });
      }
    }
  }
  
  /// Start a timer to show retry button if message stays in "sending" too long
  /// Only for messages that are actually stuck (not already sent/delivered)
  void _startSendingTimeoutCheck() {
    // SIMPLIFIED: No longer use timeout for "sending" status
    // The outbox system handles retries automatically
    // UI should only show Retry for "failed" status
    
    _sendingTimeoutTimer?.cancel();
    _sendingTimeoutTimer = null;
    
    // Clear retry button if status is not failed
    if (_showRetryForStuck && widget.message.status != MessageStatus.failed) {
      setState(() {
        _showRetryForStuck = false;
      });
    }
    
    // No timeout needed - messages_provider handles status transitions:
    // sending -> sent (after API success)
    // sending -> failed (after outbox retries exhausted)
    //
    // The only valid case for showing Retry is when status == failed
    return;
    
    // OLD CODE REMOVED:
    // Previously showed Retry after 90s timeout, but this was incorrect
    // because if API returned success, message is already "sent" on server
    // If still "sending" in UI, it means state update was missed - 
    // that's handled by _handleStuckLocalMessage in messages_provider
  }
  
  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // CRITICAL: If status is no longer sending, always hide retry and cancel timer
    if (widget.message.status != MessageStatus.sending) {
      _sendingTimeoutTimer?.cancel();
      _sendingTimeoutTimer = null;
      if (_showRetryForStuck) {
        setState(() {
          _showRetryForStuck = false;
        });
      }
      return; // No need to start timeout check for non-sending status
    }
    
    // If status changed TO sending (e.g., retry), restart timeout
    if (oldWidget.message.status != MessageStatus.sending && 
        widget.message.status == MessageStatus.sending) {
      _showRetryForStuck = false;
      _startSendingTimeoutCheck();
    }
  }

  void _initAudio() {
    // Setup callback for marking as played
    final audioService = ref.read(globalAudioServiceProvider.notifier);
    audioService.onPlaybackCompleted = (messageId) {
      if (messageId == widget.message.id && !_hasMarkedAsPlayed) {
        _markAudioAsPlayed();
      }
    };
  }
  

  Future<void> _playPauseAudio() async {
    // Block if audio is still downloading
    if (_isDownloadingAudio) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Загрузка аудио...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    
    // Defer provider state changes to avoid modifying provider during build
    await Future.microtask(() async {
      final audioService = ref.read(globalAudioServiceProvider.notifier);
      
      try {
        // Check if we have a local path or need to use URL
        String? localPath = _localAudioPath;
        if (localPath == null) {
          final audioStorageService = ref.read(audioStorageServiceProvider);
          localPath = await audioStorageService.getLocalAudioPath(widget.message.id);
        }
        
        if (localPath == null && widget.message.filePath == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Голосовое сообщение больше не доступно'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
        
        final audioUrl = widget.message.filePath != null 
            ? '${ApiConstants.baseUrl}${widget.message.filePath}'
            : '';
        
        // Setup sequential playback callback
        audioService.getNextAudioMessage = (currentMessageId, chatId) async {
          return _findNextAudioMessage(currentMessageId, chatId);
        };
        
        // Play using GlobalAudioService
        await audioService.playMessage(
          messageId: widget.message.id,
          chatId: widget.message.chatId,
          audioUrl: audioUrl,
          senderName: widget.message.senderName,
          localFilePath: localPath,
        );
        
        // Mark as played when started (if not sender)
        if (!_hasMarkedAsPlayed) {
          _markAsPlayedTimer?.cancel();
          _markAsPlayedTimer = Timer(const Duration(milliseconds: 200), () {
            if (mounted && !_hasMarkedAsPlayed) {
              _markAudioAsPlayed();
            }
          });
        }
        
      } catch (e) {
        print('[AUDIO] Error in _playPauseAudio: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка воспроизведения'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }
  
  /// Cycle through playback speeds using GlobalAudioService
  void _cyclePlaybackSpeed() {
    final audioService = ref.read(globalAudioServiceProvider.notifier);
    audioService.cycleSpeed();
  }
  
  /// Find the next audio message in sequence after the current one
  /// Returns null if no more audio messages (sequence ends when non-audio message is found)
  Future<({String messageId, String audioUrl, String? senderName, String? localFilePath})?> 
  _findNextAudioMessage(String currentMessageId, String chatId) async {
    try {
      final messagesState = ref.read(messagesProvider(chatId));
      final messages = messagesState.messages;
      
      // Find current message index
      final currentIndex = messages.indexWhere((m) => m.id == currentMessageId);
      if (currentIndex == -1 || currentIndex >= messages.length - 1) {
        return null; // Current message not found or is the last one
      }
      
      // Check next message
      final nextMessage = messages[currentIndex + 1];
      
      // Stop sequence if next message is not audio
      if (nextMessage.type != MessageType.audio) {
        print('[AUDIO] Next message is ${nextMessage.type}, stopping sequence');
        return null;
      }
      
      // Get audio path
      final audioStorageService = ref.read(audioStorageServiceProvider);
      String? localPath = nextMessage.localAudioPath ?? 
                          await audioStorageService.getLocalAudioPath(nextMessage.id);
      
      final audioUrl = nextMessage.filePath != null 
          ? '${ApiConstants.baseUrl}${nextMessage.filePath}'
          : '';
      
      return (
        messageId: nextMessage.id,
        audioUrl: audioUrl,
        senderName: nextMessage.senderName,
        localFilePath: localPath,
      );
    } catch (e) {
      print('[AUDIO] Error finding next audio message: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _markAsPlayedTimer?.cancel();
    _sendingTimeoutTimer?.cancel();
    _preloadPlayer?.dispose();
    super.dispose();
  }

  Widget _buildMessageStatusIcon() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Цвета статусов - контрастные на светло-зеленом фоне
    final pendingColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final sentColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final deliveredColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final readColor = AppColors.readCheckmarks; // Голубые галочки как в Telegram
    
    // Check if media is being uploaded - don't show duplicate indicator
    final isMediaUploading = widget.message.uploadProgress != null &&
                             widget.message.uploadProgress! < 1.0 &&
                             (widget.message.type == MessageType.audio ||
                              widget.message.type == MessageType.image ||
                              widget.message.type == MessageType.file);
    
    switch (widget.message.status) {
      case MessageStatus.sending:
        // Don't show spinner if media has its own upload indicator
        if (isMediaUploading) {
          // Show clock icon instead of spinner (avoid duplicate indicators)
          return Icon(
            Icons.access_time,
            size: 14,
            color: pendingColor,
          );
        }
        // Simple spinner for text messages
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(pendingColor),
          ),
        );
      case MessageStatus.sent:
        // Одна серая галочка - отправлено, но не доставлено
        return Icon(
          Icons.check,
          size: 14,
          color: sentColor,
        );
      case MessageStatus.delivered:
        // Две серых галочки - доставлено, но не прочитано
        return Icon(
          Icons.done_all,
          size: 14,
          color: deliveredColor,
        );
      case MessageStatus.read:
        // Две голубых галочки - прочитано (как в Telegram)
        return Icon(
          Icons.done_all,
          size: 14,
          color: readColor,
        );
      case MessageStatus.played:
        // Голубые галочки - воспроизведено (для аудио)
        return Icon(
          Icons.done_all,
          size: 14,
          color: readColor,
        );
      case MessageStatus.failed:
        // Red error icon with retry functionality
        return GestureDetector(
          onTap: _handleRetry,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 16,
                color: Colors.red[700],
              ),
              const SizedBox(width: 2),
              Text(
                'Retry',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildMessageContent(BuildContext context, bool isMe) {
    final theme = Theme.of(context);
    final textColor = isMe ? theme.outgoingTextColor : theme.incomingTextColor;
    
    switch (widget.message.type) {
      case MessageType.text:
        return Text(
          widget.message.content ?? '',
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            height: 1.3,
          ),
        );
      
      case MessageType.audio:
        // Get playback state from GlobalAudioService
        final globalState = ref.watch(globalAudioServiceProvider);
        final isCurrentMsg = globalState.messageId == widget.message.id;
        final isPlaying = isCurrentMsg && globalState.isPlaying;
        final isLoading = isCurrentMsg && globalState.isLoading;
        final position = isCurrentMsg ? globalState.position : Duration.zero;
        final duration = isCurrentMsg && globalState.duration != null 
            ? globalState.duration! 
            : _cachedDuration ?? Duration.zero;
        final playbackSpeed = isCurrentMsg ? globalState.speed : 1.0;
        final outputRoute = globalState.outputRoute;
        final isDark = theme.brightness == Brightness.dark;
        
        // Check if audio is uploading
        final isUploading = widget.message.status == MessageStatus.sending && 
                            widget.message.uploadProgress != null &&
                            widget.message.uploadProgress! < 1.0;
        final uploadProgress = widget.message.uploadProgress ?? 0.0;
        
        // Определить, прослушано ли сообщение
        final isPlayed = widget.message.status == MessageStatus.played;
        
        // Telegram-style colors for audio player
        final Color playerColor = isPlayed 
            ? AppColors.primaryGreen
            : textColor;
        final Color waveformActiveColor = isPlayed 
            ? AppColors.primaryGreen
            : (isMe 
                ? (isDark ? Colors.white70 : Colors.black54)
                : (isDark ? Colors.white54 : Colors.grey[600]!));
        final Color waveformInactiveColor = isMe
            ? (isDark ? Colors.white24 : Colors.black26)
            : (isDark ? Colors.white24 : Colors.grey[300]!);
        final Color audioTextColor = isMe 
            ? theme.outgoingTextColor.withOpacity(0.7)
            : theme.incomingTextColor.withOpacity(0.7);
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show upload progress indicator when uploading
            if (isUploading)
              SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          value: uploadProgress,
                          strokeWidth: 3,
                          backgroundColor: playerColor.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(playerColor),
                        ),
                      ),
                      Text(
                        '${(uploadProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: playerColor,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // Show loading indicator while downloading or loading audio
            else if (_isDownloadingAudio || isLoading) ...[
              // Check if we have download progress
              if (widget.message.downloadProgress != null && widget.message.downloadProgress! < 1.0)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            value: widget.message.downloadProgress,
                            strokeWidth: 3,
                            backgroundColor: playerColor.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(playerColor),
                          ),
                        ),
                        Text(
                          '${((widget.message.downloadProgress ?? 0) * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: playerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(playerColor),
                      ),
                    ),
                  ),
                ),
            ]
            else AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Stack(
                      key: ValueKey<bool>(isPlaying),
                      alignment: Alignment.center,
                      children: [
                        // Пульсирующий индикатор при воспроизведении
                        if (isPlaying && isCurrentMsg)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.8, end: 1.2),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeInOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: playerColor.withOpacity(0.15),
                                  ),
                                ),
                              );
                            },
                            onEnd: () {
                              // Restart animation
                              if (mounted && isPlaying) {
                                setState(() {});
                              }
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: playerColor,
                            size: 28,
                          ),
                          onPressed: _playPauseAudio,
                        ),
                      ],
                    ),
                  ),
            
            // Audio route indicator (earpiece/speaker/bluetooth)
            if (isCurrentMsg && !_isDownloadingAudio && !isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  outputRoute == AudioOutputRoute.earpiece
                      ? Icons.phone_in_talk
                      : outputRoute == AudioOutputRoute.bluetooth
                          ? Icons.bluetooth_audio
                          : Icons.volume_up,
                  color: playerColor.withOpacity(0.6),
                  size: 16,
                ),
              ),
            
            // Speed control button (only visible when current message)
            if (!_isDownloadingAudio && !isLoading && isCurrentMsg)
              GestureDetector(
                onTap: _cyclePlaybackSpeed,
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isPlayed 
                        ? (isMe ? Colors.green[400]!.withOpacity(0.3) : Colors.green[600]!.withOpacity(0.3))
                        : (isMe ? Colors.white.withOpacity(0.2) : Colors.grey[300]!.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '${playbackSpeed}x',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: playerColor,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: GestureDetector(
                onTapDown: (details) => _seekAudio(details, isMe),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AudioWaveform(
                      progress: duration.inMilliseconds > 0
                          ? position.inMilliseconds / duration.inMilliseconds
                          : 0.0,
                      activeColor: waveformActiveColor,
                      inactiveColor: waveformInactiveColor,
                      height: 30,
                      barsCount: 25,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: audioTextColor,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Playback speed button
                            if (playbackSpeed != 1.0) ...[
                              GestureDetector(
                                onTap: _cyclePlaybackSpeed,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: playerColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${playbackSpeed}x',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: audioTextColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: audioTextColor,
                              ),
                            ),
                            // Show "played" indicator for received audio messages
                            if (isPlayed && !isMe) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.headphones,
                                size: 14,
                                color: AppColors.primaryGreen,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      
      case MessageType.image:
        return GestureDetector(
          onTap: () => _showFullScreenImage(context),
          child: _buildImageWidget(),
        );
      
      case MessageType.file:
        return _buildFileWidget(context);
      
      case MessageType.poll:
        return _buildPollWidget(context, isMe);
    }
  }

  Widget _buildFileWidget(BuildContext context) {
    final profileState = ref.read(profileProvider);
    final currentUserId = profileState.userId;
    final isFromMe = (currentUserId != null && widget.message.senderId == currentUserId) ||
                     (widget.message.isLocalOnly == true);
    final textColor = isFromMe ? Colors.white : Colors.black87;
    final fileName = widget.message.originalFileName ?? 'Файл';
    final fileSize = widget.message.fileSize ?? 0;
    final isUploading = widget.message.status == MessageStatus.sending && 
                        widget.message.uploadProgress != null &&
                        widget.message.uploadProgress! < 1.0;
    final isDownloading = widget.message.downloadProgress != null &&
                          widget.message.downloadProgress! < 1.0;
    final progress = isUploading 
        ? (widget.message.uploadProgress ?? 0.0)
        : (widget.message.downloadProgress ?? 0.0);
    final isTransferring = isUploading || isDownloading;
    
    // Format file size
    String formattedSize;
    if (fileSize < 1024) {
      formattedSize = '$fileSize Б';
    } else if (fileSize < 1024 * 1024) {
      formattedSize = '${(fileSize / 1024).toStringAsFixed(1)} КБ';
    } else {
      formattedSize = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} МБ';
    }
    
    return GestureDetector(
      onTap: isTransferring ? null : () => _openOrDownloadFile(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 250),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isFromMe 
                            ? Colors.white.withOpacity(0.2)
                            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isUploading ? Icons.cloud_upload 
                            : isDownloading ? Icons.cloud_download 
                            : Icons.insert_drive_file,
                        color: isFromMe ? Colors.white : Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    if (isTransferring)
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isFromMe ? Colors.white : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTransferring 
                            ? '${(progress * 100).toInt()}% • $formattedSize'
                            : formattedSize,
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isTransferring) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.download,
                    color: textColor.withOpacity(0.7),
                    size: 20,
                  ),
                ],
              ],
            ),
            // Removed duplicate LinearProgressIndicator - circular indicator with percentage is sufficient
          ],
        ),
      ),
    );
  }

  Future<void> _openOrDownloadFile(BuildContext context) async {
    // Check if file is available locally
    if (widget.message.localFilePath != null && 
        File(widget.message.localFilePath!).existsSync()) {
      // Open the local file with system dialog
      final result = await OpenFilex.open(widget.message.localFilePath!);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть файл: ${result.message}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    // Need to download the file first
    if (widget.message.filePath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл недоступен'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    final fileUrl = '${ApiConstants.baseUrl}${widget.message.filePath}';
    final fileName = widget.message.originalFileName ?? 'downloaded_file';
    
    try {
      // Get directory for downloaded files
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      
      final localPath = '${downloadDir.path}/$fileName';
      final messagesNotifier = ref.read(messagesProvider(widget.message.chatId).notifier);
      
      // Download the file with progress callback
      final dio = Dio();
      await dio.download(
        fileUrl,
        localPath,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            messagesNotifier.updateDownloadProgress(widget.message.id, progress);
          }
        },
      );
      
      // Clear download progress and update local path
      messagesNotifier.clearDownloadProgress(widget.message.id);
      messagesNotifier.updateMessageLocalPath(widget.message.id, localFilePath: localPath);
      
      // Open file
      if (context.mounted) {
        final result = await OpenFilex.open(localPath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось открыть файл: ${result.message}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Clear download progress on error
      ref.read(messagesProvider(widget.message.chatId).notifier)
          .clearDownloadProgress(widget.message.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  /// Build reply quote widget with optional image thumbnail
  Widget _buildReplyQuote(BuildContext context, bool isMe) {
    final reply = widget.message.replyToMessage!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Контрастные цвета для цитаты
    final quoteBackgroundColor = isMe 
        ? (isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.08))
        : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.12));
    
    final quoteBorderColor = isMe 
        ? (isDark ? AppColors.lightGreen : AppColors.primaryGreen)
        : theme.colorScheme.primary;
    
    final quoteNameColor = isMe 
        ? (isDark ? AppColors.lightGreen : AppColors.primaryGreen)
        : theme.colorScheme.primary;
    
    final quoteTextColor = isMe 
        ? (isDark ? Colors.white70 : Colors.black87)
        : (isDark ? Colors.white70 : Colors.grey[700]!);
    
    final hasImage = reply.type == MessageType.image && reply.filePath != null;
    
    return GestureDetector(
      onTap: () {
        // Navigate to replied message
        if (widget.onReplyTap != null) {
          widget.onReplyTap!(reply.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: quoteBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: quoteBorderColor,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image thumbnail if replying to image
            if (hasImage)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: '${ApiConstants.baseUrl}${reply.filePath}',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 40,
                      height: 40,
                      color: Colors.grey[300],
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 40,
                      height: 40,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, size: 20),
                    ),
                  ),
                ),
              ),
            // Text content
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reply.senderName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: quoteNameColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getReplyPreviewText(reply),
                    style: TextStyle(
                      fontSize: 12,
                      color: quoteTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getReplyPreviewText(ReplyMessage reply) {
    switch (reply.type) {
      case MessageType.text:
        return reply.content ?? '';
      case MessageType.audio:
        return '🎤 Голосовое сообщение';
      case MessageType.image:
        return '📷 Фото';
      case MessageType.file:
        return '📎 ${reply.originalFileName ?? "Файл"}';
      case MessageType.poll:
        return '📊 Голосование';
    }
  }

  Widget _buildPollWidget(BuildContext context, bool isMe) {
    final pollData = widget.message.pollData;
    if (pollData == null) {
      return const Text('Ошибка: данные голосования недоступны');
    }
    
    final poll = Poll.fromJson(pollData);
    final profileState = ref.watch(profileProvider);
    final currentUserId = profileState.userId;
    final isCreator = widget.message.senderId == currentUserId;
    
    return PollWidget(
      poll: poll,
      isFromMe: isMe,
      canClose: isCreator && !poll.isClosed,
      onVote: (optionIds) async {
        // Voting will be handled by MessagesProvider
        await ref.read(messagesProvider(widget.message.chatId).notifier)
            .votePoll(poll.id, optionIds);
      },
      onRetract: (optionIds) async {
        await ref.read(messagesProvider(widget.message.chatId).notifier)
            .retractPollVote(poll.id, optionIds);
      },
      onClose: isCreator ? () async {
        await ref.read(messagesProvider(widget.message.chatId).notifier)
            .closePoll(poll.id);
      } : null,
    );
  }

  Widget _buildImageWidget() {
    final isUploading = widget.message.status == MessageStatus.sending && 
                        widget.message.uploadProgress != null &&
                        widget.message.uploadProgress! < 1.0;
    final progress = widget.message.uploadProgress ?? 0.0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Adaptive constraints for horizontal/vertical images
    const double maxWidth = 250.0;
    const double maxHeight = 300.0;
    const double minSize = 120.0;
    
    Widget imageWidget;
    
    // Check if we have local image first
    if (widget.message.localImagePath != null && 
        File(widget.message.localImagePath!).existsSync()) {
      imageWidget = Image.file(
        File(widget.message.localImagePath!),
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
      );
    } else {
      // Otherwise use network image
      final imageUrl = widget.message.filePath != null
          ? '${ApiConstants.baseUrl}${widget.message.filePath}'
          : null;
      
      if (imageUrl != null) {
        imageWidget = CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          // Shimmer placeholder - only show when NOT uploading (to avoid duplicate indicators)
          placeholder: (context, url) => _buildShimmerPlaceholder(isDark),
          fadeInDuration: const Duration(milliseconds: 300),
          fadeOutDuration: const Duration(milliseconds: 100),
          errorWidget: (context, url, error) => Container(
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            child: Center(
              child: Icon(
                Icons.error_outline, 
                size: 48,
                color: isDark ? Colors.grey[600] : Colors.grey[500],
              ),
            ),
          ),
        );
      } else {
        imageWidget = Container(
          color: isDark ? Colors.grey[800] : Colors.grey[300],
          child: Center(
            child: Text(
              'Изображение недоступно',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        );
      }
    }
    
    // Hero animation wrapper for fullscreen transition
    final heroTag = 'image_${widget.message.id}';
    
    // Wrap with upload progress overlay if uploading
    return Hero(
      tag: heroTag,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          minWidth: minSize,
          minHeight: minSize,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Image with aspect ratio preservation
              AspectRatio(
                aspectRatio: 1.0, // Default to square, image will fill with cover
                child: imageWidget,
              ),
              // Upload progress overlay - single indicator, no shimmer underneath
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 4,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
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
  
  /// Build shimmer placeholder for loading images
  Widget _buildShimmerPlaceholder(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * value, 0),
              end: Alignment(-0.5 + 2.0 * value, 0),
              colors: isDark
                  ? [
                      Colors.grey[800]!,
                      Colors.grey[700]!,
                      Colors.grey[800]!,
                    ]
                  : [
                      Colors.grey[300]!,
                      Colors.grey[100]!,
                      Colors.grey[300]!,
                    ],
            ),
          ),
        );
      },
      onEnd: () {
        // Restart animation
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _showFullScreenImage(BuildContext context) {
    final contactsNames = ref.read(contactsNamesProvider);
    
    // Try to get contact name from phone book, fallback to sender name from message
    String displayName = widget.message.senderName;
    if (contactsNames[widget.message.senderId] != null && 
        contactsNames[widget.message.senderId]!.isNotEmpty) {
      displayName = contactsNames[widget.message.senderId]!;
    }
    
    // Build list of all images for horizontal swiping
    List<ImageData>? allImages;
    int initialIndex = 0;
    
    if (widget.allImageMessages != null && widget.allImageMessages!.isNotEmpty) {
      allImages = widget.allImageMessages!.map((msg) {
        // Get display name for each message sender
        String senderDisplayName = msg.senderName;
        if (contactsNames[msg.senderId] != null && 
            contactsNames[msg.senderId]!.isNotEmpty) {
          senderDisplayName = contactsNames[msg.senderId]!;
        }
        
        return ImageData(
          imageUrl: msg.filePath != null
              ? '${ApiConstants.baseUrl}${msg.filePath}'
              : null,
          localPath: msg.localImagePath,
          senderName: senderDisplayName,
          createdAt: msg.createdAt,
          messageId: msg.id,
        );
      }).toList();
      
      // Find current image index
      initialIndex = widget.imageIndex;
    }
    
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) => FullScreenImageViewer(
          imageUrl: widget.message.filePath != null
              ? '${ApiConstants.baseUrl}${widget.message.filePath}'
              : null,
          localPath: widget.message.localImagePath,
          senderName: displayName,
          createdAt: widget.message.createdAt,
          messageId: widget.message.id,
          allImages: allImages,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _seekAudio(TapDownDetails details, bool isMe) {
    final audioService = ref.read(globalAudioServiceProvider.notifier);
    final state = ref.read(globalAudioServiceProvider);
    
    // Only allow seeking if this message is currently loaded
    if (state.messageId != widget.message.id) return;
    
    final duration = state.duration ?? _cachedDuration;
    if (duration == null || duration.inMilliseconds == 0) return;
    
    // Calculate the tap position relative to the waveform width
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    
    // Get the waveform area (account for play button width ~48px and padding)
    final waveformStartX = 48.0;
    final waveformWidth = box.size.width - waveformStartX - 16.0;
    
    if (localPosition.dx < waveformStartX) return;
    
    final tapX = localPosition.dx - waveformStartX;
    final progress = (tapX / waveformWidth).clamp(0.0, 1.0);
    
    final seekPosition = Duration(
      milliseconds: (duration.inMilliseconds * progress).round(),
    );
    
    audioService.seek(seekPosition);
  }

  Future<void> _markAudioAsPlayed() async {
    // CRITICAL: Set flag IMMEDIATELY to prevent race conditions
    if (_hasMarkedAsPlayed) return;
    _hasMarkedAsPlayed = true;
    
    final profileState = ref.read(profileProvider);
    final currentUserId = profileState.userId; // Use getter that falls back to cachedUserId
    
    // Don't mark own messages as played
    if (currentUserId == null || widget.message.senderId == currentUserId) {
      return;
    }
    
    try {
      // Call API to mark as played
      await ref.read(messagesProvider(widget.message.chatId).notifier)
          .markAudioAsPlayed(widget.message.id);
      print('[AUDIO] Marked as played: ${widget.message.id}');
    } catch (e) {
      _logger.debug('message_bubble', 'Failed to mark audio as played: $e', {
        'messageId': widget.message.id
      });
      print('[AUDIO] Failed to mark as played: $e');
      // Don't reset flag - queue will retry automatically
    }
  }

  Future<void> _handleRetry() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Повторная отправка...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Use localId if available, otherwise use message id
      final messageId = widget.message.localId ?? widget.message.id;
      
      await ref.read(messagesProvider(widget.message.chatId).notifier)
          .retryFailedMessage(messageId);
      
      print('[MESSAGE_BUBBLE] Retry initiated for message: $messageId');
    } catch (e) {
      print('[MESSAGE_BUBBLE] Error retrying message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось повторить отправку'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    // Use userId getter which returns profile?.id ?? cachedUserId for immediate positioning
    final currentUserId = profileState.userId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Fallback: if profile not loaded, check by isLocalOnly flag
    final isMe = (currentUserId != null && widget.message.senderId == currentUserId) ||
                 (widget.message.isLocalOnly == true);
    
    // Get display name from contacts or fallback to server name
    final contactsNames = ref.watch(contactsNamesProvider);
    final displayName = contactsNames[widget.message.senderId] 
                        ?? widget.message.senderName;
    
    // Telegram-style colors
    final bubbleColor = widget.isHighlighted
        ? Colors.yellow.withOpacity(0.5)
        : isMe
            ? theme.outgoingBubbleColor
            : theme.incomingBubbleColor;
    
    final timeColor = theme.messageTimeColor;
    
    final secondaryTextColor = isMe
        ? (isDark ? Colors.white60 : Colors.black54)
        : (isDark ? Colors.white54 : Colors.grey[600]!);
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 4,
          left: isMe ? 48 : 8,
          right: isMe ? 8 : 48,
        ),
        child: CustomPaint(
          painter: BubblePainter(
            color: bubbleColor,
            isMe: isMe,
            isDark: isDark,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: EdgeInsets.only(
              left: isMe ? 12 : 16,
              right: isMe ? 16 : 12,
              top: 8,
              bottom: 6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender name (for incoming messages in groups)
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                        fontSize: 13,
                      ),
                    ),
                  ),
                // Forward indicator
                if (widget.message.forwardedFromUserName != null) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.reply,
                        size: 14,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Переслано от ${widget.message.forwardedFromUserName}',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: secondaryTextColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                // Reply quote
                if (widget.message.replyToMessage != null)
                  _buildReplyQuote(context, isMe),
                // Message content
                _buildMessageContent(context, isMe),
                const SizedBox(height: 4),
                // Time and status row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(widget.message.createdAt.toLocal()),
                      style: TextStyle(
                        fontSize: 11,
                        color: timeColor,
                      ),
                    ),
                    // Edited indicator
                    if (widget.message.isEdited) ...[
                      const SizedBox(width: 4),
                      Text(
                        'изм.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: timeColor,
                        ),
                      ),
                    ],
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _buildMessageStatusIcon(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter для пузыря сообщения в стиле Telegram с хвостиком
class BubblePainter extends CustomPainter {
  final Color color;
  final bool isMe;
  final bool isDark;
  
  BubblePainter({
    required this.color,
    required this.isMe,
    required this.isDark,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Тень
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(isDark ? 0.3 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    final radius = 16.0;
    final tailWidth = 8.0;
    final tailHeight = 10.0;
    
    final path = Path();
    
    if (isMe) {
      // Исходящее сообщение - хвостик справа
      path.moveTo(radius, 0);
      path.lineTo(size.width - radius - tailWidth, 0);
      path.quadraticBezierTo(size.width - tailWidth, 0, size.width - tailWidth, radius);
      path.lineTo(size.width - tailWidth, size.height - tailHeight);
      // Хвостик
      path.lineTo(size.width, size.height);
      path.lineTo(size.width - tailWidth, size.height - tailHeight - 4);
      path.lineTo(size.width - tailWidth, size.height - radius);
      path.quadraticBezierTo(size.width - tailWidth, size.height, size.width - tailWidth - radius, size.height);
      path.lineTo(radius, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - radius);
      path.lineTo(0, radius);
      path.quadraticBezierTo(0, 0, radius, 0);
    } else {
      // Входящее сообщение - хвостик слева
      path.moveTo(radius + tailWidth, 0);
      path.lineTo(size.width - radius, 0);
      path.quadraticBezierTo(size.width, 0, size.width, radius);
      path.lineTo(size.width, size.height - radius);
      path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);
      path.lineTo(radius + tailWidth, size.height);
      path.quadraticBezierTo(tailWidth, size.height, tailWidth, size.height - radius);
      path.lineTo(tailWidth, size.height - tailHeight - 4);
      // Хвостик
      path.lineTo(0, size.height);
      path.lineTo(tailWidth, size.height - tailHeight);
      path.lineTo(tailWidth, radius);
      path.quadraticBezierTo(tailWidth, 0, radius + tailWidth, 0);
    }
    
    path.close();
    
    // Рисуем тень
    canvas.drawPath(path.shift(const Offset(0, 1)), shadowPaint);
    // Рисуем пузырь
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) {
    return oldDelegate.color != color || 
           oldDelegate.isMe != isMe ||
           oldDelegate.isDark != isDark;
  }
}


