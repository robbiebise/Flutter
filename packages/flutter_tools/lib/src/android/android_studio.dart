// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../base/common.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/process.dart';
import '../base/utils.dart';
import '../base/version.dart';
import '../convert.dart';
import '../globals.dart' as globals;
import '../ios/plist_parser.dart';
import 'android_studio_validator.dart';

// Android Studio layout:

// Linux/Windows:
// $HOME/.AndroidStudioX.Y/system/.home
// $HOME/.cache/Google/AndroidStudioX.Y/.home

// macOS:
// /Applications/Android Studio.app/Contents/
// $HOME/Applications/Android Studio.app/Contents/

// Match Android Studio >= 4.1 base folder (AndroidStudio*.*)
// and < 4.1 (.AndroidStudio*.*)
final RegExp _dotHomeStudioVersionMatcher =
    RegExp(r'^\.?(AndroidStudio[^\d]*)([\d.]+)');

// TODO(andrewkolos): this global variable is used in several places to provide
// a java binary to multiple Java-dependent tools, including the Android SDK
// and Gradle. If this is null, these tools will implicitly fall back to current
// JAVA_HOME env variable and then to any java found on PATH.
//
// This logic is consistent with that used by flutter doctor to find a valid JDK,
// but this consistency is fragile--the implementations of this logic
// exist independently of each other.
//
// See https://github.com/flutter/flutter/issues/124252.
String? get javaPath => globals.androidStudio?.javaPath;

class AndroidStudio {
  /// A [version] value of null represents an unknown version.
  AndroidStudio(
    this.directory, {
    this.version,
    this.configuredPath,
    this.studioAppName = 'AndroidStudio',
    this.presetPluginsPath,
  }) {
    _initAndValidate();
  }

  static AndroidStudio? fromMacOSBundle(String bundlePath, {
    String? configuredPath,
  }) {
    final String studioPath = globals.fs.path.join(bundlePath, 'Contents');
    final String plistFile = globals.fs.path.join(studioPath, 'Info.plist');
    final Map<String, dynamic> plistValues = globals.plistParser.parseFile(plistFile);
    // If we've found a JetBrainsToolbox wrapper, ignore it.
    if (plistValues.containsKey('JetBrainsToolboxApp')) {
      return null;
    }

    final String? versionString = plistValues[PlistParser.kCFBundleShortVersionStringKey] as String?;

    Version? version;
    if (versionString != null) {
      version = Version.parse(versionString);
    }

    String? pathsSelectorValue;
    final Map<String, dynamic>? jvmOptions = castStringKeyedMap(plistValues['JVMOptions']);
    if (jvmOptions != null) {
      final Map<String, dynamic>? jvmProperties = castStringKeyedMap(jvmOptions['Properties']);
      if (jvmProperties != null) {
        pathsSelectorValue = jvmProperties['idea.paths.selector'] as String;
      }
    }

    final int? major = version?.major;
    final int? minor = version?.minor;
    String? presetPluginsPath;
    final String? homeDirPath = globals.fsUtils.homeDirPath;
    if (homeDirPath != null && pathsSelectorValue != null) {
      if (major != null && major >= 4 && minor != null && minor >= 1) {
        presetPluginsPath = globals.fs.path.join(
          homeDirPath,
          'Library',
          'Application Support',
          'Google',
          pathsSelectorValue,
        );
      } else {
        presetPluginsPath = globals.fs.path.join(
          homeDirPath,
          'Library',
          'Application Support',
          pathsSelectorValue,
        );
      }
    }
    return AndroidStudio(
      studioPath,
      version: version,
      presetPluginsPath: presetPluginsPath,
      configuredPath: configuredPath,
    );
  }

  static AndroidStudio? fromHomeDot(Directory homeDotDir) {
    final Match? versionMatch =
        _dotHomeStudioVersionMatcher.firstMatch(homeDotDir.basename);
    if (versionMatch?.groupCount != 2) {
      return null;
    }
    final Version? version = Version.parse(versionMatch![2]);
    final String? studioAppName = versionMatch[1];
    if (studioAppName == null || version == null) {
      return null;
    }

    final int major = version.major;
    final int minor = version.minor;

    // The install path is written in a .home text file,
    // it location is in <base dir>/.home for Android Studio >= 4.1
    // and <base dir>/system/.home for Android Studio < 4.1
    String dotHomeFilePath;

    if (major >= 4 && minor >= 1) {
      dotHomeFilePath = globals.fs.path.join(homeDotDir.path, '.home');
    } else {
      dotHomeFilePath =
          globals.fs.path.join(homeDotDir.path, 'system', '.home');
    }

    String? installPath;

    try {
      installPath = globals.fs.file(dotHomeFilePath).readAsStringSync();
    } on Exception {
      // ignored, installPath will be null, which is handled below
    }

    if (installPath != null && globals.fs.isDirectorySync(installPath)) {
      return AndroidStudio(
          installPath,
          version: version,
          studioAppName: studioAppName,
      );
    }
    return null;
  }

