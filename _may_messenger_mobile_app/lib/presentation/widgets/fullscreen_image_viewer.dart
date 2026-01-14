import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../core/services/gallery_service.dart';

/// Data class for image information in the gallery
class ImageData {
  final String? imageUrl;
  final String? localPath;
  final String senderName;
  final DateTime createdAt;
  final String messageId;

  const ImageData({
    this.imageUrl,
    this.localPath,
    required this.senderName,
    required this.createdAt,
    required this.messageId,
  });
}

class FullScreenImageViewer extends StatefulWidget {
  final String? imageUrl;
  final String? localPath;
  final String senderName;
  final DateTime createdAt;
  
  /// Message ID for Hero animation
  final String? messageId;
  
  /// Optional list of all images in the chat for horizontal swiping
  final List<ImageData>? allImages;
  /// Initial index in the images list
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    this.imageUrl,
    this.localPath,
    required this.senderName,
    required this.createdAt,
    this.messageId,
    this.allImages,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  // Save state
  bool _isSaving = false;
  
  // Page view for horizontal swiping between images
  late PageController _pageController;
  late int _currentIndex;
  
  // Current image data (for display in header)
  late String _currentSenderName;
  late DateTime _currentCreatedAt;
  late String? _currentImageUrl;
  late String? _currentLocalPath;

  @override
  void initState() {
    super.initState();
    
    // Initialize with single image or from list
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    
    if (widget.allImages != null && widget.allImages!.isNotEmpty) {
      final currentImage = widget.allImages![_currentIndex];
      _currentSenderName = currentImage.senderName;
      _currentCreatedAt = currentImage.createdAt;
      _currentImageUrl = currentImage.imageUrl;
      _currentLocalPath = currentImage.localPath;
    } else {
      _currentSenderName = widget.senderName;
      _currentCreatedAt = widget.createdAt;
      _currentImageUrl = widget.imageUrl;
      _currentLocalPath = widget.localPath;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  void _onPageChanged(int index) {
    if (widget.allImages != null && index < widget.allImages!.length) {
      setState(() {
        _currentIndex = index;
        final currentImage = widget.allImages![index];
        _currentSenderName = currentImage.senderName;
        _currentCreatedAt = currentImage.createdAt;
        _currentImageUrl = currentImage.imageUrl;
        _currentLocalPath = currentImage.localPath;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final bool hasMultipleImages = widget.allImages != null && widget.allImages!.length > 1;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image viewer - either PageView or single PinchZoomImage
          if (hasMultipleImages)
            _buildPageView()
          else
            _buildSingleImageView(),
    
          // Top app bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentSenderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatDate(_currentCreatedAt),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Save to gallery button
                    _isSaving
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.download, color: Colors.white),
                            onPressed: _saveImageToGallery,
                            tooltip: 'Сохранить в галерею',
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Page indicator for multiple images
          if (hasMultipleImages)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.allImages!.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPageView() {
    return PhotoViewGallery.builder(
      pageController: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: widget.allImages!.length,
      builder: (context, index) {
        final imageData = widget.allImages![index];
        return _buildPhotoViewItem(
          imageUrl: imageData.imageUrl,
          localPath: imageData.localPath,
          heroTag: 'image_${imageData.messageId}',
        );
      },
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
      ),
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
  
  Widget _buildSingleImageView() {
    return _buildPhotoView(
      imageUrl: _currentImageUrl,
      localPath: _currentLocalPath,
      heroTag: widget.messageId != null ? 'image_${widget.messageId}' : null,
    );
  }
  
  /// Build PhotoViewGalleryPageOptions for gallery
  PhotoViewGalleryPageOptions _buildPhotoViewItem({
    String? imageUrl,
    String? localPath,
    String? heroTag,
  }) {
    ImageProvider? imageProvider;
    
    // Check if we have local image first
    if (localPath != null && File(localPath).existsSync()) {
      imageProvider = FileImage(File(localPath));
    } else if (imageUrl != null) {
      imageProvider = CachedNetworkImageProvider(imageUrl);
    }
    
    return PhotoViewGalleryPageOptions(
      imageProvider: imageProvider,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4.0,
      heroAttributes: heroTag != null ? PhotoViewHeroAttributes(tag: heroTag) : null,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 48),
            SizedBox(height: 16),
            Text(
              'Не удалось загрузить изображение',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build PhotoView for single image
  Widget _buildPhotoView({
    String? imageUrl,
    String? localPath,
    String? heroTag,
  }) {
    ImageProvider? imageProvider;
    
    // Check if we have local image first
    if (localPath != null && File(localPath).existsSync()) {
      imageProvider = FileImage(File(localPath));
    } else if (imageUrl != null) {
      imageProvider = CachedNetworkImageProvider(imageUrl);
    }
    
    if (imageProvider == null) {
      return const Center(
        child: Text(
          'Изображение недоступно',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    
    return PhotoView(
      imageProvider: imageProvider,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4.0,
      heroAttributes: heroTag != null ? PhotoViewHeroAttributes(tag: heroTag) : null,
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
      ),
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 48),
            SizedBox(height: 16),
            Text(
              'Не удалось загрузить изображение',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
  

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Сегодня в ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Вчера в ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}.${date.month}.${date.year} в ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
  
  /// Save image to gallery
  Future<void> _saveImageToGallery() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      String? filePath;
      
      // Use current image data
      final localPath = _currentLocalPath;
      final imageUrl = _currentImageUrl;
      
      // If we have a local path, use it directly
      if (localPath != null && File(localPath).existsSync()) {
        filePath = localPath;
      } else if (imageUrl != null) {
        // Download the image first
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          // Save to temp file first
          final tempDir = await getTemporaryDirectory();
          final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(response.bodyBytes);
          filePath = tempFile.path;
        }
      }
      
      if (filePath != null) {
        // Save to gallery using our custom service
        final success = await GalleryService.saveImageToGallery(filePath);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success 
                ? 'Изображение сохранено в галерею' 
                : 'Ошибка сохранения изображения'),
              duration: const Duration(seconds: 2),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      } else {
        throw Exception('Не удалось получить изображение');
      }
    } catch (e) {
      print('[IMAGE_SAVE] Error saving image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
