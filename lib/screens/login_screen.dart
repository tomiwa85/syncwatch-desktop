import 'package:flutter/material.dart';

import '../api.dart';
import '../app_services.dart';
import '../theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final AppServices services;
  const LoginScreen({super.key, required this.services});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  bool _isSignup = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = widget.services.api;
      final res = _isSignup
          ? await api.signup(_email.text.trim(), _password.text, _displayName.text.trim())
          : await api.login(_email.text.trim(), _password.text);
      widget.services.auth.setSession(res);
      widget.services.socket.connect(res.accessToken);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(services: widget.services)),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not reach the server. It may be waking up — try again in ~40s.\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('SyncWatch',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Sw.text)),
                const SizedBox(height: 4),
                Text(_isSignup ? 'Create your account' : 'Sign in to sync',
                    textAlign: TextAlign.center, style: const TextStyle(color: Sw.muted)),
                const SizedBox(height: 28),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                if (_isSignup) ...[
                  TextField(
                    controller: _displayName,
                    decoration: const InputDecoration(labelText: 'Display name'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _busy ? null : _submit(),
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Sw.danger, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isSignup ? 'Sign up' : 'Log in'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _isSignup = !_isSignup),
                  child: Text(_isSignup ? 'Have an account? Log in' : 'New here? Create an account',
                      style: const TextStyle(color: Sw.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
