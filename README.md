# bloc_effect

A side-effect system for Flutter BLoC. Separate **what the screen IS** (state) from **what the screen DOES** (effects).

Side effects like navigation, snackbars, and dialogs are ephemeral one-shot actions that don't belong in persistent state. `bloc_effect` introduces a **dual-channel architecture** where your Bloc exposes two outputs: **State** and **Effect**.

## Why?

Modeling side effects as state causes:

- **Unnecessary rebuilds** — the widget tree rebuilds just to trigger a navigation
- **Ghost states** — `ShowSnackbar` lingers in state after the snackbar is dismissed
- **Cleanup boilerplate** — you need artificial resets like `emit(state.copyWith(snackbar: null))`

`bloc_effect` solves this with a dedicated effect channel that is fire-and-forget.

## Features

- **Buffered `EffectController`** — effects emitted before widget subscription are never lost
- **Re-subscription safe** — widget unmount/remount (navigation push/pop) works without losing effects
- **`EffectObserver`** — global observability for logging, analytics, and crash reporting
- **Zero extra dependencies** — only `bloc` and `flutter_bloc`
- **Familiar API** — mirrors `BlocListener`/`BlocConsumer` naming and conventions
- **Bloc and Cubit support** — single mixin on `BlocBase`
- **Dedicated test package** — `blocEffectTest()` helper

## Packages

| Package | Description | pub.dev |
|---|---|---|
| [`bloc_effect`](packages/bloc_effect/) | Core Dart package — `EffectController`, `SideEffectMixin`, `EffectObserver` | — |
| [`flutter_bloc_effect`](packages/flutter_bloc_effect/) | Flutter widgets — `SideEffectListener`, `SideEffectConsumer` | — |
| [`bloc_effect_test`](packages/bloc_effect_test/) | Test utilities — `blocEffectTest()` | — |

## Installation

```yaml
dependencies:
  flutter_bloc_effect: ^0.1.0
```

`flutter_bloc_effect` re-exports `bloc_effect`, so a single dependency is all you need.

For testing:

```yaml
dev_dependencies:
  bloc_effect_test: ^0.1.0
```

## Quick Start

### 1. Define your effects

```dart
sealed class LoginEffect {}

class NavigateToHome extends LoginEffect {}

class ShowErrorSnackbar extends LoginEffect {
  final String message;
  ShowErrorSnackbar(this.message);
}
```

### 2. Add the mixin to your Bloc or Cubit

```dart
class LoginCubit extends Cubit<LoginState>
    with SideEffectMixin<LoginState, LoginEffect> {

  Future<void> login(String email, String password) async {
    emit(LoginLoading());
    try {
      await authRepo.login(email, password);
      emit(LoginSuccess());
      emitEffect(NavigateToHome());       // One-shot effect
    } catch (e) {
      emit(LoginInitial());
      emitEffect(ShowErrorSnackbar(e.toString()));
    }
  }
}
```

Works the same with `Bloc`:

```dart
class LoginBloc extends Bloc<LoginEvent, LoginState>
    with SideEffectMixin<LoginState, LoginEffect> {

  LoginBloc() : super(LoginInitial()) {
    on<LoginRequested>((event, emit) async {
      emit(LoginLoading());
      // ...
      emitEffect(NavigateToHome());
    });
  }
}
```

### 3. Listen to effects in the UI

**`SideEffectListener`** — reacts to effects without rebuilding:

```dart
SideEffectListener<LoginCubit, LoginEffect>(
  listener: (context, effect) {
    switch (effect) {
      case NavigateToHome():
        Navigator.of(context).pushReplacementNamed('/home');
      case ShowErrorSnackbar(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  },
  child: LoginForm(),
)
```

**`SideEffectConsumer`** — combines state builder + effect listener:

```dart
SideEffectConsumer<LoginCubit, LoginState, LoginEffect>(
  builder: (context, state) {
    if (state is LoginLoading) return CircularProgressIndicator();
    return LoginForm();
  },
  listener: (context, effect) {
    if (effect is NavigateToHome) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  },
)
```

### 4. Optional: Global observer

```dart
void main() {
  EffectObserver.instance = LoggingEffectObserver();
  runApp(MyApp());
}

class LoggingEffectObserver extends EffectObserver {
  @override
  void onEffect(BlocBase bloc, Object? effect) {
    debugPrint('[Effect] ${bloc.runtimeType} -> $effect');
  }
}
```

## Testing

Use `blocEffectTest` to verify both states and effects:

```dart
blocEffectTest<LoginCubit, LoginState, LoginEffect>(
  'emits LoginSuccess state and NavigateToHome effect on successful login',
  build: () => LoginCubit(authRepo: mockAuthRepo),
  act: (cubit) => cubit.login('test@test.com', 'password'),
  expect: () => [isA<LoginLoading>(), isA<LoginSuccess>()],
  expectEffects: () => [isA<NavigateToHome>()],
);
```

## API Reference

### `SideEffectMixin<State, Effect>`

| Member | Description |
|---|---|
| `Stream<Effect> effects` | The stream of side effects |
| `void emitEffect(Effect effect)` | Emits a side effect |

### `SideEffectListener<B, E>`

| Parameter | Type | Description |
|---|---|---|
| `listener` | `void Function(BuildContext, E)` | Called once per effect |
| `bloc` | `B?` | Optional — resolved via `context.read<B>()` |
| `listenWhen` | `bool Function(E)?` | Optional effect filter |
| `child` | `Widget?` | Child widget |

### `SideEffectConsumer<B, S, E>`

| Parameter | Type | Description |
|---|---|---|
| `builder` | `Widget Function(BuildContext, S)` | Builds UI from state |
| `listener` | `void Function(BuildContext, E)` | Called once per effect |
| `bloc` | `B?` | Optional — resolved via `context.read<B>()` |
| `buildWhen` | `bool Function(S, S)?` | State filter for builder |
| `listenWhen` | `bool Function(E)?` | Effect filter for listener |

### `EffectController<E>`

Buffered broadcast stream controller. Effects emitted before any listener subscribes are queued and flushed when the first listener attaches. Supports re-subscription after cancel.

### `EffectObserver`

Set `EffectObserver.instance` at app startup to observe all effects globally.

## How Buffering Works

```
Timeline:
  Bloc created        → emitEffect(A)  → emitEffect(B)  → Widget subscribes → emitEffect(C)
  [no listener]         [buffered]        [buffered]        [flush A, B]       [delivered live]
```

If the widget unmounts (e.g. navigation) and remounts later, any effects emitted during the gap are buffered and delivered when the new listener subscribes.

## Development

This project uses a Dart workspace. To get started:

```bash
# Resolve dependencies
dart pub get

# Run all Dart tests
dart test packages/bloc_effect/test/ packages/bloc_effect_test/test/

# Run Flutter widget tests
flutter test packages/flutter_bloc_effect/test/

# Static analysis
dart analyze packages/

# Format check
dart format --set-exit-if-changed packages/
```

## License

MIT — see [LICENSE](packages/bloc_effect/LICENSE) for details.
