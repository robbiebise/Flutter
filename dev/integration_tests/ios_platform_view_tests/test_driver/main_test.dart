// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;

// TODO(cyanglaz): Move the test to engine repo once https://github.com/flutter/flutter/issues/51892 is resolved.
Future<void> main() async {
  FlutterDriver driver;

  setUpAll(() async {
    driver = await FlutterDriver.connect();
  });

  tearDownAll(() => driver.close());

  test('Merge thread to create and remove platform views should not crash', () async {

    // Start pushing in a page with platform view, merge threads.
    final SerializableFinder platformViewButton =
        find.byValueKey('platform_view_button');
    await driver.waitFor(platformViewButton);
    await driver.tap(platformViewButton);

    // Wait for the platform view page to show.
    final SerializableFinder plusButton =
        find.byValueKey('plus_button');
    await driver.waitFor(plusButton);
    await driver.waitUntilNoTransientCallbacks();

    // Tapping a raised button runs an animation that pumps enough frames to un-merge the threads.
    await driver.tap(plusButton);
    await driver.waitUntilNoTransientCallbacks();

    // Remove the page with platform view, merge threads again.
    final SerializableFinder backButton = find.pageBack();
    await driver.tap(backButton);
    await driver.waitUntilNoTransientCallbacks();

    final Health driverHealth = await driver.checkHealth();
    expect(driverHealth.status, HealthStatus.ok);
  });

    test('Merge thread to create and remove platform views should not crash', () async {

    // Start pushing in a page with platform view, merge threads.
    final SerializableFinder platformViewButton =
        find.byValueKey('platform_view_button');
    await driver.waitFor(platformViewButton);
    await driver.tap(platformViewButton);
    await driver.waitUntilNoTransientCallbacks();

    // Remove the page with platform view, threads are still merged.
    final SerializableFinder backButton = find.pageBack();
    await driver.tap(backButton);
    await driver.waitUntilNoTransientCallbacks();

    // The animation of tapping a `RaisedButton` should pump enough frames to un-merge the thread.
    final SerializableFinder no_action_button =
        find.byValueKey('no_action_button');
    await driver.waitFor(no_action_button);
    await driver.tap(no_action_button);
    await driver.waitUntilNoTransientCallbacks();

    final Health driverHealth = await driver.checkHealth();
    expect(driverHealth.status, HealthStatus.ok);
  });
}
