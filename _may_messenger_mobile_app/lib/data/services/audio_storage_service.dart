import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class AudioStorageService {
  final Dio _dio;
  
  AudioStorageService(this._dio);

  /// Get the audio directory path
  Future<Directory> _getAudioDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Get local audio file path for a message
  Future<String?> getLocalAudioPath(String messageId) async {
    try {
      final audioDir = await _getAudioDirectory();
      final file = File('${audioDir.path}/$messageId.m4a');
      
      if (await file.exists()) {
        return file.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if audio file exists locally
  Future<bool> hasLocalAudio(String messageId) async {
    final path = await getLocalAudioPath(messageId);
    return path != null;
  }

  /// Download and save audio file locally
  Future<String?> saveAudioLocally(String messageId, String audioUrl, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final audioDir = await _getAudioDirectory();
      final filePath = '${audioDir.path}/$messageId.m4a';
      
      // Download file with progress callback
      await _dio.download(
        audioUrl,
        filePath,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
        onReceiveProgress: onProgress != null 
            ? (received, total) {
                if (total > 0) {
                  onProgress(received / total);
                }
              }
            : null,
      );
      
      // Verify file was downloaded
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      // Network error or other issue
      return null;
    }
  }
  
  /// Save sent audio file locally before upload
  /// This ensures the sender can play back their own audio even offline
  Future<String?> cacheSentAudio(String messageId, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        print('[AudioStorage] Source file does not exist: $sourcePath');
        return null;
      }
      
      final audioDir = await _getAudioDirectory();
      final destPath = '${audioDir.path}/$messageId.m4a';
      
      // Copy file to audio storage
      await sourceFile.copy(destPath);
      
      print('[AudioStorage] Cached sent audio: $messageId -> $destPath');
      return destPath;
    } catch (e) {
      print('[AudioStorage] Error caching sent audio: $e');
      return null;
    }
  }
  
  /// Save audio from bytes (for received audio that needs caching)
  Future<String?> saveAudioFromBytes(String messageId, List<int> bytes) async {
    try {
      final audioDir = await _getAudioDirectory();
      final filePath = '${audioDir.path}/$messageId.m4a';
      
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      print('[AudioStorage] Saved audio from bytes: $messageId');
      return filePath;
    } catch (e) {
      print('[AudioStorage] Error saving audio from bytes: $e');
      return null;
    }
  }

  /// Delete old audio files (older than 30 days)
  Future<void> deleteOldAudioFiles() async {
    try {
      final audioDir = await _getAudioDirectory();
      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 30));
      
      final files = audioDir.listSync();
      int deletedCount = 0;
      
      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
      
      if (deletedCount > 0) {
        print('[AudioStorage] Deleted $deletedCount old audio files');
      }
    } catch (e) {
      print('[AudioStorage] Error deleting old files: $e');
    }
  }

  /// Delete specific audio file
  Future<void> deleteAudioFile(String messageId) async {
    try {
      final path = await getLocalAudioPath(messageId);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('[AudioStorage] Error deleting file: $e');
    }
  }
}
