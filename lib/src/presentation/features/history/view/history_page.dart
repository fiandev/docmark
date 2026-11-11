import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// Processing history.
///
/// OWNER: T6 (history). Lives inside the tab shell, so it renders no
/// AppBar of its own.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

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
                Icons.history,
                size: context.dimensions.size.iconDisplay,
                color: context.color.text.muted,
              ),
              Gap(context.dimensions.space.s16),
              HeadingLevel3Text(
                context.locale.history_empty,
                textAlign: TextAlign.center,
              ),
              Gap(context.dimensions.space.s8),
              BodySmallText.muted(
                context.locale.history_emptyBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
