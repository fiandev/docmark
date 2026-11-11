import 'package:flutter/material.dart';

import '../../../../core/extensions/localization.dart';
import '../../../../core/gen/l10n/app_localizations.dart';
import '../../../../domain/entities/image_format.dart';
import '../../../../domain/services/font_registry.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// Opens the family picker and returns the chosen token, or null when the
/// sheet is dismissed.
///
/// The list is [FontRegistry.pickerOrder] — the catalogue — so a new family
/// appears here by being added to the registry, never by editing this file.
Future<FontToken?> showFontPickerSheet(
  BuildContext context, {
  required FontToken selected,
}) {
  return showModalBottomSheet<FontToken>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _FontSheet(selected: selected),
  );
}

/// The localized family name for a token.
String fontTokenLabel(AppLocalizations l10n, FontToken token) {
  return switch (token) {
    FontToken.system => l10n.editor_font_system,
    FontToken.inter => l10n.editor_font_inter,
    FontToken.roboto => l10n.editor_font_roboto,
    FontToken.robotoMono => l10n.editor_font_robotoMono,
    FontToken.montserrat => l10n.editor_font_montserrat,
    FontToken.lora => l10n.editor_font_lora,
    FontToken.merriweather => l10n.editor_font_merriweather,
    FontToken.caveat => l10n.editor_font_caveat,
  };
}

class _FontSheet extends StatelessWidget {
  const _FontSheet({required this.selected});

  final FontToken selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(context.dimensions.space.s16),
            child: LabelText.muted(l10n.editor_font_title),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final token in FontRegistry.pickerOrder)
                  _FontTile(
                    token: token,
                    label: fontTokenLabel(l10n, token),
                    selected: token == selected,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FontTile extends StatelessWidget {
  const _FontTile({
    required this.token,
    required this.label,
    required this.selected,
  });

  final FontToken token;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final family = FontRegistry.familyOf(token);

    return ListTile(
      selected: selected,
      title: Text(
        label,
        style: TextStyle(fontFamily: family),
      ),
      trailing: selected
          ? Icon(
              Icons.check,
              color: context.color.primary.defaultValue,
            )
          : null,
      onTap: () => Navigator.of(context).pop(token),
    );
  }
}
