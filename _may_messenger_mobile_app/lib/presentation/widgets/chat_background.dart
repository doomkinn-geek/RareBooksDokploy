import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/themes/app_theme.dart';

/// Фон чата в стиле Telegram с паттерном
class ChatBackground extends StatelessWidget {
  final Widget child;
  
  const ChatBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.chatBackgroundDark 
            : AppColors.chatBackgroundLight,
      ),
      child: CustomPaint(
        painter: ChatPatternPainter(isDark: isDark),
        child: child,
      ),
    );
  }
}

/// Painter для паттерна чата
class ChatPatternPainter extends CustomPainter {
  final bool isDark;
  
  ChatPatternPainter({required this.isDark});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark 
          ? Colors.white.withOpacity(0.02)
          : Colors.black.withOpacity(0.03)
      ..style = PaintingStyle.fill;
    
    final strokePaint = Paint()
      ..color = isDark 
          ? Colors.white.withOpacity(0.015)
          : Colors.black.withOpacity(0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Размер ячейки паттерна
    const cellSize = 80.0;
    
    // Иконки для паттерна
    final icons = [
      _drawEnvelope,
      _drawHeart,
      _drawStar,
      _drawCircle,
      _drawDiamond,
      _drawCloud,
    ];
    
    // Рисуем паттерн
    final random = math.Random(42); // Фиксированный seed для консистентности
    
    for (double x = 0; x < size.width + cellSize; x += cellSize) {
      for (double y = 0; y < size.height + cellSize; y += cellSize) {
        // Небольшое смещение для органичности
        final offsetX = (random.nextDouble() - 0.5) * 20;
        final offsetY = (random.nextDouble() - 0.5) * 20;
        
        // Выбираем случайную иконку
        final iconIndex = random.nextInt(icons.length);
        final iconSize = 12.0 + random.nextDouble() * 8;
        final rotation = random.nextDouble() * math.pi * 2;
        
        canvas.save();
        canvas.translate(x + offsetX + cellSize / 2, y + offsetY + cellSize / 2);
        canvas.rotate(rotation);
        
        icons[iconIndex](canvas, paint, strokePaint, iconSize);
        
        canvas.restore();
      }
    }
  }
  
  void _drawEnvelope(Canvas canvas, Paint fill, Paint stroke, double size) {
    final path = Path();
    path.moveTo(-size, -size * 0.6);
    path.lineTo(size, -size * 0.6);
    path.lineTo(size, size * 0.6);
    path.lineTo(-size, size * 0.6);
    path.close();
    
    canvas.drawPath(path, stroke);
    
    // Линия конверта
    final linePath = Path();
    linePath.moveTo(-size, -size * 0.6);
    linePath.lineTo(0, size * 0.1);
    linePath.lineTo(size, -size * 0.6);
    canvas.drawPath(linePath, stroke);
  }
  
  void _drawHeart(Canvas canvas, Paint fill, Paint stroke, double size) {
    final path = Path();
    path.moveTo(0, size * 0.3);
    path.cubicTo(-size, -size * 0.3, -size, -size, 0, -size * 0.3);
    path.cubicTo(size, -size, size, -size * 0.3, 0, size * 0.3);
    canvas.drawPath(path, fill);
  }
  
  void _drawStar(Canvas canvas, Paint fill, Paint stroke, double size) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 4 * math.pi / 5) - math.pi / 2;
      final x = math.cos(angle) * size;
      final y = math.sin(angle) * size;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
  }
  
  void _drawCircle(Canvas canvas, Paint fill, Paint stroke, double size) {
    canvas.drawCircle(Offset.zero, size * 0.7, stroke);
  }
  
  void _drawDiamond(Canvas canvas, Paint fill, Paint stroke, double size) {
    final path = Path();
    path.moveTo(0, -size);
    path.lineTo(size * 0.7, 0);
    path.lineTo(0, size);
    path.lineTo(-size * 0.7, 0);
    path.close();
    canvas.drawPath(path, fill);
  }
  
  void _drawCloud(Canvas canvas, Paint fill, Paint stroke, double size) {
    canvas.drawCircle(Offset(-size * 0.5, 0), size * 0.5, fill);
    canvas.drawCircle(Offset(size * 0.5, 0), size * 0.5, fill);
    canvas.drawCircle(Offset(0, -size * 0.3), size * 0.6, fill);
  }
  
  @override
  bool shouldRepaint(covariant ChatPatternPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

