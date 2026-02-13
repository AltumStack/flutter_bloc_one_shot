import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_one_shot/bloc_one_shot.dart';
import 'package:test/test.dart';

// --- Test helpers ---

sealed class TestEffect {}

class NavigateEffect extends TestEffect {
  final String route;
  NavigateEffect(this.route);

  @override
  bool operator ==(Object other) =>
      other is NavigateEffect && other.route == route;

  @override
  int get hashCode => route.hashCode;
}

class ShowSnackbar extends TestEffect {
  final String message;
  ShowSnackbar(this.message);

  @override
  bool operator ==(Object other) =>
      other is ShowSnackbar && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

// Cubit-based
class TestCubit extends Cubit<int> with SideEffectMixin<int, TestEffect> {
  TestCubit() : super(0);

  void doSomething() {
    emit(state + 1);
    emitEffect(NavigateEffect('/home'));
  }

  void showMessage(String msg) {
    emitEffect(ShowSnackbar(msg));
  }
}

// Bloc-based
sealed class TestEvent {}

class DoSomethingEvent extends TestEvent {}

class TestBloc extends Bloc<TestEvent, int>
    with SideEffectMixin<int, TestEffect> {
  TestBloc() : super(0) {
    on<DoSomethingEvent>((event, emit) {
      emit(state + 1);
      emitEffect(NavigateEffect('/dashboard'));
    });
  }
}

class _TestObserver extends EffectObserver {
  final List<(BlocBase<dynamic>, Object?)> calls = [];

  @override
  void onEffect(BlocBase<dynamic> bloc, Object? effect) {
    calls.add((bloc, effect));
  }
}

// --- Tests ---

void main() {
  group('SideEffectMixin', () {
    group('with Cubit', () {
      late TestCubit cubit;

      setUp(() {
        cubit = TestCubit();
      });

      tearDown(() async {
        await cubit.close();
      });

      test('emitEffect delivers effect to stream', () async {
        final effects = <TestEffect>[];
        cubit.effects.listen(effects.add);
        await Future<void>.delayed(Duration.zero);

        cubit.emitEffect(NavigateEffect('/home'));
        await Future<void>.delayed(Duration.zero);

        expect(effects, [NavigateEffect('/home')]);
      });

      test('effects stream buffers before listener', () async {
        cubit.emitEffect(NavigateEffect('/a'));
        cubit.emitEffect(ShowSnackbar('hello'));

        final effects = <TestEffect>[];
        cubit.effects.listen(effects.add);
        await Future<void>.delayed(Duration.zero);

        expect(effects, [NavigateEffect('/a'), ShowSnackbar('hello')]);
      });

      test('state and effects work independently', () async {
        final states = <int>[];
        final effects = <TestEffect>[];

        cubit.stream.listen(states.add);
        cubit.effects.listen(effects.add);
        await Future<void>.delayed(Duration.zero);

        cubit.doSomething();
        await Future<void>.delayed(Duration.zero);

        expect(states, [1]);
        expect(effects, [NavigateEffect('/home')]);
      });

      test('multiple effects emitted in sequence', () async {
        final effects = <TestEffect>[];
        cubit.effects.listen(effects.add);
        await Future<void>.delayed(Duration.zero);

        cubit.showMessage('a');
        cubit.showMessage('b');
        cubit.showMessage('c');
        await Future<void>.delayed(Duration.zero);

        expect(effects, [
          ShowSnackbar('a'),
          ShowSnackbar('b'),
          ShowSnackbar('c'),
        ]);
      });
    });

    group('with Bloc', () {
      late TestBloc bloc;

      setUp(() {
        bloc = TestBloc();
      });

      tearDown(() async {
        await bloc.close();
      });

      test('emitEffect works in event handler', () async {
        final effects = <TestEffect>[];
        bloc.effects.listen(effects.add);
        await Future<void>.delayed(Duration.zero);

        bloc.add(DoSomethingEvent());
        await Future<void>.delayed(Duration.zero);

        expect(effects, [NavigateEffect('/dashboard')]);
      });

      test('state and effects both update', () async {
        final states = <int>[];
        final effects = <TestEffect>[];

        bloc.stream.listen(states.add);
        bloc.effects.listen(effects.add);
        await Future<void>.delayed(Duration.zero);

        bloc.add(DoSomethingEvent());
        await Future<void>.delayed(Duration.zero);

        expect(states, [1]);
        expect(effects, [NavigateEffect('/dashboard')]);
      });
    });

    group('close', () {
      test('closes effect controller when cubit closes', () async {
        final cubit = TestCubit();
        await cubit.close();

        expect(() => cubit.emitEffect(NavigateEffect('/x')), throwsStateError);
      });

      test('closes effect controller when bloc closes', () async {
        final bloc = TestBloc();
        await bloc.close();

        expect(() => bloc.emitEffect(NavigateEffect('/x')), throwsStateError);
      });
    });

    group('observer integration', () {
      tearDown(() {
        EffectObserver.instance = null;
      });

      test(
        'observer is notified before effect is added to controller',
        () async {
          final observer = _TestObserver();
          EffectObserver.instance = observer;

          final cubit = TestCubit();
          final effects = <TestEffect>[];
          cubit.effects.listen(effects.add);
          await Future<void>.delayed(Duration.zero);

          cubit.emitEffect(NavigateEffect('/home'));

          // Observer is called synchronously before stream delivery.
          expect(observer.calls, hasLength(1));
          expect(observer.calls.first.$1, cubit);
          expect(observer.calls.first.$2, NavigateEffect('/home'));

          await cubit.close();
        },
      );
    });
  });
}
