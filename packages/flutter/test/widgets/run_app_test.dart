// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('runApp inside onPressed does not throw', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Material(
        child: new ContainedButton(
          onPressed: () {
            runApp(const Center(child: Text('Done', textDirection: TextDirection.ltr)));
          },
          child: const Text('GO', textDirection: TextDirection.ltr)
        )
      )
    );
    await tester.tap(find.text('GO'));
    expect(find.text('Done'), findsOneWidget);
  });
}
