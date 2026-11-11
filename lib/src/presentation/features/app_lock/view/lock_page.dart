import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// The App Lock screen the router pins to while locked.
///
/// OWNER: T10 (PIN + biometrics). The page renders from the lock-card
/// theme tokens so the final implementation only replaces the body.
class LockPage extends StatelessWidget {
  const LockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.dimensions.docMark.lockCardMaxWidth,
            ),
            child: Card(
              color: context.color.docMark.lockCardBackground,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  context.dimensions.docMark.lockCardRadius,
                ),
                side: BorderSide(color: context.color.docMark.lockCardBorder),
              ),
              child: Padding(
                padding: EdgeInsets.all(
                  context.dimensions.docMark.lockCardPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: context.dimensions.size.iconDisplay,
                      color: context.color.text.muted,
                    ),
                    Gap(context.dimensions.space.s16),
                    HeadingLevel3Text(
                      context.locale.app_lock_locked_title,
                      textAlign: TextAlign.center,
                    ),
                    Gap(context.dimensions.space.s8),
                    BodySmallText.muted(
                      context.locale.app_lock_locked_body,
                      textAlign: TextAlign.center,
                    ),
                    Gap(context.dimensions.space.s24),
                    FilledButton(
                      onPressed: () {},
                      child: Text(context.locale.app_lock_unlock),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
