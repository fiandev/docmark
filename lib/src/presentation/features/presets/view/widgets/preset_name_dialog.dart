import 'package:flutter/material.dart';

import '../../../../../core/extensions/localization.dart';

/// Creates or renames a preset: one name field, validated inline.
///
/// Returns the trimmed name, or null when dismissed.
class PresetNameDialog extends StatefulWidget {
  const PresetNameDialog({
    required this.title,
    this.initialName = '',
    super.key,
  });

  final String title;
  final String initialName;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? initialName,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => PresetNameDialog(
        title: title,
        initialName: initialName ?? '',
      ),
    );
  }

  @override
  State<PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<PresetNameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    // Rename opens with the current name selected, so typing replaces it.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialName.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.locale.presets_nameRequired);

      return;
    }

    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l10n.presets_nameLabel,
          hintText: l10n.presets_nameHint,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.common_save),
        ),
      ],
    );
  }
}
