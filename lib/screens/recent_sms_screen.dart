import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_sms/models/sms_model.dart';
import 'package:share_sms/providers/sms_providers.dart';
import 'package:share_sms/screens/keyword_rule_screen.dart';
import 'package:share_sms/screens/share_sms_screen.dart';

class RecentSmsScreen extends ConsumerWidget {
  const RecentSmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAndroid = ref.watch(isAndroidPlatformProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent SMS'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (isAndroid)
            IconButton(
              icon: const Icon(Icons.rule),
              tooltip: 'Manage Keywords',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const KeywordRuleScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: isAndroid 
          ? const _AndroidSmsContent() 
          : const _NonAndroidContent(),
      floatingActionButton: isAndroid ? FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ShareSmsScreen(),
            ),
          );
        },
        child: const Icon(Icons.share),
      ) : null,
    );
  }
}

class _AndroidSmsContent extends ConsumerWidget {
  const _AndroidSmsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smsPermissionStatusAsync = ref.watch(smsPermissionStatusProvider);
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(smsPermissionStatusProvider);
        ref.invalidate(smsListProvider);
      },
      child: smsPermissionStatusAsync.when(
        data: (status) {
          if (status == null) {
            return const Center(
              child: Text('SMS service not available'),
            );
          }
          
          if (status.isGranted) {
            return _SmsListView();
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('SMS permission is required to view messages'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final status = await ref.read(requestSmsPermissionProvider.future);
                      if (status != null && status.isGranted) {
                        ref.invalidate(smsListProvider);
                      } else if (status != null && status.isPermanentlyDenied) {
                        openAppSettings();
                      }
                    },
                    child: const Text('Grant Permission'),
                  ),
                ],
              ),
            );
          }
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error checking permission: $error'),
        ),
      ),
    );
  }
}

class _SmsListView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smsListAsync = ref.watch(smsListProvider);
    
    // Subscribe to SMS listener to receive new messages
    ref.listen(smsListenerProvider, (previous, next) {
      if (next.asData?.value != null) {
        // A new SMS was received, refresh the list
        ref.invalidate(smsListProvider);
      }
    });
    
    return smsListAsync.when(
      data: (smsList) {
        if (smsList.isEmpty) {
          return const Center(
            child: Text('No SMS messages found'),
          );
        }
        
        return ListView.builder(
          itemCount: smsList.length,
          itemBuilder: (context, index) {
            final sms = smsList[index];
            return _SmsListItem(sms: sms);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Text('Error loading SMS: $error'),
      ),
    );
  }
}

class _SmsListItem extends StatelessWidget {
  final SmsModel sms;
  
  const _SmsListItem({required this.sms});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(sms.address != null && sms.address!.isNotEmpty 
              ? sms.address![0] 
              : '?'),
        ),
        title: Text(
          sms.address ?? 'Unknown Sender', 
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          sms.body ?? 'No content', 
          maxLines: 2, 
          overflow: TextOverflow.ellipsis,
        ),
        trailing: sms.date != null 
            ? Text(DateFormat('MMM d, hh:mm a').format(sms.date!)) 
            : null,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ShareSmsScreen(preSelectedSms: sms),
            ),
          );
        },
      ),
    );
  }
}

class _NonAndroidContent extends StatelessWidget {
  const _NonAndroidContent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_android, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'SMS features are only available on Android devices',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
