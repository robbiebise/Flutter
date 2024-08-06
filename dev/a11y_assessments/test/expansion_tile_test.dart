// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a11y_assessments/use_cases/expansion_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  testWidgets('action chip can run', (WidgetTester tester) async {
    await pumpsUseCase(tester, ExpansionTileUseCase());
    expect(find.byType(ExpansionTile), findsExactly(3));
  });
}
