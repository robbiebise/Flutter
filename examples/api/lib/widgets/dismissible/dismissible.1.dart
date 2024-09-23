// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Flutter code sample for [Dismissible] using [Dismissible.shouldTriggerDismiss].

void main() => runApp(const DismissibleExampleApp());

class DismissibleExampleApp extends StatefulWidget {
  const DismissibleExampleApp({super.key});

  @override
  State<DismissibleExampleApp> createState() => _DismissibleExampleAppState();
}

class _DismissibleExampleAppState extends State<DismissibleExampleApp> {
  UniqueKey _refreshKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() {
            _refreshKey = UniqueKey();
          }),
          child: const Icon(Icons.refresh),
        ),
        appBar: AppBar(
          title: const Text('Dismissible Sample - shouldTriggerDismiss'),
        ),
        body: DismissibleExample(key: _refreshKey),
      ),
    );
  }
}

class DismissibleExample extends StatefulWidget {
  const DismissibleExample({super.key});

  @override
  State<DismissibleExample> createState() => _DismissibleExampleState();
}

class _DismissibleExampleState extends State<DismissibleExample> {
  late List<_Dismissible> dismissibleWidgets = <_Dismissible>[
    _Dismissible(
      index: 0,
      title: 'Default behavior',
      description: '`shouldTriggerDismiss: null`',
      onDismissed: _dismissItem,
    ),
    _Dismissible(
      index: 1,
      title: 'Default behavior',
      description: '`shouldTriggerDismiss: (_) => null`',
      shouldTriggerDismiss: (_) => null,
      onDismissed: _dismissItem,
    ),
    _Dismissible(
      index: 2,
      title: 'Default behavior',
      description: '`shouldTriggerDismiss: (details) => details.reached || details.isFling`',
      shouldTriggerDismiss: (TriggerDismissDetails details) => details.reached || details.isFling,
      onDismissed: _dismissItem,
    ),
    _Dismissible(
      index: 3,
      title: 'Never dismiss',
      description: '`shouldTriggerDismiss: (_) => false`',
      shouldTriggerDismiss: (_) => false,
      onDismissed: _dismissItem,
    ),
    _Dismissible(
      index: 4,
      title: 'Always dismiss',
      description: '`shouldTriggerDismiss: (_) => true`',
      shouldTriggerDismiss: (_) => true,
      onDismissed: _dismissItem,
    ),
    _Dismissible(
      index: 5,
      title: 'Only accept if threshold is reached (Disable flinging)',
      shouldTriggerDismiss: (TriggerDismissDetails details) => details.reached,
      onDismissed: _dismissItem,
    ),
    _Dismissible(
      index: 6,
      title: 'Only accept if flung (Disable threshold check)',
      shouldTriggerDismiss: (TriggerDismissDetails details) => details.isFling,
      onDismissed: _dismissItem,
    ),
    _Dismissible(
      index: 7,
      title: 'Accept dismiss before threshold',
      description: '`details.progress >= 0.2`',
      shouldTriggerDismiss: (TriggerDismissDetails details) {
        if (details.progress >= 0.2) {
          return true;
        }
        return null;
      },
      onDismissed: _dismissItem,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: dismissibleWidgets,
    );
  }

  void _dismissItem(_Dismissible dismissedItem) {
    setState(() {
      dismissibleWidgets = dismissibleWidgets
          .where((_Dismissible item) => item != dismissedItem)
          .toList();
    });
  }
}

/// A [Dismissible] widget used to demonstrates the behavior of the [shouldTriggerDismiss]
/// parameter.
///
/// Change background color to red when the item is reached based on
/// [DismissUpdateDetails.reached] value of [Dismissible.onUpdate] events.
class _Dismissible extends StatefulWidget {
  _Dismissible({
    required this.index,
    required this.title,
    required this.onDismissed,
    this.description,
    this.shouldTriggerDismiss,
  }) : super(key: ValueKey<int>(index));

  final int index;
  final String title;
  final String? description;
  final TriggerDismissCallback? shouldTriggerDismiss;
  final ValueChanged<_Dismissible> onDismissed;

  @override
  State<_Dismissible> createState() => _DismissibleState();
}

class _DismissibleState extends State<_Dismissible> {
  bool reached = false;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('dismissible-${widget.index}'),
      background: ColoredBox(
        color: reached ? Colors.red : Colors.blue,
      ),
      onUpdate: (DismissUpdateDetails details) {
        setState(() {
          reached = details.reached;
        });
      },
      shouldTriggerDismiss: widget.shouldTriggerDismiss,
      child: ListTile(
        title: Text(widget.title),
        subtitle: widget.description != null ? Text(widget.description!) : null,
      ),
      onDismissed: (_) => widget.onDismissed(widget),
    );
  }
}
