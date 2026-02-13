import 'dart:async';

import 'package:bloc_effect/bloc_effect.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Signature for the `listener` callback in [SideEffectListener].
typedef SideEffectListenerCallback<E> =
    void Function(BuildContext context, E effect);

/// Signature for the `listenWhen` filter in [SideEffectListener].
///
/// Unlike [BlocListenerCondition], this takes a single effect (not previous/current)
/// because effects are ephemeral one-shot actions with no "previous" value.
typedef SideEffectListenerCondition<E> = bool Function(E effect);

/// A widget that listens to side effects emitted by a [Bloc] or [Cubit] that
/// uses [SideEffectMixin].
///
/// Similar to [BlocListener], but for effects instead of state changes.
/// The [listener] callback is invoked once per effect and does NOT trigger
/// widget rebuilds.
///
/// ```dart
/// SideEffectListener<AuthBloc, AuthEffect>(
///   listener: (context, effect) {
///     switch (effect) {
///       case NavigateToHome():
///         Navigator.of(context).pushReplacementNamed('/home');
///       case ShowError(:final message):
///         ScaffoldMessenger.of(context).showSnackBar(
///           SnackBar(content: Text(message)),
///         );
///     }
///   },
///   child: LoginForm(),
/// )
/// ```
class SideEffectListener<B extends BlocBase<dynamic>, E>
    extends StatefulWidget {
  /// Creates a [SideEffectListener].
  ///
  /// The [listener] is required and called once per emitted effect.
  /// If [bloc] is omitted, it is resolved via `context.read<B>()`.
  const SideEffectListener({
    required this.listener,
    this.bloc,
    this.listenWhen,
    this.child,
    super.key,
  });

  /// The bloc or cubit to listen to.
  ///
  /// If `null`, resolved via `context.read<B>()`.
  final B? bloc;

  /// Called once per side effect.
  final SideEffectListenerCallback<E> listener;

  /// Optional filter. If provided, [listener] is only called when this
  /// returns `true` for the given effect.
  final SideEffectListenerCondition<E>? listenWhen;

  /// The child widget.
  final Widget? child;

  @override
  State<SideEffectListener<B, E>> createState() =>
      _SideEffectListenerState<B, E>();
}

class _SideEffectListenerState<B extends BlocBase<dynamic>, E>
    extends State<SideEffectListener<B, E>> {
  StreamSubscription<E>? _subscription;
  late B _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = widget.bloc ?? context.read<B>();
    _assertMixin(_bloc);
    _subscribe();
  }

  @override
  void didUpdateWidget(SideEffectListener<B, E> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldBloc = oldWidget.bloc ?? _bloc;
    final newBloc = widget.bloc ?? context.read<B>();
    if (oldBloc != newBloc) {
      _unsubscribe();
      _bloc = newBloc;
      _assertMixin(_bloc);
      _subscribe();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bloc = widget.bloc ?? context.read<B>();
    if (_bloc != bloc) {
      _unsubscribe();
      _bloc = bloc;
      _assertMixin(_bloc);
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    final mixin = _bloc as SideEffectMixin<dynamic, E>;
    _subscription = mixin.effects.listen((effect) {
      if (widget.listenWhen?.call(effect) ?? true) {
        widget.listener(context, effect);
      }
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _assertMixin(B bloc) {
    assert(
      bloc is SideEffectMixin<dynamic, E>,
      '${bloc.runtimeType} does not use SideEffectMixin<dynamic, $E>. '
      'Make sure your Bloc or Cubit includes '
      '"with SideEffectMixin<YourState, $E>".',
    );
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
