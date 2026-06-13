import 'package:flutter/material.dart';

class WizardStepShell extends StatelessWidget {
  final String? stepLabel;
  final String title;
  final String subtitle;
  final Widget child;

  const WizardStepShell({
    super.key,
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final stepColor = theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stepLabel != null && stepLabel!.isNotEmpty) ...[
          Text(
            stepLabel!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: stepColor,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(fontSize: 15, color: onSurface.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 18),
        child,
      ],
    );
  }
}
