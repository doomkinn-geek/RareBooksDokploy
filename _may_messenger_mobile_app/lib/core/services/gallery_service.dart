import 'dart:io';
import 'dart:typed_data';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for saving images to device gallery
class GalleryService {
  /// Save an image file to the gallery
  /// Returns true if successful, false otherwise
  static Future<bool> saveImageToGallery(String sourcePath) async {
    try {
      print('[GalleryService] Saving image from: $sourcePath');
      
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

      // Read file bytes
      final Uint8List bytes = await sourceFile.readAsBytes();
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = sourcePath.split('.').last.toLowerCase();
      final fileName = 'Депеша_$timestamp.$extension';
      
      // Use saver_gallery to save to gallery
      final result = await SaverGallery.saveImage(
        bytes,
        fileName: fileName,
        androidRelativePath: 'Pictures/Депеша',
        skipIfExists: false,
      );
      
      if (result.isSuccess) {
        print('[GalleryService] Image saved successfully to gallery');
        return true;
      } else {
        print('[GalleryService] Failed to save image: ${result.errorMessage}');
        return false;
      }
    } catch (e) {
      print('[GalleryService] Error saving image: $e');
      return false;
    }
  }
  
  /// Save image bytes directly to gallery
  static Future<bool> saveImageBytesToGallery(Uint8List bytes, String extension) async {
    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        final status = await Permission.photos.status;
        if (!status.isGranted) {
          final result = await Permission.photos.request();
          if (!result.isGranted) {
            final storageStatus = await Permission.storage.request();
            if (!storageStatus.isGranted) {
              print('[GalleryService] Storage permission denied');
              return false;
            }
          }
        }
      }
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'Депеша_$timestamp.$extension';
      
      // Use saver_gallery to save to gallery
      final result = await SaverGallery.saveImage(
        bytes,
        fileName: fileName,
        androidRelativePath: 'Pictures/Депеша',
        skipIfExists: false,
      );
      
      if (result.isSuccess) {
        print('[GalleryService] Image saved successfully to gallery');
        return true;
      } else {
        print('[GalleryService] Failed to save image: ${result.errorMessage}');
        return false;
      }
    } catch (e) {
      print('[GalleryService] Error saving image bytes: $e');
      return false;
    }
  }
}
