import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Universal camera button widget
/// - Tap: shows bottom sheet with options (photo, video, gallery)
/// - Long-press: immediately opens camera for video recording (quick access)
class CameraButton extends StatelessWidget {
  final VoidCallback onTakePhoto;
  final VoidCallback onRecordVideo;
  final VoidCallback onPickFromGallery;
  final Color? iconColor;

  const CameraButton({
    super.key,
    required this.onTakePhoto,
    required this.onRecordVideo,
    required this.onPickFromGallery,
    this.iconColor,
  });

  void _showMediaOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Медиа',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            // Take photo option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text('Сделать фото'),
              subtitle: const Text('Открыть камеру'),
              onTap: () {
                Navigator.pop(context);
                onTakePhoto();
              },
            ),
            // Record video option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.videocam, color: Colors.red),
              ),
              title: const Text('Записать видео'),
              subtitle: const Text('Записать с камеры'),
              onTap: () {
                Navigator.pop(context);
                onRecordVideo();
              },
            ),
            // Pick from gallery option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library, color: Colors.purple),
              ),
              title: const Text('Выбрать из галереи'),
              subtitle: const Text('Фото или видео'),
              onTap: () {
                Navigator.pop(context);
                onPickFromGallery();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _onLongPress() {
    HapticFeedback.mediumImpact();
    // Long-press immediately opens camera for video recording
    onRecordVideo();
  }

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
    
    return GestureDetector(
      onTap: () => _showMediaOptions(context),
      onLongPress: _onLongPress,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.camera_alt,
          color: color,
        ),
      ),
    );
  }
}
