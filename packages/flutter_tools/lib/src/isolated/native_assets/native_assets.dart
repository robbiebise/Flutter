// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Logic for native assets shared between all host OSes.

import 'package:logging/logging.dart' as logging;
import 'package:native_assets_builder/native_assets_builder.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_assets_cli/native_assets_cli_internal.dart';
import 'package:package_config/package_config_types.dart';

import '../../android/gradle_utils.dart' as gradle_utils;
import '../../base/common.dart';
import '../../base/file_system.dart';
import '../../base/logger.dart';
import '../../base/platform.dart';
import '../../build_info.dart' as build_info;
import '../../build_system/exceptions.dart';
import '../../cache.dart';
import '../../features.dart';
import '../../globals.dart' as globals;
import '../../macos/xcode.dart' as xcode;
import '../../resident_runner.dart';
import '../../run_hot.dart';
import 'android/native_assets.dart';
import 'ios/native_assets.dart';
import 'linux/native_assets.dart';
import 'macos/native_assets.dart';
import 'macos/native_assets_host.dart';
import 'windows/native_assets.dart';

/// The assets produced by a Dart build and the dependencies of those assets.
///
/// If any of the dependencies change, then the Dart build should be performed
/// again.
final class DartBuildResult {
  const DartBuildResult(this.codeAssets, this.dependencies);
  const DartBuildResult.empty()
      : codeAssets = const <NativeCodeAssetImpl>[],
        dependencies = const <Uri>[];

  final List<NativeCodeAssetImpl> codeAssets;
  final List<Uri> dependencies;
}

/// Invokes the build of all transitive Dart packages & prepares code assets to
/// be included in the native build.
Future<(DartBuildResult, Uri)> runFlutterSpecificDartBuild({
  required Map<String, String> environmentDefines,
  required FlutterNativeAssetsBuildRunner buildRunner,
  required build_info.TargetPlatform targetPlatform,
  required Uri projectUri,
  Uri? nativeAssetsYamlUri,
  required FileSystem fileSystem,
}) async {
  final OS targetOS = _getNativeOSFromTargetPlatfrorm(targetPlatform);
  final Uri buildUri = nativeAssetsBuildUri(projectUri, targetOS);
  final Directory buildDir = fileSystem.directory(buildUri);

  final bool flutterTester = targetPlatform == build_info.TargetPlatform.tester;

  if (nativeAssetsYamlUri == null) {
    // Only `flutter test` uses the
    // `build/native_assets/<os>/native_assets.yaml` file which uses absolute
    // paths to the shared libraries.
    //
    // testCompilerBuildNativeAssets() passes `null`
    assert(flutterTester);
    nativeAssetsYamlUri ??= buildUri.resolve('native_assets.yaml');
  }

  if (!await buildDir.exists()) {
    // Ensure the folder exists so the native build system can copy it even
    // if there's no native assets.
    await buildDir.create(recursive: true);
  }

  if (!await _nativeBuildRequired(buildRunner)) {
    await writeNativeAssetsYaml(
        KernelAssets(), nativeAssetsYamlUri, fileSystem);
    return (const DartBuildResult.empty(), nativeAssetsYamlUri);
  }

  final build_info.BuildMode buildMode;
  if (flutterTester) {
    buildMode = build_info.BuildMode.debug;
  } else {
    final String? environmentBuildMode =
        environmentDefines[build_info.kBuildMode];
    if (environmentBuildMode == null) {
      throw MissingDefineException(build_info.kBuildMode, 'native_assets');
    }
    buildMode = build_info.BuildMode.fromCliName(environmentBuildMode);
  }
  final List<Target> targets = flutterTester
      ? <Target>[Target.current]
      : _targetsForOS(targetPlatform, targetOS, environmentDefines);
  final DartBuildResult result = targets.isEmpty
      ? const DartBuildResult.empty()
      : await _runDartBuild(
          environmentDefines: environmentDefines,
          buildRunner: buildRunner,
          targets: targets,
          projectUri: projectUri,
          buildMode: _nativeAssetsBuildMode(buildMode),
          fileSystem: fileSystem,
          targetOS: targetOS);

  final String? codesignIdentity =
      environmentDefines[build_info.kCodesignIdentity];

  final Map<NativeCodeAssetImpl, KernelAsset> assetTargetLocations =
      _assetTargetLocationsForOS(
          targetOS, result.codeAssets, flutterTester, buildUri);
  await _copyNativeCodeAssetsForOS(targetOS, buildUri, buildMode, fileSystem,
      assetTargetLocations, codesignIdentity, flutterTester);
  final KernelAssets vmAssetMapping =
      KernelAssets(assetTargetLocations.values.toList());
  await writeNativeAssetsYaml(vmAssetMapping, nativeAssetsYamlUri, fileSystem);
  return (result, nativeAssetsYamlUri);
}

