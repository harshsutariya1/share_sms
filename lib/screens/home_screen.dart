import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_sms/providers/auth_providers.dart';
import 'package:share_sms/providers/sms_providers.dart'; 
import 'package:share_sms/screens/profile_screen.dart'; 

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.title});
  final String title;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isAndroid = false;

  Future<void> _checkAndRequestSmsPermission() async {
    final smsService = ref.read(smsServiceProvider);
    PermissionStatus status = await smsService!.checkSmsPermission();
    if (status.isDenied) {
      status = await smsService.requestSmsPermission();
    }
    if (status.isGranted) {
      ref.invalidate(smsListProvider); // Refresh SMS list after getting permission
      ref.invalidate(smsPermissionStatusProvider); // Refresh permission status
    } else if (status.isPermanentlyDenied) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS permission permanently denied. Please enable it in app settings.')),
            );
            openAppSettings(); // From permission_handler
        }
    } else {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS permission denied.')),
            );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    _isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final authService = ref.watch(authServiceProvider);
    final userDetailsAsyncValue = ref.watch(currentUserDetailsProvider);
    final smsPermissionStatusAsync = _isAndroid ? ref.watch(smsPermissionStatusProvider) : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              authService.signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_isAndroid) {
            final smsService = ref.read(smsServiceProvider);
            final status = await smsService?.checkSmsPermission();
            if (status!.isGranted) {
                 ref.invalidate(smsListProvider);
            } else {
                _checkAndRequestSmsPermission();
            }
          }
          ref.invalidate(currentUserDetailsProvider);
        },
        child: ListView( // Changed to ListView to accommodate multiple sections
          padding: const EdgeInsets.all(16.0),
          children: [
            // User Details Section
            userDetailsAsyncValue.when(
              data: (userModel) {
                if (userModel != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Welcome, ${userModel.username ?? userModel.email}!',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }
                final firebaseUser = ref.watch(authStateChangesProvider).asData?.value;
                if (firebaseUser != null) {
                  return Text(
                    'Welcome, ${firebaseUser.email ?? "User"}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  );
                }
                return const Text('User details not found.');
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error: ${error.toString()}'),
            ),
            const SizedBox(height: 24),

            // SMS Section (Android only)
            if (_isAndroid) ...[
              const Text("Recent SMS Messages", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              smsPermissionStatusAsync?.when(
                data: (status) {
                  if (status!.isGranted) {
                    final smsListAsyncValue = ref.watch(smsListProvider);
                    return smsListAsyncValue.when(
                      data: (smsList) {
                        if (smsList.isEmpty) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Text('No SMS messages found.'),
                          ));
                        }
                        return Column( // Wrap ListView.builder in a Column or use shrinkWrap + physics
                          children: List.generate(smsList.take(5).length, (index) { // Show top 5 or less
                              final sms = smsList[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4.0),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(sms.address != null && sms.address!.isNotEmpty ? sms.address![0] : '?'),
                                  ),
                                  title: Text(sms.address ?? 'Unknown Sender', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(sms.body ?? 'No content', maxLines: 2, overflow: TextOverflow.ellipsis),
                                  trailing: sms.date != null ? Text(DateFormat('MMM d, hh:mm a').format(sms.date!), style: Theme.of(context).textTheme.bodySmall) : null,
                                ),
                              );
                            }
                          ),
                        );
                      },
                      loading: () => const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: CircularProgressIndicator(),
                      )),
                      error: (err, stack) => Center(child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Text('Error loading SMS: ${err.toString()}'),
                      )),
                    );
                  } else {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.sms_failed_outlined),
                          label: const Text('Grant SMS Permission'),
                          onPressed: _checkAndRequestSmsPermission,
                        ),
                      ),
                    );
                  }
                },
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(),
                )),
                error: (err, stack) => Center(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('Error checking SMS permission: ${err.toString()}'),
                )),
              ) ?? const SizedBox.shrink(), // Fallback for when smsPermissionStatusAsync is null
            ] else ...[
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Text('SMS viewing is only available on Android.'),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
