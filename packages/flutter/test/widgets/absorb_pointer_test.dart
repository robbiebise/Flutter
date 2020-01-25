// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';

import 'semantics_tester.dart';

void main() {
  testWidgets('AbsorbPointer blocks widgets behind', (WidgetTester tester) async {
    final List<String> log = <String>[];
    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: <Widget>[
          GestureDetector(
            onTap: () {log.add('background');},
          ),
          AbsorbPointer(
            absorbing: true,
            child: GestureDetector(
              onTap: () {log.add('foreground');},
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.byType(AbsorbPointer));
    expect(log, <String>[]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: <Widget>[
          GestureDetector(
            onTap: () {log.add('background');},
          ),
          AbsorbPointer(
            absorbing: false,
            child: GestureDetector(
              onTap: () {log.add('foreground');},
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.byType(AbsorbPointer));
    expect(log, <String>['foreground']);
  });

  testWidgets('AbsorbPointer do not block siblings', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      Column(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onTap: () => tapped = true,
            ),
          ),
          const Expanded(
            child: AbsorbPointer(
              absorbing: true,
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.byType(GestureDetector));
    expect(tapped, true);
  });

  testWidgets('AbsorbPointer semantics', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);
    await tester.pumpWidget(
      AbsorbPointer(
        absorbing: true,
        child: Semantics(
          label: 'test',
          textDirection: TextDirection.ltr,
        ),
      ),
    );
    expect(semantics, hasSemantics(
      TestSemantics.root(), ignoreId: true, ignoreRect: true, ignoreTransform: true));

    await tester.pumpWidget(
      AbsorbPointer(
        absorbing: false,
        child: Semantics(
          label: 'test',
          textDirection: TextDirection.ltr,
        ),
      ),
    );

    expect(semantics, hasSemantics(
      TestSemantics.root(
        children: <TestSemantics>[
          TestSemantics.rootChild(
            label: 'test',
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
      ignoreId: true, ignoreRect: true, ignoreTransform: true));
    semantics.dispose();
  });

  testWidgets('AbsorbPointer blocks mouse events', (WidgetTester tester) async {
    final List<String> logs = <String>[];
    final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.moveTo(const Offset(200, 200));
    addTearDown(gesture.removePointer);

    await tester.pumpWidget(
      Container(
        alignment: Alignment.topLeft,
        child: Container(
          width: 100,
          height: 100,
          child: Stack(
            textDirection: TextDirection.ltr,
            children: <Widget>[
              MouseRegion(onEnter: (_) {logs.add('background');}),
              AbsorbPointer(
                absorbing: true,
                child: MouseRegion(onEnter: (_) {logs.add('foreground');}),
              ),
            ],
          ),
        ),
      ),
    );

    await gesture.moveTo(const Offset(50, 50));
    expect(logs, <String>[]);

    await tester.pumpWidget(
      Container(
        alignment: Alignment.topLeft,
        child: Container(
          width: 100,
          height: 100,
          child: Stack(
            textDirection: TextDirection.ltr,
            children: <Widget>[
              MouseRegion(onEnter: (_) {logs.add('background');}),
              AbsorbPointer(
                absorbing: false,
                child: MouseRegion(onEnter: (_) {logs.add('foreground');}),
              ),
            ],
          ),
        ),
      ),
    );

    expect(logs, <String>['foreground']);
  });
}
