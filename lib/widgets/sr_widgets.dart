import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

// ─────────────────────────────────────────────
//  SRBtn — main CTA button
//  kind: 'primary' | 'soft' | 'dark'
// ─────────────────────────────────────────────
class SRBtn extends StatelessWidget {
  const SRBtn(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = 'primary',
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String kind;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isPrimary = kind == 'primary';
    final isDark = kind == 'dark';

    final textWidget = Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: isPrimary || isDark ? Colors.white : SRColors.primary,
      ),
    );

    Widget content = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  textWidget,
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    size: 18,
                    color: isPrimary || isDark ? Colors.white : SRColors.primary,
                  ),
                ],
              )
            : textWidget;

    if (isPrimary) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [SRColors.primary, SRColors.accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 30,
              offset: const Offset(0, 14),
              color: SRColors.primary.withValues(alpha: 0.4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Center(child: content),
          ),
        ),
      );
    }

    if (isDark) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: SRColors.dark,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Center(child: content),
          ),
        ),
      );
    }

    // soft: white bg with border
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: SRColors.card,
        border: Border.all(color: SRColors.primary, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Center(child: content),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  GradientText — wraps Text with ShaderMask
// ─────────────────────────────────────────────
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.colors = const [SRColors.primary, SRColors.secondary],
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final List<Color> colors;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}

// ─────────────────────────────────────────────
//  SRDots — onboarding dot indicator
// ─────────────────────────────────────────────
class SRDots extends StatelessWidget {
  const SRDots({super.key, required this.active, required this.total});

  final int active;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? SRColors.primary : SRColors.line,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
//  SRCard — styled card widget
// ─────────────────────────────────────────────
class SRCard extends StatelessWidget {
  const SRCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18.0,
    this.color = SRColors.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 12),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
