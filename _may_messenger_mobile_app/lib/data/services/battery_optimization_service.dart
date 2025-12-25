import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage battery optimization settings
/// Requesting exemption from battery optimization ensures reliable
/// message delivery and push notifications
class BatteryOptimizationService {
  static const String _keyAskedForOptimization = 'asked_battery_optimization';
  
  /// Check if battery optimization is disabled for this app
  Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true; // Only relevant for Android
    
    try {
      return await DisableBatteryOptimization.isBatteryOptimizationDisabled ?? false;
    } catch (e) {
      print('[BatteryOptimization] Error checking status: $e');
      return false;
    }
  }
  
  /// Request to disable battery optimization
  /// Returns true if already disabled or user granted permission
  Future<bool> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    
    try {
      // First check if already disabled
      final isDisabled = await isBatteryOptimizationDisabled();
      if (isDisabled) return true;
      
      // Request to disable
      await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
      
      // Check again after user returns from settings
      return await isBatteryOptimizationDisabled();
    } catch (e) {
      print('[BatteryOptimization] Error requesting disable: $e');
      return false;
    }
  }
  
  /// Show a dialog explaining why battery optimization exemption is needed
  /// and offer to open settings
  Future<void> showOptimizationDialog(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    // Check if already asked before
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_keyAskedForOptimization) ?? false;
    
    // Check if already disabled
    final isDisabled = await isBatteryOptimizationDisabled();
    if (isDisabled) return;
    
    // Don't show dialog immediately on first launch - wait for second launch
    if (!alreadyAsked) {
      await prefs.setBool(_keyAskedForOptimization, true);
      return;
    }
    
    if (!context.mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_alert, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Оптимизация батареи')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Для надежной доставки сообщений рекомендуется отключить оптимизацию батареи для этого приложения.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Это позволит:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('• Получать уведомления без задержек'),
            Text('• Быстро доставлять сообщения'),
            Text('• Своевременно обновлять статусы'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Позже'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Настроить'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await requestDisableBatteryOptimization();
    }
  }
  
  /// Check manufacturer-specific optimization settings
  /// Some manufacturers (Xiaomi, Huawei, Samsung) have additional restrictions
  Future<void> showManufacturerOptimizationDialog(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    try {
      // Try to show auto-start settings if available
      final hasAutoStart = await DisableBatteryOptimization.isAutoStartEnabled ?? false;
      
      if (!hasAutoStart && context.mounted) {
        // Show info about manufacturer settings
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Для надежной работы также рекомендуется разрешить автозапуск в настройках телефона',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('[BatteryOptimization] Error checking auto-start: $e');
    }
  }
}

/// Provider for BatteryOptimizationService
final batteryOptimizationServiceProvider = Provider<BatteryOptimizationService>((ref) {
  return BatteryOptimizationService();
});