  final String directory;
  final String studioAppName;

  /// The version of Android Studio.
  ///
  /// A null value represents an unknown version.
  final Version? version;

  final String? configuredPath;
  final String? presetPluginsPath;

  String? _javaPath;
  bool _isValid = false;
  final List<String> _validationMessages = <String>[];

  /// The path of the JDK bundled with Android Studio.
  ///
  /// This will be null if the bundled JDK could not be found or run.
  String? get javaPath => _javaPath;

  bool get isValid => _isValid;

  String? get pluginsPath {
    if (presetPluginsPath != null) {
      return presetPluginsPath!;
    }

    // TODO(andrewkolos): This is a bug. We shouldn't treat an unknown
    // version as equivalent to 0.0.
    // See https://github.com/flutter/flutter/issues/121468.
    final int major = version?.major ?? 0;
    final int minor = version?.minor ?? 0;
    final String? homeDirPath = globals.fsUtils.homeDirPath;
    if (homeDirPath == null) {
      return null;
    }
    if (globals.platform.isMacOS) {
      /// plugin path of Android Studio has been changed after version 4.1.
      if (major >= 4 && minor >= 1) {
        return globals.fs.path.join(
          homeDirPath,
          'Library',
          'Application Support',
          'Google',
          'AndroidStudio$major.$minor',
        );
      } else {
        return globals.fs.path.join(
          homeDirPath,
          'Library',
          'Application Support',
          'AndroidStudio$major.$minor',
        );
      }
    } else {
      // JetBrains Toolbox write plugins here
      final String toolboxPluginsPath = '$directory.plugins';

      if (globals.fs.directory(toolboxPluginsPath).existsSync()) {
        return toolboxPluginsPath;
      }

      if (major >= 4 && minor >= 1 &&
          globals.platform.isLinux) {
        return globals.fs.path.join(
          homeDirPath,
          '.local',
          'share',
          'Google',
          '$studioAppName$major.$minor',
        );
      }

      return globals.fs.path.join(
        homeDirPath,
        '.$studioAppName$major.$minor',
        'config',
        'plugins',
      );
    }
  }

  List<String> get validationMessages => _validationMessages;

  /// Locates the newest, valid version of Android Studio.
  ///
  /// In the case that `--android-studio-dir` is configured, the version of
  /// Android Studio found at that location is always returned, even if it is
  /// invalid.
  static AndroidStudio? latestValid() {
   final String? configuredStudioPath = globals.config.getValue('android-studio-dir') as String?;
    if (configuredStudioPath != null && !globals.fs.directory(configuredStudioPath).existsSync()) {
      throwToolExit('''
Could not find the Android Studio installation at the manually configured path "$configuredStudioPath".
Please verify that the path is correct and update it by running this command: flutter config --android-studio-dir '<path>'

To have flutter search for Android Studio installations automatically, remove
the configured path by running this command: flutter config --android-studio-dir ''
''');
    }

    // Find all available Studio installations.
    final List<AndroidStudio> studios = allInstalled();
    if (studios.isEmpty) {
      return null;
    }

    final AndroidStudio? manuallyConfigured = studios
      .where((AndroidStudio studio) => studio.configuredPath != null &&
        studio.configuredPath == configuredStudioPath)
      .firstOrNull;

    if (manuallyConfigured != null) {
      return manuallyConfigured;
    }

    AndroidStudio? newest;
    for (final AndroidStudio studio in studios.where((AndroidStudio s) => s.isValid)) {
      if (newest == null) {
        newest = studio;
        continue;
      }

      // We prefer installs with known versions.
      if (studio.version != null && newest.version == null) {
        newest = studio;
      } else if (studio.version != null && newest.version != null &&
          studio.version! > newest.version!) {
        newest = studio;
      } else if (studio.version == null && newest.version == null &&
            studio.directory.compareTo(newest.directory) > 0) {
        newest = studio;
      }
    }

    return newest;
  }

  static List<AndroidStudio> allInstalled() =>
      globals.platform.isMacOS ? _allMacOS() : _allLinuxOrWindows();

