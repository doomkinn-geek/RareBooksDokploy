import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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

/// Gesture state for distinguishing between swipe and pinch
enum _GestureState {
  idle,           // No gesture in progress
  detecting,      // First touch, waiting to determine intent
  swiping,        // Confirmed vertical swipe (single finger, vertical)
  pinching,       // Confirmed pinch/zoom (two fingers or interaction started)
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  double _opacity = 1.0;
  double _currentScale = 1.0; // Track current zoom scale
  TransformationController _transformationController = TransformationController();
  
  // Animation controller for smooth double-tap zoom
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  
  // Target scale for double-tap zoom
  static const double _doubleTapZoomScale = 2.5;
  
  // Gesture detection state machine
  _GestureState _gestureState = _GestureState.idle;
  Offset? _gestureStartPosition;
  DateTime? _gestureStartTime;
  int _pointerCount = 0;
  
  // Track if InteractiveViewer is actively handling gestures
  bool _isInteractiveViewerActive = false;
  
  // Thresholds for gesture detection
  static const double _swipeDetectionThreshold = 25.0; // px before determining intent
  static const double _swipeAngleThreshold = 0.75; // Vertical angle threshold (about 40 degrees from vertical)
  static const Duration _swipeDetectionTimeout = Duration(milliseconds: 200); // Timeout for pinch detection
  
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
    _transformationController.addListener(_onTransformationChanged);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
    
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
    _animationController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    // Extract scale from transformation matrix
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale != _currentScale) {
      setState(() {
        _currentScale = scale;
      });
    }
  }
  
  void _onPageChanged(int index) {
    // Reset zoom when changing pages
    _transformationController.value = Matrix4.identity();
    _currentScale = 1.0;
    
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

  /// Handle double-tap to zoom in/out relative to center
  void _handleDoubleTap() {
    if (_currentScale > 1.05) {
      // Already zoomed - zoom out to 1x (reset to center)
      _animateToScaleCenter(1.0);
    } else {
      // Not zoomed - zoom in to target scale relative to center
      _animateToScaleCenter(_doubleTapZoomScale);
    }
  }
  
  /// Animate zoom to target scale, centered on the image center
  /// This provides a consistent zoom experience regardless of tap position
  void _animateToScaleCenter(double targetScale) {
    // Get the current transformation
    final Matrix4 currentMatrix = _transformationController.value;
    
    // Calculate the target transformation
    Matrix4 targetMatrix;
    
    if (targetScale <= 1.0) {
      // Reset to identity (no zoom, no pan)
      targetMatrix = Matrix4.identity();
    } else {
      // Zoom centered on screen center (image center)
      // When zooming to center, we need to translate so the center stays fixed
      final size = MediaQuery.of(context).size;
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      
      // Calculate the translation needed to keep center fixed after scaling
      // For center-based zoom, we translate by -(center * (scale - 1))
      // This is equivalent to zooming "into" the center
      final dx = -centerX * (targetScale - 1);
      final dy = -centerY * (targetScale - 1);
      
      targetMatrix = Matrix4.identity()
        ..translate(dx, dy)
        ..scale(targetScale);
    }
    
    // Create the animation
    _animation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Reset and start animation
    _animationController.reset();
    _animationController.forward();
  }

  /// Handle pointer down - start gesture detection
  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    
    if (_pointerCount == 1) {
      // First finger - start detection phase (but don't commit to swipe yet)
      _gestureState = _GestureState.detecting;
      _gestureStartPosition = event.localPosition;
      _gestureStartTime = DateTime.now();
    } else if (_pointerCount >= 2) {
      // Second finger detected - immediately switch to pinching mode
      // This takes priority over any potential swipe detection
      _gestureState = _GestureState.pinching;
      // Reset any swipe progress immediately
      if (_dragOffset != 0) {
        setState(() {
          _dragOffset = 0;
          _opacity = 1.0;
        });
      }
    }
  }
  
  /// Handle pointer move - determine gesture intent
  void _onPointerMove(PointerMoveEvent event) {
    // Always prioritize pinch over swipe when multiple fingers
    if (_pointerCount >= 2) {
      // Multiple fingers - definitely a pinch, not a swipe
      if (_gestureState != _GestureState.pinching) {
        _gestureState = _GestureState.pinching;
        // Reset any swipe progress
        if (_dragOffset != 0) {
          setState(() {
            _dragOffset = 0;
            _opacity = 1.0;
          });
        }
      }
      return;
    }
    
    if (_currentScale > 1.05) {
      // Zoomed in - don't allow swipe, let InteractiveViewer handle panning
      _gestureState = _GestureState.pinching;
      return;
    }
    
    // Once pinching/swiping is determined, stick with it
    if (_gestureState == _GestureState.pinching || _gestureState == _GestureState.swiping) {
      // If swiping, continue to update drag offset
      if (_gestureState == _GestureState.swiping && _gestureStartPosition != null) {
        final delta = event.localPosition - _gestureStartPosition!;
        setState(() {
          _dragOffset = delta.dy;
          _opacity = (1.0 - (_dragOffset.abs() / 300)).clamp(0.0, 1.0);
        });
      }
      return;
    }
    
    if (_gestureState == _GestureState.detecting && _gestureStartPosition != null) {
      final delta = event.localPosition - _gestureStartPosition!;
      final distance = delta.distance;
      
      // Wait for movement before determining intent
      if (distance > _swipeDetectionThreshold) {
        final horizontalDistance = delta.dx.abs();
        final verticalDistance = delta.dy.abs();
        
        // Calculate if movement is predominantly vertical or horizontal
        final verticalRatio = verticalDistance / distance;
        final horizontalRatio = horizontalDistance / distance;
        
        if (verticalRatio > _swipeAngleThreshold && verticalDistance > 30) {
          // Predominantly vertical - it's a dismiss swipe
          _gestureState = _GestureState.swiping;
        } else if (horizontalRatio > 0.6) {
          // Predominantly horizontal - let PageView handle it
          _gestureState = _GestureState.pinching;
        } else {
          // Diagonal or unclear - default to pinching to be safe
          _gestureState = _GestureState.pinching;
        }
      } else {
        // Check timeout - if stayed still, might be starting a pinch
        final elapsed = DateTime.now().difference(_gestureStartTime!);
        if (elapsed > _swipeDetectionTimeout) {
          _gestureState = _GestureState.pinching;
        }
      }
    }
  }
  
  /// Handle pointer up - finalize gesture
  void _onPointerUp(PointerUpEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    
    if (_pointerCount == 0) {
      // All fingers lifted
      if (_gestureState == _GestureState.swiping) {
        // Check if we should dismiss
        if (_dragOffset.abs() > 100) {
          Navigator.of(context).pop();
        } else {
          // Reset position
          setState(() {
            _dragOffset = 0.0;
            _opacity = 1.0;
          });
        }
      }
      
      // Reset state
      _gestureState = _GestureState.idle;
      _gestureStartPosition = null;
      _gestureStartTime = null;
      
      // Allow some delay before re-enabling PageView to prevent accidental swipe
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _pointerCount == 0) {
          setState(() {
            _isInteractiveViewerActive = false;
          });
        }
      });
    }
  }
  
  /// Handle pointer cancel
  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    
    if (_pointerCount == 0) {
      // Reset everything
      setState(() {
        _dragOffset = 0.0;
        _opacity = 1.0;
        _isInteractiveViewerActive = false;
      });
      _gestureState = _GestureState.idle;
      _gestureStartPosition = null;
      _gestureStartTime = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMultipleImages = widget.allImages != null && widget.allImages!.length > 1;
    
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_opacity),
      body: Listener(
        // Use Listener for low-level pointer events to properly detect gesture intent
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: GestureDetector(
          // Double-tap detection only - swipe is handled by Listener
          onDoubleTap: _handleDoubleTap,
          // Prevent GestureDetector from absorbing gestures
          behavior: HitTestBehavior.translucent,
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: Stack(
              children: [
                // Image viewer - either PageView or single InteractiveViewer
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
                
                // Zoom indicator (shows current zoom level when zoomed)
                if (_currentScale > 1.05)
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_currentScale.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
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
          ),
        ),
      ),
    );
  }
  
  Widget _buildPageView() {
    final screenSize = MediaQuery.of(context).size;
    
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      // Disable page scrolling when:
      // 1. Zoomed in
      // 2. InteractiveViewer is handling gesture (pinch/pan)
      // 3. Multiple pointers detected (pinch gesture)
      physics: (_currentScale > 1.05 || _isInteractiveViewerActive || _pointerCount >= 2)
          ? const NeverScrollableScrollPhysics() 
          : const BouncingScrollPhysics(),
      itemCount: widget.allImages!.length,
      itemBuilder: (context, index) {
        final imageData = widget.allImages![index];
        return InteractiveViewer(
          transformationController: index == _currentIndex 
              ? _transformationController 
              : TransformationController(),
          minScale: 1.0,  // Don't allow zoom out below 1x
          maxScale: 5.0,  // Increased max zoom
          // Allow panning beyond boundaries when zoomed
          boundaryMargin: EdgeInsets.all(_currentScale > 1.0 ? 100 : 0),
          panEnabled: _currentScale > 1.0, // Only pan when zoomed
          scaleEnabled: true,
          onInteractionStart: (details) {
            // Mark InteractiveViewer as active
            setState(() {
              _isInteractiveViewerActive = true;
            });
            
            // When InteractiveViewer starts interaction with 2+ fingers, mark as pinching
            if (details.pointerCount >= 2) {
              _gestureState = _GestureState.pinching;
            }
          },
          onInteractionUpdate: (details) {
            // If scale changes or multiple pointers, ensure we're in pinching mode
            if (details.pointerCount >= 2 || details.scale != 1.0) {
              _gestureState = _GestureState.pinching;
            }
          },
          onInteractionEnd: (details) {
            // Mark InteractiveViewer as inactive
            setState(() {
              _isInteractiveViewerActive = false;
            });
            
            // Reset drag offset when zooming is done
            if (_currentScale <= 1.0 && _dragOffset != 0) {
              setState(() {
                _dragOffset = 0.0;
                _opacity = 1.0;
              });
            }
          },
          child: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: _buildImageFromData(imageData),
          ),
        );
      },
    );
  }
  
  Widget _buildSingleImageView() {
    final screenSize = MediaQuery.of(context).size;
    
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 1.0,  // Don't allow zoom out below 1x
      maxScale: 5.0,  // Increased max zoom
      // Allow panning beyond boundaries when zoomed
      boundaryMargin: EdgeInsets.all(_currentScale > 1.0 ? 100 : 0),
      panEnabled: _currentScale > 1.0, // Only pan when zoomed
      scaleEnabled: true,
      onInteractionStart: (details) {
        // Mark InteractiveViewer as active
        setState(() {
          _isInteractiveViewerActive = true;
        });
        
        // When InteractiveViewer starts interaction with 2+ fingers, mark as pinching
        if (details.pointerCount >= 2) {
          _gestureState = _GestureState.pinching;
        }
      },
      onInteractionUpdate: (details) {
        // If scale changes or multiple pointers, ensure we're in pinching mode
        if (details.pointerCount >= 2 || details.scale != 1.0) {
          _gestureState = _GestureState.pinching;
        }
      },
      onInteractionEnd: (details) {
        // Mark InteractiveViewer as inactive
        setState(() {
          _isInteractiveViewerActive = false;
        });
        
        // Reset drag offset when zooming is done
        if (_currentScale <= 1.0 && _dragOffset != 0) {
          setState(() {
            _dragOffset = 0.0;
            _opacity = 1.0;
          });
        }
      },
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: _buildImage(),
      ),
    );
  }
  
  Widget _buildImageFromData(ImageData imageData) {
    Widget imageWidget;
    
    if (imageData.localPath != null && File(imageData.localPath!).existsSync()) {
      imageWidget = Image.file(
        File(imageData.localPath!),
        fit: BoxFit.contain,
        alignment: Alignment.center,
      );
    } else if (imageData.imageUrl != null) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageData.imageUrl!,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        fadeInDuration: const Duration(milliseconds: 200),
        errorWidget: (context, url, error) => const Center(
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
    } else {
      imageWidget = const Center(
        child: Text(
          'Изображение недоступно',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    
    // Center the image in the available space
    // Wrap in Hero for smooth transition animation
    return Center(
      child: Hero(
        tag: 'image_${imageData.messageId}',
        child: imageWidget,
      ),
    );
  }

  Widget _buildImage() {
    Widget imageWidget;
    
    if (widget.localPath != null && File(widget.localPath!).existsSync()) {
      imageWidget = Image.file(
        File(widget.localPath!),
        fit: BoxFit.contain,
        alignment: Alignment.center,
      );
    } else if (widget.imageUrl != null) {
      imageWidget = CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        fadeInDuration: const Duration(milliseconds: 200),
        errorWidget: (context, url, error) => const Center(
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
    } else {
      imageWidget = const Center(
        child: Text(
          'Изображение недоступно',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    
    // Center the image in the available space
    // Wrap in Hero for smooth transition animation (if messageId is provided)
    Widget result = Center(child: imageWidget);
    
    if (widget.messageId != null) {
      return Hero(
        tag: 'image_${widget.messageId}',
        child: result,
      );
    }
    return result;
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
