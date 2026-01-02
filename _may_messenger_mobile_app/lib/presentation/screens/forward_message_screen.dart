import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chats_provider.dart';
import '../providers/contacts_names_provider.dart';
import '../../data/models/message_model.dart';
import '../../data/models/chat_model.dart';

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
                    final isGroup = chat.type == ChatType.group;
                    
                    // Get display name for the chat
                    String displayName = chat.title;
                    if (!isGroup && chat.otherParticipantId != null) {
                      // For private chats, show the other participant's name
                      displayName = contactsNames[chat.otherParticipantId] ?? displayName;
                    }
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: isGroup
                            ? const Icon(Icons.group, color: Colors.white)
                            : Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                      ),
                      title: Text(displayName),
                      subtitle: isGroup
                          ? const Text('Групповой чат')
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

