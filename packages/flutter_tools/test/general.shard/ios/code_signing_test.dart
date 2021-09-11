// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';
import 'dart:convert';

import 'package:flutter_tools/src/base/config.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;
import 'package:flutter_tools/src/ios/code_signing.dart';

import '../../src/common.dart';
import '../../src/fake_process_manager.dart';

const String kCertificates = '''
1) 86f7e437faa5a7fce15d1ddcb9eaeaea377667b8 "iPhone Developer: Profile 1 (1111AAAA11)"
2) da4b9237bacccdf19c0760cab7aec4a8359010b0 "iPhone Developer: Profile 2 (2222BBBB22)"
3) 5bf1fd927dfb8679496a2e6cf00cbe50c1c87145 "iPhone Developer: Profile 3 (3333CCCC33)"
    3 valid identities found''';

void main() {
  group('Auto signing', () {
    Config testConfig;
    AnsiTerminal testTerminal;
    BufferLogger logger;

    setUp(() async {
      logger = BufferLogger.test();
      testConfig = Config.test();
      testTerminal = TestTerminal();
      testTerminal.usesTerminalUi = true;
    });

    testWithoutContext('No auto-sign if Xcode project settings are not available', () async {
      final Map<String, String> signingConfigs = await getCodeSigningIdentityDevelopmentTeam(
        buildSettings: null,
        processManager: FakeProcessManager.empty(),
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      );
      expect(signingConfigs, isNull);
    });

    testWithoutContext('No discovery if development team specified in Xcode project', () async {
      final Map<String, String> signingConfigs = await getCodeSigningIdentityDevelopmentTeam(
        buildSettings: <String, String>{
          'DEVELOPMENT_TEAM': 'abc',
        },
        processManager: FakeProcessManager.empty(),
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      );
      expect(signingConfigs, isNull);
      expect(logger.statusText, equals(
        'Automatically signing iOS for device deployment using specified development team in Xcode project: abc\n'
      ));
    });

    testWithoutContext('No auto-sign if security or openssl not available', () async {
      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        const FakeCommand(
          command: <String>['which', 'security'],
          exitCode: 1,
        ),
      ]);

      final Map<String, String> signingConfigs = await getCodeSigningIdentityDevelopmentTeam(
        buildSettings: <String, String>{
          'bogus': 'bogus',
        },
        processManager: processManager,
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      );
      expect(signingConfigs, isNull);
    });

    testWithoutContext('No valid code signing certificates shows instructions', () async {
      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        const FakeCommand(
          command: <String>['which', 'security'],
        ),
        const FakeCommand(
          command: <String>['which', 'openssl'],
        ),
        const FakeCommand(
          command: <String>['security', 'find-identity', '-p', 'codesigning', '-v'],
        ),
      ]);

      await expectLater(() => getCodeSigningIdentityDevelopmentTeam(
        buildSettings: <String, String>{},
        processManager: processManager,
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      ), throwsToolExit(message: 'No development certificates available to code sign app for device deployment'));
    });

    testWithoutContext('Test single identity and certificate organization works', () async {
      final Completer<void> completer = Completer<void>();
      final StreamController<List<int>> controller = StreamController<List<int>>();
      const String certificates = '''
1) 86f7e437faa5a7fce15d1ddcb9eaeaea377667b8 "iPhone Developer: Profile 1 (1111AAAA11)"
    1 valid identities found''';
      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        const FakeCommand(
          command: <String>['which', 'security'],
        ),
        const FakeCommand(
          command: <String>['which', 'openssl'],
        ),
        const FakeCommand(
          command: <String>['security', 'find-identity', '-p', 'codesigning', '-v'],
          stdout: certificates,
        ),
        const FakeCommand(
          command: <String>['security', 'find-certificate', '-c', '1111AAAA11', '-p'],
          stdout: 'This is a fake certificate',
        ),
        FakeCommand(
          command: const <String>['openssl', 'x509', '-subject'],
          stdin: IOSink(controller.sink),
          stdout: 'subject= /CN=iPhone Developer: Profile 1 (1111AAAA11)/OU=3333CCCC33/O=My Team/C=US',
          completer: completer,
        )
      ]);

      // Verify that certifacte value is passed into openssl command.
      String stdin;
      controller.stream.listen((List<int> chunk) {
        stdin = utf8.decode(chunk);
        completer.complete();
      });

      final Map<String, String> signingConfigs = await getCodeSigningIdentityDevelopmentTeam(
        buildSettings: <String, String>{
          'bogus': 'bogus',
        },
        processManager: processManager,
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      );

      expect(logger.statusText, contains('iPhone Developer: Profile 1 (1111AAAA11)'));
      expect(logger.errorText, isEmpty);
      expect(stdin, 'This is a fake certificate');
      expect(signingConfigs, <String, String>{'DEVELOPMENT_TEAM': '3333CCCC33'});
    });

    testWithoutContext('Test single identity (Catalina format) and certificate organization works', () async {
      final Completer<void> completer = Completer<void>();
      final StreamController<List<int>> controller = StreamController<List<int>>();
      const String certificates = '''
1) 86f7e437faa5a7fce15d1ddcb9eaeaea377667b8 "Apple Development: Profile 1 (1111AAAA11)"
    1 valid identities found''';
      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        const FakeCommand(
          command: <String>['which', 'security'],
        ),
        const FakeCommand(
          command: <String>['which', 'openssl'],
        ),
        const FakeCommand(
          command: <String>['security', 'find-identity', '-p', 'codesigning', '-v'],
          stdout: certificates,
        ),
        const FakeCommand(
          command: <String>['security', 'find-certificate', '-c', '1111AAAA11', '-p'],
          stdout: 'This is a fake certificate',
        ),
        FakeCommand(
          command: const <String>['openssl', 'x509', '-subject'],
          stdin: IOSink(controller.sink),
          stdout: 'subject= /CN=iPhone Developer: Profile 1 (1111AAAA11)/OU=3333CCCC33/O=My Team/C=US',
          completer: completer,
        )
      ]);

      // Verify that certifacte value is passed into openssl command.
      String stdin;
      controller.stream.listen((List<int> chunk) {
        stdin = utf8.decode(chunk);
        completer.complete();
      });

      final Map<String, String> signingConfigs = await getCodeSigningIdentityDevelopmentTeam(
        buildSettings: <String, String>{
          'bogus': 'bogus',
        },
        processManager: processManager,
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      );

      expect(logger.statusText, contains('Apple Development: Profile 1 (1111AAAA11)'));
      expect(logger.errorText, isEmpty);
      expect(stdin, 'This is a fake certificate');
      expect(signingConfigs, <String, String>{'DEVELOPMENT_TEAM': '3333CCCC33'});
    });

    testWithoutContext('Test multiple identity and certificate organization works', () async {
      final Completer<void> completer = Completer<void>();
      final StreamController<List<int>> controller = StreamController<List<int>>();
      mockTerminalStdInStream = Stream<String>.value('3');
      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        const FakeCommand(
          command: <String>['which', 'security'],
        ),
        const FakeCommand(
          command: <String>['which', 'openssl'],
        ),
        const FakeCommand(
          command: <String>['security', 'find-identity', '-p', 'codesigning', '-v'],
          stdout: kCertificates,
        ),
        const FakeCommand(
          command: <String>['security', 'find-certificate', '-c', '3333CCCC33', '-p'],
          stdout: 'This is a fake certificate',
        ),
        FakeCommand(
          command: const <String>['openssl', 'x509', '-subject'],
          stdin: IOSink(controller.sink),
          stdout: 'subject= /CN=iPhone Developer: Profile 3 (3333CCCC33)/OU=4444DDDD44/O=My Team/C=US',
          completer: completer,
        )
      ]);

      // Verify that certifacte value is passed into openssl command.
      String stdin;
      controller.stream.listen((List<int> chunk) {
        stdin = utf8.decode(chunk);
        completer.complete();
      });

      final Map<String, String> signingConfigs = await getCodeSigningIdentityDevelopmentTeam(
        buildSettings: <String, String>{
          'bogus': 'bogus',
        },
        processManager: processManager,
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      );

      expect(
        logger.statusText,
        contains('Please select a certificate for code signing [<bold>1</bold>|2|3|a]: 3'),
      );
      expect(
        logger.statusText,
        contains('Signing iOS app for device deployment using developer identity: "iPhone Developer: Profile 3 (3333CCCC33)"'),
      );
      expect(logger.errorText, isEmpty);
      expect(stdin, 'This is a fake certificate');
      expect(signingConfigs, <String, String>{'DEVELOPMENT_TEAM': '4444DDDD44'});
      expect(testConfig.getValue('ios-signing-cert'), 'iPhone Developer: Profile 3 (3333CCCC33)');
    });

    testWithoutContext('Test multiple identity in machine mode works', () async {
      testTerminal.usesTerminalUi = false;
      final Completer<void> completer = Completer<void>();
      final StreamController<List<int>> controller = StreamController<List<int>>();
      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        const FakeCommand(
          command: <String>['which', 'security'],
        ),
        const FakeCommand(
          command: <String>['which', 'openssl'],
        ),
        const FakeCommand(
          command: <String>['security', 'find-identity', '-p', 'codesigning', '-v'],
          stdout: kCertificates,
        ),
        const FakeCommand(
          command: <String>['security', 'find-certificate', '-c', '1111AAAA11', '-p'],
          stdout: 'This is a fake certificate',
        ),
        FakeCommand(
          command: const <String>['openssl', 'x509', '-subject'],
          stdin: IOSink(controller.sink),
          stdout: 'subject= /CN=iPhone Developer: Profile 3 (1111AAAA11)/OU=5555EEEE55/O=My Team/C=US',
          completer: completer,
        )
      ]);

      // Verify that certifacte value is passed into openssl command.
      String stdin;
      controller.stream.listen((List<int> chunk) {
        stdin = utf8.decode(chunk);
        completer.complete();
      });

      final Map<String, String> signingConfigs = await getCodeSigningIdentityDevelopmentTeam(
        buildSettings: <String, String>{
          'bogus': 'bogus',
        },
        processManager: processManager,
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      );

      expect(
        logger.statusText,
        contains('Signing iOS app for device deployment using developer identity: "iPhone Developer: Profile 1 (1111AAAA11)"'),
      );
      expect(logger.errorText, isEmpty);
      expect(stdin, 'This is a fake certificate');
      expect(signingConfigs, <String, String>{'DEVELOPMENT_TEAM': '5555EEEE55'});
    });

    testWithoutContext('Test saved certificate used', () async {
      testConfig.setValue('ios-signing-cert', 'iPhone Developer: Profile 3 (3333CCCC33)');
      final Completer<void> completer = Completer<void>();
      final StreamController<List<int>> controller = StreamController<List<int>>();
      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        const FakeCommand(
          command: <String>['which', 'security'],
        ),
        const FakeCommand(
          command: <String>['which', 'openssl'],
        ),
        const FakeCommand(
          command: <String>['security', 'find-identity', '-p', 'codesigning', '-v'],
          stdout: kCertificates,
        ),
        const FakeCommand(
          command: <String>['security', 'find-certificate', '-c', '3333CCCC33', '-p'],
          stdout: 'This is a fake certificate',
        ),
        FakeCommand(
          command: const <String>['openssl', 'x509', '-subject'],
          stdin: IOSink(controller.sink),
          stdout: 'subject= /CN=iPhone Developer: Profile 3 (3333CCCC33)/OU=4444DDDD44/O=My Team/C=US',
          completer: completer,
        )
      ]);

      // Verify that certifacte value is passed into openssl command.
      String stdin;
      controller.stream.listen((List<int> chunk) {
        stdin = utf8.decode(chunk);
        completer.complete();
      });

      final Map<String, String> signingConfigs = await getCodeSigningIdentityDevelopmentTeam(
        buildSettings: <String, String>{
          'bogus': 'bogus',
        },
        processManager: processManager,
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      );

      expect(
        logger.statusText,
        contains('Found saved certificate choice "iPhone Developer: Profile 3 (3333CCCC33)". To clear, use "flutter config"'),
      );
      expect(
        logger.statusText,
        contains('Signing iOS app for device deployment using developer identity: "iPhone Developer: Profile 3 (3333CCCC33)"'),
      );
      expect(logger.errorText, isEmpty);
      expect(stdin, 'This is a fake certificate');
      expect(signingConfigs, <String, String>{'DEVELOPMENT_TEAM': '4444DDDD44'});
    });

    testWithoutContext('Test invalid saved certificate shows error and prompts again', () async {
      testConfig.setValue('ios-signing-cert', 'iPhone Developer: Invalid Profile');
      mockTerminalStdInStream = Stream<String>.value('3');
      final Completer<void> completer = Completer<void>();
      final StreamController<List<int>> controller = StreamController<List<int>>();
      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        const FakeCommand(
          command: <String>['which', 'security'],
        ),
        const FakeCommand(
          command: <String>['which', 'openssl'],
        ),
        const FakeCommand(
          command: <String>['security', 'find-identity', '-p', 'codesigning', '-v'],
          stdout: kCertificates,
        ),
        const FakeCommand(
          command: <String>['security', 'find-certificate', '-c', '3333CCCC33', '-p'],
          stdout: 'This is a fake certificate',
        ),
        FakeCommand(
          command: const <String>['openssl', 'x509', '-subject'],
          stdin: IOSink(controller.sink),
          stdout: 'subject= /CN=iPhone Developer: Profile 3 (3333CCCC33)/OU=4444DDDD44/O=My Team/C=US',
          completer: completer,
        )
      ]);

      // Verify that certifacte value is passed into openssl command.
      String stdin;
      controller.stream.listen((List<int> chunk) {
        stdin = utf8.decode(chunk);
        completer.complete();
      });

      final Map<String, String> signingConfigs = await getCodeSigningIdentityDevelopmentTeam(
        buildSettings: <String, String>{
          'bogus': 'bogus',
        },
        processManager: processManager,
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      );

      expect(
        logger.errorText,
        containsIgnoringWhitespace('Saved signing certificate "iPhone Developer: Invalid Profile" is not a valid development certificate'),
      );
      expect(
        logger.statusText,
        contains('Certificate choice "iPhone Developer: Profile 3 (3333CCCC33)"'),
      );
      expect(signingConfigs, <String, String>{'DEVELOPMENT_TEAM': '4444DDDD44'});
      expect(stdin, 'This is a fake certificate');
      expect(testConfig.getValue('ios-signing-cert'), 'iPhone Developer: Profile 3 (3333CCCC33)');
    });

    testWithoutContext('find-identity failure', () async {
      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        const FakeCommand(
          command: <String>['which', 'security'],
        ),
        const FakeCommand(
          command: <String>['which', 'openssl'],
        ),
        const FakeCommand(
          command: <String>['security', 'find-identity', '-p', 'codesigning', '-v'],
          exitCode: 1,
        ),
      ]);

      final Map<String, String> signingConfigs = await getCodeSigningIdentityDevelopmentTeam(
        buildSettings: <String, String>{
          'bogus': 'bogus',
        },
        processManager: processManager,
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      );
      expect(signingConfigs, isNull);
    });

    testWithoutContext('find-certificate failure', () async {
      mockTerminalStdInStream = Stream<String>.value('3');

      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        const FakeCommand(
          command: <String>['which', 'security'],
        ),
        const FakeCommand(
          command: <String>['which', 'openssl'],
        ),
        const FakeCommand(
          command: <String>['security', 'find-identity', '-p', 'codesigning', '-v'],
          stdout: kCertificates,
        ),
        const FakeCommand(
          command: <String>['security', 'find-certificate', '-c', '3333CCCC33', '-p'],
          exitCode: 1,
        ),
      ]);

      final Map<String, String> signingConfigs = await getCodeSigningIdentityDevelopmentTeam(
        buildSettings: <String, String>{
          'bogus': 'bogus',
        },
        processManager: processManager,
        logger: logger,
        config: testConfig,
        terminal: testTerminal,
      );
      expect(signingConfigs, isNull);
    });
  });
}

Stream<String> mockTerminalStdInStream;

class TestTerminal extends AnsiTerminal {
  TestTerminal() : super(stdio: globals.stdio, platform: globals.platform);

  @override
  String bolden(String message) => '<bold>$message</bold>';

  @override
  Stream<String> get keystrokes {
    return mockTerminalStdInStream;
  }

  @override
  int get preferredStyle => 0;
}
