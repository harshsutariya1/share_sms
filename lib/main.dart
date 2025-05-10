import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_sms/firebase_options.dart';
import 'package:share_sms/providers/auth_providers.dart';
import 'package:share_sms/screens/auth_screen.dart';
import 'package:share_sms/screens/main_screen.dart';
import 'package:share_sms/services/background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  await setup().then((_) {
    runApp(const ProviderScope(child: MyApp()));
  });
}

Future<void> setup() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseDatabase.instance.databaseURL =
      'https://share-it-3225d-default-rtdb.firebaseio.com';
      
  // Initialize and start background service immediately
  await BackgroundService.initialize();
  
  // Request SMS permissions early if on Android
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Permission.sms.request();
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Share SMS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: checkAuthState(ref),
    );
  }
}

Widget checkAuthState(WidgetRef ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.when(
    data: (user) {
      if (user != null) {
        return const MainScreen();
      }
      return const AuthScreen();
    },
    loading:
        () => const Scaffold(body: Center(child: CircularProgressIndicator())),
    error:
        (err, stack) =>
            Scaffold(body: Center(child: Text('Something went wrong: $err'))),
  );
}
