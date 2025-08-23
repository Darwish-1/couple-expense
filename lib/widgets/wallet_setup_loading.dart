import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Call `showWalletSetupDialog(context)` while signing in or preparing data,
/// then `Navigator.of(context, rootNavigator: true).pop()` when you’re done.
Future<void> showWalletSetupDialog(BuildContext context, {String? label}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: WalletSetupLoading(),
    ),
  );
}

class WalletSetupLoading extends StatefulWidget {
  const WalletSetupLoading({
    super.key,
    this.size = 180,
    this.label = 'Setting up your expenses…',
    this.labelStyle
  });

  /// Overall square size of the animation (wallet area).
  final double size;

  /// Label under the animation.
  final String label;
  final TextStyle? labelStyle; // <— add this

  @override
  State<WalletSetupLoading> createState() => _WalletSetupLoadingState();
}

class _WalletSetupLoadingState extends State<WalletSetupLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = widget.size * 0.44;

    return Semantics(
      label: 'Loading: ${widget.label}',
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Wallet
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _WalletPainter(
                            body: cs.primaryContainer,
                            edge: cs.primary,
                            slot: cs.onPrimaryContainer.withOpacity(0.65),
                            shadow: Colors.black.withOpacity(0.06),
                          ),
                        ),
                      ),

                      // Bills (3 with phase offsets)
                      for (int i = 0; i < 3; i++)
                        _BillParticle(
                          t: (_ctrl.value + i / 3) % 1.0,
                          radius: radius,
                          size: widget.size,
                          color: cs.tertiaryContainer,      // usually a pleasing accent
                          ink: cs.onTertiaryContainer,      // bill markings
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Subtle pulse on the label so it feels alive
_PulsingText(widget.label, style: widget.labelStyle),          ],
        ),
      ),
    );
  }
}

class _BillParticle extends StatelessWidget {
  const _BillParticle({
    required this.t,
    required this.radius,
    required this.size,
    required this.color,
    required this.ink,
  });

  final double t;      // 0..1 progress around the circle
  final double radius; // orbit radius
  final double size;   // base size for scaling
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    // Angle: start at top (-pi/2) and go clockwise.
    final angle = -math.pi / 2 + 2 * math.pi * t;

    // Center of the widget (wallet center)
    final cx = size / 2;
    final cy = size / 2 + size * 0.05; // slightly lower (wallet sits low)

    // Position on circle
    final px = cx + radius * math.cos(angle);
    final py = cy + radius * math.sin(angle);

    // Fade near the slot (top) to look like entering/exiting the wallet
    final fade = _fadeAwayNearTop(angle);
    final opacity = 0.25 + 0.75 * fade;

    // Slight size change for depth
    final scale = 0.9 + 0.1 * math.sin(2 * math.pi * t);

    // Align bill roughly along the tangent of the path
    final rotation = angle + math.pi / 2;

    // Bill size
    final bw = size * 0.26;
    final bh = size * 0.14;

    return Positioned(
      left: px - bw / 2,
      top: py - bh / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: _BillShape(width: bw, height: bh, color: color, ink: ink),
          ),
        ),
      ),
    );
  }

  // Smoothly drop opacity within ~45° of the top (the wallet slot area).
  double _fadeAwayNearTop(double angle) {
    // Wrap angle diff into [-pi, pi]
    double diff = angle - (-math.pi / 2);
    diff = (diff + math.pi) % (2 * math.pi) - math.pi;
    final a = diff.abs();

    // 0 near slot, 1 far from slot
    const cutoff = math.pi / 4; // 45°
    if (a >= cutoff) return 1.0;
    // Smoothstep: x*x*(3-2x)
    final x = (a / cutoff).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }
}

class _BillShape extends StatelessWidget {
  const _BillShape({
    required this.width,
    required this.height,
    required this.color,
    required this.ink,
  });

  final double width;
  final double height;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height * 0.22),
        boxShadow: [
          BoxShadow(
            blurRadius: height * 0.18,
            offset: Offset(0, height * 0.08),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
        border: Border.all(
          color: ink.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: CustomPaint(
        painter: _BillPainter(ink: ink),
      ),
    );
  }
}

class _BillPainter extends CustomPainter {
  _BillPainter({required this.ink});
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Simple money details: two rings & a stripe
    final center = Offset(size.width * 0.3, size.height * 0.5);
    canvas.drawCircle(center, size.height * 0.18, paint);
    canvas.drawCircle(center, size.height * 0.08, paint);

    final stripe = Paint()
      ..color = ink.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final stripeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.52, size.height * 0.32,
          size.width * 0.36, size.height * 0.36),
      Radius.circular(size.height * 0.12),
    );
    canvas.drawRRect(stripeRect, stripe);
  }

  @override
  bool shouldRepaint(covariant _BillPainter oldDelegate) => false;
}

class _WalletPainter extends CustomPainter {
  _WalletPainter({
    required this.body,
    required this.edge,
    required this.slot,
    required this.shadow,
  });

  final Color body;
  final Color edge;
  final Color slot;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Slight ground shadow
    final shadowPaint = Paint()..color = shadow;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.78),
        width: w * 0.6,
        height: h * 0.08,
      ),
      shadowPaint,
    );

    // Wallet body
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.36, w * 0.68, h * 0.38),
      Radius.circular(h * 0.10),
    );

    final bodyPaint = Paint()..color = body;
    canvas.drawRRect(rRect, bodyPaint);

    // Edge / stroke
    final edgePaint = Paint()
      ..color = edge.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.012;
    canvas.drawRRect(rRect, edgePaint);

    // Flap
    final flapRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.28, w * 0.72, h * 0.16),
      Radius.circular(h * 0.10),
    );
    final flapPaint = Paint()..color = body.withOpacity(0.95);
    canvas.drawRRect(flapRect, flapPaint);
    canvas.drawRRect(
      flapRect,
      edgePaint..color = edge.withOpacity(0.4),
    );

    // Clasp button
    final clasp = Offset(w * 0.76, h * 0.47);
    final claspPaint = Paint()..color = edge.withOpacity(0.55);
    canvas.drawCircle(clasp, h * 0.018, claspPaint);

    // Slot (where bills enter/exit)
    final slotRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, h * 0.255, w * 0.32, h * 0.035),
      Radius.circular(h * 0.02),
    );
    final slotPaint = Paint()..color = slot;
    canvas.drawRRect(slotRect, slotPaint);
  }

  @override
  bool shouldRepaint(covariant _WalletPainter oldDelegate) => false;
}

class _PulsingText extends StatefulWidget {
  const _PulsingText(this.text, {this.style});
  final String text;
  final TextStyle? style;


  @override
  State<_PulsingText> createState() => _PulsingTextState();
}

class _PulsingTextState extends State<_PulsingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1.0).animate(_a),
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
