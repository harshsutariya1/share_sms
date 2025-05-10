import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_sms/models/shared_sms_model.dart';
import 'package:share_sms/providers/sharing_providers.dart';
import 'package:share_sms/screens/outgoing_shared_messages_screen.dart';

class SharedSmsScreen extends ConsumerWidget {
  const SharedSmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingMessagesAsync = ref.watch(incomingSharedMessagesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Messages'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Add button to navigate to outgoing messages
          IconButton(
            icon: const Icon(Icons.outgoing_mail),
            tooltip: 'Messages You\'ve Shared',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OutgoingSharedMessagesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force refresh
          ref.invalidate(incomingSharedMessagesProvider);
        },
        child: incomingMessagesAsync.when(
          data: (messages) {
            if (messages.isEmpty) {
              return const Center(
                child: Text('No shared messages yet'),
              );
            }
            
            return ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return _SharedMessageItem(message: message);
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stack) => Center(
            child: Text('Error loading shared messages: $error'),
          ),
        ),
      ),
    );
  }
}

class _SharedMessageItem extends ConsumerWidget {
  final SharedSmsModel message;
  
  const _SharedMessageItem({required this.message});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mark message as read when viewed
    if (!message.isRead) {
      final sharingService = ref.read(sharingServiceProvider);
      if (sharingService != null) {
        sharingService.markMessageAsRead(message.id);
      }
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: !message.isRead
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'From: ${message.senderUserName ?? message.senderName ?? "Unknown"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (message.keywordMatched != null)
                  Chip(
                    label: Text(message.keywordMatched!),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Original sender: ${message.address ?? "Unknown"}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message.body ?? 'No content',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Original: ${message.originalDate != null ? DateFormat('MMM d, HH:mm').format(message.originalDate!) : "Unknown"}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Shared: ${DateFormat('MMM d, HH:mm').format(message.sharedDate)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
