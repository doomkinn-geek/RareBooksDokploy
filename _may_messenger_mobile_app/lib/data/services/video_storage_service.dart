import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class VideoStorageService {
  final Dio _dio;
  
  VideoStorageService(this._dio);

  /// Get the video directory path
  Future<Directory> _getVideoDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${appDir.path}/videos');
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }
    return videoDir;
  }

  /// Get local video file path for a message
  Future<String?> getLocalVideoPath(String messageId) async {
    try {
      final videoDir = await _getVideoDirectory();
      
      // Check for different extensions
      for (var ext in ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v']) {
        final file = File('${videoDir.path}/$messageId$ext');
        if (await file.exists()) {
          return file.path;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if video file exists locally
  Future<bool> hasLocalVideo(String messageId) async {
    final path = await getLocalVideoPath(messageId);
    return path != null;
  }

  /// Download and save video file locally with progress callback
  Future<String?> saveVideoLocally(
    String messageId,
    String videoUrl, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final videoDir = await _getVideoDirectory();
      
      // Extract extension from URL
      var ext = '.mp4'; // default
      final uri = Uri.parse(videoUrl);
      if (uri.path.isNotEmpty) {
        final urlExt = uri.path.split('.').last.toLowerCase();
        if (['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].contains(urlExt)) {
          ext = '.$urlExt';
        }
      }
      
      final filePath = '${videoDir.path}/$messageId$ext';
      
      // Download file with progress
      final response = await _dio.get(
        videoUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );
      
      if (response.statusCode == 404) {
        // File not found on server (might have been cleaned up)
        return null;
      }
      
      if (response.statusCode != 200) {
        return null;
      }
      
      // Save to file
      final file = File(filePath);
      await file.writeAsBytes(response.data);
      
      return filePath;
    } catch (e) {
      // Network error or other issue
      print('[VideoStorage] Error downloading video: $e');
      return null;
    }
  }

  /// Delete old video files (older than 14 days - shorter than images due to size)
  Future<void> deleteOldVideoFiles() async {
    try {
      final videoDir = await _getVideoDirectory();
      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 14));
      
      final files = videoDir.listSync();
      int deletedCount = 0;
      int freedBytes = 0;
      
      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            freedBytes += stat.size;
            await entity.delete();
            deletedCount++;
          }
        }
      }
      
      if (deletedCount > 0) {
        print('[VideoStorage] Deleted $deletedCount old video files, freed ${(freedBytes / 1024 / 1024).toStringAsFixed(1)} MB');
      }
    } catch (e) {
      print('[VideoStorage] Error deleting old files: $e');
    }
  }

  /// Delete specific video file
  Future<void> deleteVideoFile(String messageId) async {
    try {
      final path = await getLocalVideoPath(messageId);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('[VideoStorage] Error deleting file: $e');
    }
  }

  /// Save video from file path (for sent videos)
  Future<String?> saveLocalVideo(String messageId, String sourcePath) async {
    try {
      final videoDir = await _getVideoDirectory();
      final sourceFile = File(sourcePath);
      
      if (!await sourceFile.exists()) {
        return null;
      }
      
      // Extract extension
      var ext = '.mp4';
      final sourceExt = sourcePath.split('.').last.toLowerCase();
      if (['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].contains(sourceExt)) {
        ext = '.$sourceExt';
      }
      
      final filePath = '${videoDir.path}/$messageId$ext';
      
      // Copy file
      await sourceFile.copy(filePath);
      
      return filePath;
    } catch (e) {
      print('[VideoStorage] Error saving local video: $e');
      return null;
    }
  }

  /// Get total size of cached videos in bytes
  Future<int> getCacheSizeBytes() async {
    try {
      final videoDir = await _getVideoDirectory();
      int totalSize = 0;
      
      final files = videoDir.listSync();
      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all cached videos
  Future<void> clearCache() async {
    try {
      final videoDir = await _getVideoDirectory();
      final files = videoDir.listSync();
      
      for (final entity in files) {
        if (entity is File) {
          await entity.delete();
        }
      }
      
      print('[VideoStorage] Cache cleared');
    } catch (e) {
      print('[VideoStorage] Error clearing cache: $e');
    }
  }
}
