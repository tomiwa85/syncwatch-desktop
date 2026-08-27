import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../app_services.dart';
import '../protocol.dart';
import '../room_sync.dart';
import '../theme.dart';

class RoomScreen extends StatefulWidget {
  final AppServices services;
  final RoomSummaryData room;
  const RoomScreen({super.key, required this.services, required this.room});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final RoomSync _sync;
  final _chat = TextEditingController();

  Player? _player;
  VideoController? _controller;
  String? _fileName;
  int? _fileSize;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double? _dragValue;

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _sync = RoomSync(
      socket: widget.services.socket.socket,
      roomCode: widget.room.code,
      myUserId: widget.services.auth.user!.id,
      initialRoom: widget.room,
    );
    _sync.addListener(_onSyncChanged);
  }

  void _onSyncChanged() {
    if (_sync.ended && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The host ended the room.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final f = result?.files.single;
    if (f == null || f.path == null) return;

    // Tear down any previous player.
    await _disposePlayer();

    final player = Player();
    final controller = VideoController(player);
    _subs.add(player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));

    await player.open(Media(f.path!), play: false);

    setState(() {
      _player = player;
      _controller = controller;
      _fileName = f.name;
      _fileSize = f.size;
    });

    // Drive playback through the engine and jump straight to the room's state.
    _sync.engine.setPlayer(MediaKitPlayerHandle(player));
    _sync.engine.applyAuthoritative(_sync.playback.currentTime, _sync.playback.isPlaying);
  }

  Future<void> _disposePlayer() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _sync.engine.setPlayer(null);
    await _player?.dispose();
    _player = null;
    _controller = null;
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    _disposePlayer();
    _sync.dispose();
    _chat.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final s = d.inSeconds % 60;
    final m = (d.inSeconds ~/ 60) % 60;
    final h = d.inSeconds ~/ 3600;
    final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
    return '${h > 0 ? '$h:' : ''}$mm:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room ${widget.room.code}'),
        actions: [
          if (_sync.iAmHost)
            TextButton(
              onPressed: () {
                _sync.endRoom();
                Navigator.of(context).pop();
              },
              child: const Text('End room', style: TextStyle(color: Sw.danger)),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _sync,
        builder: (context, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: _buildPlayerPane()),
              SizedBox(width: 300, child: _buildSidePane()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerPane() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: _controller != null
                  ? Video(controller: _controller!, controls: NoVideoControls)
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.movie_outlined, color: Sw.muted, size: 44),
                          const SizedBox(height: 12),
                          const Text('Open your copy of the video', style: TextStyle(color: Sw.muted)),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('Open video'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final isPlaying = _sync.playback.isPlaying;
    final canControl = _sync.canControl;
    final durMs = _duration.inMilliseconds.toDouble();
    final posMs = _position.inMilliseconds.toDouble().clamp(0.0, durMs == 0 ? 1.0 : durMs);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              iconSize: 34,
              color: Sw.text,
              onPressed: canControl
                  ? () => isPlaying ? _sync.engine.userPause() : _sync.engine.userPlay()
                  : null,
              icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
            ),
            Expanded(
              child: Slider(
                value: durMs == 0 ? 0.0 : (_dragValue ?? posMs),
                max: durMs == 0 ? 1.0 : durMs,
                onChanged: canControl && durMs > 0 ? (v) => setState(() => _dragValue = v) : null,
                onChangeEnd: canControl && durMs > 0
                    ? (v) {
                        _sync.engine.userSeek(v / 1000.0);
                        setState(() => _dragValue = null);
                      }
                    : null,
              ),
            ),
            Text('${_fmt(_position)} / ${_fmt(_duration)}',
                style: const TextStyle(color: Sw.muted, fontSize: 12)),
          ],
        ),
        if (!canControl)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Host controls playback', style: TextStyle(color: Sw.muted, fontSize: 12)),
          ),
        // File actions.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open, size: 16),
              label: Text(_fileName == null ? 'Open video' : 'Change file'),
            ),
            if (_sync.iAmHost && _fileName != null)
              OutlinedButton.icon(
                onPressed: () => _sync.setSource(VideoSourceData.local(_fileName!, _fileSize!)),
                icon: const Icon(Icons.movie_creation_outlined, size: 16),
                label: const Text('Set as room video'),
              ),
            if (_fileName != null)
              OutlinedButton.icon(
                onPressed: _sync.verifyPending ? null : () => _sync.verifyFile(_fileName!, _fileSize!),
                icon: Icon(
                  _sync.myVerified == true ? Icons.verified : Icons.rule,
                  size: 16,
                  color: _sync.myVerified == true ? Sw.success : null,
                ),
                label: Text(_sync.verifyPending
                    ? 'Verifying…'
                    : _sync.myVerified == true
                        ? 'File verified'
                        : 'Verify my file'),
              ),
          ],
        ),
        if (_sync.myVerified == false && _sync.verifyReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_sync.verifyReason!, style: const TextStyle(color: Sw.danger, fontSize: 12)),
            ),
          ),
      ],
    );
  }

  Widget _buildSidePane() {
    final room = _sync.room;
    return Container(
      color: Sw.bg2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status strip — the sync breadcrumb for the test.
          Container(
            padding: const EdgeInsets.all(12),
            color: Sw.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: _sync.connected ? Sw.success : Sw.danger),
                    const SizedBox(width: 6),
                    Text(_sync.connected ? 'Connected' : 'Disconnected',
                        style: const TextStyle(fontSize: 12, color: Sw.text)),
                    const Spacer(),
                    Text(_sync.iAmHost ? 'HOST' : 'MEMBER',
                        style: const TextStyle(fontSize: 11, color: Sw.muted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'server: ${_sync.playback.isPlaying ? "▶" : "❚❚"} ${_sync.playback.currentTime.toStringAsFixed(1)}s',
                  style: const TextStyle(fontSize: 11, color: Sw.muted),
                ),
                if (_sync.lastEvent != null)
                  Text('last: ${_sync.lastEvent}', style: const TextStyle(fontSize: 11, color: Sw.muted)),
              ],
            ),
          ),
          // Members.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text('Members (${room?.members.length ?? 0})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Sw.muted)),
          ),
          ...?room?.members.map((m) => ListTile(
                dense: true,
                leading: Icon(m.role == 'host' ? Icons.star : Icons.person,
                    size: 18, color: m.role == 'host' ? Sw.accent : Sw.muted),
                title: Text(m.displayName, style: const TextStyle(fontSize: 13)),
                trailing: m.fileVerified
                    ? const Icon(Icons.verified, size: 16, color: Sw.success)
                    : const Icon(Icons.remove, size: 16, color: Sw.muted),
              )),
          const Divider(color: Sw.border, height: 1),
          // Chat.
          Expanded(child: _buildChat()),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: _sync.messages
                .map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: Sw.text),
                          children: [
                            TextSpan(
                                text: '${m.displayName}: ',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Sw.accent)),
                            TextSpan(text: m.text),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chat,
                  decoration: const InputDecoration(hintText: 'Message…', isDense: true),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _send, icon: const Icon(Icons.send, color: Sw.accent)),
            ],
          ),
        ),
      ],
    );
  }

  void _send() {
    final t = _chat.text.trim();
    if (t.isEmpty) return;
    _sync.sendChat(t);
    _chat.clear();
  }
}
