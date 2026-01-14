import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/message_model.dart';
import 'video_player_screen.dart';

/// Widget for displaying video messages in chat
class VideoMessageWidget extends StatelessWidget {
  final Message message;
  final bool isOwnMessage;
  final double maxWidth;
  final VoidCallback? onDownload;
  final bool isDownloading;

  const VideoMessageWidget({
    super.key,
    required this.message,
    required this.isOwnMessage,
    this.maxWidth = 280,
    this.onDownload,
    this.isDownloading = false,
  });

  String _formatDuration(int? milliseconds) {
    if (milliseconds == null) return '0:00';
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  bool get _hasLocalVideo =>
      message.localVideoPath != null &&
      File(message.localVideoPath!).existsSync();

  @override
  Widget build(BuildContext context) {
    // Calculate aspect ratio from metadata or use default
    final aspectRatio = (message.videoWidth != null &&
            message.videoHeight != null &&
            message.videoWidth! > 0 &&
            message.videoHeight! > 0)
        ? message.videoWidth! / message.videoHeight!
        : 16 / 9;

    // Calculate dimensions
    double width = maxWidth;
    double height = width / aspectRatio;

    // Limit height
    if (height > 300) {
      height = 300;
      width = height * aspectRatio;
    }

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          height: height,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Thumbnail or placeholder
              _buildThumbnail(),

              // Play button overlay
              _buildPlayButton(context),

              // Duration badge
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(message.videoDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // File size badge
              if (message.fileSize != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatFileSize(message.fileSize),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),

              // Upload/download progress
              if (message.uploadProgress != null &&
                  message.uploadProgress! < 1.0)
                _buildProgress(message.uploadProgress!, 'Загрузка...'),

              if (isDownloading && message.downloadProgress != null)
                _buildProgress(message.downloadProgress!, 'Скачивание...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    // For now, show a gradient placeholder
    // In future, could decode blurhash or show actual thumbnail
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOwnMessage
              ? [Colors.blue.shade800, Colors.blue.shade900]
              : [Colors.grey.shade700, Colors.grey.shade800],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie,
          color: Colors.white24,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    if (message.uploadProgress != null && message.uploadProgress! < 1.0) {
      return const SizedBox.shrink();
    }

    if (isDownloading) {
      return const SizedBox.shrink();
    }

    if (!_hasLocalVideo && message.filePath == null) {
      // Video not available (might have been cleaned up)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white70, size: 16),
            SizedBox(width: 6),
            Text(
              'Видео недоступно',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (!_hasLocalVideo) {
      // Need to download
      return GestureDetector(
        onTap: onDownload,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.download,
            color: Colors.white,
            size: 32,
          ),
        ),
      );
    }

    // Ready to play
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  Widget _buildProgress(double progress, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (message.uploadProgress != null && message.uploadProgress! < 1.0) {
      return; // Still uploading
    }

    if (isDownloading) {
      return; // Still downloading
    }

    if (!_hasLocalVideo) {
      // Need to download first
      onDownload?.call();
      return;
    }

    // Play video
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoPath: message.localVideoPath!,
          title: 'Видео',
        ),
      ),
    );
  }
}
