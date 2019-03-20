// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/run_hot.dart';

import 'src/common.dart';
import 'src/context.dart';

void main() {
  group('ProjectFileInvalidator', () {
    final MemoryFileSystem memoryFileSystem = MemoryFileSystem();
    testUsingContext('Empty project', () async {
      final ProjectFileInvalidator invalidator = ProjectFileInvalidator();
      invalidator.findInvalidated(firstBuildTime: DateTime.now(), urisToMonitor: <Uri>[]);
      expect(invalidator.updateTime, isEmpty);
    }, overrides: <Type, Generator>{
      FileSystem: () => memoryFileSystem,
    });
  });
}
