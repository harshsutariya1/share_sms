import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_sms/providers/auth_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  // Use TextEditingControllers for pre-filled and editable fields
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  var _enteredUsername = ''; // Username can remain as is or also use a controller

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: 'harsh@gmail.com');
    _passwordController = TextEditingController(text: 'password');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitAuthForm() {
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();

    if (!isValid) {
      return;
    }
    _formKey.currentState!.save(); // This will now update the local variables from controllers via onSaved

    final controller = ref.read(authScreenControllerProvider.notifier);
    final isLoginMode = ref.read(authScreenControllerProvider).isLoginMode;

    // Use the values from controllers, or the local variables updated by onSaved
    controller.submitAuthForm(
      email: _emailController.text, // Directly use controller text
      password: _passwordController.text, // Directly use controller text
      username: isLoginMode ? null : _enteredUsername,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authScreenState = ref.watch(authScreenControllerProvider);
    final authScreenController = ref.read(authScreenControllerProvider.notifier);

    ref.listen<AuthScreenState>(authScreenControllerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (!authScreenState.isLoginMode)
                        TextFormField(
                          key: const ValueKey('username'),
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          enableSuggestions: false,
                          validator: (value) {
                            if (value == null || value.trim().length < 4) {
                              return 'Please enter at least 4 characters.';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Username',
                          ),
                          onSaved: (value) {
                            _enteredUsername = value!;
                          },
                        ),
                      TextFormField(
                        key: const ValueKey('email'),
                        controller: _emailController, // Assign controller
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        enableSuggestions: false,
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty ||
                              !value.contains('@')) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                        ),
                        onSaved: (value) {
                          // This onSaved is optional if directly using controller.text in submit
                          // _enteredEmail = value!; 
                        },
                      ),
                      TextFormField(
                        key: const ValueKey('password'),
                        controller: _passwordController, // Assign controller
                        validator: (value) {
                          if (value == null || value.trim().length < 7) {
                            return 'Password must be at least 7 characters long.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        obscureText: true,
                        onSaved: (value) {
                          // This onSaved is optional if directly using controller.text in submit
                          // _enteredPassword = value!;
                        },
                      ),
                      const SizedBox(height: 12),
                      if (authScreenState.isLoading) const CircularProgressIndicator(),
                      if (!authScreenState.isLoading)
                        ElevatedButton(
                          onPressed: _submitAuthForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                          ),
                          child: Text(authScreenState.isLoginMode ? 'Login' : 'Signup'),
                        ),
                      if (!authScreenState.isLoading)
                        TextButton(
                          child: Text(
                            authScreenState.isLoginMode
                                ? 'Create new account'
                                : 'I already have an account',
                          ),
                          onPressed: () {
                            authScreenController.toggleFormType();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
