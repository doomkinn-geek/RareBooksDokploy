import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/message_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/logger_service.dart';
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

  const MessageBubble({
    super.key,
    required this.message,
    this.isHighlighted = false,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _logger = LoggerService();
  bool _isPlaying = false;
  bool _hasMarkedAsPlayed = false; // Track if we've already marked as played
  Duration? _duration;
  Duration? _position;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.audio) {
      _initAudio();
    }
  }

  void _initAudio() {
    _audioPlayer.durationStream.listen((d) {
      setState(() => _duration = d);
    });
    _audioPlayer.positionStream.listen((p) {
      setState(() => _position = p);
    });
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
      
      // Mark as played when first started playing (and user is not the sender)
      if (state.playing && 
          !_hasMarkedAsPlayed && 
          widget.message.type == MessageType.audio) {
        _markAudioAsPlayed();
      }
      
      // Сброс при окончании воспроизведения
      if (state.processingState == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
    });
  }

  Future<void> _playPauseAudio() async {
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
        
        if (_audioPlayer.processingState == ProcessingState.idle) {
          // 1. Check for local audio file first
          final audioStorageService = ref.read(audioStorageServiceProvider);
          String? localPath = widget.message.localAudioPath ?? 
                              await audioStorageService.getLocalAudioPath(widget.message.id);
          
          if (localPath != null && await File(localPath).exists()) {
            // Use local file
            await _audioPlayer.setFilePath(localPath);
          } else {
            // 2. Try to download from server
            if (widget.message.filePath == null || widget.message.filePath!.isEmpty) {
              // File was deleted on server
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
            
            final audioUrl = '${ApiConstants.baseUrl}${widget.message.filePath}';
            
            try {
              // Show loading indicator
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Загрузка аудио...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
              
              // Download and save locally
              localPath = await audioStorageService.saveAudioLocally(
                widget.message.id, 
                audioUrl
              );
              
              if (localPath != null) {
                await _audioPlayer.setFilePath(localPath);
                
                // Update cache with local path
                final localDataSource = ref.read(localDataSourceProvider);
                await localDataSource.updateMessageLocalAudioPath(
                  widget.message.chatId,
                  widget.message.id,
                  localPath
                );
              } else {
                // Failed to download - file may be deleted
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
            } catch (e) {
              // Network error or file deleted
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Не удалось загрузить аудио'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              return;
            }
          }
        }
        await _audioPlayer.play();
      }
    } catch (e) {
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildMessageStatusIcon() {
    switch (widget.message.status) {
      case MessageStatus.sending:
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
        // Синяя иконка динамика - воспроизведено (для аудио)
        return const Icon(
          Icons.volume_up,
          size: 14,
          color: Colors.blue,
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: isMe ? Colors.white : null,
                size: 28,
              ),
              onPressed: _playPauseAudio,
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
                      activeColor: isMe ? Colors.white : Theme.of(context).colorScheme.primary,
                      inactiveColor: isMe ? Colors.white30 : Colors.grey[300]!,
                      height: 30,
                      barsCount: 25,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _position != null
                              ? '${_position!.inMinutes}:${(_position!.inSeconds % 60).toString().padLeft(2, '0')}'
                              : '0:00',
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        Text(
                          _duration != null
                              ? '${_duration!.inMinutes}:${(_duration!.inSeconds % 60).toString().padLeft(2, '0')}'
                              : '0:00',
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.grey[600],
                          ),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: widget.message.filePath != null
              ? '${ApiConstants.baseUrl}${widget.message.filePath}'
              : null,
          localPath: widget.message.localImagePath,
          senderName: widget.message.senderName,
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
    if (_hasMarkedAsPlayed) return;
    
    final profileState = ref.read(profileProvider);
    final currentUserId = profileState.profile?.id;
    
    // Don't mark own messages as played
    if (currentUserId == null || widget.message.senderId == currentUserId) {
      return;
    }
    
    _hasMarkedAsPlayed = true;
    
    try {
      // Call API to mark as played
      await ref.read(messagesProvider(widget.message.chatId).notifier)
          .markAudioAsPlayed(widget.message.id);
    } catch (e) {
      _logger.debug('message_bubble', 'Failed to mark audio as played: $e', {
        'messageId': widget.message.id
      });
      // Reset flag to retry later
      _hasMarkedAsPlayed = false;
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

  Future<void> _showDeleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сообщение'),
        content: const Text('Сообщение будет удалено у всех участников чата'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(messagesProvider(widget.message.chatId).notifier)
            .deleteMessage(widget.message.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Сообщение удалено'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось удалить сообщение'),
              duration: Duration(seconds: 2),
            ),
          );
        }
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
      child: GestureDetector(
        onLongPress: isMe ? () => _showDeleteDialog(context) : null,
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
    );
  }
}


