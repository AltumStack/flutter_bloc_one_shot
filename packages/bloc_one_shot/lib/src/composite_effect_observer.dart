import 'package:bloc/bloc.dart';

import 'effect_observer.dart';

/// An [EffectObserver] that delegates to multiple child observers.
///
/// Use this when you need several independent observers (e.g. logging,
/// analytics, crash reporting) without manually combining them into a
/// single class.
///
/// ```dart
/// void main() {
///   EffectObserver.instance = CompositeEffectObserver([
///     LoggingEffectObserver(),
///     AnalyticsEffectObserver(),
///     SentryEffectObserver(),
///   ]);
///   runApp(MyApp());
/// }
/// ```
class CompositeEffectObserver extends EffectObserver {
  /// Creates a [CompositeEffectObserver] that delegates to [observers].
  CompositeEffectObserver(this.observers);

  /// The list of child observers to notify.
  final List<EffectObserver> observers;

  @override
  void onEffect(BlocBase<dynamic> bloc, Object? effect) {
    for (final observer in observers) {
      observer.onEffect(bloc, effect);
    }
  }
}
