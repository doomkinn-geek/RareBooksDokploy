import 'package:flutter/material.dart';
import '../../data/models/message_model.dart';

/// A widget that allows swiping a message to reply
class SwipeableMessage extends StatefulWidget {
  final Widget child;
  final Message message;
  final VoidCallback? onSwipeReply;

  const SwipeableMessage({
    super.key,
    required this.child,
    required this.message,
    this.onSwipeReply,
  });

  @override
  State<SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<SwipeableMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragExtent = 0;
  
  static const double _swipeThreshold = 60.0;
  static const double _maxSwipe = 80.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // Disable swipe if no callback
    if (widget.onSwipeReply == null) return;
    
    // Only allow right swipe (positive dx)
    if (details.delta.dx > 0 || _dragExtent > 0) {
      setState(() {
        _dragExtent = (_dragExtent + details.delta.dx).clamp(0.0, _maxSwipe);
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragExtent >= _swipeThreshold && widget.onSwipeReply != null) {
      // Trigger reply
      widget.onSwipeReply!();
      // Haptic feedback
      HapticFeedback.lightImpact();
    }
    
    // Animate back to start
    _animation = Tween<double>(begin: _dragExtent, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward(from: 0);
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _dragExtent = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final offset = _controller.isAnimating ? _animation.value : _dragExtent;
          return Stack(
            children: [
              // Reply icon that appears when swiping
              if (offset > 10)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Opacity(
                      opacity: (offset / _swipeThreshold).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: (offset / _swipeThreshold).clamp(0.5, 1.0),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.reply,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Message content
              Transform.translate(
                offset: Offset(offset, 0),
                child: widget.child,
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

// Helper class for haptic feedback
class HapticFeedback {
  static void lightImpact() {
    // Will be implemented through platform channels if needed
  }
}

// AnimatedBuilder alias for AnimatedWidget
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;
  
  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);
  
  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

