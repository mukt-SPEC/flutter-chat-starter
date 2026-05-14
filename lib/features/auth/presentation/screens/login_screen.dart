import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    await ref.read(authControllerProvider.notifier).signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _signUp() async {
    await ref.read(authControllerProvider.notifier).signUp(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final errorText = authState.hasError
        ? AuthController.toReadableError(authState.error!)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              enabled: !isLoading,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              enabled: !isLoading,
            ),
            const SizedBox(height: 16),
            if (errorText != null) ...[
              Text(
                errorText,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () {
                      if (_isLoginMode) {
                        _signIn();
                      } else {
                        _signUp();
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isLoginMode ? 'Sign in' : 'Sign up'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                      });
                    },
              child: Text(
                _isLoginMode
                    ? "Don't have an account? Sign up"
                    : 'Already have an account? Sign in',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