Future<Uri?> runFlutterSpecificDartDryRunOnPlatforms({
  required Uri projectUri,
  required FileSystem fileSystem,
  required FlutterNativeAssetsBuildRunner buildRunner,
  required List<build_info.TargetPlatform> targetPlatforms,
}) async {
  if (!await _nativeBuildRequired(buildRunner)) {
    return null;
  }

  final Map<NativeCodeAssetImpl, KernelAsset> assetTargetLocations =
      <NativeCodeAssetImpl, KernelAsset>{};
  for (final build_info.TargetPlatform targetPlatform in targetPlatforms) {
    // This dry-run functionality is only used in the `flutter run`
    // implementation (not in `flutter build` or `flutter test`).
    //
    // Though we can end up with `flutterTester == true` if someone uses the
    // `flutter-tester` device via `flutter run -d flutter-tester` (which mainly
    // happens in tests)
    final bool flutterTester =
        targetPlatform == build_info.TargetPlatform.tester;

    final OSImpl targetOS = _getNativeOSFromTargetPlatfrorm(targetPlatform);
    if (targetOS != OS.macOS &&
        targetOS != OS.windows &&
        targetOS != OS.linux) {
      await ensureNoNativeAssetsOrOsIsSupported(
        projectUri,
        targetPlatform.toString(),
        fileSystem,
        buildRunner,
      );
    }

    final Uri buildUri = nativeAssetsBuildUri(projectUri, targetOS);
    final DartBuildResult result = await _runDartDryRunBuild(
        buildRunner: buildRunner,
        projectUri: projectUri,
        fileSystem: fileSystem,
        targetOS: targetOS);
    assetTargetLocations.addAll(_assetTargetLocationsForOS(
        targetOS, result.codeAssets, flutterTester, buildUri));
  }

  final Uri buildUri = targetPlatforms.length == 1
      ? nativeAssetsBuildUri(
          projectUri, _getNativeOSFromTargetPlatfrorm(targetPlatforms.single))
      : _buildUriMultiple(projectUri);
  final Uri nativeAssetsYamlUri = buildUri.resolve('native_assets.yaml');
  await writeNativeAssetsYaml(
    KernelAssets(assetTargetLocations.values.toList()),
    nativeAssetsYamlUri,
    fileSystem,
  );
  return nativeAssetsYamlUri;
}

/// Gets the native asset id to dylib mapping to embed in the kernel file.
///
/// Run hot compiles a kernel file that is pushed to the device after hot
/// restart. We need to embed the native assets mapping in order to access
/// native assets after hot restart.
class HotRunnerNativeAssetsBuilderImpl implements HotRunnerNativeAssetsBuilder {
  const HotRunnerNativeAssetsBuilderImpl();

  @override
  Future<Uri?> dryRun({
    required Uri projectUri,
    required FileSystem fileSystem,
    required List<FlutterDevice> flutterDevices,
    required String packageConfigPath,
    required PackageConfig packageConfig,
    required Logger logger,
  }) async {
    final FlutterNativeAssetsBuildRunner buildRunner =
        FlutterNativeAssetsBuildRunnerImpl(
      projectUri,
      packageConfigPath,
      packageConfig,
      fileSystem,
      globals.logger,
    );

    // If `flutter run -d all` is used then we may have multiple OSes.
    final List<build_info.TargetPlatform> targetPlatforms = flutterDevices
        .map((FlutterDevice d) => d.targetPlatform)
        .nonNulls
        .toList();

    return runFlutterSpecificDartDryRunOnPlatforms(
      projectUri: projectUri,
      fileSystem: fileSystem,
      buildRunner: buildRunner,
      targetPlatforms: targetPlatforms,
    );
  }
}

/// Programmatic API to be used by Dart launchers to invoke native builds.
///
/// It enables mocking `package:native_assets_builder` package.
/// It also enables mocking native toolchain discovery via [cCompilerConfig].
abstract class FlutterNativeAssetsBuildRunner {
  /// Whether the project has a `.dart_tools/package_config.json`.
  ///
  /// If there is no package config, [packagesWithNativeAssets], [build], and
  /// [buildDryRun] must not be invoked.
  Future<bool> hasPackageConfig();

  /// All packages in the transitive dependencies that have a `build.dart`.
  Future<List<Package>> packagesWithNativeAssets();

  /// Runs all [packagesWithNativeAssets] `build.dart` in dry run.
  Future<BuildDryRunResult> buildDryRun({
    required bool includeParentEnvironment,
    required LinkModePreferenceImpl linkModePreference,
    required OSImpl targetOS,
    required Uri workingDirectory,
  });

  /// Runs all [packagesWithNativeAssets] `build.dart`.
  Future<BuildResult> build({
    required bool includeParentEnvironment,
    required BuildModeImpl buildMode,
    required LinkModePreferenceImpl linkModePreference,
    required Target target,
    required Uri workingDirectory,
    CCompilerConfigImpl? cCompilerConfig,
    int? targetAndroidNdkApi,
    int? targetIOSVersion,
    int? targetMacOSVersion,
    IOSSdkImpl? targetIOSSdkImpl,
    required bool linkingEnabled,
  });

