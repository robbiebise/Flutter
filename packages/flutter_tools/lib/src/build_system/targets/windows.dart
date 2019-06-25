// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../base/file_system.dart';
import '../build_system.dart';

/// Copies all of the input files to the correct copy dir.
Future<void> copyWindowsAssets(Map<String, ChangeType> updates,
  Environment environment) async {
  // This path needs to match the prefix in the rule below.
  final String basePath = fs.path.join(
    environment.cacheDir.absolute.path,
    'engine',
    'windows-x64',
  );
  for (String input in updates.keys) {
    final String outputPath = fs.path.join(
      environment.projectDir.path,
      'windows',
      'flutter',
      fs.path.relative(input, from: basePath),
    );
    final File destinationFile = fs.file(outputPath);
    if (!destinationFile.parent.existsSync()) {
      destinationFile.parent.createSync(recursive: true);
    }
    fs.file(input).copySync(destinationFile.path);
  }
}

/// Copies the Windows desktop embedding files to the copy directory.
const Target unpackWindows = Target(
  name: 'unpack_windows',
  inputs: <Source>[
    Source.pattern('{CACHE_DIR}/engine/windows-x64/flutter_windows.dll'),
    Source.pattern('{CACHE_DIR}/engine/windows-x64/flutter_windows.dll.exp'),
    Source.pattern('{CACHE_DIR}/engine/windows-x64/flutter_windows.dll.lib'),
    Source.pattern('{CACHE_DIR}/engine/windows-x64/flutter_windows.dll.pdb'),
    Source.pattern('{CACHE_DIR}/engine/windows-x64/flutter_export.h'),
    Source.pattern('{CACHE_DIR}/engine/windows-x64/flutter_messenger.h'),
    Source.pattern('{CACHE_DIR}/engine/windows-x64/flutter_plugin_registrar.h'),
    Source.pattern('{CACHE_DIR}/engine/windows-x64/flutter_glfw.h'),
    Source.pattern('{CACHE_DIR}/engine/windows-x64/icudtl.dat'),
    Source.pattern('{CACHE_DIR}/engine/windows-x64/cpp_client_wrapper/*'),
  ],
  outputs: <Source>[
    Source.pattern('{PROJECT_DIR}/windows/flutter/flutter_windows.dll'),
    Source.pattern('{PROJECT_DIR}/windows/flutter/flutter_windows.dll.exp'),
    Source.pattern('{PROJECT_DIR}/windows/flutter/flutter_windows.dll.lib'),
    Source.pattern('{PROJECT_DIR}/windows/flutter/flutter_windows.dll.pdb'),
    Source.pattern('{PROJECT_DIR}/windows/flutter/flutter_export.h'),
    Source.pattern('{PROJECT_DIR}/windows/flutter/flutter_messenger.h'),
    Source.pattern('{PROJECT_DIR}/windows/flutter/flutter_plugin_registrar.h'),
    Source.pattern('{PROJECT_DIR}/windows/flutter/flutter_glfw.h'),
    Source.pattern('{PROJECT_DIR}/windows/flutter/icudtl.dat'),
    Source.pattern('{PROJECT_DIR}/windows/flutter/cpp_client_wrapper/*'),
  ],
  dependencies: <Target>[],
  buildAction: copyWindowsAssets,
);
