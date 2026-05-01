import 'package:flutter/material.dart';

/// Tiny modal text-prompt helper. Returns the entered text on Save, or null
/// if cancelled. Shared between board / boards-list screens to avoid
/// duplication.
Future<String?> promptForText({
  required BuildContext context,
  required String title,
  required String hint,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