  /// Runs all [packagesWithNativeAssets] `link.dart`.
  Future<LinkResult> link({
    required bool includeParentEnvironment,
    required BuildModeImpl buildMode,
    required LinkModePreferenceImpl linkModePreference,
    required Target target,
    required Uri workingDirectory,
    required BuildResult buildResult,
    CCompilerConfigImpl? cCompilerConfig,
    int? targetAndroidNdkApi,
    int? targetIOSVersion,
    int? targetMacOSVersion,
    IOSSdkImpl? targetIOSSdkImpl,
  });

  /// The C compiler config to use for compilation.
  Future<CCompilerConfigImpl> get cCompilerConfig;

  /// The NDK compiler to use to use for compilation for Android.
  Future<CCompilerConfigImpl> get ndkCCompilerConfigImpl;
}

/// Uses `package:native_assets_builder` for its implementation.
class FlutterNativeAssetsBuildRunnerImpl
    implements FlutterNativeAssetsBuildRunner {
  FlutterNativeAssetsBuildRunnerImpl(
    this.projectUri,
    this.packageConfigPath,
    this.packageConfig,
    this.fileSystem,
    this.logger,
  );

  final Uri projectUri;
  final String packageConfigPath;
  final PackageConfig packageConfig;
  final FileSystem fileSystem;
  final Logger logger;

  late final logging.Logger _logger = logging.Logger('')
    ..onRecord.listen((logging.LogRecord record) {
      final int levelValue = record.level.value;
      final String message = record.message;
      if (levelValue >= logging.Level.SEVERE.value) {
        logger.printError(message);
      } else if (levelValue >= logging.Level.WARNING.value) {
        logger.printWarning(message);
      } else if (levelValue >= logging.Level.INFO.value) {
        logger.printTrace(message);
      } else {
        logger.printTrace(message);
      }
    });

  late final Uri _dartExecutable =
      fileSystem.directory(Cache.flutterRoot).uri.resolve('bin/dart');

  late final NativeAssetsBuildRunner _buildRunner = NativeAssetsBuildRunner(
    logger: _logger,
    dartExecutable: _dartExecutable,
  );

  @override
  Future<bool> hasPackageConfig() {
    return fileSystem.file(packageConfigPath).exists();
  }

  @override
  Future<List<Package>> packagesWithNativeAssets() async {
    final PackageLayout packageLayout = PackageLayout.fromPackageConfig(
      packageConfig,
      Uri.file(packageConfigPath),
    );
    // It suffices to only check for build hooks. If no packages have a build
    // hook. Then no build hook will output any assets for any link hook, and
    // thus the link hooks will never be run.
    return packageLayout.packagesWithAssets(Hook.build);
  }

  @override
  Future<BuildDryRunResult> buildDryRun({
    required bool includeParentEnvironment,
    required LinkModePreferenceImpl linkModePreference,
    required OSImpl targetOS,
    required Uri workingDirectory,
  }) {
    final PackageLayout packageLayout = PackageLayout.fromPackageConfig(
      packageConfig,
      Uri.file(packageConfigPath),
    );
    return _buildRunner.buildDryRun(
      includeParentEnvironment: includeParentEnvironment,
      linkModePreference: linkModePreference,
      targetOS: targetOS,
      workingDirectory: workingDirectory,
      packageLayout: packageLayout,
      linkingEnabled: false, // Dry run is only used in JIT mode.
    );
  }

  @override
  Future<BuildResult> build({
    required bool includeParentEnvironment,
    required BuildModeImpl buildMode,
    required LinkModePreferenceImpl linkModePreference,
    required Target target,
    required Uri workingDirectory,
    CCompilerConfigImpl? cCompilerConfig,
    int? targetIOSVersion,
    int? targetMacOSVersion,
    int? targetAndroidNdkApi,
    IOSSdkImpl? targetIOSSdkImpl,
    required bool linkingEnabled,
  }) {
    final PackageLayout packageLayout = PackageLayout.fromPackageConfig(
      packageConfig,
      Uri.file(packageConfigPath),
    );
    return _buildRunner.build(
      buildMode: buildMode,
      cCompilerConfig: cCompilerConfig,
      includeParentEnvironment: includeParentEnvironment,
      linkModePreference: linkModePreference,
      target: target,
      targetAndroidNdkApi: targetAndroidNdkApi,
      targetIOSSdk: targetIOSSdkImpl,
      workingDirectory: workingDirectory,
      packageLayout: packageLayout,
      targetIOSVersion: targetIOSVersion,
      targetMacOSVersion: targetMacOSVersion,
      linkingEnabled: linkingEnabled,
    );
  }

  @override
  Future<LinkResult> link({
    required bool includeParentEnvironment,
    required BuildModeImpl buildMode,
    required LinkModePreferenceImpl linkModePreference,
    required Target target,
    required Uri workingDirectory,
    required BuildResult buildResult,
    CCompilerConfigImpl? cCompilerConfig,
    int? targetAndroidNdkApi,
    int? targetIOSVersion,
    int? targetMacOSVersion,
    IOSSdkImpl? targetIOSSdkImpl,
  }) {
    final PackageLayout packageLayout = PackageLayout.fromPackageConfig(
      packageConfig,
      Uri.file(packageConfigPath),
    );
    return _buildRunner.link(
      buildMode: buildMode,
      cCompilerConfig: cCompilerConfig,
      includeParentEnvironment: includeParentEnvironment,
      linkModePreference: linkModePreference,
      target: target,
      targetAndroidNdkApi: targetAndroidNdkApi,
      targetIOSSdk: targetIOSSdkImpl,
      workingDirectory: workingDirectory,
      packageLayout: packageLayout,
      buildResult: buildResult,
      targetIOSVersion: targetIOSVersion,
      targetMacOSVersion: targetMacOSVersion,
    );
  }

  @override
  late final Future<CCompilerConfigImpl> cCompilerConfig = () {
    if (globals.platform.isMacOS || globals.platform.isIOS) {
      return cCompilerConfigMacOS();
    }
    if (globals.platform.isLinux) {
      return cCompilerConfigLinux();
    }
    if (globals.platform.isWindows) {
      return cCompilerConfigWindows();
    }
    if (globals.platform.isAndroid) {
      throwToolExit('Should use ndkCCompilerConfig for Android.');
    }
    throwToolExit('Unknown target OS.');
  }();

  @override
  late final Future<CCompilerConfigImpl> ndkCCompilerConfigImpl = () {
    return cCompilerConfigAndroid();
  }();
}

