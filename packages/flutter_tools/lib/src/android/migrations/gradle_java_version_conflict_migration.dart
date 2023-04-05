// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../base/file_system.dart';
import '../../base/project_migrator.dart';
import '../../base/version.dart';
import '../../project.dart';
import '../android_studio.dart';

// Android Studio 2022.2 "Flamingo" is the first to bundle a Java 17 JDK.
// Previous versions bundled a Java 11 JDK.
final Version _androidStudioFlamingo = Version(2022, 2, 0);
final RegExp _distributionUrlMatch = RegExp(r'^\s*distributionUrl');
final RegExp _gradleVersionMatch = RegExp(
  r'^\s*distributionUrl\s*=\s*https\\://services\.gradle\.org/distributions/gradle-((?:\d|\.)+)-(?:all|bin)\.zip');
final Version _lowestSupportedGradleVersion = Version(7, 3, 0); // minimum for JDK 17
const String _newGradleVersionString = r'7.4';

/// Migrate to a newer version of Gradle when the existing does not support
/// the version of Java provided by the detected Android Studio version.
///
/// For more info see the Gradle-Java compatibility matrix:
/// https://docs.gradle.org/current/userguide/compatibility.html
class GradleJavaVersionConflictMigration extends ProjectMigrator {
  GradleJavaVersionConflictMigration(
    AndroidProject project,
    super.logger,
    AndroidStudio? androidStudio,
  ) : _androidStudio = androidStudio,
      _gradleWrapperPropertiesFile = project.hostAppGradleRoot
        .childDirectory('gradle').childDirectory('wrapper').childFile('gradle-wrapper.properties');
  final File _gradleWrapperPropertiesFile;
  final AndroidStudio? _androidStudio;

  // TODO(gmackall): Modify this migration to be based directly on JDK version.
  @override
  void migrate() {
    if (!_gradleWrapperPropertiesFile.existsSync()) {
      logger.printTrace('gradle-wrapper.properties not found, skipping Gradle-Java version compatibility check.');
      return;
    }

    if (_androidStudio == null) {
      logger.printTrace('Android Studio version could not be detected, '
          'skipping Gradle-Java version compatibility check.');
      return;
    } else if (_androidStudio!.version < _androidStudioFlamingo) {
      logger.printTrace('Version of Android Studio is less than impacted version, no migration necessary.');
      return;
    }

    processFileLines(_gradleWrapperPropertiesFile);
  }

  @override
  String migrateLine(String line) {
    if (!_distributionUrlMatch.hasMatch(line)) {
      return line;
    }
    final RegExpMatch? match = _gradleVersionMatch.firstMatch(line);
    if (match == null || match.groupCount < 1) {
      logger.printTrace('Failed to parse Gradle version from distribution url, '
          'skipping Gradle-Java version compatibility check.');
      return line;
    }
    final String existingVersionString = match[1]!;
    final Version existingVersion = Version.parse(existingVersionString)!;
    if (existingVersion < _lowestSupportedGradleVersion) {
      logger.printStatus('Conflict detected between versions of Android Studio '
          'and Gradle, upgrading Gradle version from $existingVersion to 7.4');
      return line.replaceAll(existingVersionString, _newGradleVersionString);
    }
    // Version of gradle is already high enough, no migration necessary.
    return line;
  }
}
