# flutter_bloc_one_shot

[![pub package](https://img.shields.io/pub/v/flutter_bloc_one_shot.svg)](https://pub.dev/packages/flutter_bloc_one_shot)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Flutter widgets for [`bloc_one_shot`](https://pub.dev/packages/bloc_one_shot). Provides `SideEffectListener` and `SideEffectConsumer` that mirror the `BlocListener`/`BlocConsumer` API you already know.

> **For test utilities** (`blocEffectTest`), see [`bloc_one_shot_test`](https://pub.dev/packages/bloc_one_shot_test).

## Installation

```yaml
dependencies:
  flutter_bloc_one_shot: ^0.1.0
```

This package re-exports `bloc_one_shot`, so you only need a single dependency for both core and widgets.

## Quick Start

### 1. Define effects and add the mixin

```dart
// Effects — ephemeral, one-shot actions
sealed class LoginEffect {}
class NavigateToHome extends LoginEffect {}
class ShowErrorSnackbar extends LoginEffect {
  final String message;
  ShowErrorSnackbar(this.message);
}

// Cubit with SideEffectMixin
class LoginCubit extends Cubit<LoginState>
    with SideEffectMixin<LoginState, LoginEffect> {

  Future<void> login(String email, String password) async {
    emit(LoginLoading());
    try {
      await authRepo.login(email, password);
      emit(LoginSuccess());
      emitEffect(NavigateToHome());           // Side effect
    } catch (e) {
      emit(LoginInitial());
      emitEffect(ShowErrorSnackbar(e.toString()));
    }
  }
}
```

### 2. Use widgets in the UI

See `SideEffectListener` and `SideEffectConsumer` below.

## Widgets

### `SideEffectListener`

Listens to side effects **without rebuilding** the widget tree. Use this for navigation, snackbars, dialogs, and other fire-and-forget actions.

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

#### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `listener` | `void Function(BuildContext, E)` | Yes | Called once per effect |
| `bloc` | `B?` | No | If omitted, resolved via `context.read<B>()` |
| `listenWhen` | `bool Function(E)?` | No | Filter — listener only fires when this returns `true` |
| `child` | `Widget?` | No | Child widget |

#### Bloc resolution

If `bloc` is not provided, `SideEffectListener` resolves it from the widget tree using `context.read<B>()`. This means you can provide your Bloc via `BlocProvider` as usual:

```dart
BlocProvider(
  create: (_) => LoginCubit(),
  child: SideEffectListener<LoginCubit, LoginEffect>(
    listener: (context, effect) { /* ... */ },
    child: LoginForm(),
  ),
)
```

#### Filtering effects

Use `listenWhen` to filter which effects trigger the listener:

```dart
SideEffectListener<LoginCubit, LoginEffect>(
  listenWhen: (effect) => effect is NavigateToHome,
  listener: (context, effect) {
    // Only called for NavigateToHome effects
    Navigator.of(context).pushReplacementNamed('/home');
  },
  child: LoginForm(),
)
```

> **Note:** Unlike `BlocListener`'s condition which receives `(previous, current)`, `listenWhen` takes a single effect. Effects are ephemeral — there is no "previous" effect.

#### Buffered delivery

Effects emitted before the widget subscribes (e.g. during Bloc initialization) are buffered and delivered when the listener mounts:

```dart
// Effect emitted before widget tree is built
final cubit = LoginCubit();
cubit.emitEffect(ShowErrorSnackbar('Session expired'));

// Later, when the widget mounts, it receives the buffered effect
SideEffectListener<LoginCubit, LoginEffect>(
  bloc: cubit,
  listener: (context, effect) {
    // 'Session expired' is delivered here
  },
  child: LoginForm(),
)
```

#### Re-subscription safety

When a widget unmounts (e.g. during navigation) and remounts later, any effects emitted during the gap are buffered and delivered to the new listener:

```
Widget mounts     →  effect A (delivered)  →  Widget unmounts
Widget remounts   →  effect B (was buffered, now delivered)  →  effect C (delivered live)
```

---

### `SideEffectConsumer`

Combines `BlocBuilder` (for state) and `SideEffectListener` (for effects) in a single widget. Equivalent to nesting a `SideEffectListener` around a `BlocBuilder`.

```dart
SideEffectConsumer<LoginCubit, LoginState, LoginEffect>(
  builder: (context, state) {
    return switch (state) {
      LoginLoading() => const Center(child: CircularProgressIndicator()),
      LoginSuccess() => const Center(child: Text('Welcome!')),
      _ => LoginForm(),
    };
  },
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
)
```

#### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `builder` | `Widget Function(BuildContext, S)` | Yes | Builds UI from state |
| `listener` | `void Function(BuildContext, E)` | Yes | Called once per effect |
| `bloc` | `B?` | No | If omitted, resolved via `context.read<B>()` |
| `buildWhen` | `bool Function(S, S)?` | No | State filter — same as `BlocBuilder.buildWhen` |
| `listenWhen` | `bool Function(E)?` | No | Effect filter |

#### Independent filters

`buildWhen` and `listenWhen` operate independently — you can filter state rebuilds without affecting effect delivery, and vice versa:

```dart
SideEffectConsumer<CounterCubit, int, CounterEffect>(
  // Only rebuild when count is even
  buildWhen: (previous, current) => current.isEven,
  // Only listen to overflow effects
  listenWhen: (effect) => effect is ShowOverflow,
  builder: (context, count) => Text('$count'),
  listener: (context, effect) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Counter overflow!')),
    );
  },
)
```

## When to Use What

| Scenario | Widget |
|---|---|
| React to effects only (navigation, snackbar) | `SideEffectListener` |
| Build UI from state only | `BlocBuilder` (from `flutter_bloc`) |
| Build UI from state + react to effects | `SideEffectConsumer` |
| Listen to state changes (not effects) | `BlocListener` (from `flutter_bloc`) |

## Global Effect Observer

Set up a global observer at app startup to log, track, or report all effects:

```dart
void main() {
  EffectObserver.instance = AppEffectObserver();
  runApp(MyApp());
}

class AppEffectObserver extends EffectObserver {
  @override
  void onEffect(BlocBase bloc, Object? effect) {
    debugPrint('[Effect] ${bloc.runtimeType} -> $effect');
    // Also: send to analytics, attach as Sentry breadcrumb, etc.
  }
}
```

## Full Example

```dart
// main.dart
void main() {
  EffectObserver.instance = LoggingEffectObserver();
  runApp(
    MaterialApp(
      home: BlocProvider(
        create: (_) => LoginCubit(),
        child: const LoginPage(),
      ),
    ),
  );
}

// login_page.dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SideEffectConsumer<LoginCubit, LoginState, LoginEffect>(
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
        builder: (context, state) {
          return switch (state) {
            LoginLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            _ => LoginForm(
                onSubmit: (email, password) {
                  context.read<LoginCubit>().login(email, password);
                },
              ),
          };
        },
      ),
    );
  }
}
```

## License

MIT — see [LICENSE](LICENSE) for details.
