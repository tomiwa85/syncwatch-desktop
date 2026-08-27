import 'package:flutter/material.dart';

import 'app_services.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'screens/my_rooms_screen.dart';
import 'theme.dart';
import 'ui.dart';

class SwTopBar extends StatelessWidget implements PreferredSizeWidget {
  final AppServices services;
  const SwTopBar({super.key, required this.services});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  void _goLobby(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

  Future<void> _signOut(BuildContext context) async {
    final ok = await swConfirm(
      context,
      title: 'Sign out?',
      description: "You'll need to sign in again to rejoin your watch parties.",
      confirmLabel: 'Sign out',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    services.auth.clear();
    services.socket.dispose();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(services: services)),
      (r) => false,
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        var deleting = false;
        return StatefulBuilder(
          builder: (ctx, setState) {
            final canDelete = controller.text.trim().toUpperCase() == 'DELETE' && !deleting;
            return AlertDialog(
              backgroundColor: Sw.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Delete your account?', style: TextStyle(color: Sw.text)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This permanently erases your account and everything tied to it — your rooms, '
                    'memberships, and watch history. This cannot be undone.',
                    style: TextStyle(color: Sw.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SwInput(
                    label: 'Type "DELETE" to confirm',
                    hint: 'DELETE',
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              actions: [
                SwButton(label: 'Cancel', variant: SwVariant.ghost, onPressed: deleting ? null : () => Navigator.pop(ctx, false)),
                SwButton(
                  label: 'Delete account',
                  variant: SwVariant.danger,
                  loading: deleting,
                  onPressed: !canDelete
                      ? null
                      : () async {
                          setState(() => deleting = true);
                          try {
                            await services.api.deleteAccount();
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (_) {
                            setState(() => deleting = false);
                            if (ctx.mounted) swToast(ctx, "Couldn't delete your account", danger: true);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && context.mounted) {
      services.auth.clear();
      services.socket.dispose();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(services: services)),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = services.auth.user?.displayName ?? 'Account';
    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 20,
      title: InkWell(
        onTap: () => _goLobby(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SwLogo(size: 30),
              SizedBox(width: 10),
              SwWordmark(size: 20),
            ],
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          color: Sw.surfaceRaised,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          offset: const Offset(0, 48),
          onSelected: (v) {
            switch (v) {
              case 'rooms':
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyRoomsScreen(services: services)));
                break;
              case 'history':
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => HistoryScreen(services: services)));
                break;
              case 'signout':
                _signOut(context);
                break;
              case 'delete':
                _deleteAccount(context);
                break;
            }
          },
          itemBuilder: (_) => [
            _item('rooms', Icons.grid_view_rounded, 'My rooms'),
            _item('history', Icons.movie_outlined, 'Watch history'),
            const PopupMenuDivider(),
            _item('signout', Icons.logout, 'Sign out', danger: true),
            _item('delete', Icons.delete_outline, 'Delete account', danger: true),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(color: Sw.muted, fontSize: 13)),
                const SizedBox(width: 8),
                SwAvatar(name: name, size: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label, {bool danger = false}) {
    final color = danger ? Sw.danger : Sw.text;
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }
}
