import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The bordered surface every Settings group is cut from.
///
/// Elevation stays flat on purpose: the border carries the group boundary,
/// matching the home dashboard's action cards.
class SettingsCard extends StatelessWidget {
  const SettingsCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.color.background.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.symmetric(
        horizontal: context.dimensions.space.s16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          context.dimensions.radius.medium,
        ),
        side: BorderSide(color: context.color.border.subtle),
      ),
      child: Column(children: children),
    );
  }
}