Future<Uri> writeNativeAssetsYaml(
  KernelAssets assets,
  Uri nativeAssetsYamlUri,
  FileSystem fileSystem,
) async {
  globals.logger
      .printTrace('Writing writeNativeAssetsYaml($nativeAssetsYamlUri).');
  final String nativeAssetsDartContents = assets.toNativeAssetsFile();
  final File nativeAssetsFile = fileSystem.file(nativeAssetsYamlUri);
  final Directory parentDirectory = nativeAssetsFile.parent;
  if (!await parentDirectory.exists()) {
    await parentDirectory.create(recursive: true);
  }
  await nativeAssetsFile.writeAsString(nativeAssetsDartContents);
  globals.logger.printTrace('Writing ${nativeAssetsFile.path} done.');
  return nativeAssetsFile.uri;
}

Future<bool> _nativeBuildRequired(
    FlutterNativeAssetsBuildRunner buildRunner) async {
  if (await _hasNoPackageConfig(buildRunner)) {
    return false;
  }
  final List<Package> packagesWithNativeAssets =
      await buildRunner.packagesWithNativeAssets();
  if (packagesWithNativeAssets.isEmpty) {
    globals.logger.printTrace(
      'No packages with native assets. Skipping native assets compilation.',
    );
    return false;
  }

  if (!featureFlags.isNativeAssetsEnabled) {
    final String packageNames =
        packagesWithNativeAssets.map((Package p) => p.name).join(' ');
    throwToolExit(
      'Package(s) $packageNames require the native assets feature to be enabled. '
      'Enable using `flutter config --enable-native-assets`.',
    );
  }
  return true;
}

/// Checks whether this project does not yet have a package config file.
///
/// A project has no package config when `pub get` has not yet been run.
///
/// Native asset builds cannot be run without a package config. If there is
/// no package config, leave a logging trace about that.
Future<bool> _hasNoPackageConfig(
    FlutterNativeAssetsBuildRunner buildRunner) async {
  final bool packageConfigExists = await buildRunner.hasPackageConfig();
  if (!packageConfigExists) {
    globals.logger.printTrace(
        'No package config found. Skipping native assets compilation.');
  }
  return !packageConfigExists;
}

/// Ensures that either this project has no native assets, or that native assets
/// are supported on that operating system.
///
/// Exits the tool if the above condition is not satisfied.
Future<void> ensureNoNativeAssetsOrOsIsSupported(
  Uri workingDirectory,
  String os,
  FileSystem fileSystem,
  FlutterNativeAssetsBuildRunner buildRunner,
) async {
  if (await _hasNoPackageConfig(buildRunner)) {
    return;
  }
  final List<Package> packagesWithNativeAssets =
      await buildRunner.packagesWithNativeAssets();
  if (packagesWithNativeAssets.isEmpty) {
    globals.logger.printTrace(
      'No packages with native assets. Skipping native assets compilation.',
    );
    return;
  }
  final String packageNames =
      packagesWithNativeAssets.map((Package p) => p.name).join(' ');
  throwToolExit(
    'Package(s) $packageNames require the native assets feature. '
    'This feature has not yet been implemented for `$os`. '
    'For more info see https://github.com/flutter/flutter/issues/129757.',
  );
}

