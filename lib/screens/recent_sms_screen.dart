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
    final isSupported = ref.watch(isSupportedPlatformProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent SMS'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (isSupported)
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
      body: isSupported 
          ? const _AndroidSmsContent() 
          : const _UnsupportedPlatformContent(),
      floatingActionButton: isSupported ? FloatingActionButton(
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
            return const _SmsListView();
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

class _SmsListView extends ConsumerStatefulWidget {
  const _SmsListView();

  @override
  ConsumerState<_SmsListView> createState() => _SmsListViewState();
}

class _SmsListViewState extends ConsumerState<_SmsListView> {
  @override
  void initState() {
    super.initState();
    
    // Use a post-frame callback to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSmsListener();
    });
  }
  
  void _initSmsListener() {
    final smsService = ref.read(smsServiceProvider);
    if (smsService != null) {
      smsService.startSmsListener().listen((sms) {
        if (mounted) {
          // Safely invalidate the provider after checking if widget is still mounted
          ref.invalidate(smsListProvider);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final smsListAsync = ref.watch(smsListProvider);
    
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

class _UnsupportedPlatformContent extends StatelessWidget {
  const _UnsupportedPlatformContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'SMS features are not available on this platform',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please use an Android device for full functionality',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
