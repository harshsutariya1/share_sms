import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_sms/screens/profile_screen.dart';
import 'package:share_sms/screens/recent_sms_screen.dart';
import 'package:share_sms/screens/shared_sms_screen.dart';

// Provider for the current tab index
final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
