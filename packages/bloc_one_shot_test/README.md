# bloc_one_shot_test

[![pub package](https://img.shields.io/pub/v/bloc_one_shot_test.svg)](https://pub.dev/packages/bloc_one_shot_test)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Test utilities for [`bloc_one_shot`](https://pub.dev/packages/bloc_one_shot). Provides a `blocEffectTest` helper that mirrors the `blocTest` API with added effect verification.

## Installation

```yaml
dev_dependencies:
  bloc_one_shot_test: ^0.1.0
```

## Usage

### `blocEffectTest`

A test helper for Blocs and Cubits that use `SideEffectMixin`. It verifies both **state emissions** and **side effect emissions** in a single test.

```dart
import 'package:bloc_one_shot_test/bloc_one_shot_test.dart';

blocEffectTest<LoginCubit, LoginState, LoginEffect>(
  'emits [Loading, Success] and NavigateToHome on login',
  build: () => LoginCubit(authRepo: mockAuthRepo),
  act: (cubit) => cubit.login('user@example.com', 'password'),
  expect: () => [
    isA<LoginLoading>(),
    isA<LoginSuccess>(),
  ],
  expectEffects: () => [
    isA<NavigateToHome>(),
  ],
);
```

### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `description` | `String` | Yes | Test description |
| `build` | `B Function()` | Yes | Factory that creates the Bloc/Cubit under test |
| `act` | `FutureOr<void> Function(B)?` | No | Interaction with the Bloc/Cubit (add events, call methods) |
| `wait` | `Duration?` | No | Additional wait time for async operations |
| `skipStates` | `int` | No | Number of initial state emissions to skip (default: `0`) |
| `skipEffects` | `int` | No | Number of initial effect emissions to skip (default: `0`) |
| `expect` | `dynamic Function()?` | No | Expected states — same as `blocTest` |
| `expectEffects` | `dynamic Function()?` | No | Expected side effects |
| `verify` | `FutureOr<void> Function(B)?` | No | Additional verification after the test |
| `setUp` | `FutureOr<void> Function()?` | No | Setup callback before the test |
| `tearDown` | `FutureOr<void> Function()?` | No | Teardown callback after the test |

### Examples

#### Verify only effects (no state change)

```dart
blocEffectTest<AuthCubit, AuthState, AuthEffect>(
  'emits ShowErrorSnackbar when login fails',
  build: () => AuthCubit(authRepo: failingMockRepo),
  act: (cubit) => cubit.login('bad@email.com', 'wrong'),
  expect: () => [isA<AuthLoading>(), isA<AuthInitial>()],
  expectEffects: () => [isA<ShowErrorSnackbar>()],
);
```

#### Verify no effects were emitted

```dart
blocEffectTest<CounterCubit, int, CounterEffect>(
  'does not emit effects on normal increment',
  build: () => CounterCubit(),
  act: (cubit) => cubit.increment(),
  expect: () => [1],
  expectEffects: () => <CounterEffect>[],
);
```

#### Skip initial emissions

```dart
blocEffectTest<CounterBloc, int, CounterEffect>(
  'only checks the last state after 3 increments',
  build: () => CounterBloc(),
  act: (bloc) {
    bloc.add(Increment());
    bloc.add(Increment());
    bloc.add(Increment());
  },
  wait: const Duration(milliseconds: 50),
  skipStates: 2,
  expect: () => [3],
);
```

#### With setUp, tearDown, and verify

```dart
blocEffectTest<AuthCubit, AuthState, AuthEffect>(
  'navigates to home on successful login',
  setUp: () {
    // Prepare mocks, test fixtures, etc.
    when(() => mockRepo.login(any(), any())).thenAnswer((_) async {});
  },
  build: () => AuthCubit(authRepo: mockRepo),
  act: (cubit) => cubit.login('test@test.com', 'password'),
  expectEffects: () => [isA<NavigateToHome>()],
  verify: (cubit) {
    verify(() => mockRepo.login('test@test.com', 'password')).called(1);
  },
  tearDown: () {
    // Clean up resources
  },
);
```

#### Works with both Bloc and Cubit

```dart
// Bloc
blocEffectTest<LoginBloc, LoginState, LoginEffect>(
  'Bloc: emits NavigateToHome',
  build: () => LoginBloc(),
  act: (bloc) => bloc.add(LoginRequested(email: 'a', password: 'b')),
  expectEffects: () => [isA<NavigateToHome>()],
);

// Cubit
blocEffectTest<LoginCubit, LoginState, LoginEffect>(
  'Cubit: emits NavigateToHome',
  build: () => LoginCubit(),
  act: (cubit) => cubit.login('a', 'b'),
  expectEffects: () => [isA<NavigateToHome>()],
);
```

#### Async operations with wait

For Blocs with async event handlers, use `wait` to allow time for operations to complete:

```dart
blocEffectTest<AuthBloc, AuthState, AuthEffect>(
  'handles async login with network delay',
  build: () => AuthBloc(authRepo: slowMockRepo),
  act: (bloc) => bloc.add(LoginRequested(email: 'a', password: 'b')),
  wait: const Duration(milliseconds: 300),
  expect: () => [isA<AuthLoading>(), isA<AuthSuccess>()],
  expectEffects: () => [isA<NavigateToHome>()],
);
```

## How It Works

`blocEffectTest` creates a test that:

1. Calls `setUp` (if provided)
2. Builds the Bloc/Cubit via `build()`
3. Subscribes to both `bloc.stream` (states) and `bloc.effects` (side effects)
4. Calls `act` to interact with the Bloc/Cubit
5. Waits for the specified `wait` duration (or two microtask cycles by default)
6. Asserts collected states against `expect`
7. Asserts collected effects against `expectEffects`
8. Calls `verify` for additional assertions
9. Closes the Bloc/Cubit
10. Calls `tearDown` (if provided)

## Comparison with blocTest

| Feature | `blocTest` | `blocEffectTest` |
| --- | --- | --- |
| Verify states | `expect` | `expect` |
| Verify effects | N/A | `expectEffects` |
| Skip states | `skip` | `skipStates` |
| Skip effects | N/A | `skipEffects` |
| setUp / tearDown | Yes | Yes |
| verify | Yes | Yes |
| wait | Yes | Yes |

## License

MIT — see [LICENSE](LICENSE) for details.
