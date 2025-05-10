import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_sms/providers/sms_providers.dart';
import 'package:share_sms/screens/profile_screen.dart';
import 'package:share_sms/screens/recent_sms_screen.dart';
import 'package:share_sms/screens/shared_sms_screen.dart';

// Provider for the current tab index
final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    
    // Initialize SMS listener after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSmsListener();
    });
  }
  
  void _initializeSmsListener() {
    final isSupported = ref.read(isSupportedPlatformProvider);
    
    if (isSupported) {
      final smsService = ref.read(smsServiceProvider);
      if (smsService != null) {
        // Start the SMS listener as soon as the app is launched
        print("Starting SMS listener from MainScreen");
        smsService.startSmsListener().listen((sms) {
          print("New SMS received: ${sms.address}");
          // Refresh SMS list whenever a new message is received
          ref.invalidate(smsListProvider);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: selectedTab,
        children: const [SharedSmsScreen(), RecentSmsScreen(), ProfileScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          ref.read(selectedTabProvider.notifier).state = index;
          
          // If navigating to the SMS tab, refresh the list
          if (index == 1) {
            ref.invalidate(smsListProvider);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.move_to_inbox), label: 'Received SMS'),
          NavigationDestination(icon: Icon(Icons.message), label: 'Recent SMS'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
