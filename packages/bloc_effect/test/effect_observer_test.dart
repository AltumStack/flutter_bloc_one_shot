import 'package:bloc/bloc.dart';
import 'package:bloc_effect/bloc_effect.dart';
import 'package:test/test.dart';

class _TestObserver extends EffectObserver {
  final List<(BlocBase<dynamic>, Object?)> calls = [];

  @override
  void onEffect(BlocBase<dynamic> bloc, Object? effect) {
    calls.add((bloc, effect));
  }
}

class _TestCubit extends Cubit<int> with SideEffectMixin<int, String> {
  _TestCubit() : super(0);
}

void main() {
  group('EffectObserver', () {
    tearDown(() {
      EffectObserver.instance = null;
    });

    test('instance is null by default', () {
      expect(EffectObserver.instance, isNull);
    });

    test('observer is called when emitEffect is invoked', () {
      final observer = _TestObserver();
      EffectObserver.instance = observer;

      final cubit = _TestCubit();
      cubit.emitEffect('hello');

      expect(observer.calls, hasLength(1));
      expect(observer.calls.first.$1, cubit);
      expect(observer.calls.first.$2, 'hello');

      cubit.close();
    });

    test('observer receives multiple effects in order', () {
      final observer = _TestObserver();
      EffectObserver.instance = observer;

      final cubit = _TestCubit();
      cubit.emitEffect('a');
      cubit.emitEffect('b');
      cubit.emitEffect('c');

      expect(observer.calls.map((c) => c.$2).toList(), ['a', 'b', 'c']);

      cubit.close();
    });

    test('no error when observer is null', () {
      EffectObserver.instance = null;

      final cubit = _TestCubit();
      expect(() => cubit.emitEffect('hello'), returnsNormally);

      cubit.close();
    });

    test('observer can be changed at runtime', () {
      final observer1 = _TestObserver();
      final observer2 = _TestObserver();
      EffectObserver.instance = observer1;

      final cubit = _TestCubit();
      cubit.emitEffect('first');

      EffectObserver.instance = observer2;
      cubit.emitEffect('second');

      expect(observer1.calls.map((c) => c.$2).toList(), ['first']);
      expect(observer2.calls.map((c) => c.$2).toList(), ['second']);

      cubit.close();
    });

    test('observer receives effects from multiple blocs', () {
      final observer = _TestObserver();
      EffectObserver.instance = observer;

      final cubit1 = _TestCubit();
      final cubit2 = _TestCubit();

      cubit1.emitEffect('from_1');
      cubit2.emitEffect('from_2');

      expect(observer.calls, hasLength(2));
      expect(observer.calls[0].$1, cubit1);
      expect(observer.calls[1].$1, cubit2);

      cubit1.close();
      cubit2.close();
    });
  });
}
