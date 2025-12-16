import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/message_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/logger_service.dart';
import '../providers/profile_provider.dart';
import '../providers/contacts_names_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/messages_provider.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _logger = LoggerService();
  bool _isPlaying = false;
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
      
      // Сброс при окончании воспроизведения
      if (state.processingState == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
    });
  }

  Future<void> _playPauseAudio() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
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
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.red,
        );
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
    final isMe = currentUserId != null && widget.message.senderId == currentUserId;
    
    // Get display name from contacts or fallback to server name
    final contactsNames = ref.watch(contactsNamesProvider);
    final displayName = contactsNames[widget.message.senderId] 
                        ?? widget.message.senderName;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isMe ? () => _showDeleteDialog(context) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe
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
            widget.message.type == MessageType.text
                ? Text(
                    widget.message.content ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : null,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: isMe ? Colors.white : null,
                        ),
                        onPressed: _playPauseAudio,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: _duration != null && _position != null
                                  ? _position!.inMilliseconds /
                                      _duration!.inMilliseconds
                                  : 0,
                              backgroundColor: isMe
                                  ? Colors.white30
                                  : Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isMe ? Colors.white : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              _duration != null
                                  ? '${_duration!.inMinutes}:${(_duration!.inSeconds % 60).toString().padLeft(2, '0')}'
                                  : '0:00',
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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


