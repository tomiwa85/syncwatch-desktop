import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../app_services.dart';
import '../create_room_modal.dart';
import '../protocol.dart';
import '../theme.dart';
import '../top_bar.dart';
import '../ui.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppServices services;
  const HomeScreen({super.key, required this.services});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _join = TextEditingController();
  final _search = TextEditingController();

  List<RoomSummaryData>? _public;
  RoomSummaryData? _lookup;
  Timer? _lookupTimer;
  bool _joining = false;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    _refreshPublic();
  }

  @override
  void dispose() {
    _join.dispose();
    _search.dispose();
    _lookupTimer?.cancel();
    super.dispose();
  }

  ApiClient get _api => widget.services.api;

  Future<void> _refreshPublic() async {
    setState(() => _public = null);
    try {
      final rooms = await _api.listPublicRooms();
      if (mounted) setState(() => _public = rooms);
    } catch (_) {
      if (mounted) setState(() => _public = []);
    }
  }

  void _onSearch(String value) {
    setState(() {});
    _lookupTimer?.cancel();
    final q = value.trim().toUpperCase();
    _lookup = null;
    if (q.length < 4 || (_public?.any((r) => r.code == q) ?? false)) return;
    _lookupTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final room = await _api.getRoom(q);
        if (mounted) setState(() => _lookup = room);
      } catch (_) {
        if (mounted) setState(() => _lookup = null);
      }
    });
  }

  void _openRoom(RoomSummaryData room) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(services: widget.services, room: room)));
  }

  Future<void> _handleJoin(String code, {String? password}) async {
    final clean = code.trim().toUpperCase();
    if (clean.length < 4) {
      setState(() => _joinError = 'Enter a valid room code');
      return;
    }
    setState(() {
      _joinError = null;
      _joining = true;
    });
    try {
      final room = await _api.joinRoom(clean, password: password);
      if (mounted) _openRoom(room);
    } on ApiException catch (e) {
      if (e.status == 403) {
        final pw = await _promptPassword(clean);
        if (pw != null) await _handleJoin(clean, password: pw);
      } else if (e.status == 404) {
        setState(() => _joinError = 'No room with that code');
      } else {
        if (mounted) swToast(context, 'Join failed', description: e.message, danger: true);
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<String?> _promptPassword(String code) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Sw.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Password-protected room', style: TextStyle(color: Sw.text)),
        content: SizedBox(
          width: 320,
          child: SwInput(label: 'Enter the password for $code', hint: '••••••••', controller: controller, obscure: true, autofocus: true),
        ),
        actions: [
          SwButton(label: 'Cancel', variant: SwVariant.ghost, onPressed: () => Navigator.pop(ctx)),
          SwButton(label: 'Join', variant: SwVariant.gradient, onPressed: () => Navigator.pop(ctx, controller.text)),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final room = await showCreateRoomModal(context, _api);
    if (room != null && mounted) _openRoom(room);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.services.auth.user?.displayName ?? '';
    return Scaffold(
      appBar: SwTopBar(services: widget.services),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Welcome back, ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Sw.text)),
                  GradientText(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Start a watch party or join one with a room code.', style: TextStyle(color: Sw.muted)),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, c) {
                final narrow = c.maxWidth < 560;
                final create = _createCard();
                final join = _joinCard();
                return narrow
                    ? Column(children: [create, const SizedBox(height: 16), join])
                    : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: create),
                        const SizedBox(width: 16),
                        Expanded(child: join),
                      ]);
              }),
              const SizedBox(height: 32),
              _browseSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createCard() {
    return SwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconTile(Icons.add),
          const SizedBox(height: 12),
          const Text('Create a room', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Sw.text)),
          const SizedBox(height: 2),
          const Text('Host a new watch party — public or private.', style: TextStyle(fontSize: 13, color: Sw.muted)),
          const SizedBox(height: 16),
          SwButton(label: 'Create a room', variant: SwVariant.gradient, fullWidth: true, onPressed: _create),
        ],
      ),
    );
  }

  Widget _joinCard() {
    return SwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconTile(Icons.group_outlined),
          const SizedBox(height: 12),
          const Text('Join a room', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Sw.text)),
          const SizedBox(height: 2),
          const Text('Enter a room code to watch with friends.', style: TextStyle(fontSize: 13, color: Sw.muted)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SwInput(
                  hint: 'Room code',
                  controller: _join,
                  error: _joinError,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) {
                    final up = v.toUpperCase();
                    if (up != v) {
                      _join.value = _join.value.copyWith(
                        text: up,
                        selection: TextSelection.collapsed(offset: up.length),
                      );
                    }
                  },
                  onSubmitted: (_) => _handleJoin(_join.text),
                ),
              ),
              const SizedBox(width: 8),
              SwButton(label: 'Join', variant: SwVariant.secondary, loading: _joining, onPressed: () => _handleJoin(_join.text)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconTile(IconData icon) {
    return Container(
      height: 44,
      width: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Sw.accent.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: Sw.accent, size: 22),
    );
  }

  Widget _browseSection() {
    final q = _search.text.trim().toUpperCase();
    final all = _public ?? [];
    final filtered = q.isEmpty
        ? all
        : all.where((r) => r.code.contains(q) || (r.title ?? '').toUpperCase().contains(q)).toList();
    final privateMatch =
        _lookup != null && !filtered.any((r) => r.code == _lookup!.code) ? _lookup : null;
    final results = [if (privateMatch != null) privateMatch, ...filtered];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.public, size: 18, color: Sw.text),
            const SizedBox(width: 8),
            const Text('Browse rooms', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Sw.text)),
            const Spacer(),
            SwButton(label: 'Refresh', variant: SwVariant.ghost, size: SwSize.sm, onPressed: _refreshPublic),
          ],
        ),
        const SizedBox(height: 12),
        SwInput(
          hint: 'Search by room ID or title…',
          controller: _search,
          textCapitalization: TextCapitalization.characters,
          onChanged: _onSearch,
        ),
        const SizedBox(height: 12),
        if (_public == null)
          const SwCard(child: Text('Loading rooms…', style: TextStyle(color: Sw.muted, fontSize: 13)))
        else if (results.isEmpty)
          SwCard(
            child: Row(
              children: [
                const Icon(Icons.movie_outlined, size: 18, color: Sw.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    q.isNotEmpty
                        ? 'No room matches "$q". Double-check the room ID.'
                        : 'No public rooms right now. Create one and make it public — or search a room ID.',
                    style: const TextStyle(color: Sw.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          Column(children: results.map(_roomCard).toList()),
      ],
    );
  }

  Widget _roomCard(RoomSummaryData room) {
    final host = room.members.where((m) => m.role == 'host').map((m) => m.displayName).firstOrNull ?? 'someone';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwCard(
        child: Row(
          children: [
            _avatarRow(room.members),
            const SizedBox(width: 12),
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
                  Text('${room.members.length} watching · hosted by $host',
                      style: const TextStyle(fontSize: 12, color: Sw.muted)),
                ],
              ),
            ),
            SwButton(label: 'Join', size: SwSize.sm, loading: _joining, onPressed: () => _handleJoin(room.code)),
          ],
        ),
      ),
    );
  }

  Widget _avatarRow(List<RoomMemberData> members) {
    if (members.isEmpty) {
      return Container(
        height: 28,
        width: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Sw.surfaceRaised, shape: BoxShape.circle),
        child: const Icon(Icons.movie_outlined, size: 14, color: Sw.muted),
      );
    }
    final shown = members.take(3).toList();
    return SizedBox(
      height: 28,
      width: 28.0 + (shown.length - 1) * 18,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 18.0,
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Sw.surface),
                padding: const EdgeInsets.all(1.5),
                child: SwAvatar(name: shown[i].displayName, size: 25),
              ),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