/// Ensure all native assets have a linkmode declared to be dynamic loading.
///
/// In JIT, the link mode must always be dynamic linking.
/// In AOT, the static linking has not yet been implemented in Dart:
/// https://github.com/dart-lang/sdk/issues/49418.
///
/// Therefore, ensure all `build.dart` scripts return only dynamic libraries.
void _ensureNoLinkModeStatic(List<NativeCodeAssetImpl> codeAssets) {
  final List<NativeCodeAssetImpl> staticAssets = codeAssets
      .where((NativeCodeAssetImpl a) => a.linkMode is StaticLinking)
      .toList();
  if (staticAssets.isNotEmpty) {
    final String assetIds =
        staticAssets.map((NativeCodeAssetImpl a) => a.id).toSet().join(', ');
    throwToolExit(
      'Native asset(s) $assetIds have their link mode set to static, '
      'but this is not yet supported. '
      'For more info see https://github.com/dart-lang/sdk/issues/49418.',
    );
  }
}

/// This should be the same for different archs, debug/release, etc.
/// It should work for all macOS.
Uri nativeAssetsBuildUri(Uri projectUri, OS os) {
  final String buildDir = build_info.getBuildDirectory();
  return projectUri.resolve('$buildDir/native_assets/$os/');
}

/// With `flutter run -d all` we need a place to store the native assets
/// mapping for multiple OSes combined.
Uri _buildUriMultiple(Uri projectUri) {
  final String buildDir = build_info.getBuildDirectory();
  return projectUri.resolve('$buildDir/native_assets/multiple/');
}

Map<NativeCodeAssetImpl, KernelAsset> _assetTargetLocationsWindowsLinux(
  List<NativeCodeAssetImpl> assets,
  Uri? absolutePath,
) {
  return <NativeCodeAssetImpl, KernelAsset>{
    for (final NativeCodeAssetImpl asset in assets)
      asset: _targetLocationSingleArchitecture(
        asset,
        absolutePath,
      ),
  };
}

KernelAsset _targetLocationSingleArchitecture(
    NativeCodeAssetImpl asset, Uri? absolutePath) {
  final LinkMode linkMode = asset.linkMode;
  final KernelAssetPath kernelAssetPath;
  switch (linkMode) {
    case DynamicLoadingSystem _:
      kernelAssetPath = KernelAssetSystemPath(linkMode.uri);
    case LookupInExecutable _:
      kernelAssetPath = KernelAssetInExecutable();
    case LookupInProcess _:
      kernelAssetPath = KernelAssetInProcess();
    case DynamicLoadingBundled _:
      final String fileName = asset.file!.pathSegments.last;
      Uri uri;
      if (absolutePath != null) {
        // Flutter tester needs full host paths.
        uri = absolutePath.resolve(fileName);
      } else {
        // Flutter Desktop needs "absolute" paths inside the app.
        // "relative" in the context of native assets would be relative to the
        // kernel or aot snapshot.
        uri = Uri(path: fileName);
      }
      kernelAssetPath = KernelAssetAbsolutePath(uri);
    default:
      throw Exception(
        'Unsupported asset link mode ${linkMode.runtimeType} in asset $asset',
      );
  }
  return KernelAsset(
    id: asset.id,
    target: Target.fromArchitectureAndOS(asset.architecture!, asset.os),
    path: kernelAssetPath,
  );
}

Never _throwNativeAssetsBuildDryRunFailed() {
  throwToolExit(
    'Building (dry run) native assets failed. See the logs for more details.',
  );
}

Never _throwNativeAssetsBuildFailed() {
  throwToolExit(
    'Building native assets failed. See the logs for more details.',
  );
}

Never _throwNativeAssetsLinkFailed() {
  throwToolExit(
    'Linking native assets failed. See the logs for more details.',
  );
}

/// Select the native asset build mode for a given Flutter build mode.
BuildModeImpl _nativeAssetsBuildMode(build_info.BuildMode buildMode) {
  switch (buildMode) {
    case build_info.BuildMode.debug:
      return BuildModeImpl.debug;
    case build_info.BuildMode.jitRelease:
    case build_info.BuildMode.profile:
    case build_info.BuildMode.release:
      return BuildModeImpl.release;
  }
}

Map<NativeCodeAssetImpl, KernelAsset> _assetTargetLocationsForOS(OS targetOS,
    List<NativeCodeAssetImpl> codeAssets, bool flutterTester, Uri buildUri) {
  switch (targetOS) {
    case OS.windows:
    case OS.linux:
      final Uri? absolutePath = flutterTester ? buildUri : null;
      return _assetTargetLocationsWindowsLinux(codeAssets, absolutePath);
    case OS.macOS:
      final Uri? absolutePath = flutterTester ? buildUri : null;
      return assetTargetLocationsMacOS(codeAssets, absolutePath);
    case OS.iOS:
      return assetTargetLocationsIOS(codeAssets);
    case OS.android:
      return assetTargetLocationsAndroid(codeAssets);
    default:
      throw StateError('This should be unreachable.');
  }
}

