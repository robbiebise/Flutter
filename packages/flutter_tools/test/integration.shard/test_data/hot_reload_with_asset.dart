// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import '../test_utils.dart';
import 'project.dart';

class HotReloadWithAssetProject extends Project {
  @override
  final String pubspec = '''
name: test
environment:
  sdk: ">=2.12.0-0 <3.0.0"

dependencies:
  flutter:
    sdk: flutter

flutter:
  assets:
    - pubspec.yaml
  ''';

  @override
  final String main = '''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ByteData message = const StringCodec().encodeMessage('AppLifecycleState.resumed')!;
  await ServicesBinding.instance!.defaultBinaryMessenger.handlePlatformMessage('flutter/lifecycle', message, (_) { });
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    rootBundle.evict('pubspec.yaml');
    rootBundle.load('pubspec.yaml').then((_) {
      print('LOADED DATA');
    }, onError: (dynamic error, StackTrace stackTrace) {
      print('FAILED TO LOAD');
    });
    return Container();
  }
}
''';

  void uncommentHotReloadPrint() {
    final String newMainContents = main.replaceAll(
      'LOADED DATA',
      'SECOND DATA',
    );
    writeFile(fileSystem.path.join(dir.path, 'lib', 'main.dart'), newMainContents);
  }
}
