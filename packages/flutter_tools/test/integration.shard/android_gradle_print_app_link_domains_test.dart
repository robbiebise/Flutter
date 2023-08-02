// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/gradle_utils.dart'
    show getGradlewFileName;
import 'package:flutter_tools/src/base/io.dart';
import 'package:xml/xml.dart';

import '../src/common.dart';
import 'test_utils.dart';

final XmlElement pureHttpIntentFilter = XmlElement(
  XmlName('intent-filter'),
  <XmlAttribute>[XmlAttribute(XmlName('autoVerify', 'android'), 'true')],
  <XmlElement>[
    XmlElement(
      XmlName('action'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.action.VIEW')],
    ),
    XmlElement(
      XmlName('category'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.category.DEFAULT')],
    ),
    XmlElement(
      XmlName('category'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.category.BROWSABLE')],
    ),
    XmlElement(
      XmlName('data'),
      <XmlAttribute>[
        XmlAttribute(XmlName('scheme', 'android'), 'http'),
        XmlAttribute(XmlName('host', 'android'), 'pure-http.com'),
      ],
    ),
  ],
);

final XmlElement nonHttpIntentFilter = XmlElement(
  XmlName('intent-filter'),
  <XmlAttribute>[XmlAttribute(XmlName('autoVerify', 'android'), 'true')],
  <XmlElement>[
    XmlElement(
      XmlName('action'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.action.VIEW')],
    ),
    XmlElement(
      XmlName('category'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.category.DEFAULT')],
    ),
    XmlElement(
      XmlName('category'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.category.BROWSABLE')],
    ),
    XmlElement(
      XmlName('data'),
      <XmlAttribute>[
        XmlAttribute(XmlName('scheme', 'android'), 'custom'),
        XmlAttribute(XmlName('host', 'android'), 'custom.com'),
      ],
    ),
  ],
);

final XmlElement hybridIntentFilter = XmlElement(
  XmlName('intent-filter'),
  <XmlAttribute>[XmlAttribute(XmlName('autoVerify', 'android'), 'true')],
  <XmlElement>[
    XmlElement(
      XmlName('action'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.action.VIEW')],
    ),
    XmlElement(
      XmlName('category'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.category.DEFAULT')],
    ),
    XmlElement(
      XmlName('category'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.category.BROWSABLE')],
    ),
    XmlElement(
      XmlName('data'),
      <XmlAttribute>[
        XmlAttribute(XmlName('scheme', 'android'), 'custom'),
        XmlAttribute(XmlName('host', 'android'), 'hybrid.com'),
      ],
    ),
    XmlElement(
      XmlName('data'),
      <XmlAttribute>[
        XmlAttribute(XmlName('scheme', 'android'), 'http'),
      ],
    ),
  ],
);

final XmlElement nonAutoVerifyIntentFilter = XmlElement(
  XmlName('intent-filter'),
  <XmlAttribute>[],
  <XmlElement>[
    XmlElement(
      XmlName('action'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.action.VIEW')],
    ),
    XmlElement(
      XmlName('category'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.category.DEFAULT')],
    ),
    XmlElement(
      XmlName('category'),
      <XmlAttribute>[XmlAttribute(XmlName('name', 'android'), 'android.intent.category.BROWSABLE')],
    ),
    XmlElement(
      XmlName('data'),
      <XmlAttribute>[
        XmlAttribute(XmlName('scheme', 'android'), 'http'),
        XmlAttribute(XmlName('host', 'android'), 'non-auto-verify.com'),
      ],
    ),
  ],
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = createResolvedTempDirectorySync('run_test.');
  });

  tearDown(() async {
    tryToDelete(tempDir);
  });

  void testDeeplink(dynamic deeplink, String scheme, String host, String path) {
    deeplink as Map<String, dynamic>;
    expect(deeplink['scheme'], scheme);
    expect(deeplink['host'], host);
    expect(deeplink['path'], path);
  }

  testWithoutContext(
      'gradle task exists named print<mode>AppLinkDomains that prints app link domains', () async {
    // Create a new flutter project.
    final String flutterBin =
    fileSystem.path.join(getFlutterRoot(), 'bin', 'flutter');
    ProcessResult result = await processManager.run(<String>[
      flutterBin,
      'create',
      tempDir.path,
      '--project-name=testapp',
    ], workingDirectory: tempDir.path);
    expect(result, const ProcessResultMatcher());
    // Adds intent filters for app links
    final String androidManifestPath =  fileSystem.path.join(tempDir.path, 'android', 'app', 'src', 'main', 'AndroidManifest.xml');
    final io.File androidManifestFile = io.File(androidManifestPath);
    final XmlDocument androidManifest = XmlDocument.parse(androidManifestFile.readAsStringSync());
    final XmlElement activity = androidManifest.findAllElements('activity').first;
    activity.children.add(pureHttpIntentFilter);
    activity.children.add(nonHttpIntentFilter);
    activity.children.add(hybridIntentFilter);
    activity.children.add(nonAutoVerifyIntentFilter);
    androidManifestFile.writeAsStringSync(androidManifest.toString(), flush: true);

    // Ensure that gradle files exists from templates.
    result = await processManager.run(<String>[
      flutterBin,
      'build',
      'apk',
      '--config-only',
    ], workingDirectory: tempDir.path);
    expect(result, const ProcessResultMatcher());

    final Directory androidApp = tempDir.childDirectory('android');
    result = await processManager.run(<String>[
      '.${platform.pathSeparator}${getGradlewFileName(platform)}',
      ...getLocalEngineArguments(),
      '-q', // quiet output.
      'dumpDebugAppLinkSettings',
    ], workingDirectory: androidApp.path);

    expect(result, const ProcessResultMatcher());

    final io.File fileDump = tempDir.childDirectory('build').childDirectory('app').childFile('app-link-settings-debug.json');
    expect(fileDump.existsSync(), true);
    final Map<String, dynamic> json = jsonDecode(fileDump.readAsStringSync()) as Map<String, dynamic>;
    expect(json['applicationId'], 'com.example.testapp');
    final List<dynamic> deeplinks = json['deeplinks']! as List<dynamic>;
    expect(deeplinks.length, 5);
    testDeeplink(deeplinks[0], 'http', 'pure-http.com', '.*');
    testDeeplink(deeplinks[1], 'custom', 'custom.com', '.*');
    testDeeplink(deeplinks[2], 'custom', 'hybrid.com', '.*');
    testDeeplink(deeplinks[3], 'http', 'hybrid.com', '.*');
    testDeeplink(deeplinks[4], 'http', 'non-auto-verify.com', '.*');
  });
}
