// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tools/src/android/gradle_utils.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/project.dart';
import '../../src/common.dart';
import '../../src/fake_process_manager.dart';
import '../../src/fakes.dart';

void main() {
  group('injectGradleWrapperIfNeeded', () {
    late MemoryFileSystem fileSystem;
    late Directory gradleWrapperDirectory;
    late GradleUtils gradleUtils;

    setUp(() {
      fileSystem = MemoryFileSystem.test();
      gradleWrapperDirectory =
          fileSystem.directory('cache/bin/cache/artifacts/gradle_wrapper');
      gradleWrapperDirectory.createSync(recursive: true);
      gradleWrapperDirectory
          .childFile('gradlew')
          .writeAsStringSync('irrelevant');
      gradleWrapperDirectory
          .childDirectory('gradle')
          .childDirectory('wrapper')
          .createSync(recursive: true);
      gradleWrapperDirectory
          .childDirectory('gradle')
          .childDirectory('wrapper')
          .childFile('gradle-wrapper.jar')
          .writeAsStringSync('irrelevant');
      gradleUtils = GradleUtils(
        cache: Cache.test(
            processManager: FakeProcessManager.any(), fileSystem: fileSystem),
        platform: FakePlatform(environment: <String, String>{}),
        logger: BufferLogger.test(),
        operatingSystemUtils: FakeOperatingSystemUtils(),
      );
    });

    testWithoutContext('injects the wrapper when all files are missing', () {
      final Directory sampleAppAndroid =
          fileSystem.directory('/sample-app/android');
      sampleAppAndroid.createSync(recursive: true);

      gradleUtils.injectGradleWrapperIfNeeded(sampleAppAndroid);

      expect(sampleAppAndroid.childFile('gradlew').existsSync(), isTrue);

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.jar')
              .existsSync(),
          isTrue);

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.properties')
              .existsSync(),
          isTrue);

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.properties')
              .readAsStringSync(),
          'distributionBase=GRADLE_USER_HOME\n'
          'distributionPath=wrapper/dists\n'
          'zipStoreBase=GRADLE_USER_HOME\n'
          'zipStorePath=wrapper/dists\n'
          'distributionUrl=https\\://services.gradle.org/distributions/gradle-7.5-all.zip\n');
    });

    testWithoutContext('injects the wrapper when some files are missing', () {
      final Directory sampleAppAndroid =
          fileSystem.directory('/sample-app/android');
      sampleAppAndroid.createSync(recursive: true);

      // There's an existing gradlew
      sampleAppAndroid
          .childFile('gradlew')
          .writeAsStringSync('existing gradlew');

      gradleUtils.injectGradleWrapperIfNeeded(sampleAppAndroid);

      expect(sampleAppAndroid.childFile('gradlew').existsSync(), isTrue);
      expect(sampleAppAndroid.childFile('gradlew').readAsStringSync(),
          equals('existing gradlew'));

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.jar')
              .existsSync(),
          isTrue);

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.properties')
              .existsSync(),
          isTrue);

      expect(
          sampleAppAndroid
              .childDirectory('gradle')
              .childDirectory('wrapper')
              .childFile('gradle-wrapper.properties')
              .readAsStringSync(),
          'distributionBase=GRADLE_USER_HOME\n'
          'distributionPath=wrapper/dists\n'
          'zipStoreBase=GRADLE_USER_HOME\n'
          'zipStorePath=wrapper/dists\n'
          'distributionUrl=https\\://services.gradle.org/distributions/gradle-7.5-all.zip\n');
    });

    testWithoutContext(
        'injects the wrapper and the Gradle version is derivated from the AGP version',
        () {
      const Map<String, String> testCases = <String, String>{
        // AGP version : Gradle version
        '1.0.0': '2.3',
        '3.3.1': '4.10.2',
        '3.0.0': '4.1',
        '3.0.5': '4.1',
        '3.0.9': '4.1',
        '3.1.0': '4.4',
        '3.2.0': '4.6',
        '3.3.0': '4.10.2',
        '3.4.0': '5.6.2',
        '3.5.0': '5.6.2',
        '4.0.0': '6.7',
        '4.0.5': '6.7',
        '4.1.0': '6.7',
      };

      for (final MapEntry<String, String> entry in testCases.entries) {
        final Directory sampleAppAndroid =
            fileSystem.systemTempDirectory.createTempSync('flutter_android.');
        sampleAppAndroid.childFile('build.gradle').writeAsStringSync('''
  buildscript {
      dependencies {
          classpath 'com.android.tools.build:gradle:${entry.key}'
      }
  }
  ''');
        gradleUtils.injectGradleWrapperIfNeeded(sampleAppAndroid);

        expect(sampleAppAndroid.childFile('gradlew').existsSync(), isTrue);

        expect(
            sampleAppAndroid
                .childDirectory('gradle')
                .childDirectory('wrapper')
                .childFile('gradle-wrapper.jar')
                .existsSync(),
            isTrue);

        expect(
            sampleAppAndroid
                .childDirectory('gradle')
                .childDirectory('wrapper')
                .childFile('gradle-wrapper.properties')
                .existsSync(),
            isTrue);

        expect(
            sampleAppAndroid
                .childDirectory('gradle')
                .childDirectory('wrapper')
                .childFile('gradle-wrapper.properties')
                .readAsStringSync(),
            'distributionBase=GRADLE_USER_HOME\n'
            'distributionPath=wrapper/dists\n'
            'zipStoreBase=GRADLE_USER_HOME\n'
            'zipStorePath=wrapper/dists\n'
            'distributionUrl=https\\://services.gradle.org/distributions/gradle-${entry.value}-all.zip\n');
      }
    });

    testWithoutContext('returns the gradlew path', () {
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      androidDirectory.childFile('gradlew').createSync();
      androidDirectory.childFile('gradlew.bat').createSync();
      androidDirectory.childFile('gradle.properties').createSync();

      final FlutterProject flutterProject = FlutterProjectFactory(
        logger: BufferLogger.test(),
        fileSystem: fileSystem,
      ).fromDirectory(fileSystem.currentDirectory);

      expect(
        gradleUtils.getExecutable(flutterProject),
        androidDirectory.childFile('gradlew').path,
      );
    });
    testWithoutContext('getGradleFileName for notWindows', () {
      expect(getGradlewFileName(notWindowsPlatform), 'gradlew');
    });
    testWithoutContext('getGradleFileName for windows', () {
      expect(getGradlewFileName(windowsPlatform), 'gradlew.bat');
    });

    testWithoutContext('returns the gradle properties file', () async {
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      final Directory wrapperDirectory = androidDirectory
          .childDirectory(gradleDirectoryName)
          .childDirectory(gradleWrapperDirectoryName)
        ..createSync(recursive: true);
      final File expectedFile = await wrapperDirectory
          .childFile(gradleWrapperPropertiesFilename)
          .create();
      final File gradleWrapperFile = getGradleWrapperFile(androidDirectory);
      expect(gradleWrapperFile.path, expectedFile.path);
    });

    testWithoutContext('returns the gradle wrapper version', () async {
      const String expectedVersion = '7.4.2';
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      final Directory wrapperDirectory = androidDirectory
          .childDirectory('gradle')
          .childDirectory('wrapper')
        ..createSync(recursive: true);
      wrapperDirectory
          .childFile('gradle-wrapper.properties')
          .writeAsStringSync('''
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-$expectedVersion-all.zip
''');

      expect(
        await getGradleVersion(
            androidDirectory, BufferLogger.test(), FakeProcessManager.empty()),
        expectedVersion,
      );
    });

        testWithoutContext('ignores gradle comments', () async {
      const String expectedVersion = '7.4.2';
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      final Directory wrapperDirectory = androidDirectory
          .childDirectory('gradle')
          .childDirectory('wrapper')
        ..createSync(recursive: true);
      wrapperDirectory
          .childFile('gradle-wrapper.properties')
          .writeAsStringSync('''
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
# distributionUrl=https\\://services.gradle.org/distributions/gradle-8.0.2-all.zip
distributionUrl=https\\://services.gradle.org/distributions/gradle-$expectedVersion-all.zip
# distributionUrl=https\\://services.gradle.org/distributions/gradle-8.0.2-all.zip
''');

      expect(
        await getGradleVersion(
            androidDirectory, BufferLogger.test(), FakeProcessManager.empty()),
        expectedVersion,
      );
    });

    testWithoutContext('returns gradlew version, whitespace, location', () async {
      const String expectedVersion = '7.4.2';
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      final Directory wrapperDirectory = androidDirectory
          .childDirectory('gradle')
          .childDirectory('wrapper')
        ..createSync(recursive: true);
      // Distribution url is not the last line.
      // Whitespace around distribution url.
      wrapperDirectory
          .childFile('gradle-wrapper.properties')
          .writeAsStringSync('''
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl = https\\://services.gradle.org/distributions/gradle-$expectedVersion-all.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
''');

      expect(
        await getGradleVersion(
            androidDirectory, BufferLogger.test(), FakeProcessManager.empty()),
        expectedVersion,
      );
    });

    testWithoutContext('does not crash on hypothetical new format', () async {
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      final Directory wrapperDirectory = androidDirectory
          .childDirectory('gradle')
          .childDirectory('wrapper')
        ..createSync(recursive: true);
      // Distribution url is not the last line.
      // Whitespace around distribution url.
      wrapperDirectory
          .childFile('gradle-wrapper.properties')
          .writeAsStringSync(r'distributionUrl=https\://services.gradle.org/distributions/gradle_7.4.2_all.zip');

      // FakeProcessManager.any is used here and not in other getGradleVersion
      // tests because this test does not care about process fallback logic.
      expect(
        await getGradleVersion(
            androidDirectory, BufferLogger.test(), FakeProcessManager.any()),
        isNull,
      );
    });

    testWithoutContext('returns the installed gradle version', () async {
      const String expectedVersion = '7.4.2';
      const String gradleOutput = '''

------------------------------------------------------------
Gradle $expectedVersion
------------------------------------------------------------

Build time:   2022-03-31 15:25:29 UTC
Revision:     540473b8118064efcc264694cbcaa4b677f61041

Kotlin:       1.5.31
Groovy:       3.0.9
Ant:          Apache Ant(TM) version 1.10.11 compiled on July 10 2021
JVM:          11.0.18 (Azul Systems, Inc. 11.0.18+10-LTS)
OS:           Mac OS X 13.2.1 aarch64
''';
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      final ProcessManager processManager = FakeProcessManager.empty()
        ..addCommand(const FakeCommand(
            command: <String>['gradle', gradleVersionFlag],
            stdout: gradleOutput));

      expect(
        await getGradleVersion(
          androidDirectory,
          BufferLogger.test(),
          processManager,
        ),
        expectedVersion,
      );
    });

    testWithoutContext('returns the installed gradle with whitespace formatting', () async {
      const String expectedVersion = '7.4.2';
      const String gradleOutput = 'Gradle   $expectedVersion';
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      final ProcessManager processManager = FakeProcessManager.empty()
        ..addCommand(const FakeCommand(
            command: <String>['gradle', gradleVersionFlag],
            stdout: gradleOutput));

      expect(
        await getGradleVersion(
          androidDirectory,
          BufferLogger.test(),
          processManager,
        ),
        expectedVersion,
      );
    });

    testWithoutContext('returns the AGP version when set', () async {
      const String expectedVersion = '7.3.0';
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      androidDirectory.childFile('build.gradle').writeAsStringSync('''
buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:$expectedVersion'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
''');

      expect(
        getAgpVersion(androidDirectory, BufferLogger.test()),
        expectedVersion,
      );
    });
    testWithoutContext('returns null when AGP version not set', () async {
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      androidDirectory.childFile('build.gradle').writeAsStringSync('''
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
    }
}
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
''');

      expect(
        getAgpVersion(androidDirectory, BufferLogger.test()),
        null,
      );
    });
    testWithoutContext('returns the AGP version when beta', () async {
      final Directory androidDirectory = fileSystem.directory('/android')
        ..createSync();
      androidDirectory.childFile('build.gradle').writeAsStringSync(r'''
buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:7.3.0-beta03'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
''');

      expect(
        getAgpVersion(androidDirectory, BufferLogger.test()),
        '7.3.0',
      );
    });

    group('validates gradle/agp versions', () {
      final List<GradleAgpTestData> testData = <GradleAgpTestData>[
        // Values too new *these need to update* when
        // max known gradle and max known agp versions are updated:
        // Newer tools version supports max gradle version.
        GradleAgpTestData(true, agpVersion: '8.2', gradleVersion: '8.0'),
        // Newer tools version does not even meet current gradle version requiremnts.
        GradleAgpTestData(false, agpVersion: '8.2', gradleVersion: '7.3'),
        // Newer tools version requires newer gradle version.
        GradleAgpTestData(true, agpVersion: '8.3', gradleVersion: '8.1'),

        // Minimims as defined in
        // https://developer.android.com/studio/releases/gradle-plugin#updating-gradle
        GradleAgpTestData(true, agpVersion: '8.1', gradleVersion: '8.0'),
        GradleAgpTestData(true, agpVersion: '8.0', gradleVersion: '8.0'),
        GradleAgpTestData(true, agpVersion: '7.4', gradleVersion: '7.5'),
        GradleAgpTestData(true, agpVersion: '7.3', gradleVersion: '7.4'),
        GradleAgpTestData(true, agpVersion: '7.2', gradleVersion: '7.3.3'),
        GradleAgpTestData(true, agpVersion: '7.1', gradleVersion: '7.2'),
        GradleAgpTestData(true, agpVersion: '7.0', gradleVersion: '7.0'),
        GradleAgpTestData(true, agpVersion: '4.2.0', gradleVersion: '6.7.1'),
        GradleAgpTestData(true, agpVersion: '4.1.0', gradleVersion: '6.5'),
        GradleAgpTestData(true, agpVersion: '4.0.0', gradleVersion: '6.1.1'),
        GradleAgpTestData(true, agpVersion: '3.6.0', gradleVersion: '5.6.4'),
        GradleAgpTestData(true, agpVersion: '3.5.0', gradleVersion: '5.4.1'),
        GradleAgpTestData(true, agpVersion: '3.4.0', gradleVersion: '5.1.1'),
        GradleAgpTestData(true, agpVersion: '3.3.0', gradleVersion: '4.10.1'),
        // Values too old:
        GradleAgpTestData(false, agpVersion: '3.3.0', gradleVersion: '4.9'),
        GradleAgpTestData(false, agpVersion: '7.3', gradleVersion: '7.2'),
        GradleAgpTestData(false, agpVersion: '3.0.0', gradleVersion: '7.2'),
        // Null values:
        // ignore: avoid_redundant_argument_values
        GradleAgpTestData(false, agpVersion: null, gradleVersion: '7.2'),
        // ignore: avoid_redundant_argument_values
        GradleAgpTestData(false, agpVersion: '3.0.0', gradleVersion: null),
        // ignore: avoid_redundant_argument_values
        GradleAgpTestData(false, agpVersion: null, gradleVersion: null),
        // Middle AGP cases:
        GradleAgpTestData(true, agpVersion: '8.0.1', gradleVersion: '8.0'),
        GradleAgpTestData(true, agpVersion: '7.4.1', gradleVersion: '7.5'),
        GradleAgpTestData(true, agpVersion: '7.3.1', gradleVersion: '7.4'),
        GradleAgpTestData(true, agpVersion: '7.2.1', gradleVersion: '7.3.3'),
        GradleAgpTestData(true, agpVersion: '7.1.1', gradleVersion: '7.2'),
        GradleAgpTestData(true, agpVersion: '7.0.1', gradleVersion: '7.0'),
        GradleAgpTestData(true, agpVersion: '4.2.1', gradleVersion: '6.7.1'),
        GradleAgpTestData(true, agpVersion: '4.1.1', gradleVersion: '6.5'),
        GradleAgpTestData(true, agpVersion: '4.0.1', gradleVersion: '6.1.1'),
        GradleAgpTestData(true, agpVersion: '3.6.1', gradleVersion: '5.6.4'),
        GradleAgpTestData(true, agpVersion: '3.5.1', gradleVersion: '5.4.1'),
        GradleAgpTestData(true, agpVersion: '3.4.1', gradleVersion: '5.1.1'),
        GradleAgpTestData(true, agpVersion: '3.3.1', gradleVersion: '4.10.1'),

        // Higher gradle cases:
        GradleAgpTestData(true, agpVersion: '7.4', gradleVersion: '8.0'),
        GradleAgpTestData(true, agpVersion: '7.3', gradleVersion: '7.5'),
        GradleAgpTestData(true, agpVersion: '7.2', gradleVersion: '7.4'),
        GradleAgpTestData(true, agpVersion: '7.1', gradleVersion: '7.3.3'),
        GradleAgpTestData(true, agpVersion: '7.0', gradleVersion: '7.2'),
        GradleAgpTestData(true, agpVersion: '4.2.0', gradleVersion: '7.0'),
        GradleAgpTestData(true, agpVersion: '4.1.0', gradleVersion: '6.7.1'),
        GradleAgpTestData(true, agpVersion: '4.0.0', gradleVersion: '6.5'),
        GradleAgpTestData(true, agpVersion: '3.6.0', gradleVersion: '6.1.1'),
        GradleAgpTestData(true, agpVersion: '3.5.0', gradleVersion: '5.6.4'),
        GradleAgpTestData(true, agpVersion: '3.4.0', gradleVersion: '5.4.1'),
        GradleAgpTestData(true, agpVersion: '3.3.0', gradleVersion: '5.1.1'),
      ];
      for (final GradleAgpTestData data in testData) {
        test('(gradle, agp): (${data.gradleVersion}, ${data.agpVersion})', () {
          expect(
              validateGradleAndAgp(
                BufferLogger.test(),
                gradleV: data.gradleVersion,
                agpV: data.agpVersion,
              ),
              data.validPair ? isTrue : isFalse,
              reason: 'G: ${data.gradleVersion}, AGP: ${data.agpVersion}');
        });
      }
    });

    group('Parse gradle version from distribution url', () {
      testWithoutContext('null distribution url returns null version', () {
        expect(parseGradleVersionFromDistributionUrl(null), null);
      });

      testWithoutContext('unparseable format returns null', () {
        const String distributionUrl = 'aString';
        expect(parseGradleVersionFromDistributionUrl(distributionUrl), null);
      });

      testWithoutContext("recognizable 'all' format returns correct version", () {
        const String distributionUrl = r'distributionUrl=https\://services.gradle.org/distributions/gradle-6.7-all.zip';
        expect(parseGradleVersionFromDistributionUrl(distributionUrl), '6.7');
      });

      testWithoutContext("recognizable 'bin' format returns correct version", () {
        const String distributionUrl = r'distributionUrl=https\://services.gradle.org/distributions/gradle-6.7-bin.zip';
        expect(parseGradleVersionFromDistributionUrl(distributionUrl), '6.7');
      });

      testWithoutContext("recognizable 'rc' format returns correct version", () {
        const String distributionUrl = r'distributionUrl=https\://services.gradle.org/distributions/gradle-8.1-rc-3-all.zip';
        expect(parseGradleVersionFromDistributionUrl(distributionUrl), '8.1');
      });
    });

    group('validates java/gradle versions', () {
      final List<JavaGradleTestData> testData = <JavaGradleTestData>[
        // Values too new *these need to update* when
        // max supported java and max known gradle versions are updated:
        // Newer tools version does not even meet current gradle version requiremnts.
        JavaGradleTestData(false, javaVersion: '20', gradleVersion: '7.5'),
        // Newer tools version requires newer gradle version.
        JavaGradleTestData(true, javaVersion: '20', gradleVersion: '8.2.1'),
        // Max known unsupported java version.
        JavaGradleTestData(true, javaVersion: '24', gradleVersion: '8.2.1'),

        // Minimims as defined in
        // https://docs.gradle.org/current/userguide/compatibility.html#java
        JavaGradleTestData(true, javaVersion: '19', gradleVersion: '7.6'),
        JavaGradleTestData(true, javaVersion: '18', gradleVersion: '7.5'),
        JavaGradleTestData(true, javaVersion: '17', gradleVersion: '7.3'),
        JavaGradleTestData(true, javaVersion: '16', gradleVersion: '7.0'),
        JavaGradleTestData(true, javaVersion: '15', gradleVersion: '6.7'),
        JavaGradleTestData(true, javaVersion: '14', gradleVersion: '6.3'),
        JavaGradleTestData(true, javaVersion: '13', gradleVersion: '6.0'),
        JavaGradleTestData(true, javaVersion: '12', gradleVersion: '5.4'),
        JavaGradleTestData(true, javaVersion: '11', gradleVersion: '5.0'),
        JavaGradleTestData(true, javaVersion: '1.10', gradleVersion: '4.7'),
        JavaGradleTestData(true, javaVersion: '1.9', gradleVersion: '4.3'),
        JavaGradleTestData(true, javaVersion: '1.8', gradleVersion: '2.0'),
        // Gradle too old for java version.
        JavaGradleTestData(false, javaVersion: '19', gradleVersion: '6.7'),
        JavaGradleTestData(false, javaVersion: '11', gradleVersion: '4.10.1'),
        JavaGradleTestData(false, javaVersion: '1.9', gradleVersion: '4.1'),
        // Null values:
        // ignore: avoid_redundant_argument_values
        JavaGradleTestData(false, javaVersion: null, gradleVersion: '7.2'),
        // ignore: avoid_redundant_argument_values
        JavaGradleTestData(false, javaVersion: '11', gradleVersion: null),
        // ignore: avoid_redundant_argument_values
        JavaGradleTestData(false, javaVersion: null, gradleVersion: null),
        // Middle Java cases:
        // https://www.java.com/releases/
        JavaGradleTestData(true, javaVersion: '19.0.2', gradleVersion: '8.0.2'),
        JavaGradleTestData(true, javaVersion: '19.0.2', gradleVersion: '8.0.0'),
        JavaGradleTestData(true, javaVersion: '18.0.2', gradleVersion: '8.0.2'),
        JavaGradleTestData(true, javaVersion: '17.0.3', gradleVersion: '7.5'),
        JavaGradleTestData(true, javaVersion: '16.0.1', gradleVersion: '7.3'),
        JavaGradleTestData(true, javaVersion: '15.0.2', gradleVersion: '7.3'),
        JavaGradleTestData(true, javaVersion: '14.0.1', gradleVersion: '7.0'),
        JavaGradleTestData(true, javaVersion: '13.0.2', gradleVersion: '6.7'),
        JavaGradleTestData(true, javaVersion: '12.0.2', gradleVersion: '6.3'),
        JavaGradleTestData(true, javaVersion: '11.0.18', gradleVersion: '6.0'),
        // Higher gradle cases:
        JavaGradleTestData(true, javaVersion: '19', gradleVersion: '8.0'),
        JavaGradleTestData(true, javaVersion: '18', gradleVersion: '8.0'),
        JavaGradleTestData(true, javaVersion: '17', gradleVersion: '7.5'),
        JavaGradleTestData(true, javaVersion: '16', gradleVersion: '7.3'),
        JavaGradleTestData(true, javaVersion: '15', gradleVersion: '7.3'),
        JavaGradleTestData(true, javaVersion: '14', gradleVersion: '7.0'),
        JavaGradleTestData(true, javaVersion: '13', gradleVersion: '6.7'),
        JavaGradleTestData(true, javaVersion: '12', gradleVersion: '6.3'),
        JavaGradleTestData(true, javaVersion: '11', gradleVersion: '6.0'),
        JavaGradleTestData(true, javaVersion: '1.10', gradleVersion: '5.4'),
        JavaGradleTestData(true, javaVersion: '1.9', gradleVersion: '5.0'),
        JavaGradleTestData(true, javaVersion: '1.8', gradleVersion: '4.3'),
      ];

      for (final JavaGradleTestData data in testData) {
        testWithoutContext(
            '(Java, gradle): (${data.javaVersion}, ${data.gradleVersion})', () {
          expect(
              validateJavaGradle(
                BufferLogger.test(),
                javaV: data.javaVersion,
                gradleV: data.gradleVersion,
              ),
              data.validPair ? isTrue : isFalse,
              reason: 'J: ${data.javaVersion}, G: ${data.gradleVersion}');
        });
      }
    });
  });

  group('validates java/AGP versions', () {
    final List<JavaAgpTestData> testData = <JavaAgpTestData>[
      // Strictly too old cases -- Java
      JavaAgpTestData(false, javaVersion: '1.6', agpVersion: maxKnownAgpVersion),
      JavaAgpTestData(false, javaVersion: '1.6', agpVersion: maxKnownAndSupportedAgpVersion),
      JavaAgpTestData(false, javaVersion: '1.6', agpVersion: '4.2'),
      // Strictly too old cases -- AGP
      JavaAgpTestData(false, javaVersion: '1.8', agpVersion: '1.0'),
      JavaAgpTestData(false, javaVersion: '1.8', agpVersion: '4.1'),
      JavaAgpTestData(false, javaVersion: '1.8', agpVersion: '2.3'),
      // Strictly too new cases -- Java
      JavaAgpTestData(true, javaVersion: '19', agpVersion: '8.0'),
      JavaAgpTestData(true, javaVersion: '20', agpVersion: '7.4'),
      // Strictly too new cases -- AGP
      JavaAgpTestData(false, javaVersion: '24', agpVersion: '8.3'),
      JavaAgpTestData(false, javaVersion: '17', agpVersion: '8.3'),
      JavaAgpTestData(false, javaVersion: '11', agpVersion: '8.3'),
      // Java 17 & patch versions compatibility cases
      JavaAgpTestData(true, javaVersion: '17', agpVersion: '8.0'),
      JavaAgpTestData(true, javaVersion: '17', agpVersion: maxKnownAndSupportedAgpVersion),
      JavaAgpTestData(false, javaVersion: '17', agpVersion: '8.2'),
      JavaAgpTestData(true, javaVersion: '17', agpVersion: '8.1'),
      JavaAgpTestData(true, javaVersion: '17', agpVersion: '7.4'),
      JavaAgpTestData(true, javaVersion: '17.0.3', agpVersion: '8.0'),
      JavaAgpTestData(true, javaVersion: '17.0.3', agpVersion: maxKnownAndSupportedAgpVersion),
      JavaAgpTestData(false, javaVersion: '17.0.3', agpVersion: '8.2'),
      JavaAgpTestData(true, javaVersion: '17.0.3', agpVersion: '8.1'),
      JavaAgpTestData(true, javaVersion: '17.0.3', agpVersion: '7.4'),
      // Java 11 & patch versions compatibility cases
      JavaAgpTestData(true, javaVersion: '11', agpVersion: '7.0'),
      JavaAgpTestData(true, javaVersion: '11', agpVersion: '7.4'),
      JavaAgpTestData(true, javaVersion: '11', agpVersion: '7.2'),
      JavaAgpTestData(true, javaVersion: '11', agpVersion: '4.2'),
      JavaAgpTestData(false, javaVersion: '11', agpVersion: '8.0'),
      JavaAgpTestData(true, javaVersion: '11.0.18', agpVersion: '7.0'),
      JavaAgpTestData(true, javaVersion: '11.0.18', agpVersion: '7.4'),
      JavaAgpTestData(true, javaVersion: '11.0.18', agpVersion: '7.2'),
      JavaAgpTestData(true, javaVersion: '11.0.18', agpVersion: '4.2'),
      JavaAgpTestData(false, javaVersion: '11.0.18', agpVersion: '8.0'),
      // Java 8 compatibility cases
      JavaAgpTestData(true, javaVersion: '1.8', agpVersion: '4.2'),
      JavaAgpTestData(true, javaVersion: '1.8', agpVersion: oldestDocumentedJavaAgpCompatibilityVersion),
      JavaAgpTestData(false, javaVersion: '1.8', agpVersion: '4.1'),
      JavaAgpTestData(false, javaVersion: '1.8', agpVersion: '7.0'),
      // Null value cases
      // ignore: avoid_redundant_argument_values
      JavaAgpTestData(false, javaVersion: null, agpVersion: '4.2'),
      // ignore: avoid_redundant_argument_values
      JavaAgpTestData(false, javaVersion: '1.8', agpVersion: null),
      // ignore: avoid_redundant_argument_values
      JavaAgpTestData(false, javaVersion: null, agpVersion: null),
    ];

      for (final JavaAgpTestData data in testData) {
        testWithoutContext(
            '(Java, agp): (${data.javaVersion}, ${data.agpVersion})', () {
          expect(
              validateJavaAgp(
                BufferLogger.test(),
                javaV: data.javaVersion,
                agpV: data.agpVersion,
              ),
              data.validPair ? isTrue : isFalse,
              reason: 'J: ${data.javaVersion}, G: ${data.agpVersion}');
        });
      }
  });

  group('detecting valid Gradle/AGP versions for given Java version', () {
    testWithoutContext('getValidGradleVersionRangeForJavaVersion returns valid Gradle version range for Java version', () {
      final Logger testLogger = BufferLogger.test();
      // Java version unspecified.
      expect(getValidGradleVersionRangeForJavaVersion(testLogger, javaV: null), isNull);
      // Java version too high.
      expect(getValidGradleVersionRangeForJavaVersion(testLogger, javaV: oneMajorVersionHigherJavaVersion), isNull);
      // Java version maximum known.
      // **Will need updates as more Java versions become supported**
      expect(getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '20'), isNull);
      // Known supported Java versions.
      // **Will need updates as more Java versions become supported**
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '19'),
        equals(
          const JavaGradleCompat(
            javaMin: '19',
            javaMax: '20',
            gradleMin: '7.6',
            gradleMax: maxKnownAndSupportedGradleVersion)));
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '18'),
        equals(
          const JavaGradleCompat(
            javaMin: '18',
            javaMax: '19',
            gradleMin: '7.5',
            gradleMax: maxKnownAndSupportedGradleVersion)));
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '17'),
        equals(
          const JavaGradleCompat(
            javaMin: '17',
            javaMax: '18',
            gradleMin: '7.3',
            gradleMax: maxKnownAndSupportedGradleVersion)));
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '16'),
        equals(
          const JavaGradleCompat(
            javaMin: '16',
            javaMax: '17',
            gradleMin: '7.0',
            gradleMax: maxKnownAndSupportedGradleVersion)));
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '15'),
        equals(
          const JavaGradleCompat(
            javaMin: '15',
            javaMax: '16',
            gradleMin: '6.7',
            gradleMax: maxKnownAndSupportedGradleVersion)));
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '14'),
        equals(
          const JavaGradleCompat(
            javaMin: '14',
            javaMax: '15',
            gradleMin: '6.3',
            gradleMax: maxKnownAndSupportedGradleVersion)));
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '13'),
        equals(
          const JavaGradleCompat(
            javaMin: '13',
            javaMax: '14',
            gradleMin: '6.0',
            gradleMax: maxKnownAndSupportedGradleVersion)));
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '12'),
        equals(
          const JavaGradleCompat(
            javaMin: '12',
            javaMax: '13',
            gradleMin: '5.4',
            gradleMax: maxKnownAndSupportedGradleVersion)));
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '11'),
        equals(
          const JavaGradleCompat(
            javaMin: '11',
            javaMax: '12',
            gradleMin: '5.0',
            gradleMax: maxKnownAndSupportedGradleVersion)));
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '1.10'),
        equals(
          const JavaGradleCompat(
            javaMin: '1.10',
            javaMax: '1.11',
            gradleMin: '4.7',
            gradleMax: maxKnownAndSupportedGradleVersion,
          ))
      );
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '1.9'),
        equals(
          const JavaGradleCompat(
            javaMin: '1.9',
            javaMax: '1.10',
            gradleMin: '4.3',
            gradleMax: maxKnownAndSupportedGradleVersion)));
      // Java 1.8 -- return oldest documented compatibility info
      expect(
        getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '1.8'),
        equals(
          const JavaGradleCompat(
            javaMin: '1.8',
            javaMax: '1.9',
            gradleMin: '2.0',
            gradleMax: maxKnownAndSupportedGradleVersion)));
      // Java version too low.
      expect(getValidGradleVersionRangeForJavaVersion(testLogger, javaV: '1.7'), isNull);
    });

    testWithoutContext('getMinimumAgpVersionForJavaVersion returns minimum AGP version for Java version', () {
      final Logger testLogger = BufferLogger.test();
      // Java version unspecified.
      expect(getMinimumAgpVersionForJavaVersion(testLogger, javaV: null), isNull);
      // Java version is maximum known.
      // **Case for one version higher than the maximum known Java version will need to be added here as new Java versions are supported**
      expect(
        getMinimumAgpVersionForJavaVersion(testLogger, javaV: oneMajorVersionHigherJavaVersion),
        equals(
          const JavaAgpCompat(
            javaMin: '17',
            javaDefault: '17',
            agpMin: '8.0',
            agpMax: maxKnownAgpVersion)));
      // Known Java versions.
      // **New cases will need to be added as new AGP versions are supported**
      expect(
        getMinimumAgpVersionForJavaVersion(testLogger, javaV: '17'),
        equals(
          const JavaAgpCompat(
            javaMin: '17',
            javaDefault: '17',
            agpMin: '8.0',
            agpMax: maxKnownAgpVersion)));
      expect(
        getMinimumAgpVersionForJavaVersion(testLogger, javaV: '15'),
        equals(
          const JavaAgpCompat(
            javaMin: '1.11',
            javaDefault: '1.11',
            agpMin: '7.0',
            agpMax: '7.4')));
      expect(
        getMinimumAgpVersionForJavaVersion(testLogger, javaV: '11'),
        equals(
          const JavaAgpCompat(
            javaMin: '1.11',
            javaDefault: '1.11',
            agpMin: '7.0',
            agpMax: '7.4')));
      expect(
        getMinimumAgpVersionForJavaVersion(testLogger, javaV: '1.9'),
        equals(
          const JavaAgpCompat(
            javaMin: '1.8',
            javaDefault: '1.8',
            agpMin: '4.2',
            agpMax: '4.2')));
      expect(
        getMinimumAgpVersionForJavaVersion(testLogger, javaV: '1.8'),
        equals(
          const JavaAgpCompat(
            javaMin: '1.8',
            javaDefault: '1.8',
            agpMin: '4.2',
            agpMax: '4.2')));
      // Java version too low.
      expect(getMinimumAgpVersionForJavaVersion(testLogger, javaV: '1.7'), isNull);
    });
  });
}

class GradleAgpTestData {
  GradleAgpTestData(this.validPair, {this.gradleVersion, this.agpVersion});
  final String? gradleVersion;
  final String? agpVersion;
  final bool validPair;
}

class JavaGradleTestData {
  JavaGradleTestData(this.validPair, {this.javaVersion, this.gradleVersion});
  final String? gradleVersion;
  final String? javaVersion;
  final bool validPair;
}

class JavaAgpTestData {
  JavaAgpTestData(this.validPair, {this.javaVersion, this.agpVersion});
  final String? agpVersion;
  final String? javaVersion;
  final bool validPair;
}

final Platform windowsPlatform = FakePlatform(
  operatingSystem: 'windows',
  environment: <String, String>{
    'PROGRAMFILES(X86)':  r'C:\Program Files (x86)\',
    'FLUTTER_ROOT': r'C:\flutter',
    'USERPROFILE': '/',
  }
);
final Platform notWindowsPlatform = FakePlatform(
  environment: <String, String>{
    'FLUTTER_ROOT': r'/users/someuser/flutter',
  }
);
