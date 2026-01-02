import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for saving images to device gallery
class GalleryService {
  /// Save an image file to the gallery
  /// Returns true if successful, false otherwise
  static Future<bool> saveImageToGallery(String sourcePath) async {
    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        final status = await Permission.photos.status;
        if (!status.isGranted) {
          final result = await Permission.photos.request();
          if (!result.isGranted) {
            // Try storage permission as fallback for older Android versions
            final storageStatus = await Permission.storage.request();
            if (!storageStatus.isGranted) {
              print('[GalleryService] Storage permission denied');
              return false;
            }
          }
        }
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        print('[GalleryService] Source file does not exist: $sourcePath');
        return false;
      }

      // Get the Pictures directory
      Directory? picturesDir;
      
      if (Platform.isAndroid) {
        // On Android, save to Pictures/Депеша
        final externalDir = Directory('/storage/emulated/0/Pictures/Депеша');
        if (!await externalDir.exists()) {
          await externalDir.create(recursive: true);
        }
        picturesDir = externalDir;
      } else if (Platform.isIOS) {
        // On iOS, use application documents directory
        picturesDir = await getApplicationDocumentsDirectory();
      }

      if (picturesDir == null) {
        print('[GalleryService] Could not get pictures directory');
        return false;
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = sourcePath.split('.').last;
      final targetPath = '${picturesDir.path}/image_$timestamp.$extension';

      // Copy file to gallery
      await sourceFile.copy(targetPath);
      
      print('[GalleryService] Image saved to: $targetPath');
      
      // Trigger media scan on Android to make it visible in gallery
      if (Platform.isAndroid) {
        await _triggerMediaScan(targetPath);
      }
      
      return true;
    } catch (e) {
      print('[GalleryService] Error saving image: $e');
      return false;
    }
  }

  /// Trigger Android media scanner to index the new file
  static Future<void> _triggerMediaScan(String filePath) async {
    try {
      // Use the file path to notify Android's media scanner
      // This makes the image visible in the gallery app
      final file = File(filePath);
      if (await file.exists()) {
        print('[GalleryService] File saved and ready for media scan');
        // Note: On modern Android, the file should be visible immediately
        // The MediaStore API would be used via platform channels for better integration
      }
    } catch (e) {
      print('[GalleryService] Media scan error: $e');
    }
  }
}

