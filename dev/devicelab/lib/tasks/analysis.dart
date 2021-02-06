// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;

import '../framework/task_result.dart';
import '../framework/utils.dart';

/// Run each benchmark this many times and compute average, min, max.
///
/// This must be small enough that we can do all the work in 15 minutes, the
/// devicelab deadline. Since there's four different analysis tasks, on average,
/// each can have 4 minutes. The tasks currently average a little more than a
/// minute, so that allows three runs per task.
const int _kRunsPerBenchmark = 3;

/// Path to the generated "mega gallery" app.
Directory get _megaGalleryDirectory => dir(path.join(Directory.systemTemp.path, 'mega_gallery'));

Future<void> pubGetDependencies(List<Directory> directories) async {
  for (final Directory directory in directories) {
    await inDirectory<void>(directory, () async {
      await flutter('pub', options: <String>['get']);
    });
  }
}

Future<TaskResult> analyzerBenchmarkTask() async {
  await inDirectory<void>(flutterDirectory, () async {
    rmTree(_megaGalleryDirectory);
    mkdirs(_megaGalleryDirectory);
    await pubGetDependencies(
      <Directory>[
        Directory(path.join(flutterDirectory.path, 'dev', 'tools')),
        Directory(path.join(flutterDirectory.path, 'dev', 'bots')),
        Directory(path.join(flutterDirectory.path, 'dev', 'automated_tests')),
        Directory(path.join(flutterDirectory.path, 'dev', 'benchmarks', 'complex_layout')),
        Directory(path.join(flutterDirectory.path, 'dev', 'benchmarks', 'macrobenchmarks')),
        Directory(path.join(flutterDirectory.path, 'dev', 'benchmarks', 'microbenchmarks')),
        Directory(path.join(flutterDirectory.path, 'dev', 'benchmarks', 'platform_views_layout')),
        Directory(path.join(flutterDirectory.path, 'dev', 'benchmarks', 'platform_views_layout_hybrid_composition')),
        Directory(path.join(flutterDirectory.path, 'dev', 'benchmarks', 'test_apps', 'stocks')),
        Directory(path.join(flutterDirectory.path, 'dev', 'customer_testing')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'abstract_method_smoke_test')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'android_semantics_testing')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'android_embedding_v2_smoke_test')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'android_semantics_testing')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'android_splash_screens', 'splash_screen_kitchen_sink')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'android_splash_screens', 'splash_screen_load_rotate')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'android_splash_screens', 'splash_screen_trans_rotate')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'android_views')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'channels')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'external_ui')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'flavors')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'flutter_driver_screenshot_test')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'flutter_gallery')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'gradle_deprecated_settings')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'hybrid_android_views')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'image_loading')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'ios_add2app_life_cycle', 'flutterapp')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'ios_app_with_extensions')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'ios_platform_view_tests')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'non_nullable')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'platform_interaction')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'release_smoke_test')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'ui')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'web')),
        Directory(path.join(flutterDirectory.path, 'dev', 'integration_tests', 'web_e2e_tests')),
        Directory(path.join(flutterDirectory.path, 'dev', 'manual_tests')),
	Directory(path.join(flutterDirectory.path, 'examples', 'platform_channel_swift')),
        Directory(path.join(flutterDirectory.path, 'packages', 'flutter')),
        Directory(path.join(flutterDirectory.path, 'packages', 'flutter_driver')),
        Directory(path.join(flutterDirectory.path, 'packages', 'flutter_localizations')),
        Directory(path.join(flutterDirectory.path, 'packages', 'flutter_test')),
        Directory(path.join(flutterDirectory.path, 'packages', 'flutter_web_plugins')),
        Directory(path.join(flutterDirectory.path, 'packages', 'fuchsia_remote_debug_protocol')),
        Directory(path.join(flutterDirectory.path, 'packages', 'integration_test')),
      ]);
    await dart(<String>['dev/tools/mega_gallery.dart', '--out=${_megaGalleryDirectory.path}']);
  });

  final Map<String, dynamic> data = <String, dynamic>{
    ...(await _run(_FlutterRepoBenchmark())).asMap('flutter_repo', 'batch'),
    ...(await _run(_FlutterRepoBenchmark(watch: true))).asMap('flutter_repo', 'watch'),
    ...(await _run(_MegaGalleryBenchmark())).asMap('mega_gallery', 'batch'),
    ...(await _run(_MegaGalleryBenchmark(watch: true))).asMap('mega_gallery', 'watch'),
  };

  return TaskResult.success(data, benchmarkScoreKeys: data.keys.toList());
}

class _BenchmarkResult {
  const _BenchmarkResult(this.mean, this.min, this.max);

  final double mean; // seconds

  final double min; // seconds

  final double max; // seconds

  Map<String, dynamic> asMap(String benchmark, String mode) {
    return <String, dynamic>{
      '${benchmark}_$mode': mean,
      '${benchmark}_${mode}_minimum': min,
      '${benchmark}_${mode}_maximum': max,
    };
  }
}

abstract class _Benchmark {
  _Benchmark({this.watch = false});

  final bool watch;

  String get title;

  Directory get directory;

  List<String> get options => <String>[
        '--benchmark',
        if (watch) '--watch',
      ];

  Future<double> execute(int iteration, int targetIterations) async {
    section('Analyze $title ${watch ? 'with watcher' : ''} - ${iteration + 1} / $targetIterations');
    final Stopwatch stopwatch = Stopwatch();
    await inDirectory<void>(directory, () async {
      stopwatch.start();
      await flutter('analyze', options: options);
      stopwatch.stop();
    });
    return stopwatch.elapsedMicroseconds / (1000.0 * 1000.0);
  }
}

/// Times how long it takes to analyze the Flutter repository.
class _FlutterRepoBenchmark extends _Benchmark {
  _FlutterRepoBenchmark({bool watch = false}) : super(watch: watch);

  @override
  String get title => 'Flutter repo';

  @override
  Directory get directory => flutterDirectory;

  @override
  List<String> get options {
    return super.options..add('--flutter-repo');
  }
}

/// Times how long it takes to analyze the generated "mega_gallery" app.
class _MegaGalleryBenchmark extends _Benchmark {
  _MegaGalleryBenchmark({bool watch = false}) : super(watch: watch);

  @override
  String get title => 'mega gallery';

  @override
  Directory get directory => _megaGalleryDirectory;
}

/// Runs `benchmark` several times and reports the results.
Future<_BenchmarkResult> _run(_Benchmark benchmark) async {
  final List<double> results = <double>[];
  for (int i = 0; i < _kRunsPerBenchmark; i += 1) {
    // Delete cached analysis results.
    rmTree(dir('${Platform.environment['HOME']}/.dartServer'));
    results.add(await benchmark.execute(i, _kRunsPerBenchmark));
  }
  results.sort();
  final double sum = results.fold<double>(
    0.0,
    (double previousValue, double element) => previousValue + element,
  );
  return _BenchmarkResult(sum / results.length, results.first, results.last);
}
