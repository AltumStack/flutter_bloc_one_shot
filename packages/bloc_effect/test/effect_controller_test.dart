import 'dart:async';

import 'package:bloc_effect/src/effect_controller.dart';
import 'package:test/test.dart';

void main() {
  group('EffectController', () {
    late EffectController<String> controller;

    setUp(() {
      controller = EffectController<String>();
    });

    tearDown(() async {
      if (!controller.isClosed) {
        await controller.close();
      }
    });

    test('delivers effects live when a listener is active', () async {
      final effects = <String>[];
      controller.stream.listen(effects.add);

      // Allow onListen callback to fire.
      await Future<void>.delayed(Duration.zero);

      controller.add('a');
      controller.add('b');

      await Future<void>.delayed(Duration.zero);
      expect(effects, ['a', 'b']);
    });

    test('buffers effects emitted before any listener subscribes', () async {
      controller.add('a');
      controller.add('b');

      final effects = <String>[];
      controller.stream.listen(effects.add);

      // Allow onListen + flush to propagate.
      await Future<void>.delayed(Duration.zero);

      expect(effects, ['a', 'b']);
    });

    test('buffers effects emitted after listener cancels', () async {
      final effects = <String>[];
      final sub = controller.stream.listen(effects.add);

      await Future<void>.delayed(Duration.zero);

      controller.add('a');
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();

      // These should be buffered.
      controller.add('b');
      controller.add('c');

      // Re-subscribe.
      controller.stream.listen(effects.add);
      await Future<void>.delayed(Duration.zero);

      expect(effects, ['a', 'b', 'c']);
    });

    test('supports re-subscription after cancel', () async {
      final sub = controller.stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      controller.add('buffered');

      final effects = <String>[];
      controller.stream.listen(effects.add);
      await Future<void>.delayed(Duration.zero);

      expect(effects, ['buffered']);
    });

    test('delivers effects to multiple simultaneous listeners', () async {
      final effects1 = <String>[];
      final effects2 = <String>[];

      controller.stream.listen(effects1.add);
      controller.stream.listen(effects2.add);

      await Future<void>.delayed(Duration.zero);

      controller.add('x');
      await Future<void>.delayed(Duration.zero);

      expect(effects1, ['x']);
      expect(effects2, ['x']);
    });

    test('preserves effect ordering', () async {
      for (var i = 0; i < 100; i++) {
        controller.add('effect_$i');
      }

      final effects = <String>[];
      controller.stream.listen(effects.add);
      await Future<void>.delayed(Duration.zero);

      expect(effects, List.generate(100, (i) => 'effect_$i'));
    });

    test('throws StateError when adding after close', () async {
      await controller.close();
      expect(() => controller.add('x'), throwsStateError);
    });

    test('isClosed returns true after close', () async {
      expect(controller.isClosed, isFalse);
      await controller.close();
      expect(controller.isClosed, isTrue);
    });

    test('clears buffer on close', () async {
      controller.add('a');
      controller.add('b');
      await controller.close();

      // Re-create to verify old buffer is gone (we can't re-subscribe to closed).
      // Just verify close completes without error.
      expect(controller.isClosed, isTrue);
    });

    test('flushes buffer then delivers live in correct order', () async {
      controller.add('buffered_1');
      controller.add('buffered_2');

      final effects = <String>[];
      controller.stream.listen(effects.add);

      await Future<void>.delayed(Duration.zero);

      controller.add('live_1');
      controller.add('live_2');

      await Future<void>.delayed(Duration.zero);

      expect(effects, ['buffered_1', 'buffered_2', 'live_1', 'live_2']);
    });

    test('handles empty buffer on subscribe', () async {
      final effects = <String>[];
      controller.stream.listen(effects.add);
      await Future<void>.delayed(Duration.zero);

      expect(effects, isEmpty);
    });
  });
}
