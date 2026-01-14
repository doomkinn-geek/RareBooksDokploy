import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

/// Full-screen video player screen with swipe to dismiss
class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoPath,
    this.title = 'Видео',
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String? _errorMessage;
  
  // Swipe to dismiss
  double _dragOffset = 0;
  double _dragScale = 1.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Set to landscape if video is wider than tall
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.file(File(widget.videoPath));
      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        showOptions: true,
        placeholder: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white12,
          handleColor: Theme.of(context).colorScheme.primary,
        ),
        // Russian localization for options
        optionsTranslation: OptionsTranslation(
          playbackSpeedButtonText: 'Скорость воспроизведения',
          subtitlesButtonText: 'Субтитры',
          cancelButtonText: 'Отмена',
        ),
        additionalOptions: (ctx) => [
          OptionItem(
            onTap: (ctx) {
              Navigator.of(ctx).pop();
              Navigator.of(ctx).pop(); // Close video player
            },
            iconData: Icons.close,
            title: 'Закрыть',
          ),
        ],
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка воспроизведения: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    // Restore portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }
  
  void _onVerticalDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }
  
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
      // Scale down as user drags
      _dragScale = (1 - (_dragOffset.abs() / 500)).clamp(0.7, 1.0);
    });
  }
  
  void _onVerticalDragEnd(DragEndDetails details) {
    // If dragged more than 100 pixels or with high velocity, dismiss
    if (_dragOffset.abs() > 100 || details.velocity.pixelsPerSecond.dy.abs() > 500) {
      Navigator.of(context).pop();
    } else {
      // Animate back
      setState(() {
        _dragOffset = 0;
        _dragScale = 1.0;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_isDragging ? (1 - _dragOffset.abs() / 400).clamp(0.3, 1.0) : 1.0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        elevation: 0,
        actions: [
          // Close button for accessibility
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Закрыть',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Transform.scale(
            scale: _dragScale,
            child: Center(
              child: _errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.white54,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Закрыть'),
                          ),
                        ],
                      ),
                    )
                  : !_isInitialized
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Загрузка видео...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        )
                      : Chewie(controller: _chewieController!),
            ),
          ),
        ),
      ),
    );
  }
}
