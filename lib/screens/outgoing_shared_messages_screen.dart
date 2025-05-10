import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_sms/models/shared_sms_model.dart';
import 'package:share_sms/providers/auth_providers.dart';
import 'package:share_sms/providers/sharing_providers.dart';

class OutgoingSharedMessagesScreen extends ConsumerWidget {
  const OutgoingSharedMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outgoingMessagesAsync = ref.watch(outgoingSharedMessagesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages You\'ve Shared'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force refresh
          ref.invalidate(outgoingSharedMessagesProvider);
        },
        child: outgoingMessagesAsync.when(
          data: (messages) {
            if (messages.isEmpty) {
              return const Center(
                child: Text('You haven\'t shared any messages yet'),
              );
            }
            
            return ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return _OutgoingSharedMessageItem(message: message);
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

class _OutgoingSharedMessageItem extends ConsumerWidget {
  final SharedSmsModel message;
  
  const _OutgoingSharedMessageItem({required this.message});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<String>(
                    future: _getReceiverName(ref, message.receiverId),
                    builder: (context, snapshot) {
                      return Text(
                        'Shared with: ${snapshot.data ?? "Loading..."}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      );
                    },
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
  
  Future<String> _getReceiverName(WidgetRef ref, String receiverId) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final receiverDetails = await databaseService.getUserDetails(receiverId);
      return receiverDetails?.username ?? receiverId;
    } catch (e) {
      return "Unknown";
    }
  }
}
