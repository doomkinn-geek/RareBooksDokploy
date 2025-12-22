import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/signalr_provider.dart';
import '../providers/connectivity_provider.dart';

/// Compact connection status indicator for app bar
/// Green dot - connected, Gray dot - disconnected, Orange dot - reconnecting
class ConnectionStatusIndicator extends ConsumerWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalRState = ref.watch(signalRConnectionProvider);
    final connectivityStatus = ref.watch(connectivityStatusProvider);
    
    return connectivityStatus.when(
      data: (isOnline) {
        Color color;
        String tooltip;
        
        if (!isOnline) {
          color = Colors.red;
          tooltip = 'Нет интернета';
        } else if (signalRState.isConnected) {
          color = Colors.green;
          tooltip = 'Подключено';
        } else if (signalRState.isReconnecting || signalRState.isSilentReconnecting) {
          color = Colors.orange;
          tooltip = 'Переподключение...';
        } else {
          color = Colors.grey;
          tooltip = 'Не подключено';
        }
        
        return Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

