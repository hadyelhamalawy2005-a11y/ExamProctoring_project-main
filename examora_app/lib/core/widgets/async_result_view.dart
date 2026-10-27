import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/widgets/app_error_view.dart';
import 'package:examora_app/core/widgets/app_loading_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the three states of something that loads: loading, failed (with retry) or the content. A failed load is never
/// shown as an empty list.
class AsyncResultView<T> extends StatelessWidget {
  /// Creates the view.
  const AsyncResultView({required this.value, required this.builder, required this.onRetry, super.key});

  /// What is loading.
  final AsyncValue<Result<T>> value;

  /// Builds the content once it is there.
  final Widget Function(T data) builder;

  /// Called by the retry button.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const AppLoadingView(),
      // Repositories return failures instead of throwing, so this is an unexpected error.
      error: (error, stack) => AppErrorView(failure: const ServerFailure(), onRetry: onRetry),
      data: (outcome) => switch (outcome) {
        Err<T>(:final failure) => AppErrorView(failure: failure, onRetry: onRetry),
        Ok<T>(:final value) => builder(value),
      },
    );
  }
}
