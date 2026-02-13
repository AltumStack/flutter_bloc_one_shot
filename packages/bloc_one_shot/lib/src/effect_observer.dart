import 'package:bloc/bloc.dart';

/// An abstract class that provides global observability for side effects.
///
/// Analogous to [BlocObserver] but for effects. Set [instance] at app startup
/// to receive callbacks whenever any bloc or cubit emits a side effect.
///
/// ```dart
/// void main() {
///   EffectObserver.instance = MyEffectObserver();
///   runApp(MyApp());
/// }
///
/// class MyEffectObserver extends EffectObserver {
///   @override
///   void onEffect(BlocBase bloc, Object effect) {
///     debugPrint('[Effect] ${bloc.runtimeType} → $effect');
///   }
/// }
/// ```
abstract class EffectObserver {
  /// Called whenever any bloc/cubit emits a side effect via [SideEffectMixin].
  ///
  /// [bloc] is the bloc or cubit that emitted the effect.
  /// [effect] is the emitted effect object.
  void onEffect(BlocBase<dynamic> bloc, Object? effect) {}

  /// The global observer instance.
  ///
  /// Set this at app startup to observe all side effects across the app.
  /// If `null`, no observation occurs.
  static EffectObserver? instance;
}
