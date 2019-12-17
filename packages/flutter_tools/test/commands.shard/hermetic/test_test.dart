// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/test.dart';
import 'package:flutter_tools/src/test/test_wrapper.dart';
import 'package:process/process.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/testbed.dart';

void main() {
  Cache.disableLocking();

  FakePackageTest fakePackageTest;
  MemoryFileSystem fs;

  setUp(() {
    fakePackageTest = FakePackageTest();
    fs = MemoryFileSystem();
    fs.file('pubspec.yaml').createSync();
    fs.directory('test').childFile('some_test.dart').createSync(recursive: true);
  });

  testUsingContext('Pipes test-randomize-ordering-seed to package:test',
      () async {
    final TestCommand testCommand = TestCommand();
    final CommandRunner<void> commandRunner =
        createTestCommandRunner(testCommand);

    await commandRunner.run(const <String>[
      'test',
      '--test-randomize-ordering-seed=random',
      '--no-pub',
    ]);
    expect(
      fakePackageTest.lastArgs,
      contains('--test-randomize-ordering-seed=random'),
    );
  }, overrides: <Type, Generator>{
    Test: () => fakePackageTest,
    FileSystem: () => fs,
    ProcessManager: () => FakeProcessManager.any(),
    Cache: () => FakeCache(),
  });
}

class FakePackageTest extends Test {
  List<String> lastArgs;

  @override
  Future<void> main(List<String> args) async {
    lastArgs = args;
  }
}
