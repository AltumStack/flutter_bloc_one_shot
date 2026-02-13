import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'side_effect_listener.dart';

/// A widget that combines [BlocBuilder] and [SideEffectListener].
///
/// Rebuilds [builder] on state changes and calls [listener] on side effects.
/// This is a convenience widget equivalent to nesting a [SideEffectListener]
/// around a [BlocBuilder].
///
/// ```dart
/// SideEffectConsumer<AuthBloc, AuthState, AuthEffect>(
///   builder: (context, state) {
///     if (state is AuthLoading) return CircularProgressIndicator();
///     return LoginForm();
///   },
///   listener: (context, effect) {
///     if (effect is NavigateToHome) {
///       Navigator.of(context).pushReplacementNamed('/home');
///     }
///   },
/// )
/// ```
class SideEffectConsumer<B extends BlocBase<S>, S, E> extends StatefulWidget {
  /// Creates a [SideEffectConsumer].
  const SideEffectConsumer({
    required this.builder,
    required this.listener,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
    super.key,
  });

  /// The bloc or cubit.
  ///
  /// If `null`, resolved via `context.read<B>()`.
  final B? bloc;

  /// Called to build the widget tree based on the current state.
  final BlocWidgetBuilder<S> builder;

  /// Called once per side effect.
  final SideEffectListenerCallback<E> listener;

  /// Optional state filter for [builder]. Same semantics as [BlocBuilder.buildWhen].
  final BlocBuilderCondition<S>? buildWhen;

  /// Optional effect filter for [listener].
  final SideEffectListenerCondition<E>? listenWhen;

  @override
  State<SideEffectConsumer<B, S, E>> createState() =>
      _SideEffectConsumerState<B, S, E>();
}

class _SideEffectConsumerState<B extends BlocBase<S>, S, E>
    extends State<SideEffectConsumer<B, S, E>> {
  @override
  Widget build(BuildContext context) {
    return SideEffectListener<B, E>(
      bloc: widget.bloc,
      listener: widget.listener,
      listenWhen: widget.listenWhen,
      child: BlocBuilder<B, S>(
        bloc: widget.bloc,
        buildWhen: widget.buildWhen,
        builder: widget.builder,
      ),
    );
  }
}
