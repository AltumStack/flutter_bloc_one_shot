import 'package:bloc/bloc.dart';
import 'package:bloc_one_shot/bloc_one_shot.dart';
import 'package:bloc_one_shot_test/bloc_one_shot_test.dart';

// --- Test helpers ---

sealed class CounterEffect {}

class ShowOverflow extends CounterEffect {
  @override
  bool operator ==(Object other) => other is ShowOverflow;

  @override
  int get hashCode => runtimeType.hashCode;
}

class ShowUnderflow extends CounterEffect {
  @override
  bool operator ==(Object other) => other is ShowUnderflow;

  @override
  int get hashCode => runtimeType.hashCode;
}

sealed class CounterEvent {}

class Increment extends CounterEvent {}

class Decrement extends CounterEvent {}

class CounterBloc extends Bloc<CounterEvent, int>
    with SideEffectMixin<int, CounterEffect> {
  CounterBloc() : super(0) {
    on<Increment>((event, emit) {
      if (state >= 10) {
        emitEffect(ShowOverflow());
      } else {
        emit(state + 1);
      }
    });
    on<Decrement>((event, emit) {
      if (state <= 0) {
        emitEffect(ShowUnderflow());
      } else {
        emit(state - 1);
      }
    });
  }
}

class CounterCubit extends Cubit<int> with SideEffectMixin<int, CounterEffect> {
  CounterCubit() : super(0);

  void increment() {
    if (state >= 10) {
      emitEffect(ShowOverflow());
    } else {
      emit(state + 1);
    }
  }

  void decrement() {
    if (state <= 0) {
      emitEffect(ShowUnderflow());
    } else {
      emit(state - 1);
    }
  }
}

// --- Tests ---

void main() {
  // Bloc tests
  blocEffectTest<CounterBloc, int, CounterEffect>(
    'emits [1] when Increment is added',
    build: () => CounterBloc(),
    act: (bloc) => bloc.add(Increment()),
    expect: () => [1],
    expectEffects: () => <CounterEffect>[],
  );

  blocEffectTest<CounterBloc, int, CounterEffect>(
    'emits ShowOverflow when incrementing past max',
    build: () => CounterBloc(),
    act: (bloc) {
      // Increment to 10 first.
      for (var i = 0; i < 11; i++) {
        bloc.add(Increment());
      }
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    expectEffects: () => [ShowOverflow()],
  );

  blocEffectTest<CounterBloc, int, CounterEffect>(
    'emits ShowUnderflow when decrementing past min',
    build: () => CounterBloc(),
    act: (bloc) => bloc.add(Decrement()),
    expect: () => <int>[],
    expectEffects: () => [ShowUnderflow()],
  );

  blocEffectTest<CounterBloc, int, CounterEffect>(
    'skipStates skips the specified number of states',
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

  blocEffectTest<CounterBloc, int, CounterEffect>(
    'supports setUp and tearDown',
    build: () => CounterBloc(),
    setUp: () {
      // Can run setup logic.
    },
    tearDown: () {
      // Can run teardown logic.
    },
    act: (bloc) => bloc.add(Increment()),
    expect: () => [1],
  );

  blocEffectTest<CounterBloc, int, CounterEffect>(
    'verify callback receives the bloc',
    build: () => CounterBloc(),
    act: (bloc) => bloc.add(Increment()),
    verify: (bloc) {
      assert(bloc.state == 1);
    },
  );

  // Cubit tests
  blocEffectTest<CounterCubit, int, CounterEffect>(
    'cubit: emits [1] on increment',
    build: () => CounterCubit(),
    act: (cubit) => cubit.increment(),
    expect: () => [1],
    expectEffects: () => <CounterEffect>[],
  );

  blocEffectTest<CounterCubit, int, CounterEffect>(
    'cubit: emits ShowUnderflow on decrement at zero',
    build: () => CounterCubit(),
    act: (cubit) => cubit.decrement(),
    expect: () => <int>[],
    expectEffects: () => [ShowUnderflow()],
  );
}
