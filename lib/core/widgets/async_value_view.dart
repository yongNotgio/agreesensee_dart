import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common_widgets.dart';

/// Renders an [AsyncValue] with consistent loading / error / data handling so
/// screens don't repeat the `when(...)` boilerplate.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: false,
      data: data,
      loading: () =>
          loading ?? const Center(child: CircularProgressIndicator()),
      error: (err, _) => ErrorRetry(message: '$err', onRetry: onRetry),
    );
  }
}
