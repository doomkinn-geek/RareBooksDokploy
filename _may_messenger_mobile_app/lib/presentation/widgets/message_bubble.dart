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
import '../../core/constants/api_constants.dart';
import '../../core/services/logger_service.dart';
import '../../data/services/proximity_audio_service.dart';
import '../providers/profile_provider.dart';
import '../providers/contacts_names_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/messages_provider.dart';
import 'fullscreen_image_viewer.dart';
import 'audio_waveform.dart';
import 'audio_player_manager.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final Message message;
  final bool isHighlighted;
  final Function(String messageId)? onReplyTap;

  const MessageBubble({
    super.key,
    required this.message,
    this.isHighlighted = false,
    this.onReplyTap,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _logger = LoggerService();
  bool _isPlaying = false;
  bool _isDownloadingAudio = false; // Track audio download state
  bool _hasMarkedAsPlayed = false; // Track if we've already marked as played
  bool _isNearEar = false; // Track proximity sensor state
  Duration? _duration;
  Duration? _position;
  Timer? _markAsPlayedTimer; // Debounce timer for mark as played
  Timer? _sendingTimeoutTimer; // Fallback timer for stuck "sending" status
  bool _showRetryForStuck = false; // Show retry button for messages stuck in sending
  double _playbackSpeed = 1.0; // Current playback speed

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
  
  /// Preload audio duration without starting playback
  Future<void> _preloadAudioDuration() async {
    // Don't preload if already downloading or playing
    if (_isDownloadingAudio || _isPlaying) return;
    
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
        // Audio already cached locally
        final dur = await _audioPlayer.setFilePath(localPath);
        // Reset position to start for proper animation
        await _audioPlayer.seek(Duration.zero);
        if (mounted) {
          setState(() {
            _duration = dur;
            _position = Duration.zero;
            _isDownloadingAudio = false;
          });
        }
      } else {
        // Download audio from server
        if (widget.message.filePath != null && widget.message.filePath!.isNotEmpty) {
          final audioUrl = '${ApiConstants.baseUrl}${widget.message.filePath}';
          
          // Download and save locally
          localPath = await audioStorageService.saveAudioLocally(
            widget.message.id, 
            audioUrl
          );
          
          if (localPath != null) {
            final dur = await _audioPlayer.setFilePath(localPath);
            // Reset position to start for proper animation
            await _audioPlayer.seek(Duration.zero);
            
            // Update cache with local path
            final localDataSource = ref.read(localDataSourceProvider);
            await localDataSource.updateMessageLocalAudioPath(
              widget.message.chatId,
              widget.message.id,
              localPath
            );
            
            if (mounted) {
              setState(() {
                _duration = dur;
                _position = Duration.zero;
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
    // Cancel any existing timer first
    _sendingTimeoutTimer?.cancel();
    _sendingTimeoutTimer = null;
    
    // Only start timer for messages in sending status
    // Do NOT show retry for sent, delivered, read, or played messages
    if (widget.message.status != MessageStatus.sending) {
      if (_showRetryForStuck) {
        setState(() {
          _showRetryForStuck = false;
        });
      }
      return;
    }
    
    // Check how old the message is
    final messageAge = DateTime.now().difference(widget.message.createdAt);
    
    // Increase timeout to 90 seconds to avoid false positives
    // Server roundtrip + network latency + push delivery can take time
    const timeoutSeconds = 90;
    
    if (messageAge.inSeconds >= timeoutSeconds) {
      // Already past timeout, but double-check status is still sending
      if (mounted && widget.message.status == MessageStatus.sending) {
        setState(() {
          _showRetryForStuck = true;
        });
      }
    } else {
      // Schedule timer for remaining time
      final remainingTime = Duration(seconds: timeoutSeconds) - messageAge;
      _sendingTimeoutTimer = Timer(remainingTime, () {
        // CRITICAL: Re-check status when timer fires
        // Widget might have been updated while timer was running
        // Check both widget.message.status AND that we're still in sending state
        if (mounted && widget.message.status == MessageStatus.sending) {
          setState(() {
            _showRetryForStuck = true;
          });
          print('[UI_FALLBACK] Message ${widget.message.id} stuck in sending after ${timeoutSeconds}s, showing retry button');
        } else if (mounted) {
          // Status changed, make sure retry is hidden
          if (_showRetryForStuck) {
            setState(() {
              _showRetryForStuck = false;
            });
          }
        }
      });
    }
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
    _audioPlayer.durationStream.listen((d) {
      if (mounted) {
        setState(() => _duration = d);
      }
    });
    _audioPlayer.positionStream.listen((p) {
      if (mounted) {
        setState(() => _position = p);
      }
    });
    _audioPlayer.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
      
      // Start/stop proximity sensor based on playback state
      final proximityService = ref.read(proximityAudioServiceProvider);
      if (state.playing && !wasPlaying) {
        // Started playing - enable proximity sensor for earpiece mode
        proximityService.startListening();
        proximityService.addListener(_onProximityChanged);
      } else if (!state.playing && wasPlaying) {
        // Stopped playing - disable proximity sensor
        proximityService.removeListener(_onProximityChanged);
        proximityService.stopListening();
      }
      
      // Mark as played when first started playing (and user is not the sender)
      // Use debounce to prevent multiple rapid calls
      if (state.playing && 
          !_hasMarkedAsPlayed && 
          widget.message.type == MessageType.audio) {
        // Cancel previous timer if exists
        _markAsPlayedTimer?.cancel();
        // Debounce: wait 200ms before marking to avoid race conditions
        _markAsPlayedTimer = Timer(const Duration(milliseconds: 200), () {
          if (mounted && !_hasMarkedAsPlayed) {
            _markAudioAsPlayed();
          }
        });
      }
      
      // Сброс при окончании воспроизведения
      if (state.processingState == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
    });
  }
  
  /// Handle proximity sensor changes
  void _onProximityChanged(bool isNearEar) {
    if (mounted) {
      setState(() {
        _isNearEar = isNearEar;
      });
    }
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
    
    final playerManager = ref.read(audioPlayerManagerProvider);
    
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        playerManager.unregisterPlayer(widget.message.id);
      } else {
        // Register this player and stop others
        playerManager.registerPlayer(widget.message.id, () async {
          if (_isPlaying) {
            await _audioPlayer.pause();
          }
        });
        
        // Audio should already be loaded by _preloadAudioDuration
        // If not, it means the file was deleted or failed to download
        if (_audioPlayer.processingState == ProcessingState.idle) {
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
        
        // Set playback speed (preserves pitch)
        await _audioPlayer.setSpeed(_playbackSpeed);
        await _audioPlayer.play();
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
  }
  
  /// Cycle through playback speeds: 1.0 -> 1.25 -> 1.5 -> 2.0 -> 1.0
  void _cyclePlaybackSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.25;
      } else if (_playbackSpeed == 1.25) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });
    
    // Update speed if currently playing
    if (_isPlaying) {
      _audioPlayer.setSpeed(_playbackSpeed);
    }
    
    // Show snackbar with current speed
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Скорость: ${_playbackSpeed}x'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _markAsPlayedTimer?.cancel();
    _sendingTimeoutTimer?.cancel();
    // Clean up proximity sensor if still listening
    if (_isPlaying) {
      final proximityService = ref.read(proximityAudioServiceProvider);
      proximityService.removeListener(_onProximityChanged);
      proximityService.stopListening();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildMessageStatusIcon() {
    switch (widget.message.status) {
      case MessageStatus.sending:
        // If stuck in sending for too long, show retry button instead of spinner
        if (_showRetryForStuck) {
          return GestureDetector(
            onTap: _handleRetry,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh,
                  size: 14,
                  color: Colors.orange[300],
                ),
                const SizedBox(width: 2),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange[300],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        );
      case MessageStatus.sent:
        // Одна серая галочка - отправлено, но не доставлено
        return const Icon(
          Icons.check,
          size: 14,
          color: Colors.white70,
        );
      case MessageStatus.delivered:
        // Две серых галочки - доставлено, но не прочитано
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.grey[400],
        );
      case MessageStatus.read:
        // Две зеленых галочки - прочитано
        return const Icon(
          Icons.done_all,
          size: 14,
          color: Colors.green,
        );
      case MessageStatus.played:
        // Зеленые галочки - воспроизведено (для аудио)
        return const Icon(
          Icons.done_all,
          size: 14,
          color: Colors.green,
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
                color: Colors.red[300],
              ),
              const SizedBox(width: 2),
              Text(
                'Retry',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red[300],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildMessageContent(BuildContext context, bool isMe) {
    switch (widget.message.type) {
      case MessageType.text:
        return Text(
          widget.message.content ?? '',
          style: TextStyle(
            color: isMe ? Colors.white : null,
          ),
        );
      
      case MessageType.audio:
        // Определить, прослушано ли сообщение
        final isPlayed = widget.message.status == MessageStatus.played;
        
        // Все элементы зеленые для прослушанных
        final Color playerColor = isPlayed 
            ? (isMe ? Colors.green[300]! : Colors.green[700]!) 
            : (isMe ? Colors.white : Colors.black);
        final Color waveformColor = isPlayed 
            ? (isMe ? Colors.green[200]! : Colors.green[400]!) 
            : (isMe ? Colors.white70 : Colors.grey);
        final Color textColor = isPlayed
            ? (isMe ? Colors.green[100]! : Colors.green[800]!)
            : (isMe ? Colors.white70 : Colors.grey[600]!);
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show loading indicator while downloading, otherwise show play/pause button
            _isDownloadingAudio
                ? SizedBox(
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
                  )
                : IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: playerColor,
                size: 28,
              ),
              onPressed: _playPauseAudio,
            ),
            // Speed control button (only visible when not downloading)
            if (!_isDownloadingAudio)
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
                      '${_playbackSpeed}x',
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
                      progress: _duration != null && _position != null && _duration!.inMilliseconds > 0
                          ? _position!.inMilliseconds / _duration!.inMilliseconds
                          : 0.0,
                      activeColor: waveformColor,
                      inactiveColor: isMe ? Colors.white30 : Colors.grey[300]!,
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
                              _position != null
                                  ? '${_position!.inMinutes}:${(_position!.inSeconds % 60).toString().padLeft(2, '0')}'
                                  : '0:00',
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor,
                              ),
                            ),
                            // Show earpiece indicator when phone is near ear
                            if (_isPlaying && _isNearEar) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.hearing,
                                size: 12,
                                color: textColor,
                              ),
                            ],
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Playback speed button
                            if (_playbackSpeed != 1.0) ...[
                              GestureDetector(
                                onTap: _cyclePlaybackSpeed,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPlayed 
                                        ? (isMe ? Colors.green[400]!.withOpacity(0.3) : Colors.green[600]!.withOpacity(0.3))
                                        : (isMe ? Colors.white.withOpacity(0.2) : Colors.grey[300]!.withOpacity(0.5)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_playbackSpeed}x',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              _duration != null
                                  ? '${_duration!.inMinutes}:${(_duration!.inSeconds % 60).toString().padLeft(2, '0')}'
                                  : '0:00',
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor,
                              ),
                            ),
                            // Show "played" indicator for received audio messages
                            if (isPlayed && !isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.headphones,
                                size: 14,
                                color: Colors.green[700],
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
    }
  }

  Widget _buildFileWidget(BuildContext context) {
    final profileState = ref.read(profileProvider);
    final currentUserId = profileState.profile?.id;
    final isFromMe = (currentUserId != null && widget.message.senderId == currentUserId) ||
                     (widget.message.isLocalOnly == true);
    final textColor = isFromMe ? Colors.white : Colors.black87;
    final fileName = widget.message.originalFileName ?? 'Файл';
    final fileSize = widget.message.fileSize ?? 0;
    
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
      onTap: () => _openOrDownloadFile(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 250),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
                Icons.insert_drive_file,
                color: isFromMe ? Colors.white : Theme.of(context).colorScheme.primary,
                size: 28,
              ),
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
                    formattedSize,
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download,
              color: textColor.withOpacity(0.7),
              size: 20,
            ),
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
      // Show download progress
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Загрузка файла...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }
      
      // Get directory for downloaded files
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      
      final localPath = '${downloadDir.path}/$fileName';
      
      // Download the file (files are served as static files, no auth needed)
      final dio = Dio();
      await dio.download(
        fileUrl,
        localPath,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      // Hide download snackbar and open file
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        final result = await OpenFilex.open(localPath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось открыть файл: ${result.message}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        // Update message with local path for future use
        ref.read(messagesProvider(widget.message.chatId).notifier)
            .updateMessageLocalPath(widget.message.id, localFilePath: localPath);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  /// Build reply quote widget
  Widget _buildReplyQuote(BuildContext context, bool isMe) {
    final reply = widget.message.replyToMessage!;
    
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
          color: isMe 
              ? Colors.white.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMe ? Colors.white54 : Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reply.senderName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isMe ? Colors.white70 : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _getReplyPreviewText(reply),
              style: TextStyle(
                fontSize: 11,
                color: isMe ? Colors.white60 : Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
        return '[Голосовое сообщение]';
      case MessageType.image:
        return '[Изображение]';
      case MessageType.file:
        return '[Файл: ${reply.originalFileName ?? "файл"}]';
    }
  }

  Widget _buildImageWidget() {
    // Check if we have local image first
    if (widget.message.localImagePath != null && 
        File(widget.message.localImagePath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(widget.message.localImagePath!),
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    }
    
    // Otherwise use network image
    final imageUrl = widget.message.filePath != null
        ? '${ApiConstants.baseUrl}${widget.message.filePath}'
        : null;
    
    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.error_outline, size: 48),
            ),
          ),
        ),
      );
    }
    
    return Container(
      width: 200,
      height: 200,
      color: Colors.grey[300],
      child: const Center(
        child: Text('Изображение недоступно'),
      ),
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
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: widget.message.filePath != null
              ? '${ApiConstants.baseUrl}${widget.message.filePath}'
              : null,
          localPath: widget.message.localImagePath,
          senderName: displayName, // Use contact name if available
          createdAt: widget.message.createdAt,
        ),
      ),
    );
  }

  void _seekAudio(TapDownDetails details, bool isMe) {
    if (_duration == null || _duration!.inMilliseconds == 0) return;
    
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
      milliseconds: (_duration!.inMilliseconds * progress).round(),
    );
    
    _audioPlayer.seek(seekPosition);
  }

  Future<void> _markAudioAsPlayed() async {
    // CRITICAL: Set flag IMMEDIATELY to prevent race conditions
    if (_hasMarkedAsPlayed) return;
    _hasMarkedAsPlayed = true;
    
    final profileState = ref.read(profileProvider);
    final currentUserId = profileState.profile?.id;
    
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
    final currentUserId = profileState.profile?.id;
    
    // Fallback: if profile not loaded, check by isLocalOnly flag
    final isMe = (currentUserId != null && widget.message.senderId == currentUserId) ||
                 (widget.message.isLocalOnly == true);
    
    // Get display name from contacts or fallback to server name
    final contactsNames = ref.watch(contactsNamesProvider);
    final displayName = contactsNames[widget.message.senderId] 
                        ?? widget.message.senderName;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: widget.isHighlighted
              ? Colors.yellow.withOpacity(0.5)
              : isMe
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                displayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isMe
                      ? Colors.white70
                      : Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            // Forward indicator
            if (widget.message.forwardedFromUserName != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forward,
                    size: 12,
                    color: isMe ? Colors.white54 : Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Переслано от ${widget.message.forwardedFromUserName}',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: isMe ? Colors.white54 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            // Reply quote
            if (widget.message.replyToMessage != null)
              _buildReplyQuote(context, isMe),
            const SizedBox(height: 4),
            _buildMessageContent(context, isMe),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(widget.message.createdAt.toLocal()),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                // Edited indicator
                if (widget.message.isEdited) ...[
                  const SizedBox(width: 4),
                  Text(
                    'изм.',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: isMe ? Colors.white54 : Colors.grey[500],
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
    );
  }
}


