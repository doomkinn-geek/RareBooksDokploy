import 'dart:io';
import 'dart:typed_data';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

/// Result of video compression containing compressed file and metadata
class VideoCompressionResult {
  final String compressedPath;
  final int width;
  final int height;
  final int durationMs;
  final int fileSizeBytes;
  final String? thumbnailPath;
  final Uint8List? thumbnailBytes;

  VideoCompressionResult({
    required this.compressedPath,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.fileSizeBytes,
    this.thumbnailPath,
    this.thumbnailBytes,
  });
}

/// Service for compressing videos before upload
class VideoCompressionService {
  static final VideoCompressionService _instance = VideoCompressionService._internal();
  factory VideoCompressionService() => _instance;
  VideoCompressionService._internal();

  /// Compress video file and extract metadata
  /// Returns null if compression fails
  Future<VideoCompressionResult?> compressVideo(
    String videoPath, {
    void Function(double progress)? onProgress,
    VideoQuality quality = VideoQuality.MediumQuality,
  }) async {
    try {
      // Get original media info
      final info = await VideoCompress.getMediaInfo(videoPath);
      if (info.path == null) {
        print('[VideoCompression] Failed to get media info');
        return null;
      }

      // Subscribe to compression progress
      final subscription = VideoCompress.compressProgress$.subscribe((progress) {
        onProgress?.call(progress / 100.0);
      });

      try {
        // Compress video
        final compressed = await VideoCompress.compressVideo(
          videoPath,
          quality: quality,
          deleteOrigin: false,
          includeAudio: true,
        );

        if (compressed == null || compressed.path == null) {
          print('[VideoCompression] Compression failed');
          return null;
        }

        final compressedFile = File(compressed.path!);
        final fileSizeBytes = await compressedFile.length();

        // Extract metadata from compressed file
        final compressedInfo = await VideoCompress.getMediaInfo(compressed.path!);
        
        final width = compressedInfo.width?.toInt() ?? info.width?.toInt() ?? 0;
        final height = compressedInfo.height?.toInt() ?? info.height?.toInt() ?? 0;
        final durationMs = (compressedInfo.duration ?? info.duration ?? 0).toInt();

        // Generate thumbnail
        Uint8List? thumbnailBytes;
        String? thumbnailPath;
        
        try {
          thumbnailBytes = await VideoThumbnail.thumbnailData(
            video: compressed.path!,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 320,
            quality: 75,
          );

          if (thumbnailBytes != null) {
            // Save thumbnail to temp file
            final tempDir = await getTemporaryDirectory();
            thumbnailPath = '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
            await File(thumbnailPath).writeAsBytes(thumbnailBytes);
          }
        } catch (e) {
          print('[VideoCompression] Failed to generate thumbnail: $e');
        }

        print('[VideoCompression] Compressed: ${(fileSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB, '
            '${width}x$height, ${(durationMs / 1000).toStringAsFixed(1)}s');

        return VideoCompressionResult(
          compressedPath: compressed.path!,
          width: width,
          height: height,
          durationMs: durationMs,
          fileSizeBytes: fileSizeBytes,
          thumbnailPath: thumbnailPath,
          thumbnailBytes: thumbnailBytes,
        );
      } finally {
        subscription.unsubscribe();
      }
    } catch (e) {
      print('[VideoCompression] Error compressing video: $e');
      return null;
    }
  }

  /// Get video info without compression
  Future<({int width, int height, int durationMs})?> getVideoInfo(String videoPath) async {
    try {
      final info = await VideoCompress.getMediaInfo(videoPath);
      return (
        width: info.width?.toInt() ?? 0,
        height: info.height?.toInt() ?? 0,
        durationMs: info.duration?.toInt() ?? 0,
      );
    } catch (e) {
      print('[VideoCompression] Error getting video info: $e');
      return null;
    }
  }

  /// Generate thumbnail from video without compression
  Future<Uint8List?> generateThumbnail(
    String videoPath, {
    int maxWidth = 320,
    int quality = 75,
  }) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth,
        quality: quality,
      );
    } catch (e) {
      print('[VideoCompression] Error generating thumbnail: $e');
      return null;
    }
  }

  /// Cancel ongoing compression
  Future<void> cancelCompression() async {
    try {
      await VideoCompress.cancelCompression();
    } catch (e) {
      print('[VideoCompression] Error canceling compression: $e');
    }
  }

  /// Delete all temporary files created during compression
  Future<void> deleteAllTempFiles() async {
    try {
      await VideoCompress.deleteAllCache();
    } catch (e) {
      print('[VideoCompression] Error deleting temp files: $e');
    }
  }
}
