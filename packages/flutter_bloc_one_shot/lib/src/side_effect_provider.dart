import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'side_effect_listener.dart';

/// A widget that combines [BlocProvider] and [SideEffectListener] into a single
/// convenience widget.
///
/// Instead of nesting a [BlocProvider] around a [SideEffectListener]:
///
/// ```dart
/// BlocProvider(
///   create: (_) => AuthBloc(),
///   child: SideEffectListener<AuthBloc, AuthEffect>(
///     listener: (context, effect) { /* ... */ },
///     child: AuthPage(),
///   ),
/// )
/// ```
///
/// You can use [SideEffectProvider]:
///
/// ```dart
/// SideEffectProvider<AuthBloc, AuthEffect>(
///   create: (_) => AuthBloc(),
///   listener: (context, effect) { /* ... */ },
///   child: AuthPage(),
/// )
/// ```
class SideEffectProvider<B extends BlocBase<dynamic>, E>
    extends StatelessWidget {
  /// Creates a [SideEffectProvider] that creates and provides a new Bloc.
  ///
  /// The Bloc is created using [create] and automatically closed when the
  /// widget is disposed (same behavior as [BlocProvider]).
  const SideEffectProvider({
    required this.create,
    required this.listener,
    this.listenWhen,
    this.lazy = true,
    this.child,
    super.key,
  }) : _value = null;

  /// Creates a [SideEffectProvider] that provides an existing Bloc instance.
  ///
  /// The Bloc is **not** closed when the widget is disposed (same behavior as
  /// [BlocProvider.value]).
  const SideEffectProvider.value({
    required B value,
    required this.listener,
    this.listenWhen,
    this.child,
    super.key,
  }) : _value = value,
       create = null,
       lazy = true;

  /// Function that creates the Bloc. Only used by the default constructor.
  final B Function(BuildContext)? create;

  /// An existing Bloc instance. Only used by the `.value` constructor.
  final B? _value;

  /// Called once per side effect emitted by the Bloc.
  final SideEffectListenerCallback<E> listener;

  /// Optional filter. If provided, [listener] is only called when this
  /// returns `true` for the given effect.
  final SideEffectListenerCondition<E>? listenWhen;

  /// Whether to lazily create the Bloc. Defaults to `true`.
  final bool lazy;

  /// The child widget.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (_value != null) {
      return BlocProvider<B>.value(
        value: _value,
        child: SideEffectListener<B, E>(
          bloc: _value,
          listener: listener,
          listenWhen: listenWhen,
          child: child,
        ),
      );
    }

    return BlocProvider<B>(
      create: create!,
      lazy: lazy,
      child: SideEffectListener<B, E>(
        listener: listener,
        listenWhen: listenWhen,
        child: child,
      ),
    );
  }
}