Future<void> _copyNativeCodeAssetsForOS(
    OS targetOS,
    Uri buildUri,
    build_info.BuildMode buildMode,
    FileSystem fileSystem,
    Map<NativeCodeAssetImpl, KernelAsset> assetTargetLocations,
    String? codesignIdentity,
    bool flutterTester) async {
  final List<NativeCodeAssetImpl> codeAssets =
      assetTargetLocations.keys.toList();
  switch (targetOS) {
    case OS.windows:
    case OS.linux:
      await _copyNativeCodeAssetsToBundleOnWindowsLinux(
        buildUri,
        assetTargetLocations,
        buildMode,
        fileSystem,
      );
    case OS.macOS:
      if (flutterTester) {
        await copyNativeCodeAssetsMacOSFlutterTester(
          buildUri,
          fatAssetTargetLocationsMacOS(codeAssets, buildUri),
          codesignIdentity,
          buildMode,
          fileSystem,
        );
      } else {
        await copyNativeCodeAssetsMacOS(
          buildUri,
          fatAssetTargetLocationsMacOS(codeAssets, null),
          codesignIdentity,
          buildMode,
          fileSystem,
        );
      }
    case OS.iOS:
      await copyNativeCodeAssetsIOS(
        buildUri,
        fatAssetTargetLocationsIOS(codeAssets),
        codesignIdentity,
        buildMode,
        fileSystem,
      );
    case OS.android:
      await copyNativeCodeAssetsAndroid(
          buildUri, assetTargetLocations, fileSystem);
    default:
      throw StateError('This should be unreachable.');
  }
}

Future<void> _copyNativeCodeAssetsToBundleOnWindowsLinux(
  Uri buildUri,
  Map<NativeCodeAssetImpl, KernelAsset> assetTargetLocations,
  build_info.BuildMode buildMode,
  FileSystem fileSystem,
) async {
  globals.logger.printTrace('copyNativeCodeAssetsToBundleOnWindowsLinux()');
  if (assetTargetLocations.isNotEmpty) {
    globals.logger
        .printTrace('Copying native assets to ${buildUri.toFilePath()}.');
    final Directory buildDir = fileSystem.directory(buildUri.toFilePath());
    if (!buildDir.existsSync()) {
      buildDir.createSync(recursive: true);
    }
    for (final MapEntry<NativeCodeAssetImpl, KernelAsset> assetMapping
        in assetTargetLocations.entries) {
      final Uri source = assetMapping.key.file!;
      final Uri target =
          (assetMapping.value.path as KernelAssetAbsolutePath).uri;
      final Uri targetUri = buildUri.resolveUri(target);
      final String targetFullPath = targetUri.toFilePath();
      await fileSystem.file(source).copy(targetFullPath);
      globals.logger.printTrace(
          'copyNativeCodeAssetsToBundleOnWindowsLinux(): copied $source to $targetFullPath');
    }
    globals.logger.printTrace('Copying native assets done.');
  }
}

