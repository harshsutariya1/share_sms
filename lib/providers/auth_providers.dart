import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_sms/models/user_model.dart';
import 'package:share_sms/services/auth_service.dart';
import 'package:share_sms/services/database_service.dart';

// Provider for FirebaseAuth instance
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

// Provider for FirebaseDatabase instance
final firebaseDatabaseProvider = Provider<DatabaseReference>((ref) {
  // Make sure the database instance has been configured properly
  final database = FirebaseDatabase.instance;
  if (database.databaseURL == null || database.databaseURL!.isEmpty) {
    // Fallback URL if not set in main.dart
    database.databaseURL =
        'https://share-it-3225d-default-rtdb.firebaseio.com'; // Replace with your actual URL
  }
  return database.ref();
});

// Provider for DatabaseService
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(ref.watch(firebaseDatabaseProvider));
});

// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(firebaseAuthProvider),
    ref.watch(databaseServiceProvider),
  );
});

// StreamProvider for auth state changes
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Provider for current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateChangesProvider).asData?.value?.uid;
});

// Provider for current user's details from database
final currentUserDetailsProvider = FutureProvider<UserModel?>((ref) async {
  final firebaseUser = ref.watch(authStateChangesProvider).asData?.value;
  if (firebaseUser != null) {
    return await ref.watch(authServiceProvider).getCurrentUserDetails();
  }
  return null;
});

// StateNotifier for AuthScreen UI state
class AuthScreenState {
  final bool isLoading;
  final bool isLoginMode;
  final String? errorMessage;

  AuthScreenState({
    this.isLoading = false,
    this.isLoginMode = true,
    this.errorMessage,
  });

  AuthScreenState copyWith({
    bool? isLoading,
    bool? isLoginMode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthScreenState(
      isLoading: isLoading ?? this.isLoading,
      isLoginMode: isLoginMode ?? this.isLoginMode,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthScreenController extends StateNotifier<AuthScreenState> {
  final AuthService _authService;

  AuthScreenController(this._authService) : super(AuthScreenState());

  void toggleFormType() {
    state = state.copyWith(isLoginMode: !state.isLoginMode, clearError: true);
  }

  Future<void> submitAuthForm({
    required String email,
    required String password,
    String? username,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (state.isLoginMode) {
        await _authService.signInWithEmailAndPassword(email, password);
      } else {
        if (username == null || username.trim().isEmpty) {
          throw Exception("Username is required for signup.");
        }
        await _authService.createUserWithEmailAndPassword(
          email: email,
          password: password,
          username: username,
        );
      }
      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? "Authentication failed.",
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final authScreenControllerProvider =
    StateNotifierProvider<AuthScreenController, AuthScreenState>((ref) {
      return AuthScreenController(ref.watch(authServiceProvider));
    });
