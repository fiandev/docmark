import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// Saved watermark presets.
///
/// OWNER: T5 (presets). Lives inside the tab shell, so it renders no
/// AppBar of its own.
class PresetsPage extends StatelessWidget {
  const PresetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.dimensions.space.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bookmark_outline,
                size: context.dimensions.size.iconDisplay,
                color: context.color.text.muted,
              ),
              Gap(context.dimensions.space.s16),
              HeadingLevel3Text(
                context.locale.presets_empty,
                textAlign: TextAlign.center,
              ),
              Gap(context.dimensions.space.s8),
              BodySmallText.muted(
                context.locale.presets_emptyBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
