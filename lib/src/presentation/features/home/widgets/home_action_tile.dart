import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// The dashboard's single primary action: start a new document.
class HomePrimaryAction extends StatelessWidget {
  const HomePrimaryAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.color.primary.tint,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          context.dimensions.radius.large,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.dimensions.space.s16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.dimensions.space.s12),
                decoration: BoxDecoration(
                  color: context.color.primary.defaultValue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: context.dimensions.size.iconLarge,
                  color: context.color.text.onPrimary,
                ),
              ),
              Gap(context.dimensions.space.s16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeadingLevel3Text(title),
                    Gap(context.dimensions.space.s4),
                    BodySmallText(body),
                  ],
                ),
              ),
              Gap(context.dimensions.space.s8),
              Icon(
                Icons.chevron_right,
                color: context.color.primary.strong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A secondary dashboard shortcut.
class HomeActionTile extends StatelessWidget {
  const HomeActionTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.color.background.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          context.dimensions.radius.medium,
        ),
        side: BorderSide(color: context.color.border.subtle),
      ),
      child: ListTile(
        leading: Icon(icon, color: context.color.primary.defaultValue),
        title: LabelText(title),
        subtitle: BodySmallText.muted(body),
        trailing: Icon(
          Icons.chevron_right,
          color: context.color.text.muted,
        ),
        onTap: onTap,
      ),
    );
  }
}
