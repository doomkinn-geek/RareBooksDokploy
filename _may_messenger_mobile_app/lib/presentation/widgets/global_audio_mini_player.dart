import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/global_audio_service.dart';

/// Мини-плеер для отображения текущего воспроизведения аудио
/// Отображается поверх списка чатов когда есть активное воспроизведение
class GlobalAudioMiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;
  
  const GlobalAudioMiniPlayer({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(globalAudioServiceProvider);
    
    // Не показывать если нет активного воспроизведения
    if (!playbackState.hasActivePlayback) {
      return const SizedBox.shrink();
    }
    
    final audioService = ref.read(globalAudioServiceProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Play/Pause button
                _buildPlayButton(playbackState, audioService, isDark),
                const SizedBox(width: 12),
                
                // Info and progress
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sender name
                      Text(
                        playbackState.senderName ?? 'Голосовое сообщение',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Progress bar
                      _buildProgressBar(playbackState, audioService, isDark),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Time display
                _buildTimeDisplay(playbackState, isDark),
                
                const SizedBox(width: 8),
                
                // Speed button
                _buildSpeedButton(playbackState, audioService, isDark),
                
                const SizedBox(width: 4),
                
                // Close button
                _buildCloseButton(audioService, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPlayButton(AudioPlaybackState state, GlobalAudioService service, bool isDark) {
    if (state.isLoading) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
          ),
        ),
      );
    }
    
    return GestureDetector(
      onTap: () {
        if (state.isPlaying) {
          service.pause();
        } else {
          service.resume();
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.teal,
          shape: BoxShape.circle,
        ),
        child: Icon(
          state.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
  
  Widget _buildProgressBar(AudioPlaybackState state, GlobalAudioService service, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: state.progress,
        backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
        minHeight: 4,
      ),
    );
  }
  
  Widget _buildTimeDisplay(AudioPlaybackState state, bool isDark) {
    final position = state.position;
    final duration = state.duration ?? Duration.zero;
    
    String formatDuration(Duration d) {
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }
    
    return Text(
      '${formatDuration(position)} / ${formatDuration(duration)}',
      style: TextStyle(
        fontSize: 12,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
  
  Widget _buildSpeedButton(AudioPlaybackState state, GlobalAudioService service, bool isDark) {
    return GestureDetector(
      onTap: () => service.cycleSpeed(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700] : Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${state.speed}x',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCloseButton(GlobalAudioService service, bool isDark) {
    return GestureDetector(
      onTap: () => service.stop(),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700] : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close,
          size: 16,
          color: isDark ? Colors.white70 : Colors.grey[600],
        ),
      ),
    );
  }
}

