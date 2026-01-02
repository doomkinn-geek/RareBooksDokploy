import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/services/gallery_service.dart';

/// Full screen viewer for user avatars with zoom and save functionality
class FullScreenAvatarViewer extends StatefulWidget {
  final String? avatarUrl;
  final String? localPath;
  final String displayName;

  const FullScreenAvatarViewer({
    super.key,
    this.avatarUrl,
    this.localPath,
    required this.displayName,
  });

  @override
  State<FullScreenAvatarViewer> createState() => _FullScreenAvatarViewerState();
}

/// Gesture state for distinguishing between swipe and pinch
enum _GestureState {
  idle,
  detecting,
  swiping,
  pinching,
}

class _FullScreenAvatarViewerState extends State<FullScreenAvatarViewer>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  double _opacity = 1.0;
  double _currentScale = 1.0;
  final TransformationController _transformationController = TransformationController();
  
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  
  static const double _doubleTapZoomScale = 2.5;
  
  _GestureState _gestureState = _GestureState.idle;
  Offset? _gestureStartPosition;
  DateTime? _gestureStartTime;
  int _pointerCount = 0;
  
  static const double _swipeDetectionThreshold = 20.0;
  static const double _swipeAngleThreshold = 0.7;
  static const Duration _swipeDetectionTimeout = Duration(milliseconds: 150);
  
  bool _isSaving = false;

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
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale != _currentScale) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _handleDoubleTap() {
    if (_currentScale > 1.05) {
      _animateToScaleCenter(1.0);
    } else {
      _animateToScaleCenter(_doubleTapZoomScale);
    }
  }
  
  void _animateToScaleCenter(double targetScale) {
    final Matrix4 currentMatrix = _transformationController.value;
    Matrix4 targetMatrix;
    
    if (targetScale <= 1.0) {
      targetMatrix = Matrix4.identity();
    } else {
      final size = MediaQuery.of(context).size;
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      
      final dx = -centerX * (targetScale - 1);
      final dy = -centerY * (targetScale - 1);
      
      targetMatrix = Matrix4.identity()
        ..translate(dx, dy)
        ..scale(targetScale);
    }
    
    _animation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.reset();
    _animationController.forward();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    
    if (_pointerCount == 1) {
      _gestureState = _GestureState.detecting;
      _gestureStartPosition = event.localPosition;
      _gestureStartTime = DateTime.now();
    } else if (_pointerCount >= 2) {
      _gestureState = _GestureState.pinching;
      if (_dragOffset != 0) {
        setState(() {
          _dragOffset = 0;
          _opacity = 1.0;
        });
      }
    }
  }
  
  void _onPointerMove(PointerMoveEvent event) {
    if (_currentScale > 1.05) {
      _gestureState = _GestureState.pinching;
      return;
    }
    
    if (_pointerCount >= 2) {
      _gestureState = _GestureState.pinching;
      return;
    }
    
    if (_gestureState == _GestureState.detecting && _gestureStartPosition != null) {
      final delta = event.localPosition - _gestureStartPosition!;
      final distance = delta.distance;
      
      if (distance > _swipeDetectionThreshold) {
        final verticalRatio = delta.dy.abs() / distance;
        
        if (verticalRatio > _swipeAngleThreshold) {
          _gestureState = _GestureState.swiping;
        } else {
          _gestureState = _GestureState.pinching;
        }
      } else {
        final elapsed = DateTime.now().difference(_gestureStartTime!);
        if (elapsed > _swipeDetectionTimeout) {
          _gestureState = _GestureState.pinching;
        }
      }
    }
    
    if (_gestureState == _GestureState.swiping) {
      final delta = event.localPosition - _gestureStartPosition!;
      setState(() {
        _dragOffset = delta.dy;
        _opacity = (1.0 - (_dragOffset.abs() / 300)).clamp(0.0, 1.0);
      });
    }
  }
  
  void _onPointerUp(PointerUpEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    
    if (_pointerCount == 0) {
      if (_gestureState == _GestureState.swiping) {
        if (_dragOffset.abs() > 100) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _dragOffset = 0.0;
            _opacity = 1.0;
          });
        }
      }
      
      _gestureState = _GestureState.idle;
      _gestureStartPosition = null;
      _gestureStartTime = null;
    }
  }
  
  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    
    if (_pointerCount == 0) {
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
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: GestureDetector(
          onDoubleTap: _handleDoubleTap,
          behavior: HitTestBehavior.translucent,
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 4.0,
                    onInteractionStart: (details) {
                      if (details.pointerCount >= 2) {
                        _gestureState = _GestureState.pinching;
                      }
                    },
                    onInteractionEnd: (details) {
                      if (_currentScale <= 1.0 && _dragOffset != 0) {
                        setState(() {
                          _dragOffset = 0.0;
                          _opacity = 1.0;
                        });
                      }
                    },
                    child: _buildAvatar(),
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
                            child: Text(
                              widget.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                                  onPressed: _saveAvatarToGallery,
                                  tooltip: 'Сохранить в галерею',
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Zoom indicator
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

  Widget _buildAvatar() {
    if (widget.localPath != null && File(widget.localPath!).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(widget.localPath!),
          fit: BoxFit.cover,
          width: 300,
          height: 300,
        ),
      );
    } else if (widget.avatarUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: widget.avatarUrl!,
          fit: BoxFit.cover,
          width: 300,
          height: 300,
          placeholder: (context, url) => Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          errorWidget: (context, url, error) => _buildFallbackAvatar(context),
        ),
      );
    } else {
      return _buildFallbackAvatar(context);
    }
  }
  
  Widget _buildFallbackAvatar(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 120,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  /// Save avatar to gallery
  Future<void> _saveAvatarToGallery() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      String? filePath;
      
      // If we have a local path, use it directly
      if (widget.localPath != null && File(widget.localPath!).existsSync()) {
        filePath = widget.localPath;
      } else if (widget.avatarUrl != null) {
        // Download the image first
        final response = await http.get(Uri.parse(widget.avatarUrl!));
        if (response.statusCode == 200) {
          // Save to temp file first
          final tempDir = await getTemporaryDirectory();
          final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
                ? 'Аватар сохранен в галерею' 
                : 'Ошибка сохранения аватара'),
              duration: const Duration(seconds: 2),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      } else {
        throw Exception('Не удалось получить изображение');
      }
    } catch (e) {
      print('[AVATAR_SAVE] Error saving avatar: $e');
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

