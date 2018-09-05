// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:process/process.dart';

import '../src/common.dart';
import 'test_data/basic_project.dart';

void main() {
  group('flutter_run', () {
    Directory tempDir;
    final BasicProject _project = new BasicProject();

    setUp(() async {
      tempDir = fs.systemTempDirectory.createTempSync('flutter_run_integration_test.');
      await _project.setUpIn(tempDir);
    });

    tearDown(() async {
      tryToDelete(tempDir);
    });
    test('reports an error if an invalid device is supplied', () async {
      // This test forces flutter to check for all possible devices to catch issues
      // like https://github.com/flutter/flutter/issues/21418 which were skipped
      // over because other integration tesst run using flutter-tester which short-cuts
      // some of the checks for devices.
      final String flutterBin = fs.path.join(getFlutterRoot(), 'bin', 'flutter');

      const ProcessManager _processManager = LocalProcessManager();
      final ProcessResult _proc = await _processManager.run(
        <String>[flutterBin, 'run', '-d', 'invalid-device-id'],
        workingDirectory: tempDir.path
      );

      expect(_proc.stdout, isNot(contains('flutter has exited unexpectedly')));
      expect(_proc.stderr, isNot(contains('flutter has exited unexpectedly')));
      expect(_proc.stderr, contains('Unable to locate a development'));
    });
  }, timeout: const Timeout.factor(6));
}
