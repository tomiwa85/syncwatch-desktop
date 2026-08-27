import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app_services.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Required once before any media_kit Player is created.
  MediaKit.ensureInitialized();
  runApp(SyncWatchApp(services: AppServices.create()));
}

class SyncWatchApp extends StatelessWidget {
  final AppServices services;
  const SyncWatchApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SyncWatch',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: SplashScreen(services: services),
    );
  }
}
