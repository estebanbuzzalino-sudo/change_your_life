import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stepLabel != null && stepLabel!.isNotEmpty) ...[
          Text(
            stepLabel!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        child,
      ],
    );
  }
}
