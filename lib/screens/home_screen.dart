import 'package:flutter/material.dart';

import '../api.dart';
import '../app_services.dart';
import '../protocol.dart';
import '../theme.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppServices services;
  const HomeScreen({super.key, required this.services});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _openRoom(RoomSummaryData room) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoomScreen(services: widget.services, room: room)),
    );
  }

  Future<void> _run(Future<RoomSummaryData> Function() action) async {
    setState(() => _busy = true);
    try {
      final room = await action();
      if (mounted) _openRoom(room);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.services.auth.user;
    return Scaffold(
      appBar: AppBar(title: const Text('SyncWatch')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Signed in as ${user?.displayName ?? "?"}',
                    style: const TextStyle(color: Sw.muted)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run(() => widget.services.api.createRoom()),
                  icon: const Icon(Icons.add),
                  label: const Text('Create a room'),
                ),
                const SizedBox(height: 24),
                const Divider(color: Sw.border),
                const SizedBox(height: 24),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Room code', hintText: 'e.g. ABC123'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || _code.text.trim().isEmpty
                      ? null
                      : () => _run(() => widget.services.api.joinRoom(_code.text.trim())),
                  icon: const Icon(Icons.login),
                  label: const Text('Join room'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tip: create a room here, then join the same code on your phone (or a '
                  'second desktop) to test that they sync.',
                  style: TextStyle(color: Sw.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
