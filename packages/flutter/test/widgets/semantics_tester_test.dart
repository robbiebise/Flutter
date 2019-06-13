

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'semantics_tester.dart';

void main() {
  testWidgets('Semantics tester visits last child', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);
    const TextStyle textStyle = TextStyle(fontFamily: 'Ahem');
    await tester.pumpWidget(
      Text.rich(
        TextSpan(
          children: <TextSpan>[
            const TextSpan(text: 'hello'),
            TextSpan(text: 'world', recognizer: TapGestureRecognizer()..onTap = () { }),
          ],
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      ),
    );
    final TestSemantics expectedSemantics = TestSemantics.root(
      children: <TestSemantics>[
        TestSemantics.rootChild(
          children: <TestSemantics>[
            TestSemantics(
              label: 'hello',
              textDirection: TextDirection.ltr,
            ),
            TestSemantics(),
          ],
        ),
      ],
    );
    expect(semantics, isNot(hasSemantics(expectedSemantics, ignoreTransform: true, ignoreId: true, ignoreRect: true)));
    semantics.dispose();
  });
}
