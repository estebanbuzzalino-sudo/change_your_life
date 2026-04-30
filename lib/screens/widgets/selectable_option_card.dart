import 'package:flutter/material.dart';

class SelectableOptionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const SelectableOptionCard({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Colors.green.shade700 : Colors.black12;
    final backgroundColor = !enabled
        ? Colors.grey.shade100
        : (selected ? Colors.green.shade50 : Colors.white);
    final iconColor = !enabled
        ? Colors.grey.shade500
        : (selected ? Colors.green.shade700 : Colors.black87);
    final titleColor = !enabled ? Colors.grey.shade600 : Colors.black87;
    final subtitleColor = !enabled ? Colors.grey.shade500 : Colors.black54;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 13, color: subtitleColor),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? Colors.green.shade700 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
