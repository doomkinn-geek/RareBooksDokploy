import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecorderWidget extends StatefulWidget {
  final AudioRecorder? audioRecorder; // External recorder (optional for continuing recording)
  final String? audioPath; // Path to existing file (optional)
  final Duration? initialDuration; // Already recorded duration (optional)
  final Function(String) onSend;
  final VoidCallback onCancel;

  const AudioRecorderWidget({
    super.key,
    required this.onSend,
    required this.onCancel,
    this.audioRecorder,
    this.audioPath,
    this.initialDuration,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  late AudioRecorder _audioRecorder;
  String? _audioPath;
  Duration _duration = Duration.zero;
  Timer? _timer;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    
    // Check if we're continuing an existing recording
    if (widget.audioRecorder != null && widget.audioPath != null && widget.initialDuration != null) {
      // Continue existing recording
      _audioRecorder = widget.audioRecorder!;
      _audioPath = widget.audioPath;
      _duration = widget.initialDuration!;
      _isRecording = true;
      
      // Continue timer from current duration
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _duration = widget.initialDuration! + Duration(seconds: timer.tick);
          });
        }
      });
    } else {
      // Start new recording
      _audioRecorder = AudioRecorder();
      _startRecording();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Only dispose recorder if we created it (not passed from external)
    if (widget.audioRecorder == null) {
      _audioRecorder.dispose();
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final audioPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: audioPath,
        );

        setState(() {
          _isRecording = true;
          _audioPath = audioPath;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _duration = Duration(seconds: timer.tick);
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка записи: $e')),
        );
      }
      widget.onCancel();
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _sendAudio() async {
    await _stopRecording();
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      widget.onSend(_audioPath!);
    }
  }

  Future<void> _cancelRecording() async {
    await _stopRecording();
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      await File(_audioPath!).delete();
    }
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _duration.inMinutes;
    final seconds = _duration.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        height: 56, // Fixed height to match normal UI
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _cancelRecording,
              icon: const Icon(Icons.delete),
              color: Colors.red,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isRecording)
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                    ),
                  Text(
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _sendAudio,
              icon: const Icon(Icons.send),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}


