# bloc_one_shot

[![bloc_one_shot](https://img.shields.io/pub/v/bloc_one_shot.svg?label=bloc_one_shot)](https://pub.dev/packages/bloc_one_shot)
[![flutter_bloc_one_shot](https://img.shields.io/pub/v/flutter_bloc_one_shot.svg?label=flutter_bloc_one_shot)](https://pub.dev/packages/flutter_bloc_one_shot)
[![bloc_one_shot_test](https://img.shields.io/pub/v/bloc_one_shot_test.svg?label=bloc_one_shot_test)](https://pub.dev/packages/bloc_one_shot_test)
[![codecov](https://codecov.io/gh/AltumStack/flutter_bloc_one_shot/branch/master/graph/badge.svg)](https://app.codecov.io/github/AltumStack/flutter_bloc_one_shot)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A side-effect system for Flutter BLoC. Separate **what the screen IS** (state) from **what the screen DOES** (effects).

📖 [Read the full article on Medium](https://medium.com/@amarturelo/side-effects-in-flutter-bloc-2026-transient-states-or-separate-stream-eef506b91a10)

Side effects like navigation, snackbars, and dialogs are ephemeral one-shot actions that don't belong in persistent state. `bloc_one_shot` introduces a **dual-channel architecture** where your Bloc exposes two outputs: **State** and **Effect**.

## Why?

Modeling side effects as state causes:

- **Unnecessary rebuilds** — the widget tree rebuilds just to trigger a navigation
- **Ghost states** — `ShowSnackbar` lingers in state after the snackbar is dismissed
- **Cleanup boilerplate** — you need artificial resets like `emit(state.copyWith(snackbar: null))`

`bloc_one_shot` solves this with a dedicated effect channel that is fire-and-forget.

## Features

- **Buffered `EffectController`** — effects emitted before widget subscription are never lost
- **Re-subscription safe** — widget unmount/remount (navigation push/pop) works without losing effects
- **`EffectObserver`** — global observability for logging, analytics, and crash reporting
- **Zero extra dependencies** — only `bloc` and `flutter_bloc`
- **Familiar API** — mirrors `BlocListener`/`BlocConsumer` naming and conventions
- **Bloc and Cubit support** — single mixin on `BlocBase`
- **Dedicated test package** — `blocEffectTest()` helper

## Packages

| Package | Description | Version |
| --- | --- | --- |
| [`bloc_one_shot`](packages/bloc_one_shot/) | Core Dart package — `EffectController`, `SideEffectMixin`, `EffectObserver` | `0.1.0` |
| [`flutter_bloc_one_shot`](packages/flutter_bloc_one_shot/) | Flutter widgets — `SideEffectProvider`, `SideEffectListener`, `SideEffectConsumer`, `MultipleSideEffectListener` | `0.2.0` |
| [`bloc_one_shot_test`](packages/bloc_one_shot_test/) | Test utilities — `blocEffectTest()` | `0.1.0` |

## Installation

```yaml
dependencies:
  flutter_bloc_one_shot: ^0.2.0
```

`flutter_bloc_one_shot` re-exports `bloc_one_shot`, so a single dependency is all you need.

For testing:

```yaml
dev_dependencies:
  bloc_one_shot_test: ^0.1.0
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

**`SideEffectProvider`** — creates/provides a Bloc and listens to effects in one widget:

```dart
SideEffectProvider<LoginCubit, LoginEffect>(
  create: (_) => LoginCubit(),
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

**`MultipleSideEffectListener`** — listens to effects from multiple blocs without nesting:

```dart
MultipleSideEffectListener(
  listeners: [
    SideEffectListener<AuthBloc, AuthEffect>(
      listener: (context, effect) { /* ... */ },
    ),
    SideEffectListener<NotificationBloc, NotificationEffect>(
      listener: (context, effect) { /* ... */ },
    ),
  ],
  child: HomePage(),
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
| --- | --- |
| `Stream<Effect> effects` | The stream of side effects |
| `void emitEffect(Effect effect)` | Emits a side effect |

### `SideEffectProvider<B, E>`

| Parameter | Type | Description |
| --- | --- | --- |
| `create` | `B Function(BuildContext)` | Creates the Bloc (default constructor) |
| `value` | `B` | Existing Bloc instance (`.value` constructor) |
| `listener` | `void Function(BuildContext, E)` | Called once per effect |
| `listenWhen` | `bool Function(E)?` | Optional effect filter |
| `lazy` | `bool` | Lazily create the Bloc (default: `true`) |
| `child` | `Widget?` | Child widget |

### `SideEffectListener<B, E>`

| Parameter | Type | Description |
| --- | --- | --- |
| `listener` | `void Function(BuildContext, E)` | Called once per effect |
| `bloc` | `B?` | Optional — resolved via `context.read<B>()` |
| `listenWhen` | `bool Function(E)?` | Optional effect filter |
| `child` | `Widget?` | Child widget |

### `MultipleSideEffectListener`

| Parameter | Type | Description |
| --- | --- | --- |
| `listeners` | `List<SingleChildWidget>` | List of `SideEffectListener` widgets |
| `child` | `Widget` | Child widget rendered below all listeners |

### `SideEffectConsumer<B, S, E>`

| Parameter | Type | Description |
| --- | --- | --- |
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

```text
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
dart test packages/bloc_one_shot/test/ packages/bloc_one_shot_test/test/

# Run Flutter widget tests
flutter test packages/flutter_bloc_one_shot/test/

# Static analysis
dart analyze packages/

# Format check
dart format --set-exit-if-changed packages/
```

## Contributing

Contributions are welcome! To get started:

1. Fork the repo and create your branch from `develop`
2. Run `dart pub get` to resolve dependencies
3. Make your changes and add tests
4. Ensure all checks pass:

   ```bash
   dart test packages/bloc_one_shot/test/ packages/bloc_one_shot_test/test/
   flutter test packages/flutter_bloc_one_shot/test/
   dart analyze packages/
   dart format --set-exit-if-changed packages/
   ```

5. Update the CHANGELOG of the affected packages
6. Open a pull request — the [PR template](.github/PULL_REQUEST_TEMPLATE.md) will guide you through the required information

## License

MIT — see [LICENSE](packages/bloc_one_shot/LICENSE) for details.
