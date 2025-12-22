import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/hub_connection.dart';
import '../providers/signalr_provider.dart';

class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalRService = ref.watch(signalRServiceProvider);
    final connectionState = signalRService.connectionState;
    
    // Watch SignalRConnectionState to check reconnecting flags
    final connectionNotifierState = ref.watch(signalRConnectionProvider);

    // Hide banner completely during silent reconnecting
    if (connectionNotifierState.isSilentReconnecting) {
      return const SizedBox.shrink();
    }

    // Only show banner when not connected or connecting
    // Hide banner when connected or when state is null (initial state)
    if (connectionState == HubConnectionState.Connected || connectionState == null) {
      return const SizedBox.shrink();
    }
    
    // Show banner only for explicit reconnecting or when actually reconnecting
    if (connectionState == HubConnectionState.Reconnecting && !connectionNotifierState.isReconnecting) {
      // Don't show banner for automatic reconnects unless explicitly requested
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 32,
      color: _getStatusColor(connectionState),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _getStatusIcon(connectionState),
            const SizedBox(width: 8),
            Text(
              _getStatusText(connectionState),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (connectionState == HubConnectionState.Reconnecting) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
            if (connectionState == HubConnectionState.Disconnected) ...[
              const SizedBox(width: 12),
              TextButton(
                onPressed: () async {
                  try {
                    await ref.read(signalRConnectionProvider.notifier).reconnect();
                  } catch (e) {
                    print('[ConnectionBanner] Reconnect failed: $e');
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(HubConnectionState? state) {
    switch (state) {
      case HubConnectionState.Connected:
        return Colors.green;
      case HubConnectionState.Connecting:
      case HubConnectionState.Reconnecting:
        return Colors.orange;
      case HubConnectionState.Disconnected:
      case HubConnectionState.Disconnecting:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _getStatusIcon(HubConnectionState? state) {
    switch (state) {
      case HubConnectionState.Connected:
        return const Icon(Icons.cloud_done, size: 16, color: Colors.white);
      case HubConnectionState.Connecting:
      case HubConnectionState.Reconnecting:
        return const Icon(Icons.cloud_sync, size: 16, color: Colors.white);
      case HubConnectionState.Disconnected:
      case HubConnectionState.Disconnecting:
        return const Icon(Icons.cloud_off, size: 16, color: Colors.white);
      default:
        return const Icon(Icons.cloud_queue, size: 16, color: Colors.white);
    }
  }

  String _getStatusText(HubConnectionState? state) {
    switch (state) {
      case HubConnectionState.Connected:
        return 'Connected';
      case HubConnectionState.Connecting:
        return 'Connecting...';
      case HubConnectionState.Reconnecting:
        return 'Reconnecting...';
      case HubConnectionState.Disconnected:
        return 'Connection lost';
      case HubConnectionState.Disconnecting:
        return 'Disconnecting...';
      default:
        return 'Unknown status';
    }
  }
}

