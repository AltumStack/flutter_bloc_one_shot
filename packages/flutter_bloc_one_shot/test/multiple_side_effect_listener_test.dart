import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_one_shot/flutter_bloc_one_shot.dart';
import 'package:flutter_test/flutter_test.dart';

// --- Test helpers ---

sealed class EffectA {}

class EffectA1 extends EffectA {
  final String value;
  EffectA1(this.value);

  @override
  bool operator ==(Object other) => other is EffectA1 && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'EffectA1($value)';
}

sealed class EffectB {}

class EffectB1 extends EffectB {
  final int code;
  EffectB1(this.code);

  @override
  bool operator ==(Object other) => other is EffectB1 && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'EffectB1($code)';
}

class EffectB2 extends EffectB {
  @override
  bool operator ==(Object other) => other is EffectB2;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'EffectB2()';
}

class CubitA extends Cubit<int> with SideEffectMixin<int, EffectA> {
  CubitA() : super(0);

  void sendA(String value) => emitEffect(EffectA1(value));
}

class CubitB extends Cubit<int> with SideEffectMixin<int, EffectB> {
  CubitB() : super(0);

  void sendB(int code) => emitEffect(EffectB1(code));
  void sendB2() => emitEffect(EffectB2());
}

// --- Tests ---

void main() {
  group('MultipleSideEffectListener', () {
    testWidgets('renders the child widget', (tester) async {
      final cubitA = CubitA();
      final cubitB = CubitB();

      await tester.pumpWidget(
        MaterialApp(
          home: MultipleSideEffectListener(
            listeners: [
              SideEffectListener<CubitA, EffectA>(
                bloc: cubitA,
                listener: (context, effect) {},
              ),
              SideEffectListener<CubitB, EffectB>(
                bloc: cubitB,
                listener: (context, effect) {},
              ),
            ],
            child: const Text('hello'),
          ),
        ),
      );

      expect(find.text('hello'), findsOneWidget);

      await cubitA.close();
      await cubitB.close();
    });

    testWidgets('each listener receives effects only from its bloc', (
      tester,
    ) async {
      final cubitA = CubitA();
      final cubitB = CubitB();
      final effectsA = <EffectA>[];
      final effectsB = <EffectB>[];

      await tester.pumpWidget(
        MaterialApp(
          home: MultipleSideEffectListener(
            listeners: [
              SideEffectListener<CubitA, EffectA>(
                bloc: cubitA,
                listener: (context, effect) => effectsA.add(effect),
              ),
              SideEffectListener<CubitB, EffectB>(
                bloc: cubitB,
                listener: (context, effect) => effectsB.add(effect),
              ),
            ],
            child: const SizedBox(),
          ),
        ),
      );

      cubitA.sendA('nav');
      await tester.pump();

      expect(effectsA, [EffectA1('nav')]);
      expect(effectsB, isEmpty);

      cubitB.sendB(42);
      await tester.pump();

      expect(effectsA, [EffectA1('nav')]);
      expect(effectsB, [EffectB1(42)]);

      await cubitA.close();
      await cubitB.close();
    });

    testWidgets('both listeners receive effects independently', (tester) async {
      final cubitA = CubitA();
      final cubitB = CubitB();
      final effectsA = <EffectA>[];
      final effectsB = <EffectB>[];

      await tester.pumpWidget(
        MaterialApp(
          home: MultipleSideEffectListener(
            listeners: [
              SideEffectListener<CubitA, EffectA>(
                bloc: cubitA,
                listener: (context, effect) => effectsA.add(effect),
              ),
              SideEffectListener<CubitB, EffectB>(
                bloc: cubitB,
                listener: (context, effect) => effectsB.add(effect),
              ),
            ],
            child: const SizedBox(),
          ),
        ),
      );

      cubitA.sendA('first');
      cubitB.sendB(1);
      cubitA.sendA('second');
      cubitB.sendB(2);
      await tester.pump();

      expect(effectsA, [EffectA1('first'), EffectA1('second')]);
      expect(effectsB, [EffectB1(1), EffectB1(2)]);

      await cubitA.close();
      await cubitB.close();
    });

    testWidgets('works with blocs provided via BlocProvider context', (
      tester,
    ) async {
      final cubitA = CubitA();
      final cubitB = CubitB();
      final effectsA = <EffectA>[];
      final effectsB = <EffectB>[];

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<CubitA>.value(value: cubitA),
              BlocProvider<CubitB>.value(value: cubitB),
            ],
            child: MultipleSideEffectListener(
              listeners: [
                SideEffectListener<CubitA, EffectA>(
                  listener: (context, effect) => effectsA.add(effect),
                ),
                SideEffectListener<CubitB, EffectB>(
                  listener: (context, effect) => effectsB.add(effect),
                ),
              ],
              child: const SizedBox(),
            ),
          ),
        ),
      );

      cubitA.sendA('ctx');
      cubitB.sendB(99);
      await tester.pump();

      expect(effectsA, [EffectA1('ctx')]);
      expect(effectsB, [EffectB1(99)]);

      await cubitA.close();
      await cubitB.close();
    });

    testWidgets('cleans up subscriptions on dispose', (tester) async {
      final cubitA = CubitA();
      final cubitB = CubitB();
      final effectsA = <EffectA>[];
      final effectsB = <EffectB>[];

      await tester.pumpWidget(
        MaterialApp(
          home: MultipleSideEffectListener(
            listeners: [
              SideEffectListener<CubitA, EffectA>(
                bloc: cubitA,
                listener: (context, effect) => effectsA.add(effect),
              ),
              SideEffectListener<CubitB, EffectB>(
                bloc: cubitB,
                listener: (context, effect) => effectsB.add(effect),
              ),
            ],
            child: const SizedBox(),
          ),
        ),
      );

      // Remove the widget tree to trigger dispose.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      cubitA.sendA('after');
      cubitB.sendB(0);
      await tester.pump();

      expect(effectsA, isEmpty);
      expect(effectsB, isEmpty);

      await cubitA.close();
      await cubitB.close();
    });

    testWidgets('listenWhen works inside multi-listener', (tester) async {
      final cubitB = CubitB();
      final effectsB = <EffectB>[];

      await tester.pumpWidget(
        MaterialApp(
          home: MultipleSideEffectListener(
            listeners: [
              SideEffectListener<CubitB, EffectB>(
                bloc: cubitB,
                listenWhen: (effect) => effect is EffectB1,
                listener: (context, effect) => effectsB.add(effect),
              ),
            ],
            child: const SizedBox(),
          ),
        ),
      );

      cubitB.sendB(1);
      cubitB.sendB2();
      cubitB.sendB(2);
      await tester.pump();

      expect(effectsB, [EffectB1(1), EffectB1(2)]);

      await cubitB.close();
    });
  });
}
