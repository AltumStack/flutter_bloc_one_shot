import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_effect/bloc_effect.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart' as test;

/// Creates a test for a bloc or cubit that uses [SideEffectMixin].
///
/// Mirrors the `blocTest` API from `bloc_test` with added effect verification:
/// - [expect] verifies emitted states (same as `blocTest`)
/// - [expectEffects] verifies emitted side effects
///
/// ```dart
/// blocEffectTest<AuthBloc, AuthState, AuthEffect>(
///   'emits [Loading, Authenticated] and NavigateToHome effect',
///   build: () => AuthBloc(authRepo: mockAuthRepo),
///   act: (bloc) => bloc.add(LoginRequested(credentials)),
///   expect: () => [AuthLoading(), AuthAuthenticated()],
///   expectEffects: () => [NavigateToHome()],
/// );
/// ```
@isTest
void blocEffectTest<B extends BlocBase<State>, State, Effect>(
  String description, {
  required B Function() build,
  FutureOr<void> Function(B bloc)? act,
  Duration? wait,
  int skipStates = 0,
  int skipEffects = 0,
  dynamic Function()? expect,
  dynamic Function()? expectEffects,
  FutureOr<void> Function(B bloc)? verify,
  FutureOr<void> Function()? setUp,
  FutureOr<void> Function()? tearDown,
}) {
  test.test(description, () async {
    if (setUp != null) await setUp();

    final bloc = build();

    final states = <State>[];
    final effects = <Effect>[];

    final stateSubscription = bloc.stream.skip(skipStates).listen(states.add);

    StreamSubscription<Effect>? effectSubscription;
    if (bloc is SideEffectMixin<State, Effect>) {
      effectSubscription = bloc.effects.skip(skipEffects).listen(effects.add);
    }

    if (act != null) await act(bloc);

    // Allow microtasks and event handlers to complete.
    if (wait != null) {
      await Future<void>.delayed(wait);
    } else {
      // Give enough time for async event handlers.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    await stateSubscription.cancel();
    await effectSubscription?.cancel();

    if (expect != null) {
      final expected = expect();
      test.expect(states, expected);
    }

    if (expectEffects != null) {
      final expected = expectEffects();
      test.expect(effects, expected);
    }

    if (verify != null) await verify(bloc);

    await bloc.close();

    if (tearDown != null) await tearDown();
  });
}