  static List<AndroidStudio> _allMacOS() {
    final List<FileSystemEntity> candidatePaths = <FileSystemEntity>[];

    void checkForStudio(String path) {
      if (!globals.fs.isDirectorySync(path)) {
        return;
      }
      try {
        final Iterable<Directory> directories = globals.fs
            .directory(path)
            .listSync(followLinks: false)
            .whereType<Directory>();
        for (final Directory directory in directories) {
          final String name = directory.basename;
          // An exact match, or something like 'Android Studio 3.0 Preview.app'.
          if (name.startsWith('Android Studio') && name.endsWith('.app')) {
            candidatePaths.add(directory);
          } else if (!directory.path.endsWith('.app')) {
            checkForStudio(directory.path);
          }
        }
      } on Exception catch (e) {
        globals.printTrace('Exception while looking for Android Studio: $e');
      }
    }

    checkForStudio('/Applications');
    final String? homeDirPath = globals.fsUtils.homeDirPath;
    if (homeDirPath != null) {
      checkForStudio(globals.fs.path.join(
        homeDirPath,
        'Applications',
      ));
    }

    final String? configuredStudioDir = globals.config.getValue('android-studio-dir') as String?;
    FileSystemEntity? configuredStudioDirAsEntity;
    if (configuredStudioDir != null) {
      configuredStudioDirAsEntity = globals.fs.file(configuredStudioDir);
      if (configuredStudioDirAsEntity.basename == 'Contents') {
        configuredStudioDirAsEntity = configuredStudioDirAsEntity.parent;
      }
      if (!candidatePaths
          .any((FileSystemEntity e) => e.path == configuredStudioDirAsEntity!.path)) {
        candidatePaths.add(configuredStudioDirAsEntity);
      }
    }

    // Query Spotlight for unexpected installation locations.
    String spotlightQueryResult = '';
    try {
      final ProcessResult spotlightResult = globals.processManager.runSync(<String>[
        'mdfind',
        // com.google.android.studio, com.google.android.studio-EAP
        'kMDItemCFBundleIdentifier="com.google.android.studio*"',
      ]);
      spotlightQueryResult = spotlightResult.stdout as String;
    } on ProcessException {
      // The Spotlight query is a nice-to-have, continue checking known installation locations.
    }
    for (final String studioPath in LineSplitter.split(spotlightQueryResult)) {
      final Directory appBundle = globals.fs.directory(studioPath);
      if (!candidatePaths.any((FileSystemEntity e) => e.path == studioPath)) {
        candidatePaths.add(appBundle);
      }
    }

    return candidatePaths
        .map<AndroidStudio?>((FileSystemEntity e) =>
          AndroidStudio.fromMacOSBundle(
            e.path,
            configuredPath: configuredStudioDirAsEntity?.path == e.path ? configuredStudioDir : null,
          )
        )
        .whereType<AndroidStudio>()
        .toList();
  }

