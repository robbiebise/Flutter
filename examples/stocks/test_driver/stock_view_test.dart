// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;

void main() {
  group('basic stock view test', () {
    FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      if (driver != null)
        driver.close();
    });

    test('open AAPL stock', () async {
      final SerializableFinder stockList = find.byValueKey('stock-list');
      expect(stockList, isNotNull);

      final SerializableFinder aaplStockRow = find.byValueKey('AAPL');
      await driver.scrollUntilVisible(stockList, aaplStockRow);

      await driver.tap(aaplStockRow);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final SerializableFinder stockOption = find.byValueKey('AAPL_symbol_name');
      final String symbol = await driver.getText(stockOption, timeout: const Duration(milliseconds: 500));

      expect(symbol, 'AAPL');
    });
  });
}
