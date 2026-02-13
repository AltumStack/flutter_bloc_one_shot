import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_effect/flutter_bloc_effect.dart';
import 'package:flutter_test/flutter_test.dart';

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

  @override
  String toString() => 'NavigateEffect($route)';
}

class ShowSnackbar extends TestEffect {
  final String message;
  ShowSnackbar(this.message);

  @override
  bool operator ==(Object other) =>
      other is ShowSnackbar && other.message == message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'ShowSnackbar($message)';
}

class TestCubit extends Cubit<int> with SideEffectMixin<int, TestEffect> {
  TestCubit() : super(0);

  void navigate(String route) => emitEffect(NavigateEffect(route));
  void showMessage(String msg) => emitEffect(ShowSnackbar(msg));
  void increment() => emit(state + 1);
}

// --- Tests ---

void main() {
  group('SideEffectListener', () {
    testWidgets('calls listener when effect is emitted', (tester) async {
      final cubit = TestCubit();
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectListener<TestCubit, TestEffect>(
            bloc: cubit,
            listener: (context, effect) => effects.add(effect),
            child: const SizedBox(),
          ),
        ),
      );

      cubit.navigate('/home');
      await tester.pump();

      expect(effects, [NavigateEffect('/home')]);

      await cubit.close();
    });

    testWidgets('resolves bloc from context when not provided', (tester) async {
      final cubit = TestCubit();
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TestCubit>.value(
            value: cubit,
            child: SideEffectListener<TestCubit, TestEffect>(
              listener: (context, effect) => effects.add(effect),
              child: const SizedBox(),
            ),
          ),
        ),
      );

      cubit.navigate('/settings');
      await tester.pump();

      expect(effects, [NavigateEffect('/settings')]);

      await cubit.close();
    });

    testWidgets('applies listenWhen filter', (tester) async {
      final cubit = TestCubit();
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectListener<TestCubit, TestEffect>(
            bloc: cubit,
            listenWhen: (effect) => effect is NavigateEffect,
            listener: (context, effect) => effects.add(effect),
            child: const SizedBox(),
          ),
        ),
      );

      cubit.navigate('/home');
      cubit.showMessage('hello');
      cubit.navigate('/settings');
      await tester.pump();

      expect(effects, [NavigateEffect('/home'), NavigateEffect('/settings')]);

      await cubit.close();
    });

    testWidgets('does not rebuild child on effect', (tester) async {
      final cubit = TestCubit();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectListener<TestCubit, TestEffect>(
            bloc: cubit,
            listener: (context, effect) {},
            child: Builder(
              builder: (context) {
                buildCount++;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final initialBuildCount = buildCount;

      cubit.navigate('/home');
      cubit.navigate('/settings');
      await tester.pump();

      expect(buildCount, initialBuildCount);

      await cubit.close();
    });

    testWidgets('receives buffered effects emitted before subscription', (
      tester,
    ) async {
      final cubit = TestCubit();
      cubit.navigate('/buffered');

      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectListener<TestCubit, TestEffect>(
            bloc: cubit,
            listener: (context, effect) => effects.add(effect),
            child: const SizedBox(),
          ),
        ),
      );

      await tester.pump();

      expect(effects, [NavigateEffect('/buffered')]);

      await cubit.close();
    });

    testWidgets('resubscribes when bloc changes', (tester) async {
      final cubit1 = TestCubit();
      final cubit2 = TestCubit();
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectListener<TestCubit, TestEffect>(
            bloc: cubit1,
            listener: (context, effect) => effects.add(effect),
            child: const SizedBox(),
          ),
        ),
      );

      cubit1.navigate('/from_1');
      await tester.pump();

      // Switch to cubit2.
      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectListener<TestCubit, TestEffect>(
            bloc: cubit2,
            listener: (context, effect) => effects.add(effect),
            child: const SizedBox(),
          ),
        ),
      );

      cubit2.navigate('/from_2');
      await tester.pump();

      expect(effects, [NavigateEffect('/from_1'), NavigateEffect('/from_2')]);

      await cubit1.close();
      await cubit2.close();
    });

    testWidgets('cleans up subscription on dispose', (tester) async {
      final cubit = TestCubit();
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectListener<TestCubit, TestEffect>(
            bloc: cubit,
            listener: (context, effect) => effects.add(effect),
            child: const SizedBox(),
          ),
        ),
      );

      // Dispose by removing widget.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Effect emitted after dispose should be buffered, not delivered.
      cubit.navigate('/after_dispose');
      await tester.pump();

      expect(effects, isEmpty);

      await cubit.close();
    });

    testWidgets('receives multiple effects in order', (tester) async {
      final cubit = TestCubit();
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectListener<TestCubit, TestEffect>(
            bloc: cubit,
            listener: (context, effect) => effects.add(effect),
            child: const SizedBox(),
          ),
        ),
      );

      cubit.navigate('/a');
      cubit.showMessage('hello');
      cubit.navigate('/b');
      await tester.pump();

      expect(effects, [
        NavigateEffect('/a'),
        ShowSnackbar('hello'),
        NavigateEffect('/b'),
      ]);

      await cubit.close();
    });
  });
}
