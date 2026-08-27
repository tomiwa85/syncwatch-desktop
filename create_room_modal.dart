import 'package:flutter/material.dart';

import 'api.dart';
import 'protocol.dart';
import 'theme.dart';
import 'ui.dart';

/// Shows the "create a watch party" dialog. Returns the created room, or null.
Future<RoomSummaryData?> showCreateRoomModal(BuildContext context, ApiClient api) {
  return showDialog<RoomSummaryData>(
    context: context,
    builder: (ctx) {
      var visibility = 'PRIVATE';
      final password = TextEditingController();
      var creating = false;

      return StatefulBuilder(
        builder: (ctx, setState) {
          Widget option(String value, IconData icon, String title, String desc) {
            final active = visibility == value;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => visibility = value),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: active ? Sw.accent.withOpacity(0.12) : Sw.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? Sw.accent : Sw.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 36,
                        width: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? Sw.accent : Sw.surfaceRaised,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 18, color: active ? Colors.white : Sw.muted),
                      ),
                      const SizedBox(height: 10),
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Sw.text)),
                      const SizedBox(height: 2),
                      Text(desc, style: const TextStyle(fontSize: 11, color: Sw.muted)),
                    ],
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Sw.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Create a watch party', style: TextStyle(color: Sw.text)),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pick who can join. You can share the code either way.',
                      style: TextStyle(fontSize: 13, color: Sw.muted)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      option('PRIVATE', Icons.lock_outline, 'Private', 'Only people with the code'),
                      const SizedBox(width: 12),
                      option('PUBLIC', Icons.public, 'Public', 'Anyone can find & join'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwInput(label: 'Password (optional)', hint: 'Leave blank for no password', controller: password, obscure: true),
                ],
              ),
            ),
            actions: [
              SwButton(label: 'Cancel', variant: SwVariant.ghost, onPressed: creating ? null : () => Navigator.pop(ctx)),
              SwButton(
                label: 'Create room',
                variant: SwVariant.gradient,
                loading: creating,
                onPressed: creating
                    ? null
                    : () async {
                        setState(() => creating = true);
                        try {
                          final room = await api.createRoom(visibility: visibility, password: password.text.trim());
                          if (ctx.mounted) Navigator.pop(ctx, room);
                        } on ApiException catch (e) {
                          setState(() => creating = false);
                          if (ctx.mounted) swToast(ctx, 'Create failed', description: e.message, danger: true);
                        } catch (_) {
                          setState(() => creating = false);
                          if (ctx.mounted) swToast(ctx, 'Create failed', danger: true);
                        }
                      },
              ),
            ],
          );
        },
      );
    },
  );
}
