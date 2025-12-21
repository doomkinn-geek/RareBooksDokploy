import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  final Dio _dio;
  
  ImageStorageService(this._dio);

  /// Get the image directory path
  Future<Directory> _getImageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDir.path}/images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }

  /// Get local image file path for a message
  Future<String?> getLocalImagePath(String messageId) async {
    try {
      final imageDir = await _getImageDirectory();
      
      // Check for different extensions
      for (var ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']) {
        final file = File('${imageDir.path}/$messageId$ext');
        if (await file.exists()) {
          return file.path;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if image file exists locally
  Future<bool> hasLocalImage(String messageId) async {
    final path = await getLocalImagePath(messageId);
    return path != null;
  }

  /// Download and save image file locally
  Future<String?> saveImageLocally(String messageId, String imageUrl) async {
    try {
      final imageDir = await _getImageDirectory();
      
      // Extract extension from URL
      var ext = '.jpg'; // default
      final uri = Uri.parse(imageUrl);
      if (uri.path.isNotEmpty) {
        final urlExt = uri.path.split('.').last.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(urlExt)) {
          ext = '.$urlExt';
        }
      }
      
      final filePath = '${imageDir.path}/$messageId$ext';
      
      // Download file
      final response = await _dio.get(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      if (response.statusCode == 404) {
        // File not found on server
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
      return null;
    }
  }

  /// Delete old image files (older than 30 days)
  Future<void> deleteOldImageFiles() async {
    try {
      final imageDir = await _getImageDirectory();
      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 30));
      
      final files = imageDir.listSync();
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
        print('[ImageStorage] Deleted $deletedCount old image files');
      }
    } catch (e) {
      print('[ImageStorage] Error deleting old files: $e');
    }
  }

  /// Delete specific image file
  Future<void> deleteImageFile(String messageId) async {
    try {
      final path = await getLocalImagePath(messageId);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('[ImageStorage] Error deleting file: $e');
    }
  }

  /// Save image from file path (for sent images)
  Future<String?> saveLocalImage(String messageId, String sourcePath) async {
    try {
      final imageDir = await _getImageDirectory();
      final sourceFile = File(sourcePath);
      
      if (!await sourceFile.exists()) {
        return null;
      }
      
      // Extract extension
      var ext = '.jpg';
      final sourceExt = sourcePath.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(sourceExt)) {
        ext = '.$sourceExt';
      }
      
      final filePath = '${imageDir.path}/$messageId$ext';
      
      // Copy file
      await sourceFile.copy(filePath);
      
      return filePath;
    } catch (e) {
      print('[ImageStorage] Error saving local image: $e');
      return null;
    }
  }
}

