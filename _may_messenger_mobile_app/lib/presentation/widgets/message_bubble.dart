import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/message_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/logger_service.dart';
import '../providers/profile_provider.dart';

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
    });
  }

  Future<void> _playPauseAudio() async {
    // #region agent log
    await _logger.debug('message_bubble._playPauseAudio.entry', '[H6] Play/Pause clicked', {
      'isPlaying': '$_isPlaying',
      'filePath': '${widget.message.filePath}',
      'processingState': '${_audioPlayer.processingState}'
    });
    // #endregion
    
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_audioPlayer.processingState == ProcessingState.idle) {
          final audioUrl = '${ApiConstants.baseUrl}${widget.message.filePath}';
          
          // #region agent log
          await _logger.debug('message_bubble._playPauseAudio.setUrl', '[H6] Setting audio URL', {
            'fullUrl': audioUrl
          });
          // #endregion
          
          await _audioPlayer.setUrl(audioUrl);
          
          // #region agent log
          await _logger.debug('message_bubble._playPauseAudio.urlSet', '[H6] URL set successfully', {
            'duration': '${_audioPlayer.duration}'
          });
          // #endregion
        }
        await _audioPlayer.play();
        
        // #region agent log
        await _logger.debug('message_bubble._playPauseAudio.playing', '[H6] Audio playing', {});
        // #endregion
      }
    } catch (e, stackTrace) {
      // #region agent log
      await _logger.error('message_bubble._playPauseAudio.error', '[H6] Audio error', {
        'error': e.toString(),
        'stack': stackTrace.toString().split('\n').take(3).join(' | ')
      });
      // #endregion
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final currentUserId = profileState.profile?.id;
    final isMe = currentUserId != null && widget.message.senderId == currentUserId;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                widget.message.senderName,
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
                  DateFormat('HH:mm').format(widget.message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    widget.message.status == MessageStatus.read
                        ? Icons.done_all
                        : Icons.done,
                    size: 14,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}


