import 'package:flutter/material.dart';

const Color _planPurple = Color(0xFF4B3D8E);

/// Modal error for revision plan / n8n / AI failures (replaces SnackBar for those cases).
Future<void> showRevisionPlanErrorDialog(
  BuildContext context, {
  required String message,
  String title = 'Study plan unavailable',
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(Icons.error_outline, color: Colors.red.shade700, size: 36),
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: FilledButton.styleFrom(backgroundColor: _planPurple),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
