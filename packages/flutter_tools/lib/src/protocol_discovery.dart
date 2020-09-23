// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:stream_transform/stream_transform.dart';

import 'base/io.dart';
import 'device.dart';
import 'globals.dart' as globals;

/// Discovers a specific service protocol on a device, and forwards the service
/// protocol device port to the host.
class ProtocolDiscovery {
  ProtocolDiscovery._(
    this.logReader,
    this.serviceName, {
    this.portForwarder,
    this.throttleDuration,
    this.throttleTimeout,
    this.hostPort,
    this.devicePort,
    this.ipv6,
  }) : assert(logReader != null)
  {
    _deviceLogSubscription = logReader.logLines.listen(
      _handleLine,
      onDone: _stopScrapingLogs,
    );
    _uriStreamController = _BufferedStreamController<Uri>();
  }

  factory ProtocolDiscovery.observatory(
    DeviceLogReader logReader, {
    DevicePortForwarder portForwarder,
    Duration throttleDuration,
    Duration throttleTimeout,
    @required int hostPort,
    @required int devicePort,
    @required bool ipv6,
  }) {
    const String kObservatoryService = 'Observatory';
    return ProtocolDiscovery._(
      logReader,
      kObservatoryService,
      portForwarder: portForwarder,
      throttleDuration: throttleDuration ?? const Duration(milliseconds: 200),
      throttleTimeout: throttleTimeout,
      hostPort: hostPort,
      devicePort: devicePort,
      ipv6: ipv6,
    );
  }

  final DeviceLogReader logReader;
  final String serviceName;
  final DevicePortForwarder portForwarder;
  final int hostPort;
  final int devicePort;
  final bool ipv6;

  /// The time to wait before forwarding a new observatory URIs from [logReader].
  final Duration throttleDuration;

  /// The time between URIs are discovered before timing out when scraping the [logReader].
  ///
  /// If null, log scanning will continue indefinitely.
  final Duration throttleTimeout;

  StreamSubscription<String> _deviceLogSubscription;
  _BufferedStreamController<Uri> _uriStreamController;

  /// The discovered service URL.
  ///
  /// Returns null if the log reader shuts down before any uri is found.
  ///
  /// Use [uris] instead.
  // TODO(egarciad): replace `uri` for `uris`.
  Future<Uri> get uri async {
    try {
      return await uris.first;
    } on StateError {
      return null;
    }
  }

  /// The discovered service URLs.
  ///
  /// When a new observatory URL: is available in [logReader],
  /// the URLs are forwarded at most once every [throttleDuration].
  /// Returns when no event has been observed for [throttleTimeout].
  ///
  /// Port forwarding is only attempted when this is invoked,
  /// for each observatory URL in the stream.
  Stream<Uri> get uris {
    Stream<Uri> uriStream = _uriStreamController.stream
      .throttle(throttleDuration);
    if (throttleTimeout != null) {
      // Don't throw a TimeoutException. The URL wasn't found in time, just close the stream.
      uriStream = uriStream.timeout(throttleTimeout,
          onTimeout: (EventSink<Uri> sink) => sink.close());
    }
    return uriStream.asyncMap<Uri>(_forwardPort);
  }

  Future<void> cancel() => _stopScrapingLogs();

  Future<void> _stopScrapingLogs() async {
    await _uriStreamController?.close();
    await _deviceLogSubscription?.cancel();
    _deviceLogSubscription = null;
  }

  Match _getPatternMatch(String line) {
    final RegExp r = RegExp(RegExp.escape(serviceName) + r' listening on ((http|//)[a-zA-Z0-9:/=_\-\.\[\]]+)');
    return r.firstMatch(line);
  }

  Uri _getObservatoryUri(String line) {
    final Match match = _getPatternMatch(line);
    if (match != null) {
      return Uri.parse(match[1]);
    }
    return null;
  }

  void _handleLine(String line) {
    Uri uri;
    try {
      uri = _getObservatoryUri(line);
    } on FormatException catch (error, stackTrace) {
      _uriStreamController.addError(error, stackTrace);
    }
    if (uri == null) {
      return;
    }
    if (devicePort != null && uri.port != devicePort) {
      globals.printTrace('skipping potential observatory $uri due to device port mismatch');
      return;
    }
    _uriStreamController.add(uri);
  }

  Future<Uri> _forwardPort(Uri deviceUri) async {
    globals.printTrace('$serviceName URL on device: $deviceUri');
    Uri hostUri = deviceUri;

    if (portForwarder != null) {
      final int actualDevicePort = deviceUri.port;
      final int actualHostPort = await portForwarder.forward(actualDevicePort, hostPort: hostPort);
      globals.printTrace('Forwarded host port $actualHostPort to device port $actualDevicePort for $serviceName');
      hostUri = deviceUri.replace(port: actualHostPort);
    }

    assert(InternetAddress(hostUri.host).isLoopback);
    if (ipv6) {
      hostUri = hostUri.replace(host: InternetAddress.loopbackIPv6.host);
    }
    return hostUri;
  }
}

/// Provides a broadcast stream controller that buffers the events
/// if there isn't a listener attached.
/// The events are then delivered when a listener is attached to the stream.
class _BufferedStreamController<T> {
  _BufferedStreamController() : _events = <dynamic>[];

  /// The stream that this controller is controlling.
  Stream<T> get stream {
    return _streamController.stream;
  }

  StreamController<T> _streamControllerInstance;

  StreamController<T> get _streamController {
    _streamControllerInstance ??= StreamController<T>.broadcast(onListen: () {
      for (final dynamic event in _events) {
        assert(T is! List);
        if (event is T) {
          _streamControllerInstance.add(event);
        } else {
          _streamControllerInstance.addError(
            event.first as Object,
            event.last as StackTrace,
          );
        }
      }
      _events.clear();
    });
    return _streamControllerInstance;
  }

  final List<dynamic> _events;

  /// Sends [event] if there is a listener attached to the broadcast stream.
  /// Otherwise, it enqueues [event] until a listener is attached.
  void add(T event) {
    if (_streamController.hasListener) {
      _streamController.add(event);
    } else {
      _events.add(event);
    }
  }

  /// Sends or enqueues an error event.
  void addError(Object error, [StackTrace stackTrace]) {
    if (_streamController.hasListener) {
      _streamController.addError(error, stackTrace);
    } else {
      _events.add(<dynamic>[error, stackTrace]);
    }
  }

  /// Closes the stream.
  Future<void> close() {
    return _streamController.close();
  }
}