  static List<AndroidStudio> _allLinuxOrWindows() {
    final List<AndroidStudio> studios = <AndroidStudio>[];

    bool alreadyFoundStudioAt(String path, { Version? newerThan }) {
      return studios.any((AndroidStudio studio) {
        if (studio.directory != path) {
          return false;
        }
        if (newerThan != null) {
          if (studio.version == null) {
            return false;
          }
          return studio.version!.compareTo(newerThan) >= 0;
        }
        return true;
      });
    }

    // Read all $HOME/.AndroidStudio*/system/.home
    // or $HOME/.cache/Google/AndroidStudio*/.home files.
    // There may be several pointing to the same installation,
    // so we grab only the latest one.
    final String? homeDirPath = globals.fsUtils.homeDirPath;

    if (homeDirPath != null && globals.fs.directory(homeDirPath).existsSync()) {
      final Directory homeDir = globals.fs.directory(homeDirPath);

      final List<Directory> directoriesToSearch = <Directory>[homeDir];

      // >=4.1 has new install location at $HOME/.cache/Google
      final String cacheDirPath =
          globals.fs.path.join(homeDirPath, '.cache', 'Google');

      if (globals.fs.isDirectorySync(cacheDirPath)) {
        directoriesToSearch.add(globals.fs.directory(cacheDirPath));
      }

      final List<Directory> entities = <Directory>[];

      for (final Directory baseDir in directoriesToSearch) {
        final Iterable<Directory> directories =
            baseDir.listSync(followLinks: false).whereType<Directory>();
        entities.addAll(directories.where((Directory directory) =>
            _dotHomeStudioVersionMatcher.hasMatch(directory.basename)));
      }

      for (final Directory entity in entities) {
        final AndroidStudio? studio = AndroidStudio.fromHomeDot(entity);
        if (studio != null && !alreadyFoundStudioAt(studio.directory, newerThan: studio.version)) {
          studios.removeWhere((AndroidStudio other) => other.directory == studio.directory);
          studios.add(studio);
        }
      }
    }

    // Discover Android Studio > 4.1
    if (globals.platform.isWindows && globals.platform.environment.containsKey('LOCALAPPDATA')) {
      final Directory cacheDir = globals.fs.directory(globals.fs.path.join(globals.platform.environment['LOCALAPPDATA']!, 'Google'));
      if (!cacheDir.existsSync()) {
        return studios;
      }
      for (final Directory dir in cacheDir.listSync().whereType<Directory>()) {
        final String name  = globals.fs.path.basename(dir.path);
        AndroidStudioValidator.idToTitle.forEach((String id, String title) {
          if (name.startsWith(id)) {
            final String version = name.substring(id.length);
            String? installPath;

            try {
              installPath = globals.fs.file(globals.fs.path.join(dir.path, '.home')).readAsStringSync();
            } on FileSystemException {
              // ignored
            }
            if (installPath != null && globals.fs.isDirectorySync(installPath)) {
              final AndroidStudio studio = AndroidStudio(
                installPath,
                version: Version.parse(version),
                studioAppName: title,
              );
              if (!alreadyFoundStudioAt(studio.directory, newerThan: studio.version)) {
                studios.removeWhere((AndroidStudio other) => other.directory == studio.directory);
                studios.add(studio);
              }
            }
          }
        });
      }
    }

    final String? configuredStudioDir = globals.config.getValue('android-studio-dir') as String?;
    if (configuredStudioDir != null) {
      final AndroidStudio? matchingAlreadyFoundInstall = studios
        .where((AndroidStudio other) =>
          globals.fs.directory(configuredStudioDir).path == globals.fs.directory(other.directory).path)
        .firstOrNull;
      if (matchingAlreadyFoundInstall != null) {
        studios.remove(matchingAlreadyFoundInstall);
        studios.add(AndroidStudio(configuredStudioDir,
          configuredPath: configuredStudioDir,
          version: matchingAlreadyFoundInstall.version));
      } else {
        studios.add(AndroidStudio(configuredStudioDir,
          configuredPath: configuredStudioDir));
      }
    }

    if (globals.platform.isLinux) {
      void checkWellKnownPath(String path) {
        if (globals.fs.isDirectorySync(path) && !alreadyFoundStudioAt(path)) {
          studios.add(AndroidStudio(path));
        }
      }

      // Add /opt/android-studio and $HOME/android-studio, if they exist.
      checkWellKnownPath('/opt/android-studio');
      checkWellKnownPath('${globals.fsUtils.homeDirPath}/android-studio');
    }
    return studios;
  }

  static String? extractStudioPlistValueWithMatcher(String plistValue, RegExp keyMatcher) {
    return keyMatcher.stringMatch(plistValue)?.split('=').last.trim().replaceAll('"', '');
  }

  void _initAndValidate() {
    _isValid = false;
    _validationMessages.clear();

    if (configuredPath != null) {
      _validationMessages.add('android-studio-dir = $configuredPath');
    }

    if (!globals.fs.isDirectorySync(directory)) {
      _validationMessages.add('Android Studio not found at $directory');
      return;
    }

    final String javaPath;
    if (globals.platform.isMacOS) {
      if (version != null && version!.major < 2020) {
        javaPath = globals.fs.path.join(directory, 'jre', 'jdk', 'Contents', 'Home');
      } else if (version != null && version!.major < 2022) {
        javaPath = globals.fs.path.join(directory, 'jre', 'Contents', 'Home');
      // See https://github.com/flutter/flutter/issues/125246 for more context.
      } else {
        javaPath = globals.fs.path.join(directory, 'jbr', 'Contents', 'Home');
      }
    } else {
      if (version != null && version!.major < 2022) {
        javaPath = globals.fs.path.join(directory, 'jre');
      } else {
        javaPath = globals.fs.path.join(directory, 'jbr');
      }
    }
    final String javaExecutable = globals.fs.path.join(javaPath, 'bin', 'java');
    if (!globals.processManager.canRun(javaExecutable)) {
      _validationMessages.add('Unable to find bundled Java version.');
    } else {
      RunResult? result;
      try {
        result = globals.processUtils.runSync(<String>[javaExecutable, '-version']);
      } on ProcessException catch (e) {
        _validationMessages.add('Failed to run Java: $e');
      }
      if (result != null && result.exitCode == 0) {
        final List<String> versionLines = result.stderr.split('\n');
        final String javaVersion = versionLines.length >= 2 ? versionLines[1] : versionLines[0];
        _validationMessages.add('Java version $javaVersion');
        _javaPath = javaPath;
        _isValid = true;
      } else {
        _validationMessages.add('Unable to determine bundled Java version.');
      }
    }
  }

  @override
  String toString() => 'Android Studio ($version)';
}
