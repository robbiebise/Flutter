import 'dart:async';

import 'package:flutter/services.dart';

/// A mock stream handler for an [EventChannel] that mimics the native
/// StreamHandler API.
abstract class MockStreamHandler {
  /// Handler for the listen event.
  void onListen(dynamic arguments, MockStreamHandlerEventSink events);

  /// Handler for the cancel event.
  void onCancel(dynamic arguments);
}

/// Convenience class for creating a [MockStreamHandler] inline.
class InlineMockStreamHandler extends MockStreamHandler {
  /// Create a new [InlineMockStreamHandler] with the given [onListen] and
  /// [onCancel] handlers.
  InlineMockStreamHandler({
    required void Function(dynamic arguments, MockStreamHandlerEventSink events) onListen,
    void Function(dynamic arguments)? onCancel,
  })  : _onListenInline = onListen,
        _onCancelInline = onCancel;

  final void Function(dynamic arguments, MockStreamHandlerEventSink events) _onListenInline;
  final void Function(dynamic arguments)? _onCancelInline;

  @override
  void onListen(dynamic arguments, MockStreamHandlerEventSink events) => _onListenInline(arguments, events);

  @override
  void onCancel(dynamic arguments) => _onCancelInline?.call(arguments);
}

/// A mock event sink for a [MockStreamHandler] that mimics the native
/// EventSink API.
class MockStreamHandlerEventSink {
  /// Create a new [MockStreamHandlerEventSink] with the given [_sink].
  MockStreamHandlerEventSink(this._sink);

  final EventSink<dynamic> _sink;

  /// Send a success event.
  void success(dynamic event) => _sink.add(event);

  /// Send an error event.
  void error({
    required String code,
    String? message,
    Object? details,
  }) => _sink.addError(PlatformException(code: code, message: message, details: details));

  /// Send an end of stream event.
  void endOfStream() => _sink.close();
}

// void main() {
//   group('EventChannel', () {
//     test('can receive event stream', () async {
//       bool canceled = false;
//       TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
//           .setMockStreamHandler(
//         channel,
//         InlineMockStreamHandler(
//           onListen:
//               (dynamic arguments, MockStreamHandlerEventSink events) async {
//             events.success('${arguments}1');
//             events.success('${arguments}2');
//             events.endOfStream();
//           },
//           onCancel: (dynamic arguments) {
//             canceled = true;
//           },
//         ),
//       );
//       final List<dynamic> events =
//           await channel.receiveBroadcastStream('hello').toList();
//       expect(events, orderedEquals(<String>['hello1', 'hello2']));
//       await Future<void>.delayed(Duration.zero);
//       expect(canceled, isTrue);
//     });
//   });
// }
