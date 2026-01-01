import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String? imageUrl;
  final String? localPath;
  final String senderName;
  final DateTime createdAt;

  const FullScreenImageViewer({
    super.key,
    this.imageUrl,
    this.localPath,
    required this.senderName,
    required this.createdAt,
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
  final TransformationController _transformationController = TransformationController();
  
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
  
  // Thresholds for gesture detection
  static const double _swipeDetectionThreshold = 20.0; // px before determining intent
  static const double _swipeAngleThreshold = 0.7; // cos of max angle from vertical (about 45 degrees)
  static const Duration _swipeDetectionTimeout = Duration(milliseconds: 150);

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
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
      // First finger - start detection phase
      _gestureState = _GestureState.detecting;
      _gestureStartPosition = event.localPosition;
      _gestureStartTime = DateTime.now();
    } else if (_pointerCount >= 2) {
      // Second finger - it's a pinch, not a swipe
      _gestureState = _GestureState.pinching;
      // Reset any swipe progress
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
    if (_currentScale > 1.05) {
      // Zoomed in - don't allow swipe
      _gestureState = _GestureState.pinching;
      return;
    }
    
    if (_pointerCount >= 2) {
      // Multiple fingers - it's a pinch
      _gestureState = _GestureState.pinching;
      return;
    }
    
    if (_gestureState == _GestureState.detecting && _gestureStartPosition != null) {
      final delta = event.localPosition - _gestureStartPosition!;
      final distance = delta.distance;
      
      // Wait for movement to exceed threshold before determining intent
      if (distance > _swipeDetectionThreshold) {
        // Calculate if movement is predominantly vertical
        final verticalRatio = delta.dy.abs() / distance;
        
        if (verticalRatio > _swipeAngleThreshold) {
          // Predominantly vertical movement - it's a swipe
          _gestureState = _GestureState.swiping;
        } else {
          // Horizontal or diagonal - let InteractiveViewer handle it
          _gestureState = _GestureState.pinching;
        }
      } else {
        // Check timeout - if finger stayed still too long, it might be a pinch start
        final elapsed = DateTime.now().difference(_gestureStartTime!);
        if (elapsed > _swipeDetectionTimeout) {
          // Timeout without clear vertical movement - default to pinching
          _gestureState = _GestureState.pinching;
        }
      }
    }
    
    // Apply swipe movement
    if (_gestureState == _GestureState.swiping) {
      final delta = event.localPosition - _gestureStartPosition!;
      setState(() {
        _dragOffset = delta.dy;
        _opacity = (1.0 - (_dragOffset.abs() / 300)).clamp(0.0, 1.0);
      });
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
      });
      _gestureState = _GestureState.idle;
      _gestureStartPosition = null;
      _gestureStartTime = null;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // Image viewer with zoom (pinch-to-zoom)
                // InteractiveViewer handles its own gestures
                Center(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 4.0,
                    onInteractionStart: (details) {
                      // When InteractiveViewer starts interaction, mark as pinching
                      if (details.pointerCount >= 2) {
                        _gestureState = _GestureState.pinching;
                      }
                    },
                    onInteractionEnd: (details) {
                      // Reset drag offset when zooming is done
                      if (_currentScale <= 1.0 && _dragOffset != 0) {
                        setState(() {
                          _dragOffset = 0.0;
                          _opacity = 1.0;
                        });
                      }
                    },
                    child: _buildImage(),
                  ),
                ),
          
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
                            widget.senderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatDate(widget.createdAt),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.localPath != null && File(widget.localPath!).existsSync()) {
      return Image.file(
        File(widget.localPath!),
        fit: BoxFit.contain,
      );
    } else if (widget.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
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
      return const Center(
        child: Text(
          'Изображение недоступно',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
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
}
