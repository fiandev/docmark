import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// DocMark's home dashboard.
///
/// OWNER: T6 (dashboard data). The entry points below are the frozen
/// surface: New Watermark, Recent, Presets, Settings. There is no logout
/// — the app has no remote session.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(context.dimensions.space.s16),
          children: [
            HeadingLevel1Text(context.locale.home_title),
            Gap(context.dimensions.space.s8),
            BodySmallText.muted(context.locale.home_subtitle),
            Gap(context.dimensions.space.s24),
            _HomeActionTile(
              icon: Icons.add_photo_alternate_outlined,
              label: context.locale.home_newWatermark,
              route: Routes.documentPicker,
            ),
            Gap(context.dimensions.space.s8),
            _HomeActionTile(
              icon: Icons.history,
              label: context.locale.home_recent,
              route: Routes.history,
            ),
            Gap(context.dimensions.space.s8),
            _HomeActionTile(
              icon: Icons.bookmark_outline,
              label: context.locale.home_presets,
              route: Routes.presets,
            ),
            Gap(context.dimensions.space.s8),
            _HomeActionTile(
              icon: Icons.settings_outlined,
              label: context.locale.home_settings,
              route: Routes.settings,
            ),
            Gap(context.dimensions.space.s24),
            BodySmallText.muted(context.locale.home_recentEmpty),
          ],
        ),
      ),
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  const _HomeActionTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final Routes route;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.color.background.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.dimensions.radius.medium),
        side: BorderSide(color: context.color.border.subtle),
      ),
      child: ListTile(
        leading: Icon(icon, color: context.color.primary.defaultValue),
        title: LabelText(label),
        trailing: Icon(Icons.chevron_right, color: context.color.text.muted),
        onTap: () => context.goNamed(route.name),
      ),
    );
  }
}
