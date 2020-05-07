// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'test_widgets.dart';

void checkTree(WidgetTester tester, List<BoxDecoration> expectedDecorations) {
  final MultiChildRenderObjectElement element = tester.element(find.byElementPredicate(
    (Element element) => element is MultiChildRenderObjectElement
  ));
  expect(element, isNotNull);
  expect(element.renderObject, isA<RenderStack>());
  final RenderStack renderObject = element.renderObject as RenderStack;
  try {
    RenderObject child = renderObject.firstChild;
    for (final BoxDecoration decoration in expectedDecorations) {
      expect(child, isA<RenderDecoratedBox>());
      final RenderDecoratedBox decoratedBox = child as RenderDecoratedBox;
      expect(decoratedBox.decoration, equals(decoration));
      final StackParentData decoratedBoxParentData = decoratedBox.parentData as StackParentData;
      child = decoratedBoxParentData.nextSibling;
    }
    expect(child, isNull);
  } catch (e) {
    print(renderObject.toStringDeep());
    rethrow;
  }
}

class MockMultiChildRenderObjectWidget extends MultiChildRenderObjectWidget {
  MockMultiChildRenderObjectWidget({ Key key, List<Widget> children }) : super(key: key, children: children);

  @override
  RenderObject createRenderObject(BuildContext context) => null;
}

