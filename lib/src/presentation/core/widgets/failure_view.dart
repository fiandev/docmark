import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../../core/extensions/localization.dart';
import '../../../domain/failures/business_failure.dart';
import '../failure/business_failure_ui_mapper.dart';
import '../router/routes.dart';
import '../theme/theme.dart';

/// The standard full-body failure state. Hand it the raw error from an
/// `AsyncError` — a [BusinessFailure] renders its mapped copy and
/// recovery action; anything else degrades to the generic model, so no
/// error type ever renders as a blank screen.
///
/// ```dart
/// FailureView(error: error, onRetry: () => ref.invalidate(provider))
/// ```
///
/// The retry button appears only when the mapped action is retry and
/// [onRetry] is provided. Snackbar-shaped call sites do not use this
/// widget; they read `BusinessFailureUIMapper.map(...).message` directly.
///
/// DocMark has no remote session, so `reauthenticate` means "return to the
/// app's entry point": the button sends the user home, where App Lock (or
/// the editor) can re-establish the context.
class FailureView extends StatelessWidget {
  const FailureView({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error;
    final model = failure is BusinessFailure
        ? BusinessFailureUIMapper.map(failure, context.locale)
        : BusinessFailureUIMapper.unexpected(context.locale);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: context.dimensions.size.iconDisplay,
            color: context.color.text.muted,
          ),
          Gap(context.dimensions.space.s8),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.dimensions.space.s24,
            ),
            child: Text(model.message, textAlign: TextAlign.center),
          ),
          Gap(context.dimensions.space.s24),
          switch (model.action) {
            .retry when onRetry != null => FilledButton(
              onPressed: onRetry,
              child: Text(context.locale.retry),
            ),
            .reauthenticate => FilledButton(
              onPressed: () => context.go(Routes.home.path),
              child: Text(context.locale.signInAgain),
            ),
            _ => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }
}
