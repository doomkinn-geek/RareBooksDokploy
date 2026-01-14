import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/services/video_compression_service.dart';
import 'image_preview_dialog.dart';
import 'video_preview_dialog.dart';

/// Type of media to pick
enum MediaPickerType { image, video }

/// Result of video picking with metadata
class VideoPickResult {
  final String path;
  final int width;
  final int height;
  final int durationMs;
  final int fileSizeBytes;

  VideoPickResult({
    required this.path,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.fileSizeBytes,
  });
}

/// Buttons for picking media (images and videos)
class MediaPickerButtons extends StatelessWidget {
  final Function(String) onImageSelected;
  final Function(VideoPickResult)? onVideoSelected;
  final bool showVideoOption;

  const MediaPickerButtons({
    super.key,
    required this.onImageSelected,
    this.onVideoSelected,
    this.showVideoOption = true,
  });

  Future<bool> _requestCameraPermission(BuildContext context) async {
    final statuses = await [
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
      return false;
    }
    return true;
  }

  Future<bool> _requestGalleryPermission(BuildContext context) async {
    if (Platform.isAndroid) {
      final statuses = await [
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
        return false;
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
        return false;
      }
    }
    return true;
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    if (source == ImageSource.camera) {
      if (!await _requestCameraPermission(context)) return;
    } else {
      if (!await _requestGalleryPermission(context)) return;
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

  Future<void> _pickVideo(BuildContext context, ImageSource source) async {
    if (onVideoSelected == null) return;

    if (source == ImageSource.camera) {
      if (!await _requestCameraPermission(context)) return;
    } else {
      if (!await _requestGalleryPermission(context)) return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5), // 5 minute limit
      );

      if (video == null) return;

      if (!context.mounted) return;

      // Show loading dialog during compression
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Сжатие видео...'),
            ],
          ),
        ),
      );

      try {
        // Compress video
        final compressionService = VideoCompressionService();
        final result = await compressionService.compressVideo(video.path);

        // Close loading dialog
        if (context.mounted) Navigator.of(context).pop();

        if (result == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ошибка сжатия видео')),
            );
          }
          return;
        }

        if (!context.mounted) return;

        // Show preview dialog
        final shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => VideoPreviewDialog(
            videoPath: result.compressedPath,
            durationMs: result.durationMs,
            fileSizeBytes: result.fileSizeBytes,
            onSend: () => Navigator.of(context).pop(true),
            onCancel: () => Navigator.of(context).pop(false),
          ),
        );

        if (shouldSend == true && context.mounted) {
          onVideoSelected!(VideoPickResult(
            path: result.compressedPath,
            width: result.width,
            height: result.height,
            durationMs: result.durationMs,
            fileSizeBytes: result.fileSizeBytes,
          ));
        }
      } catch (e) {
        // Close loading dialog if still open
        if (context.mounted) Navigator.of(context).pop();
        rethrow;
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

      var result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: 80,
        minWidth: 2048,
        minHeight: 2048,
      );

      if (result != null) {
        final file = File(result.path);
        final fileSize = await file.length();

        // If still > 5MB, re-compress with lower quality
        if (fileSize > 5 * 1024 * 1024) {
          print('[MediaPicker] File too large (${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB), recompressing...');

          final targetPath2 =
              '${tempDir.path}/compressed2_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      print('[MediaPicker] Compression failed: $e');
      return null;
    }
  }

  void _showMediaPickerMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Выбрать изображение'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.gallery);
              },
            ),
            if (showVideoOption && onVideoSelected != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Записать видео'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Выбрать видео'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo(context, ImageSource.gallery);
                },
              ),
            ],
          ],
        ),
      ),
    );
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
        if (showVideoOption && onVideoSelected != null)
          IconButton(
            onPressed: () => _pickVideo(context, ImageSource.gallery),
            icon: const Icon(Icons.videocam),
            tooltip: 'Видео',
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }
}
