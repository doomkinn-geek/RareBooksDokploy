import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chats_provider.dart';
import '../providers/contacts_names_provider.dart';
import '../../data/models/message_model.dart';

/// Screen to select a chat for forwarding a message
class ForwardMessageScreen extends ConsumerWidget {
  final Message message;

  const ForwardMessageScreen({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsState = ref.watch(chatsProvider);
    final contactsNames = ref.watch(contactsNamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Переслать в...'),
      ),
      body: chatsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : chatsState.chats.isEmpty
              ? const Center(
                  child: Text('Нет доступных чатов'),
                )
              : ListView.builder(
                  itemCount: chatsState.chats.length,
                  itemBuilder: (context, index) {
                    final chat = chatsState.chats[index];
                    
                    // Get display name for the chat
                    String displayName = chat.name ?? 'Чат';
                    if (!chat.isGroup) {
                      // For private chats, show the other participant's name
                      final otherParticipantId = chat.participants
                          .firstWhere((p) => p != chat.name, orElse: () => chat.name ?? 'Unknown');
                      displayName = contactsNames[otherParticipantId] ?? displayName;
                    }
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: chat.isGroup
                            ? const Icon(Icons.group, color: Colors.white)
                            : Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                      ),
                      title: Text(displayName),
                      subtitle: chat.isGroup
                          ? Text('${chat.participants.length} участников')
                          : null,
                      onTap: () {
                        // Return selected chat ID
                        Navigator.of(context).pop(chat.id);
                      },
                    );
                  },
                ),
    );
  }
}

