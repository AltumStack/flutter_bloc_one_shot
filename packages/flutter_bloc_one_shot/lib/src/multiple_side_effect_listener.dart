import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Merges multiple [SideEffectListener] widgets into one widget tree.
///
/// Improves readability and eliminates nesting when listening to
/// side effects from multiple blocs.
///
/// ```dart
/// MultipleSideEffectListener(
///   listeners: [
///     SideEffectListener<AuthBloc, AuthEffect>(
///       listener: (context, effect) { /* ... */ },
///     ),
///     SideEffectListener<NavBloc, NavEffect>(
///       listener: (context, effect) { /* ... */ },
///     ),
///   ],
///   child: MyWidget(),
/// )
/// ```
class MultipleSideEffectListener extends MultiProvider {
  /// Creates a [MultipleSideEffectListener] that nests multiple
  /// [SideEffectListener] widgets.
  MultipleSideEffectListener({
    required List<SingleChildWidget> listeners,
    required Widget child,
    super.key,
  }) : super(providers: listeners, child: child);
}
