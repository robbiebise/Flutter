// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';
import 'dart:typed_data';

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/symbolize.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:meta/meta.dart';
import 'package:test/fake.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/fakes.dart';

void main() {
  MemoryFileSystem fileSystem;
  FakeStdio stdio;
  SymbolizeCommand command;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    stdio = FakeStdio();
    command = SymbolizeCommand(
      stdio: stdio,
      fileSystem: fileSystem,
      dwarfSymbolizationService: DwarfSymbolizationService.test(),
    );
  });

  testUsingContext('Regression test for type error in codec', () async {
    final DwarfSymbolizationService symbolizationService = DwarfSymbolizationService.test();
    final StreamController<List<int>> output = StreamController<List<int>>();

    unawaited(symbolizationService.decode(
      input: Stream<Uint8List>.fromIterable(<Uint8List>[
        utf8.encode('Hello, World\n') as Uint8List,
      ]),
      symbols: Uint8List(0),
      output: IOSink(output.sink),
    ));

    await expectLater(
      output.stream.transform(utf8.decoder),
      emits('Hello, World'),
    );
  });


  testUsingContext('symbolize exits when --debug-info argument is missing', () async {
    final Future<void> result = createTestCommandRunner(command)
      .run(const <String>['symbolize']);

    expect(result, throwsToolExit(message: '"--debug-info" is required to symbolize stack traces.'));
  });

  testUsingContext('symbolize exits when --debug-info file is missing', () async {
    final Future<void> result = createTestCommandRunner(command)
      .run(const <String>['symbolize', '--debug-info=app.debug']);

    expect(result, throwsToolExit(message: 'app.debug does not exist.'));
  });

  testUsingContext('symbolize exits when --input file is missing', () async {
    fileSystem.file('app.debug').createSync();
    final Future<void> result = createTestCommandRunner(command)
      .run(const <String>['symbolize', '--debug-info=app.debug', '--input=foo.stack', '--output=results/foo.result']);

    expect(result, throwsToolExit(message: ''));
  });

  testUsingContext('symbolize succeeds when DwarfSymbolizationService does not throw', () async {
    fileSystem.file('app.debug').writeAsBytesSync(<int>[1, 2, 3]);
    fileSystem.file('foo.stack').writeAsStringSync('hello');

    await createTestCommandRunner(command)
      .run(const <String>['symbolize', '--debug-info=app.debug', '--input=foo.stack', '--output=results/foo.result']);

    expect(fileSystem.file('results/foo.result'), exists);
    expect(fileSystem.file('results/foo.result').readAsBytesSync(), <int>[104, 101, 108, 108, 111, 10]); // hello
  });

  testUsingContext('symbolize throws when DwarfSymbolizationService throws', () async {
    command = SymbolizeCommand(
      stdio: stdio,
      fileSystem: fileSystem,
      dwarfSymbolizationService: FakeDwarfSymbolizationService(),
    );

    fileSystem.file('app.debug').writeAsBytesSync(<int>[1, 2, 3]);
    fileSystem.file('foo.stack').writeAsStringSync('hello');

    expect(
      createTestCommandRunner(command).run(const <String>[
        'symbolize', '--debug-info=app.debug', '--input=foo.stack', '--output=results/foo.result']),
      throwsToolExit(message: 'test'),
    );
  });
}

class FakeDwarfSymbolizationService extends Fake implements DwarfSymbolizationService {
  @override
  Future<void> decode({
    @required Stream<List<int>> input,
    @required IOSink output,
    @required Uint8List symbols,
  }) async {
    throwToolExit('test');
  }
}
