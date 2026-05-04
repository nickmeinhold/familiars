import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/auth_service.dart';

/// Sign-in entry point for the familiars app.
///
/// Both Apple and Google are offered. On iOS, Apple is presented first
/// because it's OS-native (works on the simulator with no extra config)
/// and Apple's review guidelines require it to be at-least-as-prominent
/// as third-party providers when the app supports those.
class LoginScreen extends StatefulWidget {
  final AuthService auth;
  const LoginScreen({super.key, required this.auth});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _runSignIn(Future<String?> Function() signIn) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final error = await signIn();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showApple = Platform.isIOS || Platform.isMacOS;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.auto_awesome,
                  size: 80, color: Colors.deepPurple),
              const SizedBox(height: 24),
              Text(
                'Familiars',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A board of bound agents',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (showApple) ...[
                SignInWithAppleButton(
                  onPressed: _isLoading
                      ? () {}
                      : () => _runSignIn(widget.auth.signInWithApple),
                  style: Theme.of(context).brightness == Brightness.dark
                      ? SignInWithAppleButtonStyle.white
                      : SignInWithAppleButtonStyle.black,
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _runSignIn(widget.auth.signInWithGoogle),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login, size: 24),
                label: const Text('Continue with Google'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
