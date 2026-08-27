import 'package:flutter/material.dart';

import '../app_services.dart';
import '../create_room_modal.dart';
import '../protocol.dart';
import '../theme.dart';
import '../top_bar.dart';
import '../ui.dart';
import 'room_screen.dart';

class MyRoomsScreen extends StatefulWidget {
  final AppServices services;
  const MyRoomsScreen({super.key, required this.services});

  @override
  State<MyRoomsScreen> createState() => _MyRoomsScreenState();
}

class _MyRoomsScreenState extends State<MyRoomsScreen> {
  List<RoomSummaryData>? _rooms;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final rooms = await widget.services.api.listMyRooms();
      if (mounted) setState(() => _rooms = rooms);
    } catch (_) {
      if (mounted) setState(() => _rooms = []);
    }
  }

  void _open(RoomSummaryData room) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(services: widget.services, room: room)));
  }

  Future<void> _create() async {
    final room = await showCreateRoomModal(context, widget.services.api);
    if (room != null && mounted) _open(room);
  }

  Future<void> _delete(RoomSummaryData room) async {
    final ok = await swConfirm(
      context,
      title: 'Delete this room?',
      description: "Room ${room.code} will be permanently deleted for everyone. This can't be undone.",
      confirmLabel: 'Delete room',
      danger: true,
    );
    if (!ok) return;
    final prev = _rooms;
    setState(() => _rooms = _rooms?.where((r) => r.code != room.code).toList());
    try {
      await widget.services.api.deleteRoom(room.code);
      if (mounted) swToast(context, 'Room deleted', success: true);
    } catch (_) {
      if (mounted) {
        setState(() => _rooms = prev);
        swToast(context, "Couldn't delete the room", danger: true);
      }
    }
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(children: [
                          Icon(Icons.grid_view_rounded, size: 22, color: Sw.text),
                          SizedBox(width: 8),
                          Text('My rooms', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Sw.text)),
                        ]),
                        SizedBox(height: 4),
                        Text("Rooms you're hosting — open, or delete them.", style: TextStyle(fontSize: 13, color: Sw.muted)),
                      ],
                    ),
                  ),
                  SwButton(label: 'New room', icon: Icons.add, variant: SwVariant.gradient, size: SwSize.sm, onPressed: _create),
                ],
              ),
              const SizedBox(height: 20),
              _body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final rooms = _rooms;
    if (rooms == null) {
      return const SwCard(child: Text('Loading your rooms…', style: TextStyle(color: Sw.muted, fontSize: 13)));
    }
    if (rooms.isEmpty) {
      return SwCard(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          children: [
            Container(
              height: 56,
              width: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Sw.accent.withOpacity(0.14), shape: BoxShape.circle),
              child: const Icon(Icons.grid_view_rounded, color: Sw.accent, size: 26),
            ),
            const SizedBox(height: 12),
            const Text("You're not hosting any rooms", style: TextStyle(fontWeight: FontWeight.w600, color: Sw.text)),
            const SizedBox(height: 2),
            const Text("Create one and it'll show up here.", style: TextStyle(fontSize: 13, color: Sw.muted)),
            const SizedBox(height: 16),
            SwButton(label: 'Create a room', icon: Icons.add, variant: SwVariant.gradient, size: SwSize.sm, onPressed: _create),
          ],
        ),
      );
    }
    return Column(children: rooms.map(_roomCard).toList());
  }

  Widget _roomCard(RoomSummaryData room) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(room.code, style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 2, color: Sw.text)),
                      const SizedBox(width: 8),
                      room.visibility == 'PUBLIC'
                          ? const SwBadge(label: 'Public', icon: Icons.public, tone: BadgeTone.accent)
                          : const SwBadge(label: 'Private', icon: Icons.lock_outline),
                      if (room.hasPassword) ...[
                        const SizedBox(width: 6),
                        const SwBadge(label: 'Password', icon: Icons.lock_outline),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${room.members.length} in the room', style: const TextStyle(fontSize: 12, color: Sw.muted)),
                ],
              ),
            ),
            SwButton(label: 'Open', icon: Icons.play_arrow_rounded, size: SwSize.sm, onPressed: () => _open(room)),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _delete(room),
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Sw.muted,
              tooltip: 'Delete room',
            ),
          ],
        ),
      ),
    );
  }
}
