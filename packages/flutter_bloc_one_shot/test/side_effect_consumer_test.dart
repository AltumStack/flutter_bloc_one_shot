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

class TestCubit extends Cubit<int> with SideEffectMixin<int, TestEffect> {
  TestCubit() : super(0);

  void navigate(String route) => emitEffect(NavigateEffect(route));
  void showMessage(String msg) => emitEffect(ShowSnackbar(msg));
  void increment() => emit(state + 1);
}

// --- Tests ---

void main() {
  group('SideEffectConsumer', () {
    testWidgets('builds with initial state and receives effects', (
      tester,
    ) async {
      final cubit = TestCubit();
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectConsumer<TestCubit, int, TestEffect>(
            bloc: cubit,
            builder: (context, state) => Text('$state'),
            listener: (context, effect) => effects.add(effect),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      cubit.navigate('/home');
      await tester.pump();

      expect(effects, [NavigateEffect('/home')]);

      await cubit.close();
    });

    testWidgets('rebuilds on state change', (tester) async {
      final cubit = TestCubit();

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectConsumer<TestCubit, int, TestEffect>(
            bloc: cubit,
            builder: (context, state) => Text('count: $state'),
            listener: (context, effect) {},
          ),
        ),
      );

      expect(find.text('count: 0'), findsOneWidget);

      cubit.increment();
      await tester.pump();

      expect(find.text('count: 1'), findsOneWidget);

      await cubit.close();
    });

    testWidgets('applies buildWhen filter', (tester) async {
      final cubit = TestCubit();
      final builtStates = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectConsumer<TestCubit, int, TestEffect>(
            bloc: cubit,
            buildWhen: (previous, current) => current.isEven,
            builder: (context, state) {
              builtStates.add(state);
              return Text('$state');
            },
            listener: (context, effect) {},
          ),
        ),
      );

      // Initial build with state 0.
      expect(builtStates, [0]);

      cubit.increment(); // 1 — odd, skip rebuild
      await tester.pumpAndSettle();

      // buildWhen returned false for 1, so no rebuild.
      expect(builtStates, [0]);
      expect(find.text('0'), findsOneWidget);

      await cubit.close();
    });

    testWidgets('applies listenWhen filter', (tester) async {
      final cubit = TestCubit();
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectConsumer<TestCubit, int, TestEffect>(
            bloc: cubit,
            listenWhen: (effect) => effect is ShowSnackbar,
            builder: (context, state) => Text('$state'),
            listener: (context, effect) => effects.add(effect),
          ),
        ),
      );

      cubit.navigate('/home');
      cubit.showMessage('filtered in');
      await tester.pump();

      expect(effects, [ShowSnackbar('filtered in')]);

      await cubit.close();
    });

    testWidgets('state and effects work independently', (tester) async {
      final cubit = TestCubit();
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SideEffectConsumer<TestCubit, int, TestEffect>(
            bloc: cubit,
            builder: (context, state) => Text('count: $state'),
            listener: (context, effect) => effects.add(effect),
          ),
        ),
      );

      // Only state change.
      cubit.increment();
      await tester.pump();
      expect(find.text('count: 1'), findsOneWidget);
      expect(effects, isEmpty);

      // Only effect.
      cubit.navigate('/home');
      await tester.pump();
      expect(find.text('count: 1'), findsOneWidget);
      expect(effects, [NavigateEffect('/home')]);

      await cubit.close();
    });

    testWidgets('handles bloc provided via context', (tester) async {
      final cubit = TestCubit();
      final effects = <TestEffect>[];

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TestCubit>.value(
            value: cubit,
            child: SideEffectConsumer<TestCubit, int, TestEffect>(
              builder: (context, state) => Text('$state'),
              listener: (context, effect) => effects.add(effect),
            ),
          ),
        ),
      );

      cubit.navigate('/ctx');
      await tester.pump();

      expect(effects, [NavigateEffect('/ctx')]);

      await cubit.close();
    });
  });
}
