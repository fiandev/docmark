import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// Horizontal strip of PDF page thumbnails for page selection.
class ExportPageSelector extends StatelessWidget {
  const ExportPageSelector({
    required this.pages,
    required this.thumbnails,
    required this.selected,
    required this.onToggle,
    this.enabled = true,
    super.key,
  });

  final List<int> pages;
  final Map<int, Uint8List> thumbnails;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tileWidth = context.dimensions.space.s80;
    final tileHeight = tileWidth * 4 / 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelText(context.locale.export_pageRange),
        Gap(context.dimensions.space.s8),
        SizedBox(
          height: tileHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pages.length,
            separatorBuilder: (context, index) =>
                Gap(context.dimensions.space.s8),
            itemBuilder: (context, index) {
              final page = pages[index];

              return _PageTile(
                page: page,
                thumbnail: thumbnails[page],
                selected: selected.contains(page),
                width: tileWidth,
                onTap: enabled ? () => onToggle(page) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.page,
    required this.thumbnail,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final int page;
  final Uint8List? thumbnail;
  final bool selected;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.dimensions.radius.small);
    final borderColor = selected
        ? context.color.docMark.selection
        : context.color.border.defaultValue;
    final borderWidth = selected
        ? context.dimensions.border.lg
        : context.dimensions.border.xs;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: context.color.background.surface,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: thumbnail == null
                  ? Center(
                      child: Icon(
                        Icons.description_outlined,
                        size: context.dimensions.size.iconMedium,
                        color: context.color.text.muted,
                      ),
                    )
                  : Image.memory(
                      thumbnail!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
            ),
            Padding(
              padding: EdgeInsets.all(context.dimensions.space.s4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected)
                    Icon(
                      Icons.check_circle,
                      size: context.dimensions.size.iconSmall,
                      color: context.color.docMark.selection,
                    ),
                  if (selected) Gap(context.dimensions.space.s4),
                  LabelText(context.locale.export_pageNumber(page + 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
