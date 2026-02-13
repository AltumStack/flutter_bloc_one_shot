import 'package:bloc/bloc.dart';
import 'package:bloc_effect/src/effect_controller.dart';
import 'package:bloc_effect/src/effect_observer.dart';

/// A mixin that adds side-effect emission capability to any [Bloc] or [Cubit].
///
/// Side effects are ephemeral, one-shot actions (navigation, snackbars, dialogs)
/// that should not be modeled as persistent state.
///
/// Usage with Bloc:
/// ```dart
/// class AuthBloc extends Bloc<AuthEvent, AuthState>
///     with SideEffectMixin<AuthState, AuthEffect> {
///   AuthBloc() : super(AuthInitial()) {
///     on<LoginRequested>((event, emit) async {
///       emit(AuthLoading());
///       try {
///         await _authRepo.login(event.credentials);
///         emit(AuthAuthenticated());
///         emitEffect(NavigateToHome());
///       } catch (e) {
///         emitEffect(ShowErrorSnackbar(e.toString()));
///       }
///     });
///   }
/// }
/// ```
///
/// Usage with Cubit:
/// ```dart
/// class AuthCubit extends Cubit<AuthState>
///     with SideEffectMixin<AuthState, AuthEffect> {
///   Future<void> login(Credentials credentials) async {
///     emit(AuthLoading());
///     try {
///       await _authRepo.login(credentials);
///       emit(AuthAuthenticated());
///       emitEffect(NavigateToHome());
///     } catch (e) {
///       emitEffect(ShowErrorSnackbar(e.toString()));
///     }
///   }
/// }
/// ```
mixin SideEffectMixin<State, Effect> on BlocBase<State> {
  late final EffectController<Effect> _effectController =
      EffectController<Effect>();

  /// The stream of side effects emitted by this bloc/cubit.
  ///
  /// Subscribe to this stream to react to one-shot actions like navigation,
  /// showing snackbars, or opening dialogs.
  Stream<Effect> get effects => _effectController.stream;

  /// Emits a side [effect].
  ///
  /// The effect is delivered to any active listener immediately, or buffered
  /// if no listener is currently subscribed. Buffered effects are flushed
  /// when a listener subscribes.
  ///
  /// If an [EffectObserver] is set, it is notified before the effect is
  /// added to the controller.
  void emitEffect(Effect effect) {
    EffectObserver.instance?.onEffect(this, effect);
    _effectController.add(effect);
  }

  @override
  Future<void> close() {
    _effectController.close();
    return super.close();
  }
}
