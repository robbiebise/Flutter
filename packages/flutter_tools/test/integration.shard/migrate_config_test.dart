// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/migrate/migrate_config.dart';
import 'package:flutter_tools/src/project.dart';

import '../src/common.dart';
import '../src/context.dart';
import 'test_data/migrate_project.dart';
import 'test_driver.dart';
import 'test_utils.dart';


void main() {
  Directory tempDir;
  FlutterRunTestDriver flutter;
  BufferLogger logger;

  setUp(() async {
    tempDir = createResolvedTempDirectorySync('run_test.');
    flutter = FlutterRunTestDriver(tempDir);
    logger = BufferLogger.test();
  });

  tearDown(() async {
    await flutter.stop();
    tryToDelete(tempDir);
  });

  testUsingContext('parse simple config file', () async {
    // Flutter Stable 1.22.6 hash: 9b2d32b605630f28625709ebd9d78ab3016b2bf6
    final MigrateProject project = MigrateProject('version:1.22.6_stable');
    await project.setUpIn(tempDir);
    final String flutterBin = fileSystem.path.join(getFlutterRoot(), 'bin', 'flutter');

    FlutterProjectFactory flutterFactory = FlutterProjectFactory(logger: logger, fileSystem: fileSystem);
    FlutterProject flutterProject = flutterFactory.fromDirectory(tempDir);

    File configFile = tempDir.childFile('.migrate_config');
    configFile.createSync(recursive: true);
    configFile.writeAsStringSync('''
# Generated section.
platform: root
createRevision: abcdefg1234567
baseRevision: abcdefg1234567base

# User provided section

# List of Local paths (relative to this file) that should be
# ignored by the migrate tool.
#
# Files that are not part of the templates will be ignored by default.
unmanagedFiles:
  - lib/main.dart

''', flush: true);
    MigrateConfig config = MigrateConfig.fromFile(configFile);

    expect(config.platform, equals('root'));
    expect(config.createRevision, equals('abcdefg1234567'));
    expect(config.baseRevision, equals('abcdefg1234567base'));
    expect(config.unmanagedFiles[0], equals('lib/main.dart'));

    configFile.writeAsStringSync('''
# Generated section.
platform: root
createRevision: null
baseRevision: null

# User provided section

# List of Local paths (relative to this file) that should be
# ignored by the migrate tool.
#
# Files that are not part of the templates will be ignored by default.
unmanagedFiles:

''', flush: true);

    config = MigrateConfig.fromFile(configFile);

    expect(config.platform, equals('root'));
    expect(config.createRevision, equals(null));
    expect(config.baseRevision, equals(null));
    expect(config.unmanagedFiles.isEmpty, true);
  });

  testUsingContext('write simple config file', () async {
    // Flutter Stable 1.22.6 hash: 9b2d32b605630f28625709ebd9d78ab3016b2bf6
    final MigrateProject project = MigrateProject('version:1.22.6_stable');
    await project.setUpIn(tempDir);
    final String flutterBin = fileSystem.path.join(getFlutterRoot(), 'bin', 'flutter');

    FlutterProjectFactory flutterFactory = FlutterProjectFactory(logger: logger, fileSystem: fileSystem);
    FlutterProject flutterProject = flutterFactory.fromDirectory(tempDir);

    MigrateConfig config = MigrateConfig(
      platform: 'root',
      createRevision: null,
      baseRevision: null,
      unmanagedFiles: <String>[],
    );
    config.writeFile(projectDirectory: tempDir);
    File configFile = tempDir.childFile('.migrate_config');
    expect(configFile.readAsStringSync(), equals('''
# Generated section.
platform: root
createRevision: null
baseRevision: null

# User provided section

# List of Local paths (relative to this file) that should be
# ignored by the migrate tool.
#
# Files that are not part of the templates will be ignored by default.
unmanagedFiles:

'''));

    config = MigrateConfig(
      platform: 'android',
      createRevision: 'abcd',
      baseRevision: '1234',
      unmanagedFiles: <String>['test1/test.dart', 'file/two.txt'],
    );
    config.writeFile(projectDirectory: tempDir);
    configFile = tempDir.childDirectory('android').childFile('.migrate_config');
    expect(configFile.readAsStringSync(), equals('''
# Generated section.
platform: android
createRevision: abcd
baseRevision: 1234

# User provided section

# List of Local paths (relative to this file) that should be
# ignored by the migrate tool.
#
# Files that are not part of the templates will be ignored by default.
unmanagedFiles:
  - test1/test.dart
  - file/two.txt

'''));
  });

  testUsingContext('parse project', () async {
    // Flutter Stable 1.22.6 hash: 9b2d32b605630f28625709ebd9d78ab3016b2bf6
    final MigrateProject project = MigrateProject('version:1.22.6_stable');
    await project.setUpIn(tempDir);
    final String flutterBin = fileSystem.path.join(getFlutterRoot(), 'bin', 'flutter');

    FlutterProjectFactory flutterFactory = FlutterProjectFactory(logger: logger, fileSystem: fileSystem);
    FlutterProject flutterProject = flutterFactory.fromDirectory(tempDir);

    File configFile = tempDir.childFile('.migrate_config');
    configFile.createSync(recursive: true);
    configFile.writeAsStringSync('''
# Generated section.
platform: root
createRevision: abcdefg1234567
baseRevision: abcdefg1234567base

# User provided section

# List of Local paths (relative to this file) that should be
# ignored by the migrate tool.
#
# Files that are not part of the templates will be ignored by default.
unmanagedFiles:
  - lib/main.dart

''', flush: true);

    configFile = tempDir.childDirectory('android').childFile('.migrate_config');
    configFile.writeAsStringSync('''
# Generated section.
platform: android
createRevision: abcdefg1234567
baseRevision: abcdefg1234567

# User provided section

# List of Local paths (relative to this file) that should be
# ignored by the migrate tool.
#
# Files that are not part of the templates will be ignored by default.
unmanagedFiles:

''', flush: true);

    final String currentRevision = 'newlygenerated';
    final List<MigrateConfig> configs = await MigrateConfig.parseOrCreateMigrateConfigs(projectDirectory: tempDir, currentRevision: currentRevision);

    expect(configs.length, equals(3));
    expect(configs[0].platform, equals('root'));
    expect(configs[0].baseRevision, equals('abcdefg1234567base'));
    expect(configs[1].platform, equals('android'));
    expect(configs[1].baseRevision, equals('abcdefg1234567'));
    expect(configs[2].platform, equals('ios'));
    expect(configs[2].baseRevision, equals(currentRevision));
    expect(configs[2].createRevision, equals(null));
  });
}
