import 'package:flutter/material.dart';

import '../api.dart';
import '../app_services.dart';
import '../theme.dart';
import '../ui.dart';
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

  void _switchMode(bool signup) {
    setState(() {
      _isSignup = signup;
      _error = null;
      _password.clear();
    });
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
      setState(() => _error = 'Could not reach the server. It may be waking up — try again in ~40s.');
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
                // Brand
                const Center(child: SwLogo(size: 88)),
                const SizedBox(height: 14),
                const Center(child: SwWordmark(size: 24)),
                const SizedBox(height: 8),
                Text(
                  _isSignup ? 'Create your account to start watching together.' : 'Sign in to your watch parties.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Sw.muted, fontSize: 13),
                ),
                const SizedBox(height: 28),

                // Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Sw.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Sw.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _modeToggle(),
                      const SizedBox(height: 20),
                      if (_isSignup) ...[
                        SwInput(label: 'Display name', hint: 'Your name', controller: _displayName),
                        const SizedBox(height: 14),
                      ],
                      SwInput(
                        label: 'Email',
                        hint: 'you@example.com',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      SwInput(
                        label: 'Password',
                        hint: _isSignup ? 'At least 8 characters' : '••••••••',
                        controller: _password,
                        obscure: true,
                        onSubmitted: (_) => _busy ? null : _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Sw.danger, fontSize: 12)),
                      ],
                      const SizedBox(height: 20),
                      SwButton(
                        label: _isSignup ? 'Create account' : 'Sign in',
                        variant: SwVariant.gradient,
                        size: SwSize.lg,
                        fullWidth: true,
                        loading: _busy,
                        onPressed: _busy ? null : _submit,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_isSignup ? 'Already have an account?' : 'New to SyncWatch?',
                        style: const TextStyle(color: Sw.muted, fontSize: 13)),
                    TextButton(
                      onPressed: _busy ? null : () => _switchMode(!_isSignup),
                      child: Text(_isSignup ? 'Sign in' : 'Create one',
                          style: const TextStyle(color: Sw.accent, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeToggle() {
    Widget tab(String label, bool signup) {
      final active = _isSignup == signup;
      return Expanded(
        child: GestureDetector(
          onTap: () => _switchMode(signup),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Sw.surfaceRaised : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: active ? Sw.text : Sw.muted)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Sw.bg2, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [tab('Sign in', false), tab('Sign up', true)]),
    );
  }
}