/// Invokes the build of all transitive Dart packages.
///
/// This will invoke `hook/build.dart` and `hook/link.dart` (if applicable) for
/// all transitive dart packages that define such hooks.
Future<DartBuildResult> _runDartBuild({
  required Map<String, String> environmentDefines,
  required FlutterNativeAssetsBuildRunner buildRunner,
  required List<Target> targets,
  required Uri projectUri,
  required BuildModeImpl buildMode,
  required FileSystem fileSystem,
  required OS targetOS,
}) async {
  final bool linkingEnabled = buildMode == BuildMode.release;
  final String targetString = targets.length == 1
      ? targets.single.toString()
      : targets.toList().toString();
  globals.logger
      .printTrace('Building native assets for $targetString $buildMode.');
  final List<Asset> assets = <Asset>[];
  final Set<Uri> dependencies = <Uri>{};
  final build_info.EnvironmentType? environmentType;
  if (targetOS == OS.iOS) {
    final String? sdkRoot = environmentDefines[build_info.kSdkRoot];
    if (sdkRoot == null) {
      throw MissingDefineException(build_info.kSdkRoot, 'native_assets');
    }
    environmentType = xcode.environmentTypeFromSdkroot(sdkRoot, fileSystem);
  } else {
    environmentType = null;
  }

  final CCompilerConfigImpl cCompilerConfig = targetOS == OS.android
      ? await buildRunner.ndkCCompilerConfigImpl
      : await buildRunner.cCompilerConfig;
  final IOSSdkImpl? targetIOSSdk =
      targetOS == OS.iOS ? getIOSSdk(environmentType!) : null;
  // TODO(dcharkes): Fetch minimum iOS version from somewhere. https://github.com/flutter/flutter/issues/145104
  final int? targetIOSVersion = targetOS == OS.iOS ? 12 : null;
  // TODO(dcharkes): Fetch minimum MacOS version from somewhere. https://github.com/flutter/flutter/issues/145104
  final int? targetMacOSVersion = targetOS == OS.macOS ? 13 : null;

  final String? codesignIdentity =
      environmentDefines[build_info.kCodesignIdentity];
  assert(
      codesignIdentity == null || targetOS == OS.iOS || targetOS == OS.macOS);

  final int? targetAndroidNdkApi = targetOS == OS.android
      ? int.parse(environmentDefines[build_info.kMinSdkVersion] ??
          gradle_utils.minSdkVersion)
      : null;

  for (final Target target in targets) {
    final BuildResult buildResult = await buildRunner.build(
      linkModePreference: LinkModePreferenceImpl.dynamic,
      target: target,
      buildMode: buildMode,
      workingDirectory: projectUri,
      includeParentEnvironment: true,
      linkingEnabled: linkingEnabled,
      cCompilerConfig: cCompilerConfig,
      targetAndroidNdkApi: targetAndroidNdkApi,
      targetIOSVersion: targetIOSVersion,
      targetMacOSVersion: targetMacOSVersion,
      targetIOSSdkImpl: targetIOSSdk,
    );
    if (!buildResult.success) {
      _throwNativeAssetsBuildFailed();
    }
    assets.addAll(buildResult.assets);
    dependencies.addAll(buildResult.dependencies);
    if (linkingEnabled) {
      final LinkResult linkResult = await buildRunner.link(
        linkModePreference: LinkModePreferenceImpl.dynamic,
        target: target,
        buildMode: buildMode,
        workingDirectory: projectUri,
        includeParentEnvironment: true,
        buildResult: buildResult,
        cCompilerConfig: cCompilerConfig,
        targetAndroidNdkApi: targetAndroidNdkApi,
        targetIOSVersion: targetIOSVersion,
        targetMacOSVersion: targetMacOSVersion,
        targetIOSSdkImpl: targetIOSSdk,
      );
      if (!linkResult.success) {
        _throwNativeAssetsLinkFailed();
      }
      assets.addAll(linkResult.assets);
      dependencies.addAll(linkResult.dependencies);
    }
  }

  final List<NativeCodeAssetImpl> codeAssets =
      assets.whereType<NativeCodeAssetImpl>().toList();
  _ensureNoLinkModeStatic(codeAssets);
  globals.logger
      .printTrace('Building native assets for $targetString $buildMode done.');
  return DartBuildResult(codeAssets, dependencies.toList());
}

Future<DartBuildResult> _runDartDryRunBuild({
  required FlutterNativeAssetsBuildRunner buildRunner,
  required Uri projectUri,
  required FileSystem fileSystem,
  required OSImpl targetOS,
}) async {
  globals.logger.printTrace('Dry running native assets for $targetOS.');
  final List<Asset> assets = <Asset>[];
  final Set<Uri> dependencies = <Uri>{};

  final BuildDryRunResult buildResult = await buildRunner.buildDryRun(
    linkModePreference: LinkModePreferenceImpl.dynamic,
    targetOS: targetOS,
    workingDirectory: projectUri,
    includeParentEnvironment: true,
  );
  if (!buildResult.success) {
    _throwNativeAssetsBuildDryRunFailed();
  }
  assets.addAll(buildResult.assets);

  final List<NativeCodeAssetImpl> codeAssets =
      assets.whereType<NativeCodeAssetImpl>().toList();
  _ensureNoLinkModeStatic(codeAssets);
  globals.logger.printTrace('Dry running native assets for $targetOS done.');
  return DartBuildResult(codeAssets, dependencies.toList());
}

List<Target> _targetsForOS(build_info.TargetPlatform targetPlatform,
    OS targetOS, Map<String, String> environmentDefines) {
  switch (targetOS) {
    case OS.linux:
      return <Target>[_getNativeTarget(targetPlatform)];
    case OS.windows:
      return <Target>[_getNativeTarget(targetPlatform)];
    case OS.macOS:
      final List<build_info.DarwinArch> darwinArchs =
          _emptyToNull(environmentDefines[build_info.kDarwinArchs])
                  ?.split(' ')
                  .map(build_info.getDarwinArchForName)
                  .toList() ??
              <build_info.DarwinArch>[
                build_info.DarwinArch.x86_64,
                build_info.DarwinArch.arm64
              ];
      return darwinArchs.map(getNativeMacOSTarget).toList();
    case OS.android:
      final String? androidArchsEnvironment =
          environmentDefines[build_info.kAndroidArchs];
      final List<build_info.AndroidArch> androidArchs = _androidArchs(
        targetPlatform,
        androidArchsEnvironment,
      );
      return androidArchs.map(getNativeAndroidTarget).toList();
    case OS.iOS:
      final List<build_info.DarwinArch> iosArchs =
          _emptyToNull(environmentDefines[build_info.kIosArchs])
                  ?.split(' ')
                  .map(build_info.getIOSArchForName)
                  .toList() ??
              <build_info.DarwinArch>[build_info.DarwinArch.arm64];
      return iosArchs.map(getNativeIOSTarget).toList();
    default:
      // TODO(dacoharkes): Implement other OSes. https://github.com/flutter/flutter/issues/129757
      // Write the file we claim to have in the [outputs].
      return <Target>[];
  }
}

