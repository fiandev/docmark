import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// Opens the palette for a watermark colour and returns the chosen ARGB
/// value, or null when the sheet is dismissed.
///
/// The swatches come from the theme tokens, so the palette follows the
/// app's colour system instead of a private list of hex values.
Future<int?> showWatermarkColorSheet(
  BuildContext context, {
  required int selected,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ColorSheet(selected: selected),
  );
}

/// Parses `#RRGGBB` or `#AARRGGBB` into an ARGB integer.
int? parseHexColor(String source) {
  final cleaned = source.trim().replaceFirst('#', '');
  if (cleaned.length != 6 && cleaned.length != 8) return null;

  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;

  return cleaned.length == 6 ? 0xFF000000 | value : value;
}

class _ColorSheet extends StatefulWidget {
  const _ColorSheet({required this.selected});

  final int selected;

  @override
  State<_ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends State<_ColorSheet> {
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _hex = TextEditingController(text: _toHex(widget.selected));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _submitHex() {
    final parsed = parseHexColor(_hex.text);
    if (parsed == null) return;
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final tokens = context.color;
    final dims = context.dimensions;
    final swatches = <Color>[
      tokens.text.strong,
      tokens.text.defaultValue,
      tokens.text.muted,
      tokens.docMark.defaultWatermarkOutline,
      tokens.docMark.defaultWatermarkBackground,
      tokens.primary.defaultValue,
      tokens.primary.strong,
      tokens.status.success,
      tokens.status.warning,
      tokens.status.danger,
      tokens.status.information,
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(dims.space.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabelText.muted(l10n.editor_fontColor),
            Gap(dims.space.s12),
            Wrap(
              spacing: dims.space.s8,
              runSpacing: dims.space.s8,
              children: [
                for (final color in swatches)
                  _ColorSwatch(
                    color: color,
                    selected: color.toARGB32() == widget.selected,
                    onTap: () =>
                        Navigator.of(context).pop(color.toARGB32()),
                  ),
              ],
            ),
            Gap(dims.space.s16),
            TextFormField(
              controller: _hex,
              decoration: InputDecoration(
                labelText: l10n.editor_color_hex,
                hintText: '#RRGGBB',
              ),
              onFieldSubmitted: (_) => _submitHex(),
            ),
            Gap(dims.space.s8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: _submitHex,
                child: Text(l10n.common_apply),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _toHex(int argb) {
    final value = argb.toRadixString(16).padLeft(8, '0').toUpperCase();

    return '#${value.substring(2)}';
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dimensions;

    return InkWell(
      borderRadius: BorderRadius.circular(dims.radius.small),
      onTap: onTap,
      child: Container(
        width: dims.size.touch,
        height: dims.size.touch,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(dims.radius.small),
          border: Border.all(
            color: selected
                ? context.color.primary.strong
                : context.color.border.defaultValue,
            width: selected ? dims.border.lg : dims.border.xs,
          ),
        ),
      ),
    );
  }
}
