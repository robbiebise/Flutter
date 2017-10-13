// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show SemanticsFlags;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'semantics_tester.dart';

void main() {
  testWidgets('Implicit Semantics merge behavior', (WidgetTester tester) async {
    final SemanticsTester semantics = new SemanticsTester(tester);

    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new Semantics(
          container: true,
          explicitChildNodes: false,
          child: new Column(
            children: <Widget>[
              const Text('Michael Goderbauer'),
              const Text('goderbauer@google.com'),
            ],
          ),
        ),
      ),
    );

    // SemanticsNode#0(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0))
    //  └SemanticsNode#1(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0), label: "Michael Goderbauer\ngoderbauer@google.com", textDirection: ltr)
    expect(
      semantics,
      hasSemantics(
        new TestSemantics.root(
          children: <TestSemantics>[
            new TestSemantics.rootChild(
              id: 1,
              label: 'Michael Goderbauer\ngoderbauer@google.com',
            ),
          ],
        ),
        ignoreRect: true,
        ignoreTransform: true,
      ),
    );

    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new Semantics(
          container: true,
          explicitChildNodes: true,
          child: new Column(
            children: <Widget>[
              const Text('Michael Goderbauer'),
              const Text('goderbauer@google.com'),
            ],
          ),
        ),
      ),
    );

    // SemanticsNode#0(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0))
    //  └SemanticsNode#1(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0))
    //    ├SemanticsNode#2(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0), label: "Michael Goderbauer", textDirection: ltr)
    //    └SemanticsNode#3(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0), label: "goderbauer@google.com", textDirection: ltr)
    expect(
      semantics,
      hasSemantics(
        new TestSemantics.root(
          children: <TestSemantics>[
            new TestSemantics.rootChild(
              id: 1,
              children: <TestSemantics>[
                new TestSemantics(
                  id: 2,
                  label: 'Michael Goderbauer',
                ),
                new TestSemantics(
                  id: 3,
                  label: 'goderbauer@google.com',
                ),
              ],
            ),
          ],
        ),
        ignoreRect: true,
        ignoreTransform: true,
      ),
    );

    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new Semantics(
          container: true,
          explicitChildNodes: true,
          child: new Semantics(
            label: 'Signed in as',
            child: new Column(
              children: <Widget>[
                const Text('Michael Goderbauer'),
                const Text('goderbauer@google.com'),
              ],
            ),
          ),
        ),
      ),
    );

    // SemanticsNode#0(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0))
    //  └SemanticsNode#1(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0))
    //    └SemanticsNode#4(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0), label: "Signed in as\nMichael Goderbauer\ngoderbauer@google.com", textDirection: ltr)
    expect(
      semantics,
      hasSemantics(
        new TestSemantics.root(
          children: <TestSemantics>[
            new TestSemantics.rootChild(
              id: 1,
              children: <TestSemantics>[
                new TestSemantics(
                  id: 4,
                  label: 'Signed in as\nMichael Goderbauer\ngoderbauer@google.com',
                ),
              ],
            ),
          ],
        ),
        ignoreRect: true,
        ignoreTransform: true,
      ),
    );

    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new Semantics(
          container: true,
          explicitChildNodes: false,
          child: new Semantics(
            label: 'Signed in as',
            child: new Column(
              children: <Widget>[
                const Text('Michael Goderbauer'),
                const Text('goderbauer@google.com'),
              ],
            ),
          ),
        ),
      ),
    );

    // SemanticsNode#0(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0))
    //  └SemanticsNode#1(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0), label: "Signed in as\nMichael Goderbauer\ngoderbauer@google.com", textDirection: ltr)
    expect(
      semantics,
      hasSemantics(
        new TestSemantics.root(
          children: <TestSemantics>[
            new TestSemantics.rootChild(
              id: 1,
              label: 'Signed in as\nMichael Goderbauer\ngoderbauer@google.com',
            ),
          ],
        ),
        ignoreRect: true,
        ignoreTransform: true,
      ),
    );

    semantics.dispose();
  });

  testWidgets('Do not merge with conflicts', (WidgetTester tester) async {
    final SemanticsTester semantics = new SemanticsTester(tester);

    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new Semantics(
          container: true,
          explicitChildNodes: false,
          child: new Column(
            children: <Widget>[
              const Semantics(
                label: 'node 1',
                selected: true,
              ),
              const Semantics(
                label: 'node 2',
                selected: true,
              ),
              const Semantics(
                label: 'node 3',
                selected: true,
              ),
            ],
          ),
        ),
      ),
    );

    // SemanticsNode#0(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0))
    //  └SemanticsNode#8(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0))
    //   ├SemanticsNode#5(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0), selected, label: "node 1", textDirection: ltr)
    //   ├SemanticsNode#6(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0), selected, label: "node 2", textDirection: ltr)
    //   └SemanticsNode#7(Rect.fromLTRB(0.0, 0.0, 0.0, 0.0), selected, label: "node 3", textDirection: ltr)
    expect(
      semantics,
      hasSemantics(
        new TestSemantics.root(
          children: <TestSemantics>[
            new TestSemantics.rootChild(
              id: 8,
              children: <TestSemantics>[
                new TestSemantics(
                  id: 5,
                  flags: SemanticsFlags.isSelected.index,
                  label: 'node 1',
                ),
                new TestSemantics(
                  id: 6,
                  flags: SemanticsFlags.isSelected.index,
                  label: 'node 2',
                ),
                new TestSemantics(
                  id: 7,
                  flags: SemanticsFlags.isSelected.index,
                  label: 'node 3',
                ),
              ],
            ),
          ],
        ),
        ignoreRect: true,
        ignoreTransform: true,
      ),
    );

    semantics.dispose();
  });
}