void main() {
  testWidgets('MultiChildRenderObjectElement control test', (WidgetTester tester) async {

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          DecoratedBox(decoration: kBoxDecorationA),
          DecoratedBox(decoration: kBoxDecorationB),
          DecoratedBox(decoration: kBoxDecorationC),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationA, kBoxDecorationB, kBoxDecorationC]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          DecoratedBox(decoration: kBoxDecorationA),
          DecoratedBox(decoration: kBoxDecorationC),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationA, kBoxDecorationC]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          DecoratedBox(decoration: kBoxDecorationA),
          DecoratedBox(key: Key('b'), decoration: kBoxDecorationB),
          DecoratedBox(decoration: kBoxDecorationC),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationA, kBoxDecorationB, kBoxDecorationC]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          DecoratedBox(key: Key('b'), decoration: kBoxDecorationB),
          DecoratedBox(decoration: kBoxDecorationC),
          DecoratedBox(key: Key('a'), decoration: kBoxDecorationA),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationB, kBoxDecorationC, kBoxDecorationA]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          DecoratedBox(key: Key('a'), decoration: kBoxDecorationA),
          DecoratedBox(decoration: kBoxDecorationC),
          DecoratedBox(key: Key('b'), decoration: kBoxDecorationB),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationA, kBoxDecorationC, kBoxDecorationB]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          DecoratedBox(decoration: kBoxDecorationC),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationC]);

    await tester.pumpWidget(
      Stack(textDirection: TextDirection.ltr)
    );

    checkTree(tester, <BoxDecoration>[]);

  });

  testWidgets('MultiChildRenderObjectElement with stateless widgets', (WidgetTester tester) async {

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          DecoratedBox(decoration: kBoxDecorationA),
          DecoratedBox(decoration: kBoxDecorationB),
          DecoratedBox(decoration: kBoxDecorationC),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationA, kBoxDecorationB, kBoxDecorationC]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: <Widget>[
          const DecoratedBox(decoration: kBoxDecorationA),
          Container(
            child: const DecoratedBox(decoration: kBoxDecorationB),
          ),
          const DecoratedBox(decoration: kBoxDecorationC),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationA, kBoxDecorationB, kBoxDecorationC]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: <Widget>[
          const DecoratedBox(decoration: kBoxDecorationA),
          Container(
            child: Container(
              child: const DecoratedBox(decoration: kBoxDecorationB),
            ),
          ),
          const DecoratedBox(decoration: kBoxDecorationC),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationA, kBoxDecorationB, kBoxDecorationC]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: <Widget>[
          Container(
            child: Container(
              child: const DecoratedBox(decoration: kBoxDecorationB),
            ),
          ),
          Container(
            child: const DecoratedBox(decoration: kBoxDecorationA),
          ),
          const DecoratedBox(decoration: kBoxDecorationC),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationB, kBoxDecorationA, kBoxDecorationC]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: <Widget>[
          Container(
            child: const DecoratedBox(decoration: kBoxDecorationB),
          ),
          Container(
            child: const DecoratedBox(decoration: kBoxDecorationA),
          ),
          const DecoratedBox(decoration: kBoxDecorationC),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationB, kBoxDecorationA, kBoxDecorationC]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: <Widget>[
          Container(
            key: const Key('b'),
            child: const DecoratedBox(decoration: kBoxDecorationB),
          ),
          Container(
            key: const Key('a'),
            child: const DecoratedBox(decoration: kBoxDecorationA),
          ),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationB, kBoxDecorationA]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: <Widget>[
          Container(
            key: const Key('a'),
            child: const DecoratedBox(decoration: kBoxDecorationA),
          ),
          Container(
            key: const Key('b'),
            child: const DecoratedBox(decoration: kBoxDecorationB),
          ),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationA, kBoxDecorationB]);

    await tester.pumpWidget(
      Stack(textDirection: TextDirection.ltr)
    );

    checkTree(tester, <BoxDecoration>[]);
  });

  testWidgets('MultiChildRenderObjectElement with stateful widgets', (WidgetTester tester) async {
    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          DecoratedBox(decoration: kBoxDecorationA),
          DecoratedBox(decoration: kBoxDecorationB),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationA, kBoxDecorationB]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          FlipWidget(
            left: DecoratedBox(decoration: kBoxDecorationA),
            right: DecoratedBox(decoration: kBoxDecorationB),
          ),
          DecoratedBox(decoration: kBoxDecorationC),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationA, kBoxDecorationC]);

    flipStatefulWidget(tester);
    await tester.pump();

    checkTree(tester, <BoxDecoration>[kBoxDecorationB, kBoxDecorationC]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          FlipWidget(
            left: DecoratedBox(decoration: kBoxDecorationA),
            right: DecoratedBox(decoration: kBoxDecorationB),
          ),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationB]);

    flipStatefulWidget(tester);
    await tester.pump();

    checkTree(tester, <BoxDecoration>[kBoxDecorationA]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          FlipWidget(
            key: Key('flip'),
            left: DecoratedBox(decoration: kBoxDecorationA),
            right: DecoratedBox(decoration: kBoxDecorationB),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          DecoratedBox(key: Key('c'), decoration: kBoxDecorationC),
          FlipWidget(
            key: Key('flip'),
            left: DecoratedBox(decoration: kBoxDecorationA),
            right: DecoratedBox(decoration: kBoxDecorationB),
          ),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationC, kBoxDecorationA]);

    flipStatefulWidget(tester);
    await tester.pump();

    checkTree(tester, <BoxDecoration>[kBoxDecorationC, kBoxDecorationB]);

    await tester.pumpWidget(
      Stack(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          FlipWidget(
            key: Key('flip'),
            left: DecoratedBox(decoration: kBoxDecorationA),
            right: DecoratedBox(decoration: kBoxDecorationB),
          ),
          DecoratedBox(key: Key('c'), decoration: kBoxDecorationC),
        ],
      ),
    );

    checkTree(tester, <BoxDecoration>[kBoxDecorationB, kBoxDecorationC]);
  });

  // Regression test for https://github.com/flutter/flutter/issues/37136.
  test('provides useful assertion message when one of the children is null', () {
    bool assertionTriggered = false;
    try {
      MockMultiChildRenderObjectWidget(children: const <Widget>[null]);
    } catch (e) {
      expect(e.toString(), contains("MockMultiChildRenderObjectWidget's children must not contain any null values,"));
      assertionTriggered = true;
    }

    expect(assertionTriggered, isTrue);
  });
}
