import 'dart:async';
import 'dart:collection';

Channel<T> createUnbounded<T>() {
  final channel = UnboundedChannel<T>();

  return Channel<T>(channel, channel);
}

Channel<T> createBounded<T>(int capacity) {
  final channel = BoundedChannel<T>(capacity);

  return Channel<T>(channel, channel);
}

class Channel<T> {
  Channel(this.writer, this.reader);

  final ChannelWriter<T> writer;
  final ChannelReader<T> reader;
}

abstract class ChannelWriter<T> {
  Future<void> write(T item);
  void complete();
}

abstract class ChannelReader<T> {
  Future<bool> waitToRead();
  T? tryRead();
  T read();
}

class UnboundedChannel<T> implements ChannelWriter<T>, ChannelReader<T> {
  bool _completed = false;
  final ListQueue<T> _items = ListQueue<T>();
  final ListQueue<Completer<bool>> _waitingConsumers =
      ListQueue<Completer<bool>>();

  @override
  T? tryRead() {
    if (_items.isEmpty) return null;

    return _items.removeFirst();
  }

  @override
  T read() => _items.removeFirst();

  @override
  Future<bool> waitToRead() async {
    if (_items.isNotEmpty) return Future.value(true);
    if (_completed) return Future.value(false);

    final completer = Completer<bool>();
    _waitingConsumers.add(completer);
    return completer.future;
  }

  @override
  Future<void> write(T item) {
    assert(_completed == false);

    _items.addLast(item);

    if (_waitingConsumers.isNotEmpty) {
      _waitingConsumers.removeFirst().complete(true);
    }

    return Future.value();
  }

  @override
  void complete() {
    _completed = true;
    for (final consumer in _waitingConsumers) {
      consumer.complete(false);
    }
  }
}

class BoundedChannel<T> implements ChannelWriter<T>, ChannelReader<T> {
  BoundedChannel(this._capacity) : _items = ListQueue<T>(_capacity);

  final int _capacity;
  final ListQueue<T> _items;
  bool _completed = false;

  final ListQueue<Completer<void>> _waitingProducers =
      ListQueue<Completer<void>>();
  final ListQueue<Completer<bool>> _waitingConsumers =
      ListQueue<Completer<bool>>();

  @override
  T? tryRead() {
    if (_items.isEmpty) return null;

    final item = _items.removeFirst();

    if (_waitingProducers.isNotEmpty) {
      _waitingProducers.removeFirst().complete();
    }

    return item;
  }

  @override
  T read() {
    final item = _items.removeFirst();

    if (_waitingProducers.isNotEmpty) {
      _waitingProducers.removeFirst().complete();
    }

    return item;
  }

  @override
  Future<bool> waitToRead() async {
    if (_items.isNotEmpty) return true;
    if (_completed) return false;

    final completer = Completer<bool>();
    _waitingConsumers.add(completer);
    return await completer.future;
  }

  @override
  Future<void> write(T item) async {
    assert(_completed == false);
    assert(_items.length <= _capacity);

    if (_items.length == _capacity) {
      final completer = Completer<void>();
      _waitingProducers.add(completer);
      await completer.future;
    }

    assert(_items.length < _capacity);

    _items.addLast(item);

    if (_waitingConsumers.isNotEmpty) {
      _waitingConsumers.removeFirst().complete(true);
    }
  }

  @override
  void complete() {
    assert(_waitingProducers.isEmpty);

    _completed = true;
    for (final consumer in _waitingConsumers) {
      consumer.complete(false);
    }
  }
}
