// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MaterialApp(
    title: 'Focus Demo',
    home: FocusDemo(),
  ));
}

class DemoButton extends StatefulWidget {
  const DemoButton({Key? key, required this.name, this.canRequestFocus = true, this.autofocus = false}) : super(key: key);

  final String name;
  final bool canRequestFocus;
  final bool autofocus;

  @override
  State<DemoButton> createState() => _DemoButtonState();
}

class _DemoButtonState extends State<DemoButton> {
  late final FocusNode focusNode = FocusNode(
      debugLabel: widget.name,
      canRequestFocus: widget.canRequestFocus,
  );

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DemoButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    focusNode.canRequestFocus = widget.canRequestFocus;
  }

  void _handleOnPressed() {
    focusNode.requestFocus();
    print('Button ${widget.name} pressed.');
    debugDumpFocusTree();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      focusNode: focusNode,
      autofocus: widget.autofocus,
      style: ButtonStyle(
        overlayColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
          if (states.contains(MaterialState.focused))
            return Colors.red.withOpacity(0.25);
          if (states.contains(MaterialState.hovered))
            return Colors.blue.withOpacity(0.25);
          return Colors.transparent;
        }),
      ),
      onPressed: () => _handleOnPressed(),
      child: Text(widget.name),
    );
  }
}

class FocusDemo extends StatefulWidget {
  const FocusDemo({Key? key}) : super(key: key);

  @override
  State<FocusDemo> createState() => _FocusDemoState();
}

class _FocusDemoState extends State<FocusDemo> {
  FocusNode? outlineFocus;

  @override
  void initState() {
    super.initState();
    outlineFocus = FocusNode(debugLabel: 'Demo Focus Node');
  }

  @override
  void dispose() {
    outlineFocus?.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyPress(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      print('Scope got key event: ${event.logicalKey}, $node');
      print('Keys down: ${RawKeyboard.instance.keysPressed}');
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        debugDumpFocusTree();
        if (event.isShiftPressed) {
          print('Moving to previous.');
          node.previousFocus();
          return KeyEventResult.handled;
        } else {
          print('Moving to next.');
          node.nextFocus();
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        node.focusInDirection(TraversalDirection.left);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        node.focusInDirection(TraversalDirection.right);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        node.focusInDirection(TraversalDirection.up);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        node.focusInDirection(TraversalDirection.down);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: FocusScope(
        debugLabel: 'Scope',
        onKey: _handleKeyPress,
        autofocus: true,
        child: DefaultTextStyle(
          style: textTheme.headline4!,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Focus Demo'),
            ),
            floatingActionButton: FloatingActionButton(
              child: const Text('+'),
              onPressed: () {},
            ),
            body: Center(
              child: Builder(builder: (BuildContext context) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const <Widget>[
                        DemoButton(
                          name: 'One',
                          autofocus: true,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const <Widget>[
                        DemoButton(name: 'Two'),
                        DemoButton(
                          name: 'Three',
                          canRequestFocus: false,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const <Widget>[
                        DemoButton(name: 'Four'),
                        DemoButton(name: 'Five'),
                        DemoButton(name: 'Six'),
                      ],
                    ),
                    OutlinedButton(onPressed: () => print('pressed'), child: const Text('PRESS ME')),
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: TextField(
                        decoration: InputDecoration(labelText: 'Enter Text', filled: true),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: TextField(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Enter Text',
                          filled: false,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
