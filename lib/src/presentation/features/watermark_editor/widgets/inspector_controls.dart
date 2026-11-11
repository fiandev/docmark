import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../domain/entities/normalized_rect.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import 'color_picker_sheet.dart';

/// A titled card in the inspector. One section, one visual group.
class InspectorSection extends StatelessWidget {
  const InspectorSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dims = context.dimensions.docMark;

    return Container(
      margin: EdgeInsets.only(bottom: dims.panelGap),
      padding: EdgeInsets.all(dims.panelPadding),
      decoration: BoxDecoration(
        color: context.color.background.surface,
        borderRadius: BorderRadius.circular(dims.panelRadius),
        border: Border.all(color: context.color.border.subtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabelText.muted(title),
          Gap(dims.panelGap),
          ...children,
        ],
      ),
    );
  }
}

/// A labelled slider with the current value beside its label.
class InspectorSlider extends StatelessWidget {
  const InspectorSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.valueLabel,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final int? divisions;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: LabelText(label)),
            if (valueLabel != null) BodySmallText.muted(valueLabel!),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// A label and a switch, sized to one row.
class InspectorSwitchRow extends StatelessWidget {
  const InspectorSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      title: LabelText(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A label and a colour swatch; tapping opens the palette.
class InspectorColorRow extends StatelessWidget {
  const InspectorColorRow({
    required this.label,
    required this.colorArgb,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int colorArgb;
  final ValueChanged<int> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showWatermarkColorSheet(
      context,
      selected: colorArgb,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dimensions;

    return InkWell(
      borderRadius: BorderRadius.circular(dims.radius.small),
      onTap: () => _pick(context),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dims.space.s8),
        child: Row(
          children: [
            Container(
              width: dims.size.iconLarge,
              height: dims.size.iconLarge,
              decoration: BoxDecoration(
                color: Color(colorArgb),
                borderRadius: BorderRadius.circular(dims.radius.small),
                border: Border.all(color: context.color.border.defaultValue),
              ),
            ),
            Gap(dims.space.s8),
            Expanded(child: LabelText(label)),
            Icon(
              Icons.chevron_right,
              size: dims.size.iconLarge,
              color: context.color.text.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Four arrow buttons that nudge the selection by a fine or coarse step.
///
/// Fine steps are what "precise positioning" means on a phone: the page is
/// a fraction of a percent wide per tap.
class InspectorNudgePad extends StatefulWidget {
  const InspectorNudgePad({
    required this.onNudge,
    required this.fineLabel,
    required this.coarseLabel,
    required this.stepLabel,
    super.key,
  });

  final ValueChanged<NormalizedOffset> onNudge;
  final String fineLabel;
  final String coarseLabel;
  final String Function(int percent) stepLabel;

  @override
  State<InspectorNudgePad> createState() => _InspectorNudgePadState();
}

class _InspectorNudgePadState extends State<InspectorNudgePad> {
  static const double _fineStep = 0.002;
  static const double _coarseStep = 0.02;

  bool _fine = true;

  double get _step => _fine ? _fineStep : _coarseStep;

  void _move(double dx, double dy) => widget.onNudge(
    NormalizedOffset(dx * _step, dy * _step),
  );

  @override
  Widget build(BuildContext context) {
    final dims = context.dimensions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(widget.fineLabel),
                selected: _fine,
                onSelected: (_) => setState(() => _fine = true),
              ),
            ),
            Gap(dims.space.s8),
            Expanded(
              child: ChoiceChip(
                label: Text(widget.coarseLabel),
                selected: !_fine,
                onSelected: (_) => setState(() => _fine = false),
              ),
            ),
            Gap(dims.space.s8),
            BodySmallText.muted(
              widget.stepLabel((_step * 100).round()),
            ),
          ],
        ),
        Gap(dims.space.s4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => _move(-1, 0),
              icon: const Icon(Icons.keyboard_arrow_left),
            ),
            IconButton(
              onPressed: () => _move(0, -1),
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              onPressed: () => _move(0, 1),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              onPressed: () => _move(1, 0),
              icon: const Icon(Icons.keyboard_arrow_right),
            ),
          ],
        ),
      ],
    );
  }
}
