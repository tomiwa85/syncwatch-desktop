import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../theme.dart';
import '../ui.dart';
import 'login_screen.dart';

const _lines = [
  'Warming things up…',
  'Connecting to your watch parties…',
  'Syncing up…',
  'Almost ready…',
];

class SplashScreen extends StatefulWidget {
  final AppServices services;
  const SplashScreen({super.key, required this.services});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int _line = 0;
  double _opacity = 0;
  Timer? _cycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _opacity = 1));
    _cycle = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() => _line = (_line + 1) % _lines.length);
    });
    Timer(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LoginScreen(services: widget.services)),
      );
    });
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sw.bg,
      body: Center(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SwLogo(size: 120),
              const SizedBox(height: 20),
              const SwWordmark(size: 26),
              const SizedBox(height: 36),
              SizedBox(
                width: 176,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: Sw.surfaceRaised,
                    valueColor: AlwaysStoppedAnimation(Sw.accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 16,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _lines[_line],
                    key: ValueKey(_line),
                    style: const TextStyle(fontSize: 12, color: Sw.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