Target _getNativeTarget(build_info.TargetPlatform targetPlatform) {
  switch (targetPlatform) {
    case build_info.TargetPlatform.linux_x64:
      return Target.linuxX64;
    case build_info.TargetPlatform.linux_arm64:
      return Target.linuxArm64;
    case build_info.TargetPlatform.windows_x64:
      return Target.windowsX64;
    case build_info.TargetPlatform.windows_arm64:
      return Target.windowsArm64;
    case build_info.TargetPlatform.android:
    case build_info.TargetPlatform.ios:
    case build_info.TargetPlatform.darwin:
    case build_info.TargetPlatform.fuchsia_arm64:
    case build_info.TargetPlatform.fuchsia_x64:
    case build_info.TargetPlatform.tester:
    case build_info.TargetPlatform.web_javascript:
    case build_info.TargetPlatform.android_arm:
    case build_info.TargetPlatform.android_arm64:
    case build_info.TargetPlatform.android_x64:
    case build_info.TargetPlatform.android_x86:
      throw Exception('Unknown targetPlatform: $targetPlatform.');
  }
}

String? _emptyToNull(String? input) {
  if (input == null || input.isEmpty) {
    return null;
  }
  return input;
}

OSImpl _getNativeOSFromTargetPlatfrorm(build_info.TargetPlatform platform) {
  switch (platform) {
    case build_info.TargetPlatform.ios:
      return OSImpl.iOS;
    case build_info.TargetPlatform.darwin:
      return OSImpl.macOS;
    case build_info.TargetPlatform.linux_x64:
    case build_info.TargetPlatform.linux_arm64:
      return OSImpl.linux;
    case build_info.TargetPlatform.windows_x64:
    case build_info.TargetPlatform.windows_arm64:
      return OSImpl.windows;
    case build_info.TargetPlatform.fuchsia_arm64:
    case build_info.TargetPlatform.fuchsia_x64:
      return OSImpl.fuchsia;
    case build_info.TargetPlatform.android:
    case build_info.TargetPlatform.android_arm:
    case build_info.TargetPlatform.android_arm64:
    case build_info.TargetPlatform.android_x64:
    case build_info.TargetPlatform.android_x86:
      return OSImpl.android;
    case build_info.TargetPlatform.tester:
      if (const LocalPlatform().isMacOS) {
        return OSImpl.macOS;
      } else if (const LocalPlatform().isLinux) {
        return OSImpl.linux;
      } else if (const LocalPlatform().isWindows) {
        return OSImpl.windows;
      } else {
        throw StateError('Unknown operating system');
      }
    case build_info.TargetPlatform.web_javascript:
      throw StateError('No dart builds for web yet.');
  }
}

List<build_info.AndroidArch> _androidArchs(
  build_info.TargetPlatform targetPlatform,
  String? androidArchsEnvironment,
) {
  switch (targetPlatform) {
    case build_info.TargetPlatform.android_arm:
      return <build_info.AndroidArch>[build_info.AndroidArch.armeabi_v7a];
    case build_info.TargetPlatform.android_arm64:
      return <build_info.AndroidArch>[build_info.AndroidArch.arm64_v8a];
    case build_info.TargetPlatform.android_x64:
      return <build_info.AndroidArch>[build_info.AndroidArch.x86_64];
    case build_info.TargetPlatform.android_x86:
      return <build_info.AndroidArch>[build_info.AndroidArch.x86];
    case build_info.TargetPlatform.android:
      if (androidArchsEnvironment == null) {
        throw MissingDefineException(build_info.kAndroidArchs, 'native_assets');
      }
      return androidArchsEnvironment
          .split(' ')
          .map(build_info.getAndroidArchForName)
          .toList();
    case build_info.TargetPlatform.darwin:
    case build_info.TargetPlatform.fuchsia_arm64:
    case build_info.TargetPlatform.fuchsia_x64:
    case build_info.TargetPlatform.ios:
    case build_info.TargetPlatform.linux_arm64:
    case build_info.TargetPlatform.linux_x64:
    case build_info.TargetPlatform.tester:
    case build_info.TargetPlatform.web_javascript:
    case build_info.TargetPlatform.windows_x64:
    case build_info.TargetPlatform.windows_arm64:
      throwToolExit('Unsupported Android target platform: $targetPlatform.');
  }
}
