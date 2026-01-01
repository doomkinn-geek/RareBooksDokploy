import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A widget that displays a date separator between messages from different days
class DateSeparator extends StatelessWidget {
  final DateTime date;
  
  const DateSeparator({
    super.key,
    required this.date,
  });
  
  /// Format the date based on how recent it is:
  /// - Today: "Сегодня"
  /// - Yesterday: "Вчера"
  /// - Within current week: Day name (e.g., "Понедельник")
  /// - Older: Full date (e.g., "15 декабря 2024")
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(messageDate).inDays;
    
    if (diff == 0) {
      return 'Сегодня';
    }
    
    if (diff == 1) {
      return 'Вчера';
    }
    
    // Within the current week (less than 7 days ago)
    if (diff < 7) {
      // Get day name in Russian
      // Capitalize first letter
      final dayName = DateFormat('EEEE', 'ru').format(date);
      return dayName[0].toUpperCase() + dayName.substring(1);
    }
    
    // Older dates - show full date
    // Check if same year
    if (date.year == now.year) {
      return DateFormat('d MMMM', 'ru').format(date);
    }
    
    return DateFormat('d MMMM yyyy', 'ru').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper class for date-related utilities
class MessageDateUtils {
  /// Check if two dates are on the same day
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

