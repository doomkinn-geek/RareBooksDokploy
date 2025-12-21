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
    // Request permissions
    final Permission permission = source == ImageSource.camera
        ? Permission.camera
        : Permission.photos;

    final status = await permission.request();
    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'Требуется разрешение на использование камеры'
                  : 'Требуется разрешение на доступ к галерее',
            ),
          ),
        );
      }
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      if (context.mounted) {
        // Compress image
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

      final result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: 85,
        minWidth: 1920,
        minHeight: 1920,
      );

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

