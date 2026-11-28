import 'package:flutter/material.dart';

/// A stylized action button for quick actions.
/// Used in dashboard for actions like "Take Quiz", "View Syllabus", etc.
class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;
  final bool outlined;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }
}

/// A row of quick action buttons
class QuickActionsRow extends StatelessWidget {
  final List<QuickActionButton> actions;
  final double spacing;

  const QuickActionsRow({super.key, required this.actions, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: actions.map((action) {
        final index = actions.indexOf(action);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index > 0 ? spacing / 2 : 0,
              right: index < actions.length - 1 ? spacing / 2 : 0,
            ),
            child: action,
          ),
        );
      }).toList(),
    );
  }
}
