// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';

import 'package:meta/meta.dart';

import '../artifacts.dart';
import '../base/file_system.dart';
import '../build_info.dart';
import '../bundle.dart';
import '../compile.dart';
import '../flutter_plugins.dart';
import '../globals_null_migrated.dart' as globals;
import '../project.dart';

/// A request to the [TestCompiler] for recompilation.
class CompilationRequest {
  CompilationRequest(this.mainUri, this.result);

  Uri mainUri;
  Completer<String> result;
}

/// A frontend_server wrapper for the flutter test runner.
///
/// This class is a wrapper around compiler that allows multiple isolates to
/// enqueue compilation requests, but ensures only one compilation at a time.
class TestCompiler {
  /// Creates a new [TestCompiler] which acts as a frontend_server proxy.
  ///
  /// [trackWidgetCreation] configures whether the kernel transform is applied
  /// to the output. This also changes the output file to include a '.track`
  /// extension.
  ///
  /// [flutterProject] is the project for which we are running tests.
  ///
  /// If [precompiledDillPath] is passed, it will be used to initialize the
  /// compiler.
  TestCompiler(
    this.buildInfo,
    this.flutterProject,
    { String precompiledDillPath }
  ) : testFilePath = precompiledDillPath ?? globals.fs.path.join(
        flutterProject.directory.path,
        getBuildDirectory(),
        'test_cache',
        getDefaultCachedKernelPath(
          trackWidgetCreation: buildInfo.trackWidgetCreation,
          dartDefines: buildInfo.dartDefines,
          extraFrontEndOptions: buildInfo.extraFrontEndOptions,
        )),
       shouldCopyDillFile = precompiledDillPath == null {
    // Compiler maintains and updates single incremental dill file.
    // Incremental compilation requests done for each test copy that file away
    // for independent execution.
    final Directory outputDillDirectory = globals.fs.systemTempDirectory.createTempSync('flutter_test_compiler.');
    outputDill = outputDillDirectory.childFile('output.dill');
    globals.printTrace('Compiler will use the following file as its incremental dill file: ${outputDill.path}');
    globals.printTrace('Listening to compiler controller...');
    compilerController.stream.listen(_onCompilationRequest, onDone: () {
      globals.printTrace('Deleting ${outputDillDirectory.path}...');
      outputDillDirectory.deleteSync(recursive: true);
    });
  }

  final StreamController<CompilationRequest> compilerController = StreamController<CompilationRequest>();
  final List<CompilationRequest> compilationQueue = <CompilationRequest>[];
  final FlutterProject flutterProject;
  final BuildInfo buildInfo;
  final String testFilePath;
  final bool shouldCopyDillFile;


  ResidentCompiler compiler;
  File outputDill;

  Future<String> compile(Uri mainDart) {
    final Completer<String> completer = Completer<String>();
    if (compilerController.isClosed) {
      return null;
    }
    compilerController.add(CompilationRequest(mainDart, completer));
    return completer.future;
  }

  Future<void> _shutdown() async {
    // Check for null in case this instance is shut down before the
    // lazily-created compiler has been created.
    if (compiler != null) {
      await compiler.shutdown();
      compiler = null;
    }
  }

  Future<void> dispose() async {
    await compilerController.close();
    await _shutdown();
  }

  /// Create the resident compiler used to compile the test.
  @visibleForTesting
  Future<ResidentCompiler> createCompiler() async {
    final ResidentCompiler residentCompiler = ResidentCompiler(
      globals.artifacts.getArtifactPath(Artifact.flutterPatchedSdkPath),
      artifacts: globals.artifacts,
      logger: globals.logger,
      processManager: globals.processManager,
      buildMode: buildInfo.mode,
      trackWidgetCreation: buildInfo.trackWidgetCreation,
      initializeFromDill: testFilePath,
      unsafePackageSerialization: false,
      dartDefines: buildInfo.dartDefines,
      packagesPath: buildInfo.packagesPath,
      extraFrontEndOptions: buildInfo.extraFrontEndOptions,
      platform: globals.platform,
      testCompilation: true,
      fileSystem: globals.fs,
      fileSystemRoots: buildInfo.fileSystemRoots,
      fileSystemScheme: buildInfo.fileSystemScheme,
    );
    return residentCompiler;
  }

  // Handle a compilation request.
  Future<void> _onCompilationRequest(CompilationRequest request) async {
    final bool isEmpty = compilationQueue.isEmpty;
    compilationQueue.add(request);
    // Only trigger processing if queue was empty - i.e. no other requests
    // are currently being processed. This effectively enforces "one
    // compilation request at a time".
    if (!isEmpty) {
      return;
    }
    while (compilationQueue.isNotEmpty) {
      final CompilationRequest request = compilationQueue.first;
      globals.printTrace('Compiling ${request.mainUri}');
      final Stopwatch compilerTime = Stopwatch()..start();
      bool firstCompile = false;
      if (compiler == null) {
        compiler = await createCompiler();
        firstCompile = true;
      }

      // Update the generated registrant to use the test target's main.
      final String mainUriString = buildInfo.packageConfig.toPackageUri(request.mainUri)?.toString()
        ?? request.mainUri.toString();
      await generateMainDartWithPluginRegistrant(
        flutterProject,
        buildInfo.packageConfig,
        mainUriString,
        globals.fs.file(request.mainUri),
        throwOnPluginPubspecError: false,
      );

      final CompilerOutput compilerOutput = await compiler.recompile(
        request.mainUri,
        <Uri>[request.mainUri, flutterProject.dartPluginRegistrant.absolute.uri],
        outputPath: outputDill.path,
        packageConfig: buildInfo.packageConfig,
        projectRootPath: flutterProject?.directory?.absolute?.path,
        checkDartPluginRegistry: true,
        fs: globals.fs,
      );
      final String outputPath = compilerOutput?.outputFilename;

      // In case compiler didn't produce output or reported compilation
      // errors, pass [null] upwards to the consumer and shutdown the
      // compiler to avoid reusing compiler that might have gotten into
      // a weird state.
      if (outputPath == null || compilerOutput.errorCount > 0) {
        request.result.complete(null);
        await _shutdown();
      } else {
        if (shouldCopyDillFile) {
          final String path = request.mainUri.toFilePath(windows: globals.platform.isWindows);
          final File outputFile = globals.fs.file(outputPath);
          final File kernelReadyToRun = await outputFile.copy('$path.dill');
          final File testCache = globals.fs.file(testFilePath);
          if (firstCompile || !testCache.existsSync() || (testCache.lengthSync() < outputFile.lengthSync())) {
            // The idea is to keep the cache file up-to-date and include as
            // much as possible in an effort to re-use as many packages as
            // possible.
            if (!testCache.parent.existsSync()) {
              testCache.parent.createSync(recursive: true);
            }
            await outputFile.copy(testFilePath);
          }
          request.result.complete(kernelReadyToRun.path);
        } else {
          request.result.complete(outputPath);
        }
        compiler.accept();
        compiler.reset();
      }
      globals.printTrace('Compiling ${request.mainUri} took ${compilerTime.elapsedMilliseconds}ms');
      // Only remove now when we finished processing the element
      compilationQueue.removeAt(0);
    }
  }
}
