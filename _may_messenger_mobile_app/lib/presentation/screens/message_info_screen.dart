import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/message_model.dart';
import '../../data/models/message_receipts_model.dart';
import '../providers/auth_provider.dart';

/// Screen showing detailed delivery/read status for a message in a group chat
/// Similar to WhatsApp's message info feature
class MessageInfoScreen extends ConsumerStatefulWidget {
  final Message message;
  final String chatTitle;
  
  const MessageInfoScreen({
    super.key,
    required this.message,
    required this.chatTitle,
  });
  
  @override
  ConsumerState<MessageInfoScreen> createState() => _MessageInfoScreenState();
}

class _MessageInfoScreenState extends ConsumerState<MessageInfoScreen> {
  MessageReceiptsResponse? _receipts;
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }
  
  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final apiDataSource = ref.read(apiDataSourceProvider);
      final receipts = await apiDataSource.getMessageReceipts(widget.message.id);
      
      if (mounted) {
        setState(() {
          _receipts = receipts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось загрузить информацию о сообщении';
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Информация о сообщении'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReceipts,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    
    if (_receipts == null) {
      return const Center(
        child: Text('Нет данных'),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadReceipts,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message preview card
            _buildMessagePreview(),
            const SizedBox(height: 24),
            
            // Summary stats
            _buildStatsSummary(),
            const SizedBox(height: 24),
            
            // Read by section
            if (_receipts!.receipts.any((r) => r.readAt != null)) ...[
              _buildSectionHeader(
                icon: Icons.done_all,
                color: Colors.blue,
                title: 'Прочитано',
                count: _receipts!.readCount,
              ),
              const SizedBox(height: 8),
              _buildReceiptsList(
                _receipts!.receipts.where((r) => r.readAt != null).toList(),
                showReadTime: true,
              ),
              const SizedBox(height: 20),
            ],
            
            // Delivered but not read section
            if (_receipts!.receipts.any((r) => r.deliveredAt != null && r.readAt == null)) ...[
              _buildSectionHeader(
                icon: Icons.done_all,
                color: Colors.grey,
                title: 'Доставлено',
                count: _receipts!.deliveredCount - _receipts!.readCount,
              ),
              const SizedBox(height: 8),
              _buildReceiptsList(
                _receipts!.receipts.where((r) => r.deliveredAt != null && r.readAt == null).toList(),
                showDeliveredTime: true,
              ),
              const SizedBox(height: 20),
            ],
            
            // Not delivered section
            if (_receipts!.receipts.any((r) => r.deliveredAt == null)) ...[
              _buildSectionHeader(
                icon: Icons.access_time,
                color: Colors.orange,
                title: 'Ожидает доставки',
                count: _receipts!.totalParticipants - _receipts!.deliveredCount,
              ),
              const SizedBox(height: 8),
              _buildReceiptsList(
                _receipts!.receipts.where((r) => r.deliveredAt == null).toList(),
              ),
            ],
            
            // Played section for audio messages
            if (widget.message.type == MessageType.audio && 
                _receipts!.receipts.any((r) => r.playedAt != null)) ...[
              const SizedBox(height: 20),
              _buildSectionHeader(
                icon: Icons.headphones,
                color: Colors.green,
                title: 'Прослушано',
                count: _receipts!.playedCount,
              ),
              const SizedBox(height: 8),
              _buildReceiptsList(
                _receipts!.receipts.where((r) => r.playedAt != null).toList(),
                showPlayedTime: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessagePreview() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chat info
            Row(
              children: [
                Icon(Icons.group, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.chatTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // Message content
            _buildMessageContent(),
            
            const SizedBox(height: 12),
            
            // Sent time
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(widget.message.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                _buildStatusIcon(widget.message.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessageContent() {
    switch (widget.message.type) {
      case MessageType.text:
        return Text(
          widget.message.content ?? '',
          style: const TextStyle(fontSize: 16),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        );
      case MessageType.audio:
        return Row(
          children: [
            Icon(Icons.mic, color: Colors.orange.shade400),
            const SizedBox(width: 8),
            const Text('Голосовое сообщение', style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        );
      case MessageType.image:
        return Row(
          children: [
            Icon(Icons.image, color: Colors.blue.shade400),
            const SizedBox(width: 8),
            const Text('Изображение', style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        );
      case MessageType.file:
        return Row(
          children: [
            Icon(Icons.attach_file, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              widget.message.content ?? 'Файл',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        );
      case MessageType.poll:
        return Row(
          children: [
            Icon(Icons.poll, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Text(
              widget.message.pollData?['question'] ?? 'Голосование',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        );
      case MessageType.video:
        return Row(
          children: [
            Icon(Icons.videocam, color: Colors.purple.shade400),
            const SizedBox(width: 8),
            const Text('Видео', style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        );
    }
  }
  
  Widget _buildStatusIcon(MessageStatus status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.grey;
        break;
      case MessageStatus.sent:
        icon = Icons.done;
        color = Colors.grey;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case MessageStatus.played:
        icon = Icons.done_all;
        color = Colors.green;
        break;
      case MessageStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
    }
    
    return Icon(icon, size: 18, color: color);
  }
  
  Widget _buildStatsSummary() {
    final receipts = _receipts!;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.people,
              label: 'Всего',
              count: receipts.totalParticipants,
              color: Colors.grey,
            ),
            _buildStatItem(
              icon: Icons.done_all,
              label: 'Доставлено',
              count: receipts.deliveredCount,
              color: Colors.grey.shade600,
            ),
            _buildStatItem(
              icon: Icons.done_all,
              label: 'Прочитано',
              count: receipts.readCount,
              color: Colors.blue,
            ),
            if (widget.message.type == MessageType.audio)
              _buildStatItem(
                icon: Icons.headphones,
                label: 'Прослушано',
                count: receipts.playedCount,
                color: Colors.green,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildReceiptsList(
    List<ParticipantReceipt> receipts, {
    bool showDeliveredTime = false,
    bool showReadTime = false,
    bool showPlayedTime = false,
  }) {
    return Column(
      children: receipts.map((receipt) {
        DateTime? timeToShow;
        String? timeLabel;
        
        if (showPlayedTime && receipt.playedAt != null) {
          timeToShow = receipt.playedAt;
          timeLabel = 'Прослушано';
        } else if (showReadTime && receipt.readAt != null) {
          timeToShow = receipt.readAt;
          timeLabel = 'Прочитано';
        } else if (showDeliveredTime && receipt.deliveredAt != null) {
          timeToShow = receipt.deliveredAt;
          timeLabel = 'Доставлено';
        }
        
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: receipt.userAvatar != null
                ? NetworkImage(receipt.userAvatar!)
                : null,
            child: receipt.userAvatar == null
                ? Text(
                    receipt.userName.isNotEmpty ? receipt.userName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Text(
            receipt.userName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: timeToShow != null
              ? Text(
                  '$timeLabel ${_formatTime(timeToShow)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                )
              : Text(
                  'Ожидает доставки',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade600,
                  ),
                ),
        );
      }).toList(),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return 'Сегодня в ${DateFormat('HH:mm').format(dateTime)}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Вчера в ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('d MMM в HH:mm', 'ru').format(dateTime);
    }
  }
  
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (date == today) {
      return 'в ${DateFormat('HH:mm').format(dateTime)}';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'вчера в ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('d.MM в HH:mm').format(dateTime);
    }
  }
}

