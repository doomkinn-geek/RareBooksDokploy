import 'package:flutter/material.dart';
import 'dart:math' as math;

class AudioWaveform extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final int barsCount;

  const AudioWaveform({
    super.key,
    required this.progress,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.grey,
    this.height = 40,
    this.barsCount = 30,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _WaveformPainter(
        progress: progress,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        barsCount: barsCount,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int barsCount;

  _WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.barsCount,
  });

  // Generate consistent random heights for bars (using seed for consistency)
  List<double> _generateBarHeights() {
    final random = math.Random(42); // Fixed seed for consistent waveform
    return List.generate(barsCount, (index) {
      // Create a wave-like pattern with randomness
      final base = (math.sin(index / barsCount * math.pi * 2) + 1) / 2;
      final randomFactor = random.nextDouble() * 0.5 + 0.5;
      return (base * 0.6 + 0.2) * randomFactor;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final barHeights = _generateBarHeights();
    final barWidth = size.width / barsCount;
    final maxHeight = size.height;

    for (int i = 0; i < barsCount; i++) {
      final x = i * barWidth;
      final barProgress = i / barsCount;
      
      // Determine bar color based on progress
      final paint = Paint()
        ..color = barProgress <= progress ? activeColor : inactiveColor
        ..strokeWidth = barWidth * 0.6
        ..strokeCap = StrokeCap.round;

      // Calculate bar height
      final height = maxHeight * barHeights[i];
      final centerY = size.height / 2;
      final top = centerY - height / 2;
      final bottom = centerY + height / 2;

      // Draw the bar
      canvas.drawLine(
        Offset(x + barWidth / 2, top),
        Offset(x + barWidth / 2, bottom),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

