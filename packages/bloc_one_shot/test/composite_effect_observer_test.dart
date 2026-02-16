import 'package:bloc/bloc.dart';
import 'package:bloc_one_shot/bloc_one_shot.dart';
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
  group('CompositeEffectObserver', () {
    tearDown(() {
      EffectObserver.instance = null;
    });

    test('delegates to all child observers', () {
      final observer1 = _TestObserver();
      final observer2 = _TestObserver();
      final observer3 = _TestObserver();

      EffectObserver.instance = CompositeEffectObserver([
        observer1,
        observer2,
        observer3,
      ]);

      final cubit = _TestCubit();
      cubit.emitEffect('hello');

      for (final observer in [observer1, observer2, observer3]) {
        expect(observer.calls, hasLength(1));
        expect(observer.calls.first.$1, cubit);
        expect(observer.calls.first.$2, 'hello');
      }

      cubit.close();
    });

    test('delivers multiple effects in order to all observers', () {
      final observer1 = _TestObserver();
      final observer2 = _TestObserver();

      EffectObserver.instance = CompositeEffectObserver([observer1, observer2]);

      final cubit = _TestCubit();
      cubit.emitEffect('a');
      cubit.emitEffect('b');
      cubit.emitEffect('c');

      for (final observer in [observer1, observer2]) {
        expect(observer.calls.map((c) => c.$2).toList(), ['a', 'b', 'c']);
      }

      cubit.close();
    });

    test('works with an empty list of observers', () {
      EffectObserver.instance = CompositeEffectObserver([]);

      final cubit = _TestCubit();
      expect(() => cubit.emitEffect('hello'), returnsNormally);

      cubit.close();
    });

    test('works with a single observer', () {
      final observer = _TestObserver();
      EffectObserver.instance = CompositeEffectObserver([observer]);

      final cubit = _TestCubit();
      cubit.emitEffect('single');

      expect(observer.calls, hasLength(1));
      expect(observer.calls.first.$2, 'single');

      cubit.close();
    });

    test('receives effects from multiple blocs', () {
      final observer1 = _TestObserver();
      final observer2 = _TestObserver();

      EffectObserver.instance = CompositeEffectObserver([observer1, observer2]);

      final cubit1 = _TestCubit();
      final cubit2 = _TestCubit();

      cubit1.emitEffect('from_1');
      cubit2.emitEffect('from_2');

      for (final observer in [observer1, observer2]) {
        expect(observer.calls, hasLength(2));
        expect(observer.calls[0].$1, cubit1);
        expect(observer.calls[0].$2, 'from_1');
        expect(observer.calls[1].$1, cubit2);
        expect(observer.calls[1].$2, 'from_2');
      }

      cubit1.close();
      cubit2.close();
    });
  });
}
