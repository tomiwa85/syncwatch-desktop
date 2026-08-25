import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Required once before any Player is created.
  MediaKit.ensureInitialized();
  runApp(const SyncWatchApp());
}

// SyncWatch brand palette (mirrors the desktop design tokens).
const _bg = Color(0xFF080B16);
const _bg2 = Color(0xFF0B0F1E);
const _surface = Color(0xFF101627);
const _accent = Color(0xFF7C6CFF);
const _muted = Color(0xFF97A1BD);
const _danger = Color(0xFFFF5D76);

class SyncWatchApp extends StatelessWidget {
  const SyncWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SyncWatch Desktop — Playback Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          surface: _surface,
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const PlayerPage(),
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  String? _fileName;
  String? _error;
  bool _hasOpened = false;

  @override
  void initState() {
    super.initState();
    // Surface libmpv errors (e.g. a codec it genuinely can't handle) in the UI.
    _player.stream.error.listen((e) {
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      // FileType.any so nothing gets filtered out — the whole point is to test
      // odd containers/codecs (.mkv, .ts, .m2ts, .avi, weird extensions).
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      final picked = result?.files.single;
      final path = picked?.path;
      if (path == null) return;
      setState(() {
        _fileName = picked!.name;
        _hasOpened = true;
      });
      await _player.open(Media(path));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _bg2,
        titleSpacing: 16,
        title: Row(
          children: [
            const Text(
              'SyncWatch',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _fileName ?? 'Playback test',
                style: const TextStyle(fontSize: 13, color: _muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Open video'),
            ),
          ),
        ],
      ),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _danger, size: 40),
            const SizedBox(height: 16),
            const Text(
              "This file couldn't be played",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: _pick, child: const Text('Try another file')),
          ],
        ),
      );
    }

    if (!_hasOpened) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_outlined, color: _muted, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Open any video to test playback',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'MKV, HEVC/H.265, AC3/DTS, 10-bit — throw the hard ones at it.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Open video'),
          ),
        ],
      );
    }

    // media_kit's Video widget ships built-in overlay controls on desktop:
    // play/pause, seek bar, volume, and fullscreen — enough to prove the concept.
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Video(controller: _controller),
    );
  }
}
