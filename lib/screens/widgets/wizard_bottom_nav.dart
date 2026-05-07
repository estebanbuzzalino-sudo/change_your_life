import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class WizardNavItem {
  final String title;
  final IconData icon;

  const WizardNavItem({
    required this.title,
    required this.icon,
  });
}

class WizardBottomNav extends StatelessWidget {
  final List<WizardNavItem> items;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const WizardBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isActive = index == currentIndex;
          final isCompleted = index < currentIndex;

          final color = isActive
              ? AppColors.primary
              : (isCompleted ? AppColors.primaryMuted : AppColors.textMuted);
          final background = isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isCompleted
                  ? AppColors.primaryMuted.withValues(alpha: 0.08)
                  : Colors.transparent);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: background,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTap == null ? null : () => onTap!(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 20, color: color),
                        const SizedBox(height: 4),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
