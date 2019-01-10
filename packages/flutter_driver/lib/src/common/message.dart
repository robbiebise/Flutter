// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// An object sent from the Flutter Driver to a Flutter application to instruct
/// the application to perform a task.
abstract class Command {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const Command({ Duration timeout })
      : timeout = timeout ?? const Duration(seconds: 5);

  /// Deserializes this command from the value generated by [serialize].
  Command.deserialize(Map<String, String> json)
      : timeout = Duration(milliseconds: int.parse(json['timeout']));

  /// The maximum amount of time to wait for the command to complete.
  ///
  /// Defaults to 5 seconds.
  final Duration timeout;

  /// Identifies the type of the command object and of the handler.
  String get kind;

  /// Serializes this command to parameter name/value pairs.
  @mustCallSuper
  Map<String, String> serialize() => <String, String>{
    'command': kind,
    'timeout': '${timeout.inMilliseconds}',
  };
}

/// An object sent from a Flutter application back to the Flutter Driver in
/// response to a command.
abstract class Result { // ignore: one_member_abstracts
  /// Serializes this message to a JSON map.
  Map<String, dynamic> toJson();
}
