import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// The watermark editor.
///
/// OWNER: T3 (state) and T4 (canvas). The constructor signature is final:
/// the router passes the document id as a required positional-named
/// argument, and the editor loads the document itself.
class EditorPage extends StatelessWidget {
  const EditorPage({required this.documentId, super.key});

  final String documentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: HeadingLevel3Text(context.locale.editor_title),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(context.dimensions.space.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: context.dimensions.size.iconDisplay,
                  color: context.color.text.muted,
                ),
                Gap(context.dimensions.space.s16),
                BodySmallText.muted(
                  context.locale.editor_placeholder,
                  textAlign: TextAlign.center,
                ),
                Gap(context.dimensions.space.s8),
                LabelText.muted(
                  context.locale.editor_documentId(documentId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
