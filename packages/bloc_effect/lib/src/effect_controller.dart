import 'dart:async';
import 'dart:collection';

/// A buffered broadcast stream controller for side effects.
///
/// When no listener is subscribed, effects are queued in an internal buffer.
/// When a listener subscribes, the buffer is flushed synchronously, ensuring
/// no effects are lost — even if emitted before the widget tree subscribes.
///
/// Re-subscription safe: after a listener cancels (e.g. widget dispose during
/// navigation), a new listener can subscribe and will receive any effects
/// that were buffered in the meantime.
class EffectController<E> {
  final _buffer = Queue<E>();
  late final StreamController<E> _controller;
  bool _isClosed = false;
  bool _hasListener = false;

  /// Creates an [EffectController].
  EffectController() {
    _controller = StreamController<E>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  void _onListen() {
    _hasListener = true;
    _flushBuffer();
  }

  void _onCancel() {
    _hasListener = false;
  }

  void _flushBuffer() {
    while (_buffer.isNotEmpty) {
      _controller.add(_buffer.removeFirst());
    }
  }

  /// Adds an [effect] to the stream.
  ///
  /// If a listener is active, the effect is delivered immediately.
  /// Otherwise, it is buffered until a listener subscribes.
  ///
  /// Throws [StateError] if the controller has been closed.
  void add(E effect) {
    if (_isClosed) {
      throw StateError('Cannot add effect after controller is closed.');
    }
    if (_hasListener) {
      _controller.add(effect);
    } else {
      _buffer.add(effect);
    }
  }

  /// The broadcast stream of effects.
  Stream<E> get stream => _controller.stream;

  /// Whether this controller has been closed.
  bool get isClosed => _isClosed;

  /// Closes the controller and clears any buffered effects.
  ///
  /// After closing, calls to [add] will throw [StateError].
  Future<void> close() {
    _isClosed = true;
    _buffer.clear();
    return _controller.close();
  }
}
