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

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  double _dragOffset = 0.0;
  double _opacity = 1.0;
  double _currentScale = 1.0; // Track current zoom scale
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
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

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    // Only allow swipe-to-dismiss when image is not zoomed
    if (_currentScale <= 1.05) {
      setState(() {
        _dragOffset += details.delta.dy;
        // Calculate opacity based on drag distance (fade out as dragging down)
        _opacity = (1.0 - (_dragOffset.abs() / 300)).clamp(0.0, 1.0);
      });
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    // Only handle dismiss when not zoomed
    if (_currentScale <= 1.05) {
      // Dismiss if dragged more than 100 pixels or fast velocity
      if (_dragOffset.abs() > 100 || 
          details.velocity.pixelsPerSecond.dy.abs() > 500) {
        Navigator.of(context).pop();
      } else {
        // Reset position if not enough drag
        setState(() {
          _dragOffset = 0.0;
          _opacity = 1.0;
        });
      }
    } else {
      // Reset if zoomed
      setState(() {
        _dragOffset = 0.0;
        _opacity = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if swipe gestures should be enabled
    final bool enableSwipeToDismiss = _currentScale <= 1.05;
    
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_opacity),
      body: GestureDetector(
        // Only intercept vertical drags when not zoomed
        onVerticalDragUpdate: enableSwipeToDismiss ? _handleVerticalDragUpdate : null,
        onVerticalDragEnd: enableSwipeToDismiss ? _handleVerticalDragEnd : null,
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Stack(
            children: [
              // Image viewer with zoom
              Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  // Double-tap to reset zoom
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
            ],
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

