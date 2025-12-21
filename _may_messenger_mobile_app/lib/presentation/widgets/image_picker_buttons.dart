import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'image_preview_dialog.dart';

class ImagePickerButtons extends StatelessWidget {
  final Function(String) onImageSelected;

  const ImagePickerButtons({
    super.key,
    required this.onImageSelected,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    // Request multiple permissions at once
    final Map<Permission, PermissionStatus> statuses;
    
    if (source == ImageSource.camera) {
      statuses = await [
        Permission.camera,
        Permission.storage,
      ].request();
      
      if (!statuses[Permission.camera]!.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Требуется разрешение на использование камеры'),
            ),
          );
        }
        return;
      }
    } else {
      // For gallery, request appropriate permissions based on Android version
      if (Platform.isAndroid) {
        statuses = await [
          Permission.photos,
          Permission.storage,
        ].request();
        
        final hasPermission = statuses[Permission.photos]?.isGranted == true ||
                              statuses[Permission.storage]?.isGranted == true;
        
        if (!hasPermission) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Требуется разрешение на доступ к галерее'),
              ),
            );
          }
          return;
        }
      } else {
        // iOS
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Требуется разрешение на доступ к галерее'),
              ),
            );
          }
          return;
        }
      }
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 80,
      );

      if (image == null) return;

      if (context.mounted) {
        // Compress image more aggressively
        final compressedPath = await _compressImage(image.path);
        final finalPath = compressedPath ?? image.path;

        // Show preview dialog
        final shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => ImagePreviewDialog(
            imagePath: finalPath,
            onSend: () => Navigator.of(context).pop(true),
            onCancel: () => Navigator.of(context).pop(false),
          ),
        );

        if (shouldSend == true && context.mounted) {
          onImageSelected(finalPath);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<String?> _compressImage(String imagePath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // First compression attempt with quality 80%
      var result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: 80,
        minWidth: 2048,
        minHeight: 2048,
      );

      if (result != null) {
        // Check file size
        final file = File(result.path);
        final fileSize = await file.length();
        
        // If still > 5MB, re-compress with lower quality
        if (fileSize > 5 * 1024 * 1024) {
          print('[ImagePicker] File too large (${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB), recompressing...');
          
          final targetPath2 = '${tempDir.path}/compressed2_${DateTime.now().millisecondsSinceEpoch}.jpg';
          result = await FlutterImageCompress.compressAndGetFile(
            result.path,
            targetPath2,
            quality: 70,
            minWidth: 2048,
            minHeight: 2048,
          );
          
          // Delete first attempt
          await file.delete();
        }
      }

      return result?.path;
    } catch (e) {
      print('[ImagePicker] Compression failed: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _pickImage(context, ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          tooltip: 'Камера',
          color: Theme.of(context).colorScheme.primary,
        ),
        IconButton(
          onPressed: () => _pickImage(context, ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          tooltip: 'Галерея',
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

