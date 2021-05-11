// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_devicelab/framework/utils.dart';

import 'common.dart';

void main() {
  group('grep', () {
    test('greps lines', () {
      expect(grep('b', from: 'ab\ncd\nba'), <String>['ab', 'ba']);
    });

    test('understands RegExp', () {
      expect(grep(RegExp('^b'), from: 'ab\nba'), <String>['ba']);
    });
  });

  group('parse service', () {
    const String badOutput = 'No uri here';
    const String sampleOutput = 'An Observatory debugger and profiler on '
      'Pixel 3 XL is available at: http://127.0.0.1:9090/LpjUpsdEjqI=/';

    test('uri', () {
        expect(parseServiceUri(sampleOutput),
          Uri.parse('http://127.0.0.1:9090/LpjUpsdEjqI=/'));
      expect(parseServiceUri(badOutput), null);
    });

    test('port', () {
      expect(parseServicePort(sampleOutput), 9090);
      expect(parseServicePort(badOutput), null);
    });
  });

  group('engine environment declarations', () {
    test('localEngine', () {
      expect(localEngine, null);
      expect(localEngineSrcPath, null);
    });
  });

  group('evalFlutter', () {
    test('sets environment', () async {
      final StringBuffer capturedPrintLines = StringBuffer();
      await runZoned<Future<void>>(
        () async {
          // Doesn't matter which command is run.
          await evalFlutter('--version');
        },
        zoneSpecification: ZoneSpecification(
          // Intercept print calls from utils.
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) async {
            capturedPrintLines.writeln(line);
          },
        ),
      );
      final String capturedPrint = capturedPrintLines.toString();
      expect(capturedPrint, contains('flutter --version in'));
      expect(capturedPrint, contains('with environment {BOT: true, LANG: en_US.UTF-8}'));
      expect(capturedPrint, contains('exit code: 0'));
    });
  });
}
