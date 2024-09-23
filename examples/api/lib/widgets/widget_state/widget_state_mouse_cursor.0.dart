// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Flutter code sample for [WidgetStateMouseCursor].

void main() {
  runApp(const WidgetStateMouseCursorExampleApp());
}

class WidgetStateMouseCursorExampleApp extends StatelessWidget {
  const WidgetStateMouseCursorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('WidgetStateMouseCursor Sample')),
        body: const Center(
          child: WidgetStateMouseCursorExample(
            // TRY THIS: Switch to get a different mouse cursor while hovering ListTile.
            enabled: false,
          ),
        ),
      ),
    );
  }
}

class ListTileCursor extends WidgetStateMouseCursor {
  const ListTileCursor();

  @override
  MouseCursor resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return SystemMouseCursors.forbidden;
    }

    return SystemMouseCursors.click;
  }

  @override
  String get debugDescription => 'ListTileCursor()';
}

class WidgetStateMouseCursorExample extends StatelessWidget {
  const WidgetStateMouseCursorExample({
    required this.enabled,
    super.key,
  });

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('ListTile'),
      enabled: enabled,
      onTap: () {},
      mouseCursor: const ListTileCursor(),
    );
  }
}
