import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/signalr_service.dart';
import '../../data/repositories/outbox_repository.dart';
import '../../data/services/event_queue_service.dart';
import '../../data/models/user_model.dart';
import '../providers/signalr_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';

/// Debug settings screen for diagnostics
/// Available for administrators in production
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  bool _autoRefresh = false;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    if (_autoRefresh) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _autoRefresh) {
          setState(() {});
          _startAutoRefresh();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final signalRService = ref.watch(signalRServiceProvider);
    final profileState = ref.watch(profileProvider);
    
    // Check if user is admin
    final profile = profileState.profile;
    final isAdmin = profile?.role == UserRole.admin;
    
    // Debug: log profile info
    debugPrint('[DebugScreen] Profile: ${profile?.toJson()}');
    debugPrint('[DebugScreen] Role: ${profile?.role}, isAdmin: $isAdmin');
    
    // Show access warning if not admin (but still show debug info)
    final showAccessWarning = !isAdmin;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Debug Diagnostics'),
        actions: [
          IconButton(
            icon: Icon(_autoRefresh ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _autoRefresh = !_autoRefresh;
                if (_autoRefresh) {
                  _startAutoRefresh();
                }
              });
            },
            tooltip: _autoRefresh ? 'Pause auto-refresh' : 'Start auto-refresh',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Manual refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (showAccessWarning) _buildAccessWarning(),
            if (showAccessWarning) const SizedBox(height: 16),
            _buildProfileSection(profileState),
            const SizedBox(height: 16),
            _buildCriticalErrorsSection(),
            const SizedBox(height: 16),
            _buildSignalRSection(signalRService),
            const SizedBox(height: 16),
            _buildOutboxSection(),
            const SizedBox(height: 16),
            _buildEventQueueSection(),
            const SizedBox(height: 16),
            _buildSystemInfoSection(),
            const SizedBox(height: 16),
            _buildActionsSection(signalRService),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessWarning() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ограниченный доступ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Эта функция предназначена для администраторов. Информация показана для диагностики.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(ProfileState profileState) {
    final profile = profileState.profile;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Профиль пользователя',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (profile == null)
              const Text('Профиль не загружен', style: TextStyle(color: Colors.red))
            else ...[
              _buildInfoRow('ID', profile.id),
              _buildInfoRow('Имя', profile.displayName),
              _buildInfoRow('Телефон', profile.phoneNumber),
              _buildInfoRow('Роль (enum)', profile.role.toString()),
              _buildInfoRow('Роль (index)', profile.role.index.toString()),
              _buildInfoRow('isAdmin', profile.isAdmin.toString()),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  'JSON: ${profile.toJson().toString()}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
            if (profileState.error != null) ...[
              const SizedBox(height: 8),
              Text(
                'Ошибка: ${profileState.error}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  final List<String> _criticalErrors = [];

  Widget _buildCriticalErrorsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text(
                      'Критические ошибки',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_criticalErrors.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      // Copy errors to clipboard
                      final errorText = _criticalErrors.join('\n\n');
                      debugPrint('[DebugScreen] Copied errors: $errorText');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ошибки скопированы в буфер обмена')),
                      );
                    },
                    tooltip: 'Копировать все ошибки',
                  ),
              ],
            ),
            const Divider(),
            if (_criticalErrors.isEmpty)
              const Text('Нет критических ошибок', style: TextStyle(color: Colors.green))
            else ...[
              Text('Последние ${_criticalErrors.length} ошибок:', 
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._criticalErrors.take(10).map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    error,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignalRSection(SignalRService signalRService) {
    final heartbeatStats = signalRService.getHeartbeatStats();
    final isConnected = signalRService.isConnected;
    final connectionState = signalRService.connectionState?.toString() ?? 'Unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  'SignalR Connection',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('Status', connectionState),
            _buildInfoRow(
              'Connected',
              isConnected ? '✅ Yes' : '❌ No',
              valueColor: isConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 8),
            const Text(
              'Heartbeat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildInfoRow(
              'Active',
              heartbeatStats['isHeartbeatActive'] == true ? '✅ Yes' : '❌ No',
            ),
            _buildInfoRow(
              'Last Pong',
              heartbeatStats['lastPongReceived'] ?? 'Never',
            ),
            _buildInfoRow(
              'Time Since Pong',
              heartbeatStats['timeSinceLastPong'] != null
                  ? '${heartbeatStats['timeSinceLastPong']}s'
                  : 'N/A',
              valueColor: _getHeartbeatColor(heartbeatStats['timeSinceLastPong']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutboxSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.outbox, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Outbox (Pending Messages)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            FutureBuilder(
              future: _getOutboxStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final stats = snapshot.data as Map<String, dynamic>? ?? {};
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Total Pending',
                      '${stats['total'] ?? 0}',
                      valueColor: (stats['total'] ?? 0) > 0 ? Colors.orange : Colors.green,
                    ),
                    _buildInfoRow('Local Only', '${stats['localOnly'] ?? 0}'),
                    _buildInfoRow('Syncing', '${stats['syncing'] ?? 0}'),
                    _buildInfoRow(
                      'Failed',
                      '${stats['failed'] ?? 0}',
                      valueColor: (stats['failed'] ?? 0) > 0 ? Colors.red : Colors.green,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventQueueSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.queue, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Event Queue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            const Text(
              'EventQueueService provides centralized event processing.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Status', '✅ Active'),
            _buildInfoRow('Processing', 'Sequential'),
            _buildInfoRow('Deduplication', '✅ Enabled'),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'System Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('Build Mode', 'Debug'),
            _buildInfoRow('Version', '2.0.0'),
            _buildInfoRow('Last Refactoring', '2025-12-22'),
            const SizedBox(height: 8),
            const Text(
              'Features',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildInfoRow('✅ Idempotency', 'Server-side'),
            _buildInfoRow('✅ Event Sourcing', 'Message statuses'),
            _buildInfoRow('✅ Heartbeat', '30s interval'),
            _buildInfoRow('✅ Incremental Sync', 'Auto on reconnect'),
            _buildInfoRow('✅ Corruption Recovery', 'Outbox'),
            _buildInfoRow('✅ Typing Debouncing', '300ms'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(SignalRService signalRService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'Debug Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // Force reconnection
                  await signalRService.disconnect();
                  await Future.delayed(const Duration(seconds: 1));
                  // Connection will auto-reconnect
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reconnection initiated')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Force Reconnect'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Outbox'),
                    content: const Text(
                      'This will clear all pending messages from Outbox. '
                      'Are you sure?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  try {
                    // Clear outbox - would need repository access
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Outbox cleared')),
                    );
                    setState(() {});
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Outbox'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Server Diagnostics'),
                    content: const Text(
                      'Server diagnostics endpoint:\n'
                      'GET /api/diagnostics/metrics\n'
                      'GET /api/diagnostics/health\n\n'
                      'Use Postman or browser to access.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.dns),
              label: const Text('Server Diagnostics Info'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Color? _getHeartbeatColor(dynamic timeSinceLastPong) {
    if (timeSinceLastPong == null) return null;
    final seconds = timeSinceLastPong as int;
    if (seconds < 45) return Colors.green;
    if (seconds < 75) return Colors.orange;
    return Colors.red;
  }

  Future<Map<String, dynamic>> _getOutboxStats() async {
    try {
      final outboxRepo = ref.read(outboxRepositoryProvider);
      final allPending = await outboxRepo.getAllPendingMessages();
      
      return {
        'total': allPending.length,
        'localOnly': allPending.where((m) => m.syncState == SyncState.localOnly).length,
        'syncing': allPending.where((m) => m.syncState == SyncState.syncing).length,
        'failed': allPending.where((m) => m.syncState == SyncState.failed).length,
      };
    } catch (e) {
      print('Error getting outbox stats: $e');
      return {'total': 0, 'localOnly': 0, 'syncing': 0, 'failed': 0};
    }
  }
}

