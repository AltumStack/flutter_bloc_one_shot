# bloc_one_shot

[![pub package](https://img.shields.io/pub/v/bloc_one_shot.svg)](https://pub.dev/packages/bloc_one_shot)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Core Dart package for managing side effects in BLoC. Provides a buffered `EffectController`, `SideEffectMixin` for Bloc/Cubit, and a global `EffectObserver`.

> **For Flutter widgets** (`SideEffectListener`, `SideEffectConsumer`), see [`flutter_bloc_one_shot`](https://pub.dev/packages/flutter_bloc_one_shot).
>
> **For test utilities** (`blocEffectTest`), see [`bloc_one_shot_test`](https://pub.dev/packages/bloc_one_shot_test).

## The Problem

In Flutter BLoC, side effects like navigation, snackbars, and dialogs are ephemeral one-shot actions. Modeling them as persistent state causes:

| Problem | Example |
|---|---|
| Unnecessary rebuilds | Widget tree rebuilds just to trigger a navigation |
| Ghost states | `ShowSnackbar` lingers in state after dismissal |
| Cleanup boilerplate | `emit(state.copyWith(snackbar: null))` after every effect |

## The Solution

`bloc_one_shot` introduces a **dual-channel architecture**: your Bloc emits **State** (what the screen IS) and **Effect** (what the screen DOES) through separate channels.

```
┌─────────────┐
│  Bloc/Cubit  │
├──────┬───────┤
│ State│ Effect│
│ stream│ stream│
└──┬───┴───┬───┘
   │       │
   ▼       ▼
Builder  Listener
(rebuilds) (fire & forget)
```

## Installation

```yaml
dependencies:
  bloc_one_shot: ^0.1.0
```

## Usage

### 1. Define your effects

```dart
sealed class AuthEffect {}

class NavigateToHome extends AuthEffect {}

class ShowErrorSnackbar extends AuthEffect {
  final String message;
  ShowErrorSnackbar(this.message);
}
```

### 2. Add the mixin to a Cubit

```dart
class AuthCubit extends Cubit<AuthState>
    with SideEffectMixin<AuthState, AuthEffect> {

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      await _authRepo.login(email, password);
      emit(AuthSuccess());
      emitEffect(NavigateToHome());
    } catch (e) {
      emit(AuthInitial());
      emitEffect(ShowErrorSnackbar(e.toString()));
    }
  }
}
```

### 3. Add the mixin to a Bloc

```dart
class AuthBloc extends Bloc<AuthEvent, AuthState>
    with SideEffectMixin<AuthState, AuthEffect> {

  AuthBloc() : super(AuthInitial()) {
    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await _authRepo.login(event.email, event.password);
        emit(AuthSuccess());
        emitEffect(NavigateToHome());
      } catch (e) {
        emit(AuthInitial());
        emitEffect(ShowErrorSnackbar(e.toString()));
      }
    });
  }
}
```

### 4. Listen to effects

```dart
final cubit = AuthCubit();

// Subscribe to effects
cubit.effects.listen((effect) {
  switch (effect) {
    case NavigateToHome():
      print('Navigate!');
    case ShowErrorSnackbar(:final message):
      print('Error: $message');
  }
});

// Subscribe to state (works independently)
cubit.stream.listen((state) {
  print('State: $state');
});
```

## API Reference

### `SideEffectMixin<State, Effect>`

A mixin constrained to `BlocBase<State>`, compatible with both `Bloc` and `Cubit`.

| Member | Type | Description |
|---|---|---|
| `effects` | `Stream<Effect>` | Broadcast stream of side effects |
| `emitEffect(effect)` | `void` | Emits a side effect — delivered live or buffered |

The effect controller is automatically closed when the Bloc/Cubit closes.

### `EffectController<E>`

A broadcast stream controller with **manual buffering**. This is the engine behind `SideEffectMixin`.

| Member | Type | Description |
|---|---|---|
| `add(effect)` | `void` | Adds an effect — delivers live or buffers |
| `stream` | `Stream<E>` | The broadcast stream |
| `isClosed` | `bool` | Whether the controller has been closed |
| `close()` | `Future<void>` | Closes the controller and clears the buffer |

**Buffering behavior:**

| Scenario | Behavior |
|---|---|
| Effect emitted, no listener | Queued in buffer |
| Listener subscribes | Buffer flushed synchronously |
| Listener cancels (widget dispose) | Subsequent effects buffered |
| New listener after cancel | Buffer flushed again |
| `add()` after `close()` | Throws `StateError` |
| Multiple listeners active | All receive live events (broadcast) |

**Why broadcast + manual buffer?**

A single-subscription `StreamController` buffers automatically but does NOT support re-subscription. Once the listener cancels (e.g. widget disposes during navigation), you cannot listen again. The broadcast approach handles re-subscription naturally.

```
Timeline:
  emitEffect(A)  →  emitEffect(B)  →  Widget subscribes  →  emitEffect(C)
  [buffered]         [buffered]        [flush A, B]          [delivered live]

  Widget disposes  →  emitEffect(D)  →  Widget remounts
  [cancel]            [buffered]        [flush D]
```

### `EffectObserver`

Global observability for all side effects across the app. Analogous to `BlocObserver`.

```dart
void main() {
  EffectObserver.instance = AppEffectObserver();
  runApp(MyApp());
}

class AppEffectObserver extends EffectObserver {
  @override
  void onEffect(BlocBase bloc, Object? effect) {
    debugPrint('[Effect] ${bloc.runtimeType} -> $effect');
  }
}
```

**Use cases:**

- **Development logging** — print all effects to console
- **Analytics** — track navigations, dialogs, user-facing actions
- **Crash reporting** — attach recent effects as breadcrumbs (Sentry, Crashlytics)
- **Integration testing** — assert global effect behavior

| Member | Type | Description |
|---|---|---|
| `onEffect(bloc, effect)` | `void` | Called on every `emitEffect` across the app |
| `EffectObserver.instance` | `static EffectObserver?` | Global instance — set at app startup |

### `CompositeEffectObserver`

An `EffectObserver` that delegates to multiple child observers. Use this when you need several independent observers (e.g. logging, analytics, crash reporting) without manually combining them into a single class.

```dart
void main() {
  EffectObserver.instance = CompositeEffectObserver([
    LoggingEffectObserver(),
    AnalyticsEffectObserver(),
    SentryEffectObserver(),
  ]);
  runApp(MyApp());
}
```

| Member | Type | Description |
|---|---|---|
| `observers` | `List<EffectObserver>` | The list of child observers to notify |

## Comparison with Alternatives

| Feature | `bloc_one_shot` | `bloc_presentation` | `bloc_one_shots` | `side_effect_bloc` |
|---|---|---|---|---|
| Buffering | Yes | No | No | No |
| Re-subscription safe | Yes | No | No | No |
| Global observer | Yes | No | No | No |
| Cubit support | Yes | Yes | Yes | No |
| Extra dependencies | None | `nested` | None | `provider` |

## License

MIT — see [LICENSE](LICENSE) for details.
