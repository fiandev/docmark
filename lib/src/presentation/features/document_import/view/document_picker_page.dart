import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// Document picker: gallery or file manager, validated by magic bytes.
///
/// OWNER: T2 (import flow). The page is a stub until the picker pipeline
/// lands; the constructor signature is final.
class DocumentPickerPage extends StatelessWidget {
  const DocumentPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: HeadingLevel3Text(context.locale.import_title),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(context.dimensions.space.s16),
          children: [
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(context.locale.import_fromGallery),
            ),
            Gap(context.dimensions.space.s12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(context.locale.import_fromFiles),
            ),
            Gap(context.dimensions.space.s24),
            BodySmallText.muted(context.locale.import_supportedFormats),
            Gap(context.dimensions.space.s8),
            BodySmallText.muted(context.locale.import_neverModified),
            Gap(context.dimensions.space.s24),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: Text(context.locale.common_cancel),
            ),
          ],
        ),
      ),
    );
  }
}
