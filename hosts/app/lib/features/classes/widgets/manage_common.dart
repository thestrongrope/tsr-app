import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message.dart';

/// Small pieces shared by the manage-a-class tabs.

/// A label and a value that the screen shows but does not edit.
class ManageFact extends StatelessWidget {
  final String label;
  final String value;

  const ManageFact({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: AppTheme.mediumText)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// `YYYY-MM-DD`, the form the API sends and accepts for a date.
String manageDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// What to tell the member about a failure, in plain words (#720).
String manageErrorText(Object error) => userMessage(error);

void showManageMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

void showManageError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(manageErrorText(error)),
      backgroundColor: AppTheme.errorRed,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
