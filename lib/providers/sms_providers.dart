import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_sms/models/sms_model.dart';
import 'package:share_sms/providers/auth_providers.dart';
import 'package:share_sms/services/sms_service.dart';

// Provider to check if the platform is supported for SMS features
final isSupportedPlatformProvider = Provider<bool>((ref) {
  // Only Android is fully supported, web is not supported for SMS
  return defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
});

// Provider for SmsService
final smsServiceProvider = Provider<SmsService?>((ref) {
  final currentUserId = ref.watch(currentUserIdProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  final isSupported = ref.watch(isSupportedPlatformProvider);
  
  // Only create SMS service on supported platforms and when user is logged in
  if (isSupported && currentUserId != null) {
    return SmsService(databaseService, currentUserId);
  }
  return null;
});

// Provider for platform check
final isAndroidPlatformProvider = Provider<bool>((ref) {
  return defaultTargetPlatform == TargetPlatform.android;
});

// Provider for SMS permission status
final smsPermissionStatusProvider = FutureProvider<PermissionStatus?>((ref) async {
  final smsService = ref.watch(smsServiceProvider);
  if (smsService != null) {
    return smsService.checkSmsPermission();
  }
  return null;
});

// Provider for SMS messages
final smsListProvider = FutureProvider<List<SmsModel>>((ref) async {
  final smsService = ref.watch(smsServiceProvider);
  if (smsService == null) {
    return [];
  }
  
  try {
    return await smsService.getSmsMessages();
  } catch (e) {
    // If permission not granted, return empty list
    return [];
  }
});

// Provider for SMS listener
final smsListenerProvider = StreamProvider<SmsModel?>((ref) {
  final smsService = ref.watch(smsServiceProvider);
  if (smsService == null) {
    return Stream.value(null);
  }
  
  return smsService.startSmsListener();
});

// Provider for requesting SMS permission
final requestSmsPermissionProvider = FutureProvider.autoDispose<PermissionStatus?>((ref) async {
  final smsService = ref.watch(smsServiceProvider);
  if (smsService == null) {
    return null;
  }
  
  return await smsService.requestSmsPermission();
});
