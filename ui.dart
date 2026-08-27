import 'package:flutter/material.dart';

import 'theme.dart';

// ---------------------------------------------------------------------------
// Brand marks
// ---------------------------------------------------------------------------

/// Rounded gradient tile with a play glyph — stands in for the SyncWatch logo.
class SwLogo extends StatelessWidget {
  final double size;
  const SwLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: Sw.gradient,
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [BoxShadow(color: Sw.accent.withOpacity(0.45), blurRadius: size * 0.4, offset: Offset(0, size * 0.12))],
      ),
      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: size * 0.6),
    );
  }
}

class SwWordmark extends StatelessWidget {
  final double size;
  const SwWordmark({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Text(
      'SyncWatch',
      style: TextStyle(fontSize: size, fontWeight: FontWeight.bold, letterSpacing: -0.3, color: Sw.text),
    );
  }
}

/// Text painted with the brand gradient.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const GradientText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (b) => Sw.gradient.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

enum SwVariant { primary, gradient, secondary, ghost, danger }

enum SwSize { sm, md, lg }

class SwButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final SwVariant variant;
  final SwSize size;
  final bool fullWidth;
  final bool loading;

  const SwButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = SwVariant.primary,
    this.size = SwSize.md,
    this.fullWidth = false,
    this.loading = false,
  });

  double get _height => switch (size) { SwSize.sm => 32, SwSize.md => 40, SwSize.lg => 48 };
  double get _padX => switch (size) { SwSize.sm => 12, SwSize.md => 16, SwSize.lg => 24 };
  double get _fontSize => switch (size) { SwSize.sm => 13, SwSize.md => 14, SwSize.lg => 16 };

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;

    Color fg;
    BoxDecoration deco;
    switch (variant) {
      case SwVariant.gradient:
        fg = Colors.white;
        deco = BoxDecoration(
          gradient: Sw.gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Sw.accent.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 6))],
        );
        break;
      case SwVariant.secondary:
        fg = Sw.text;
        deco = BoxDecoration(
          color: Sw.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Sw.border),
        );
        break;
      case SwVariant.ghost:
        fg = Sw.muted;
        deco = BoxDecoration(borderRadius: BorderRadius.circular(12));
        break;
      case SwVariant.danger:
        fg = Colors.white;
        deco = BoxDecoration(color: Sw.danger, borderRadius: BorderRadius.circular(12));
        break;
      case SwVariant.primary:
        fg = Colors.white;
        deco = BoxDecoration(color: Sw.accent, borderRadius: BorderRadius.circular(12));
        break;
    }

    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: _fontSize,
            height: _fontSize,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(fg)),
          )
        else if (icon != null)
          Icon(icon, size: _fontSize + 3, color: fg),
        if ((icon != null || loading)) const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w600, color: fg)),
      ],
    );

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : onPressed,
          child: Ink(
            decoration: deco,
            child: Container(
              height: _height,
              width: fullWidth ? double.infinity : null,
              padding: EdgeInsets.symmetric(horizontal: _padX),
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

class SwCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SwCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Sw.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Sw.border),
      ),
      child: child,
    );
  }
}

enum BadgeTone { neutral, accent, success, danger }

class SwBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final BadgeTone tone;
  const SwBadge({super.key, required this.label, this.icon, this.tone = BadgeTone.neutral});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.accent => (Sw.accent.withOpacity(0.16), Sw.accent),
      BadgeTone.success => (Sw.success.withOpacity(0.16), Sw.success),
      BadgeTone.danger => (Sw.danger.withOpacity(0.16), Sw.danger),
      BadgeTone.neutral => (Sw.surfaceRaised, Sw.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class SwAvatar extends StatelessWidget {
  final String name;
  final double size;
  const SwAvatar({super.key, required this.name, this.size = 36});

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    return parts.map((w) => w[0].toUpperCase()).join();
  }

  static double _hue(String name) {
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = c + ((hash << 5) - hash);
    }
    return (hash.abs() % 360).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final h = _hue(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, h, 0.7, 0.55).toColor(),
            HSLColor.fromAHSL(1, (h + 40) % 360, 0.7, 0.45).toColor(),
          ],
        ),
      ),
      child: Text(
        _initials(name),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * 0.4),
      ),
    );
  }
}

class SwInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final String? error;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  const SwInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscure = false,
    this.error,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Sw.muted)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          textCapitalization: textCapitalization,
          style: const TextStyle(color: Sw.text),
          decoration: InputDecoration(hintText: hint, isDense: true),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: const TextStyle(fontSize: 12, color: Sw.danger)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Feedback helpers
// ---------------------------------------------------------------------------

void swToast(BuildContext context, String title, {String? description, bool danger = false, bool success = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: danger ? Sw.danger : (success ? Sw.success : Sw.surfaceRaised),
    content: Text(
      description != null ? '$title — $description' : title,
      style: TextStyle(color: danger || success ? Colors.white : Sw.text),
    ),
  ));
}

Future<bool> swConfirm(
  BuildContext context, {
  required String title,
  String? description,
  String confirmLabel = 'Confirm',
  bool danger = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Sw.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: const TextStyle(color: Sw.text)),
      content: description == null ? null : Text(description, style: const TextStyle(color: Sw.muted)),
      actions: [
        SwButton(label: 'Cancel', variant: SwVariant.ghost, onPressed: () => Navigator.pop(ctx, false)),
        SwButton(
          label: confirmLabel,
          variant: danger ? SwVariant.danger : SwVariant.gradient,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return res ?? false;
}
