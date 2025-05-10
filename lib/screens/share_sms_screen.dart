import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_sms/models/sms_model.dart';
import 'package:share_sms/models/user_model.dart';
import 'package:share_sms/providers/sharing_providers.dart';

class ShareSmsScreen extends ConsumerStatefulWidget {
  final SmsModel? preSelectedSms;
  
  const ShareSmsScreen({super.key, this.preSelectedSms});

  @override
  ConsumerState<ShareSmsScreen> createState() => _ShareSmsScreenState();
}

class _ShareSmsScreenState extends ConsumerState<ShareSmsScreen> {
  String? _selectedUserId;
  late TextEditingController _addressController;
  late TextEditingController _bodyController;
  bool _isSharing = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.preSelectedSms?.address ?? '');
    _bodyController = TextEditingController(text: widget.preSelectedSms?.body ?? '');
  }

  @override
  void dispose() {
    _addressController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
  
  Future<void> _shareMessage() async {
    if (_selectedUserId == null) {
      setState(() {
        _errorMessage = 'Please select a user to share with';
      });
      return;
    }
    
    if (_bodyController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Message body cannot be empty';
      });
      return;
    }
    
    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });
    
    final sharingService = ref.read(sharingServiceProvider);
    
    try {
      if (sharingService != null) {
        await sharingService.shareMessageManually(
          _selectedUserId!,
          _addressController.text,
          _bodyController.text,
          widget.preSelectedSms?.date,
        );
        
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message shared successfully')),
          );
        }
      } else {
        setState(() {
          _isSharing = false;
          _errorMessage = 'Sharing service not available';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _errorMessage = 'Failed to share message: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableUsersAsync = ref.watch(availableUsersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share SMS'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a user to share this message with:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // User selection
            availableUsersAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return const Text('No users available to share with');
                }
                
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Share with',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedUserId,
                  items: users.map((user) {
                    return DropdownMenuItem<String>(
                      value: user.uid,
                      // Fix: Wrap the UserListItem with a SizedBox with fixed width
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 100,
                        child: _UserListItem(user),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserId = value;
                      _errorMessage = null;
                    });
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error loading users: $error'),
            ),
            
            const SizedBox(height: 24),
            const Text(
              'Message to share:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Message details form
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'From (phone number/sender)',
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Message content',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              
            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSharing ? null : _shareMessage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isSharing
                    ? const CircularProgressIndicator()
                    : const Text('Share Message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  final UserModel user;
  
  const _UserListItem(this.user);
  
  @override
  Widget build(BuildContext context) {
    // Fix: Restructure to avoid unbounded width for Row with Expanded
    return Row(
      mainAxisSize: MainAxisSize.min, // Add this to constrain the Row
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            user.username?.isNotEmpty == true
                ? user.username![0].toUpperCase()
                : user.email[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Fix: Use a fixed-width container instead of Expanded
        Flexible(
          child: Text(
            user.username ?? user.email,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        if (user.isOnline)
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}
