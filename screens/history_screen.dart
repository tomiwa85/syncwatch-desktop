import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../protocol.dart';
import '../theme.dart';
import '../top_bar.dart';
import '../ui.dart';

class HistoryScreen extends StatefulWidget {
  final AppServices services;
  const HistoryScreen({super.key, required this.services});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<WatchHistoryEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.services.api.getHistory();
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      if (mounted) setState(() => _entries = []);
    }
  }

  String _formatWhen(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $h:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _delete(WatchHistoryEntry e) async {
    final ok = await swConfirm(
      context,
      title: 'Remove from history?',
      description: '"${e.title ?? 'Room ${e.roomCode}'}" will be removed from your history. This only affects your view.',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (!ok) return;
    final prev = _entries;
    setState(() => _entries = _entries?.where((x) => !(x.roomCode == e.roomCode && x.endedAt == e.endedAt)).toList());
    try {
      await widget.services.api.deleteHistoryEntry(e.roomCode);
    } catch (_) {
      if (mounted) {
        setState(() => _entries = prev);
        swToast(context, "Couldn't remove that item", danger: true);
      }
    }
  }

  // Glassmorphic slide-up: everyone who watched this room.
  void _showWatchers(WatchHistoryEntry e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final count = e.coWatchers.length;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
              decoration: BoxDecoration(
                color: Sw.surface.withOpacity(0.82),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.06), Colors.transparent],
                  stops: const [0, 0.4],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.group_outlined, size: 18, color: Sw.text),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.title ?? 'Room ${e.roomCode}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Sw.text),
                          ),
                        ),
                        Text('$count ${count == 1 ? 'person' : 'people'}',
                            style: const TextStyle(fontSize: 12, color: Sw.muted)),
                      ],
                    ),
                  ),
                  Flexible(
                    child: count == 0
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Text('You watched this one solo.', style: TextStyle(color: Sw.muted)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                            itemCount: e.coWatchers.length,
                            itemBuilder: (_, i) {
                              final c = e.coWatchers[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                child: Row(
                                  children: [
                                    SwAvatar(name: c.displayName, size: 36),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(c.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w500, color: Sw.text)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SwTopBar(services: widget.services),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            children: [
              const Text('Watch history', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Sw.text)),
              const SizedBox(height: 4),
              const Text("Movies you've watched and who you watched them with.",
                  style: TextStyle(fontSize: 13, color: Sw.muted)),
              const SizedBox(height: 20),
              _body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final entries = _entries;
    if (entries == null) {
      return const SwCard(child: Text('Loading your history…', style: TextStyle(color: Sw.muted, fontSize: 13)));
    }
    if (entries.isEmpty) {
      return SwCard(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          children: [
            Container(
              height: 56,
              width: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Sw.accent.withOpacity(0.14), shape: BoxShape.circle),
              child: const Icon(Icons.movie_outlined, color: Sw.accent, size: 26),
            ),
            const SizedBox(height: 12),
            const Text('No watch parties yet', style: TextStyle(fontWeight: FontWeight.w600, color: Sw.text)),
            const SizedBox(height: 2),
            const Text("Once a room ends, it'll show up here.", style: TextStyle(fontSize: 13, color: Sw.muted)),
          ],
        ),
      );
    }
    return Column(children: entries.map(_entryCard).toList());
  }

  Widget _entryCard(WatchHistoryEntry e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showWatchers(e),
          child: SwCard(
            child: Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Sw.accent.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.movie_outlined, color: Sw.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title ?? 'Room ${e.roomCode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Sw.text)),
                      const SizedBox(height: 2),
                      Text(_formatWhen(e.endedAt), style: const TextStyle(fontSize: 12, color: Sw.muted)),
                    ],
                  ),
                ),
                if (e.coWatchers.isEmpty)
                  const Text('watched solo', style: TextStyle(fontSize: 12, color: Sw.muted))
                else
                  Row(
                    children: [
                      for (final c in e.coWatchers.take(3))
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: SwAvatar(name: c.displayName, size: 26),
                        ),
                      const SizedBox(width: 6),
                      Text('${e.coWatchers.length}', style: const TextStyle(fontSize: 12, color: Sw.muted)),
                    ],
                  ),
                IconButton(
                  onPressed: () => _delete(e),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Sw.muted,
                  tooltip: 'Remove from history',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
