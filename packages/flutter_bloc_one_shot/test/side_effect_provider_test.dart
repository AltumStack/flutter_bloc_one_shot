import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_one_shot/flutter_bloc_one_shot.dart';
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
  group('SideEffectProvider', () {
    testWidgets('renders the child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectProvider<TestCubit, TestEffect>(
            create: (_) => TestCubit(),
            listener: (context, effect) {},
            child: const Text('child'),
          ),
        ),
      );

      expect(find.text('child'), findsOneWidget);
    });

    testWidgets('provides the bloc to the child context', (tester) async {
      late TestCubit resolvedCubit;

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectProvider<TestCubit, TestEffect>(
            create: (_) => TestCubit(),
            listener: (context, effect) {},
            child: Builder(
              builder: (context) {
                resolvedCubit = context.read<TestCubit>();
                return Text('state: ${resolvedCubit.state}');
              },
            ),
          ),
        ),
      );

      expect(find.text('state: 0'), findsOneWidget);
      expect(resolvedCubit, isA<TestCubit>());
    });

    testWidgets('calls listener when effect is emitted', (tester) async {
      late TestCubit cubit;
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectProvider<TestCubit, TestEffect>(
            create: (_) => TestCubit(),
            listener: (context, effect) => effects.add(effect),
            child: Builder(
              builder: (context) {
                cubit = context.read<TestCubit>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      cubit.navigate('/home');
      await tester.pump();

      expect(effects, [NavigateEffect('/home')]);
    });

    testWidgets('applies listenWhen filter', (tester) async {
      late TestCubit cubit;
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectProvider<TestCubit, TestEffect>(
            create: (_) => TestCubit(),
            listenWhen: (effect) => effect is NavigateEffect,
            listener: (context, effect) => effects.add(effect),
            child: Builder(
              builder: (context) {
                cubit = context.read<TestCubit>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      cubit.navigate('/home');
      cubit.showMessage('ignored');
      cubit.navigate('/settings');
      await tester.pump();

      expect(effects, [NavigateEffect('/home'), NavigateEffect('/settings')]);
    });

    testWidgets('.value provides an existing bloc and listens to effects', (
      tester,
    ) async {
      final cubit = TestCubit();
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectProvider<TestCubit, TestEffect>.value(
            value: cubit,
            listener: (context, effect) => effects.add(effect),
            child: Builder(
              builder: (context) {
                // Verify bloc is accessible via context.
                final resolved = context.read<TestCubit>();
                expect(resolved, same(cubit));
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      cubit.navigate('/value');
      await tester.pump();

      expect(effects, [NavigateEffect('/value')]);

      await cubit.close();
    });

    testWidgets('.value does not close the bloc on dispose', (tester) async {
      final cubit = TestCubit();

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectProvider<TestCubit, TestEffect>.value(
            value: cubit,
            listener: (context, effect) {},
            child: const SizedBox(),
          ),
        ),
      );

      // Dispose widget tree.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Bloc should still be open — emitting state should not throw.
      expect(() => cubit.increment(), returnsNormally);

      await cubit.close();
    });

    testWidgets('create constructor closes the bloc on dispose', (
      tester,
    ) async {
      late TestCubit createdCubit;

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectProvider<TestCubit, TestEffect>(
            create: (_) {
              createdCubit = TestCubit();
              return createdCubit;
            },
            listener: (context, effect) {},
            child: const SizedBox(),
          ),
        ),
      );

      // Dispose widget tree.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Bloc should be closed — emitting state should throw.
      expect(() => createdCubit.increment(), throwsStateError);
    });

    testWidgets('lazy: false creates the bloc immediately', (tester) async {
      var created = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectProvider<TestCubit, TestEffect>(
            create: (_) {
              created = true;
              return TestCubit();
            },
            lazy: false,
            listener: (context, effect) {},
            child: const SizedBox(),
          ),
        ),
      );

      expect(created, isTrue);
    });

    testWidgets('receives multiple effects in order', (tester) async {
      late TestCubit cubit;
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectProvider<TestCubit, TestEffect>(
            create: (_) => TestCubit(),
            listener: (context, effect) => effects.add(effect),
            child: Builder(
              builder: (context) {
                cubit = context.read<TestCubit>();
                return const SizedBox();
              },
            ),
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
    });
  });
}
