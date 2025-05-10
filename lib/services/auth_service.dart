import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:share_sms/models/user_model.dart';
import 'package:share_sms/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_sms/services/background_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final DatabaseService _databaseService;

  AuthService(this._firebaseAuth, this._databaseService);

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);
      
      // Update user's online status and last active time
      if (userCredential.user != null) {
        await _databaseService.updateUserStatus(userCredential.user!.uid, true);
        
        // Store user ID and database URL in shared preferences for background tasks
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_id', userCredential.user!.uid);
        await prefs.setString('firebase_db_url', 
            FirebaseDatabase.instance.databaseURL ?? '');
        
        // Only register background service on non-web platforms
        if (!kIsWeb) {
          await BackgroundService.registerPeriodicTask();
        }
      }
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final newUser = UserModel(
          uid: userCredential.user!.uid,
          email: email,
          username: username,
          isOnline: true,
        );
        await _databaseService.createUser(newUser);
      }
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        await _databaseService.updateUserStatus(currentUser.uid, false);
        
        // Clear user ID from shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('current_user_id');
        
        // Only stop background service on non-web platforms
        if (!kIsWeb) {
          await BackgroundService.stopService();
        }
      }
      await _firebaseAuth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUserDetails() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      return await _databaseService.getUserDetails(currentUser.uid);
    }
    return null;
  }
}
