// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('Spacer takes up space.', (WidgetTester tester) async {
    await tester.pumpWidget(new Column(
      children: const <Widget>[
        const SizedBox(width: 10.0, height: 10.0),
        const Spacer(),
        const SizedBox(width: 10.0, height: 10.0),
      ],
    ));
    final Rect spacerRect = tester.getRect(find.byType(Spacer));
    expect(spacerRect.size, const Size(800.0, 580.0));
    expect(spacerRect.topLeft, const Offset(0.0, 10.0));
  });

  testWidgets('Spacer takes up space proportional to flex.', (WidgetTester tester) async {
    const Spacer spacer1 = const Spacer();
    const Spacer spacer2 = const Spacer(flex: 1);
    const Spacer spacer3 = const Spacer(flex: 2);
    const Spacer spacer4 = const Spacer(flex: 4);
    await tester.pumpWidget(new Row(
      textDirection: TextDirection.rtl,
      children: const <Widget>[
        const SizedBox(width: 10.0, height: 10.0),
        spacer1,
        const SizedBox(width: 10.0, height: 10.0),
        spacer2,
        const SizedBox(width: 10.0, height: 10.0),
        spacer3,
        const SizedBox(width: 10.0, height: 10.0),
        spacer4,
        const SizedBox(width: 10.0, height: 10.0),
      ],
    ));
    final Rect spacer1Rect = tester.getRect(find.byType(Spacer).at(0));
    final Rect spacer2Rect = tester.getRect(find.byType(Spacer).at(1));
    final Rect spacer3Rect = tester.getRect(find.byType(Spacer).at(2));
    final Rect spacer4Rect = tester.getRect(find.byType(Spacer).at(3));
    expect(spacer1Rect.size.height, 600.0);
    expect(spacer1Rect.size.width, closeTo(93.8, 0.1));
    expect(spacer1Rect.left, closeTo(696.3, 0.1));
    expect(spacer2Rect.size.width, closeTo(93.8, 0.1));
    expect(spacer2Rect.left, closeTo(592.5, 0.1));
    expect(spacer3Rect.size.width, spacer2Rect.size.width * 2.0);
    expect(spacer3Rect.left, closeTo(395.0, 0.1));
    expect(spacer4Rect.size.width, spacer3Rect.size.width * 2.0);
    expect(spacer4Rect.left, closeTo(10.0, 0.1));
  });
}
