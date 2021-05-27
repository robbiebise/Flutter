// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/time.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;
import 'package:flutter_tools/src/version.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/fake_process_manager.dart';

final SystemClock _testClock = SystemClock.fixed(DateTime(2015, 1, 1));
void main() {
  FakeProcessManager processManager;
  Cache cache;
  FileSystem fileSystem;

  setUp(() {
    processManager = FakeProcessManager.empty();
    fileSystem = MemoryFileSystem.test();
    cache = Cache.test(processManager: FakeProcessManager.any(), fileSystem: fileSystem);
    fileSystem.directory('cache/bin/cache').createSync(recursive: true);
    fileSystem.file('cache/bin/internal/engine.version')
      ..createSync(recursive: true)
      ..writeAsStringSync('ABCD');
  });

  testUsingContext('Channel enum and string transform to each other', () {
    for (final Channel channel in Channel.values) {
      expect(getNameForChannel(channel), kOfficialChannels.toList()[channel.index]);
    }
    expect(kOfficialChannels.toList().map((String str) => getChannelForName(str)).toList(),
      Channel.values);
  });

  for (final String channel in kOfficialChannels) {
    DateTime getChannelUpToDateVersion() {
      return _testClock.ago(FlutterVersion.versionAgeConsideredUpToDate(channel) ~/ 2);
    }

    DateTime getChannelOutOfDateVersion() {
      return _testClock.ago(FlutterVersion.versionAgeConsideredUpToDate(channel) * 2);
    }

    group('$FlutterVersion for $channel', () {
      setUpAll(() {
        Cache.disableLocking();
        FlutterVersion.timeToPauseToLetUserReadTheMessage = Duration.zero;
      });

      testUsingContext('prints nothing when Flutter installation looks fresh', () async {
        processManager.addCommand(const FakeCommand(
          command: <String>['git', '-c', 'log.showSignature=false', 'log', '-n', '1', '--pretty=format:%H'],
          stdout: '1234abcd',
        ));

        processManager.addCommand(const FakeCommand(
          command: <String>['git', 'tag', '--points-at', '1234abcd'],
        ));

        processManager.addCommand(const FakeCommand(
          command: <String>['git', 'describe', '--match', '*.*.*', '--long', '--tags', '1234abcd'],
          stdout: '0.1.2-3-1234abcd',
        ));

        processManager.addCommand(FakeCommand(
          command: const <String>['git', 'rev-parse', '--abbrev-ref', '--symbolic', '@{u}'],
          stdout: channel,
        ));

        processManager.addCommand(FakeCommand(
          command: const <String>['git', '-c', 'log.showSignature=false', 'log', '-n', '1', '--pretty=format:%ad', '--date=iso'],
          stdout: getChannelUpToDateVersion().toString(),
        ));

        processManager.addCommand(const FakeCommand(
          command: <String>['git', 'remote'],
        ));

        processManager.addCommand(const FakeCommand(
          command: <String>['git', 'remote', 'add', '__flutter_version_check__', 'https://github.com/flutter/flutter.git'],
        ));

        processManager.addCommand(FakeCommand(
          command: <String>['git', 'fetch', '__flutter_version_check__', channel],
        ));

        processManager.addCommand(FakeCommand(
          command: <String>['git', '-c', 'log.showSignature=false', 'log', '__flutter_version_check__/$channel', '-n', '1', '--pretty=format:%ad', '--date=iso'],
          stdout: getChannelOutOfDateVersion().toString(),
        ));
        processManager.addCommand(const FakeCommand(
          command: <String>['git', 'remote'],
        ));

        processManager.addCommands(<FakeCommand>[
          const FakeCommand(
            command: <String>['git', '-c', 'log.showSignature=false', 'log', '-n', '1', '--pretty=format:%ar'],
            stdout: '1 second ago',
          ),
          FakeCommand(
            command: const <String>['git', '-c', 'log.showSignature=false', 'log', '-n', '1', '--pretty=format:%ad', '--date=iso'],
            stdout: getChannelUpToDateVersion().toString(),
          ),
          FakeCommand(
            command: const <String>['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
            stdout: channel,
          ),
        ]);

        final FlutterVersion flutterVersion = globals.flutterVersion;
        await flutterVersion.checkFlutterVersionFreshness();
        expect(flutterVersion.channel, channel);
        expect(flutterVersion.frameworkRevision, '1234abcd');
        expect(flutterVersion.frameworkRevisionShort, '1234abcd');
        expect(flutterVersion.frameworkVersion, '0.0.0-unknown');
        expect(
          flutterVersion.toString(),
          'Flutter • channel $channel • unknown source\n'
          'Framework • revision 1234abcd (1 second ago) • ${getChannelUpToDateVersion()}\n'
          'Engine • revision ABCD\n'
          'Tools • Dart ',
        );
        expect(flutterVersion.frameworkAge, '1 second ago');
        expect(flutterVersion.getVersionString(), '$channel/1234abcd');
        expect(flutterVersion.getBranchName(), channel);
        expect(flutterVersion.getVersionString(redactUnknownBranches: true), '$channel/1234abcd');
        expect(flutterVersion.getBranchName(redactUnknownBranches: true), channel);

        _expectVersionMessage('');
        expect(processManager.hasRemainingExpectations, isFalse);
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(clock: _testClock),
        ProcessManager: () => processManager,
        Cache: () => cache,
      });
    });
  }

  testUsingContext('version handles unknown branch', () async {
    processManager.addCommands(<FakeCommand>[
      const FakeCommand(
        command: <String>['git', '-c', 'log.showSignature=false', 'log', '-n', '1', '--pretty=format:%H'],
        stdout: '1234abcd',
      ),
      const FakeCommand(
        command: <String>['git', 'tag', '--points-at', '1234abcd'],
      ),
      const FakeCommand(
        command: <String>['git', 'describe', '--match', '*.*.*', '--long', '--tags', '1234abcd'],
        stdout: '0.1.2-3-1234abcd',
      ),
      const FakeCommand(
        command: <String>['git', 'rev-parse', '--abbrev-ref', '--symbolic', '@{u}'],
        stdout: 'feature-branch',
      ),
      const FakeCommand(
        command: <String>['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
        stdout: 'feature-branch',
      ),
    ]);

    final FlutterVersion flutterVersion = globals.flutterVersion;
    expect(flutterVersion.channel, 'feature-branch');
    expect(flutterVersion.getVersionString(), 'feature-branch/1234abcd');
    expect(flutterVersion.getBranchName(), 'feature-branch');
    expect(flutterVersion.getVersionString(redactUnknownBranches: true), '[user-branch]/1234abcd');
    expect(flutterVersion.getBranchName(redactUnknownBranches: true), '[user-branch]');
    expect(processManager.hasRemainingExpectations, isFalse);
  }, overrides: <Type, Generator>{
    FlutterVersion: () => FlutterVersion(clock: _testClock),
    ProcessManager: () => processManager,
    Cache: () => cache,
  });

  testUsingContext('GitTagVersion', () {
    const String hash = 'abcdef';
    GitTagVersion gitTagVersion;

    // Master channel
    gitTagVersion = GitTagVersion.parse('1.2.3-4.5.pre-13-g$hash');
    expect(gitTagVersion.frameworkVersionFor(hash), '1.2.3-5.0.pre.13');
    expect(gitTagVersion.gitTag, '1.2.3-4.5.pre');
    expect(gitTagVersion.devVersion, 4);
    expect(gitTagVersion.devPatch, 5);

    // Stable channel
    gitTagVersion = GitTagVersion.parse('1.2.3');
    expect(gitTagVersion.frameworkVersionFor(hash), '1.2.3');
    expect(gitTagVersion.x, 1);
    expect(gitTagVersion.y, 2);
    expect(gitTagVersion.z, 3);
    expect(gitTagVersion.devVersion, null);
    expect(gitTagVersion.devPatch, null);

    // Dev channel
    gitTagVersion = GitTagVersion.parse('1.2.3-4.5.pre');
    expect(gitTagVersion.frameworkVersionFor(hash), '1.2.3-4.5.pre');
    expect(gitTagVersion.gitTag, '1.2.3-4.5.pre');
    expect(gitTagVersion.devVersion, 4);
    expect(gitTagVersion.devPatch, 5);

    gitTagVersion = GitTagVersion.parse('1.2.3-13-g$hash');
    expect(gitTagVersion.frameworkVersionFor(hash), '1.2.4-0.0.pre.13');
    expect(gitTagVersion.gitTag, '1.2.3');
    expect(gitTagVersion.devVersion, null);
    expect(gitTagVersion.devPatch, null);

    // new tag release format, dev channel
    gitTagVersion = GitTagVersion.parse('1.2.3-4.5.pre-0-g$hash');
    expect(gitTagVersion.frameworkVersionFor(hash), '1.2.3-4.5.pre');
    expect(gitTagVersion.gitTag, '1.2.3-4.5.pre');
    expect(gitTagVersion.devVersion, 4);
    expect(gitTagVersion.devPatch, 5);

    // new tag release format, stable channel
    gitTagVersion = GitTagVersion.parse('1.2.3-13-g$hash');
    expect(gitTagVersion.frameworkVersionFor(hash), '1.2.4-0.0.pre.13');
    expect(gitTagVersion.gitTag, '1.2.3');
    expect(gitTagVersion.devVersion, null);
    expect(gitTagVersion.devPatch, null);

    expect(GitTagVersion.parse('98.76.54-32-g$hash').frameworkVersionFor(hash), '98.76.55-0.0.pre.32');
    expect(GitTagVersion.parse('10.20.30-0-g$hash').frameworkVersionFor(hash), '10.20.30');
    expect(testLogger.traceText, '');
    expect(GitTagVersion.parse('v1.2.3+hotfix.1-4-g$hash').frameworkVersionFor(hash), '0.0.0-unknown');
    expect(GitTagVersion.parse('x1.2.3-4-g$hash').frameworkVersionFor(hash), '0.0.0-unknown');
    expect(GitTagVersion.parse('1.0.0-unknown-0-g$hash').frameworkVersionFor(hash), '0.0.0-unknown');
    expect(GitTagVersion.parse('beta-1-g$hash').frameworkVersionFor(hash), '0.0.0-unknown');
    expect(GitTagVersion.parse('1.2.3-4-gx$hash').frameworkVersionFor(hash), '0.0.0-unknown');
    expect(testLogger.statusText, '');
    expect(testLogger.errorText, '');
    expect(
      testLogger.traceText,
      'Could not interpret results of "git describe": v1.2.3+hotfix.1-4-gabcdef\n'
      'Could not interpret results of "git describe": x1.2.3-4-gabcdef\n'
      'Could not interpret results of "git describe": 1.0.0-unknown-0-gabcdef\n'
      'Could not interpret results of "git describe": beta-1-gabcdef\n'
      'Could not interpret results of "git describe": 1.2.3-4-gxabcdef\n',
    );
  });

  testUsingContext('determine reports correct stable version if HEAD is at a tag', () {
    const String stableTag = '1.2.3';
    final FakeProcessManager fakeProcessManager = FakeProcessManager.list(
      <FakeCommand>[
        const FakeCommand(
          command: <String>['git', 'tag', '--points-at', 'HEAD'],
          stdout: stableTag,
        ),
      ],
    );
    final ProcessUtils processUtils = ProcessUtils(
      processManager: fakeProcessManager,
      logger: BufferLogger.test(),
    );
    final GitTagVersion gitTagVersion = GitTagVersion.determine(processUtils, workingDirectory: '.');
    expect(gitTagVersion.frameworkVersionFor('abcd1234'), stableTag);
  });

  testUsingContext('determine favors stable tag over dev tag if both identify HEAD', () {
    const String stableTag = '1.2.3';
    final FakeProcessManager fakeProcessManager = FakeProcessManager.list(
      <FakeCommand>[
        const FakeCommand(
          command: <String>['git', 'tag', '--points-at', 'HEAD'],
          // This tests the unlikely edge case where a dev release made it to stable without any cherry picks
          stdout: '1.2.3-6.0.pre\n$stableTag',
        ),
      ],
    );
    final ProcessUtils processUtils = ProcessUtils(
      processManager: fakeProcessManager,
      logger: BufferLogger.test(),
    );
    final GitTagVersion gitTagVersion = GitTagVersion.determine(processUtils, workingDirectory: '.');
    expect(gitTagVersion.frameworkVersionFor('abcd1234'), stableTag);
  });

  testUsingContext('determine reports correct git describe version if HEAD is not at a tag', () {
    const String devTag = '1.2.3-2.0.pre';
    const String headRevision = 'abcd1234';
    const String commitsAhead = '12';
    final FakeProcessManager fakeProcessManager = FakeProcessManager.list(
      <FakeCommand>[
        const FakeCommand(
          command: <String>['git', 'tag', '--points-at', 'HEAD'],
          stdout: '', // no tag
        ),
        const FakeCommand(
          command: <String>['git', 'describe', '--match', '*.*.*', '--long', '--tags', 'HEAD'],
          stdout: '$devTag-$commitsAhead-g$headRevision',
        ),
      ],
    );
    final ProcessUtils processUtils = ProcessUtils(
      processManager: fakeProcessManager,
      logger: BufferLogger.test(),
    );
    final GitTagVersion gitTagVersion = GitTagVersion.determine(processUtils, workingDirectory: '.');
    // reported version should increment the number after the dash
    expect(gitTagVersion.frameworkVersionFor(headRevision), '1.2.3-3.0.pre.12');
  });

  testUsingContext('determine does not call fetch --tags', () {
    final FakeProcessManager fakeProcessManager = FakeProcessManager.list(<FakeCommand>[
      const FakeCommand(
        command: <String>['git', 'tag', '--points-at', 'HEAD'],
      ),
      const FakeCommand(
        command: <String>['git', 'describe', '--match', '*.*.*', '--long', '--tags', 'HEAD'],
        stdout: 'v0.1.2-3-1234abcd',
      ),
    ]);
    final ProcessUtils processUtils = ProcessUtils(
      processManager: fakeProcessManager,
      logger: BufferLogger.test(),
    );

    GitTagVersion.determine(processUtils, workingDirectory: '.');
    expect(fakeProcessManager, hasNoRemainingExpectations);
  });

  testUsingContext('determine does not fetch tags on dev/stable/beta', () {
    final FakeProcessManager fakeProcessManager = FakeProcessManager.list(<FakeCommand>[
      const FakeCommand(
        command: <String>['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
        stdout: 'dev',
      ),
      const FakeCommand(
        command: <String>['git', 'tag', '--points-at', 'HEAD'],
      ),
      const FakeCommand(
        command: <String>['git', 'describe', '--match', '*.*.*', '--long', '--tags', 'HEAD'],
        stdout: 'v0.1.2-3-1234abcd',
      ),
    ]);
    final ProcessUtils processUtils = ProcessUtils(
      processManager: fakeProcessManager,
      logger: BufferLogger.test(),
    );

    GitTagVersion.determine(processUtils, workingDirectory: '.', fetchTags: true);
    expect(fakeProcessManager, hasNoRemainingExpectations);
  });

  testUsingContext('determine calls fetch --tags on master', () {
    final FakeProcessManager fakeProcessManager = FakeProcessManager.list(<FakeCommand>[
      const FakeCommand(
        command: <String>['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
        stdout: 'master',
      ),
      const FakeCommand(
        command: <String>['git', 'fetch', 'https://github.com/flutter/flutter.git', '--tags', '-f'],
      ),
      const FakeCommand(
        command: <String>['git', 'tag', '--points-at', 'HEAD'],
      ),
      const FakeCommand(
        command: <String>['git', 'describe', '--match', '*.*.*', '--long', '--tags', 'HEAD'],
        stdout: 'v0.1.2-3-1234abcd',
      ),
    ]);
    final ProcessUtils processUtils = ProcessUtils(
      processManager: fakeProcessManager,
      logger: BufferLogger.test(),
    );

    GitTagVersion.determine(processUtils, workingDirectory: '.', fetchTags: true);
    expect(fakeProcessManager, hasNoRemainingExpectations);
  });

  testUsingContext('determine uses overridden git url', () {
    final FakeProcessManager fakeProcessManager = FakeProcessManager.list(<FakeCommand>[
      const FakeCommand(
        command: <String>['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
        stdout: 'master',
      ),
      const FakeCommand(
        command: <String>['git', 'fetch', 'https://githubmirror.com/flutter.git', '--tags', '-f'],
      ),
      const FakeCommand(
        command: <String>['git', 'tag', '--points-at', 'HEAD'],
      ),
      const FakeCommand(
        command: <String>['git', 'describe', '--match', '*.*.*', '--long', '--tags', 'HEAD'],
        stdout: 'v0.1.2-3-1234abcd',
      ),
    ]);
    final ProcessUtils processUtils = ProcessUtils(
      processManager: fakeProcessManager,
      logger: BufferLogger.test(),
    );

    GitTagVersion.determine(processUtils, workingDirectory: '.', fetchTags: true);
    expect(fakeProcessManager, hasNoRemainingExpectations);
  }, overrides: <Type, Generator>{
    Platform: () => FakePlatform(environment: <String, String>{
      'FLUTTER_GIT_URL': 'https://githubmirror.com/flutter.git',
    }),
  });
}

void _expectVersionMessage(String message) {
  expect(testLogger.statusText.trim(), message.trim());
  testLogger.clear();
}
