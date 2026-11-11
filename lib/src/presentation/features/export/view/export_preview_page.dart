import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../../domain/services/render_contract.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// Export preview: the last look before a file leaves the encrypted vault.
///
/// OWNER: T7 (export). The constructor signature is final; the router
/// passes the request through `GoRouterState.extra`.
class ExportPreviewPage extends StatelessWidget {
  const ExportPreviewPage({required this.request, super.key});

  final ExportRequest request;

  @override
  Widget build(BuildContext context) {
    final isEmpty = request.document.id.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: HeadingLevel3Text(context.locale.export_title),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(context.dimensions.space.s16),
          children: [
            if (isEmpty)
              BodySmallText.muted(context.locale.export_empty)
            else ...[
              _WarningCard(
                title: context.locale.export_unencrypted_warning_title,
                body: context.locale.export_unencrypted_warning_body,
              ),
              Gap(context.dimensions.space.s16),
              BodySmallText.muted(
                context.locale.export_pages(request.resolvedPages.length),
              ),
              Gap(context.dimensions.space.s24),
              FilledButton(
                onPressed: () {},
                child: Text(context.locale.export_save),
              ),
              Gap(context.dimensions.space.s12),
              OutlinedButton(
                onPressed: () {},
                child: Text(context.locale.export_share),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.color.status.warningTint,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.dimensions.radius.medium),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.dimensions.space.s16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: context.color.status.warning,
            ),
            Gap(context.dimensions.space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabelText(title),
                  Gap(context.dimensions.space.s4),
                  BodySmallText.muted(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
