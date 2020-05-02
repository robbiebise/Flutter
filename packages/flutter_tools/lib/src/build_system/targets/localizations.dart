// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:process/process.dart';
import 'package:yaml/yaml.dart';

import '../../artifacts.dart';
import '../../base/file_system.dart';
import '../../base/io.dart';
import '../../base/logger.dart';
import '../../globals.dart' as globals;
import '../build_system.dart';
import '../depfile.dart';

/// Run the localizations generation script with the configuration [options].
Future<Depfile> generateLocalizations({
  @required LocalizationOptions options,
  @required String flutterRoot,
  @required FileSystem fileSystem,
  @required ProcessManager processManager,
  @required Logger logger,
  @required Directory projectDir,
  @required String dartBinaryPath,
}) async {
  // Setup project inputs and outputs. This currently makes some
  // guess about the output and does not include all files.
  final Directory inputArb = fileSystem.directory(
    options.arbDirectory ?? projectDir
      .childDirectory('lib')
      .childFile('l10n').uri,
  );

  File outputLocalzations;
  if (options.outputLocalizationsFile != null) {
    outputLocalzations = fileSystem
      .file(inputArb.uri.resolveUri(options.outputLocalizationsFile));
  } else {
    outputLocalzations = projectDir
    .childDirectory('lib')
    .childFile('app_localizations.dart');
  }

  if (!inputArb.existsSync()) {
    logger.printError('arb-dir: ${inputArb.path} does not exist.');
    throw Exception();
  }

  final List<File> inputs = <File>[
    // Include all arb files as build inputs.
    for (final File file in inputArb.listSync().whereType<File>())
      if (fileSystem.path.extension(file.path) == '.arb')
        file,
  ];
  final List<File> outputs = <File>[
    outputLocalzations,
  ];

  final Depfile depfile = Depfile(inputs, outputs);
  final String genL10nPath = fileSystem.path.join(
    flutterRoot,
    'dev',
    'tools',
    'localization',
    'bin',
    'gen_l10n.dart',
  );
  final ProcessResult result = await processManager.run(<String>[
    dartBinaryPath,
    genL10nPath,
    if (options.arbDirectory != null)
      '--arb-dir=${options.arbDirectory.toFilePath()}',
    if (options.templateArbFile != null)
      '--template-arb-file=${options.templateArbFile.toFilePath()}',
    if (options.outputLocalizationsFile != null)
      '--output-localization-file=${options.outputLocalizationsFile.toFilePath()}',
    if (options.untranslatedMessagesFile != null)
      '--untranslated-messages-file=${options.untranslatedMessagesFile.toFilePath()}',
    if (options.outputClass != null)
      '--output-class=${options.outputClass}',
    if (options.headerFile != null)
      '--header-file=${options.headerFile.toFilePath()}',
    if (options.header != null)
      '--header=${options.header}',
    if (options.deferredLoading != null)
      '--use-deferred-loading',
    if (options.preferredSupportedLocales != null)
      '--preferred-supported-locales=${options.preferredSupportedLocales}',
  ]);
  if (result.exitCode != 0) {
    logger.printError(result.stdout + result.stderr as String);
    throw Exception();
  }
  return depfile;
}

/// A build step that runs the generate localizations script from
/// dev/tool/localizations.
class GenerateLocalizationsTarget extends Target {
  const GenerateLocalizationsTarget();

  @override
  List<Target> get dependencies => <Target>[];

  @override
  List<Source> get inputs => <Source>[
    const Source.pattern('{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/localizations.dart')
  ];

  @override
  String get name => 'gen_localizations';

  @override
  List<Source> get outputs => <Source>[];

  @override
  List<String> get depfiles => <String>['gen_localizations.d'];

  @override
  Future<void> build(Environment environment) async {
    final File configFile = environment.projectDir.childFile('l10n.yaml');

    // If the config file does not exist, exit immediately.
    if (!configFile.existsSync()) {
      return;
    }
    final LocalizationOptions options = parseLocalizationsOptions(
      file: configFile,
      logger: globals.logger,
    );
    final DepfileService depfileService = DepfileService(
      logger: environment.logger,
      fileSystem: environment.fileSystem,
    );

    final Depfile depfile = await generateLocalizations(
      fileSystem: environment.fileSystem,
      flutterRoot: environment.flutterRootDir.path,
      logger: environment.logger,
      processManager: environment.processManager,
      options: options,
      projectDir: environment.projectDir,
      dartBinaryPath: environment.artifacts
        .getArtifactPath(Artifact.engineDartBinary),
    );
    depfile.inputs.add(configFile);
    depfileService.writeToFile(
      depfile,
      environment.buildDir.childFile('gen_localizations.d'),
    );
  }
}

/// Typed configuration from the localizations config file.
class LocalizationOptions {
  const LocalizationOptions({
    this.arbDirectory,
    this.templateArbFile,
    this.outputLocalizationsFile,
    this.untranslatedMessagesFile,
    this.header,
    this.outputClass,
    this.preferredSupportedLocales,
    this.headerFile,
    this.deferredLoading,
  });

  /// The `--arb-dir` argument.
  ///
  /// The directory where all localization files should reside.
  final Uri arbDirectory;

  /// The `--template-arb-file` argument.
  ///
  /// This URI is relative to [arbDirectory].
  final Uri templateArbFile;

  /// The `--output-localization-file` argument.
  ///
  /// This URI is relative to [arbDirectory].
  final Uri outputLocalizationsFile;

  /// The `--untranslated-messages-file` argument.
  ///
  /// This URI is relative to [arbDirectory].
  final Uri untranslatedMessagesFile;

  /// The `--header` argument.
  ///
  /// The header to prepend to the generated Dart localizations
  final String header;

  /// The `--output-class` argument.
  final String outputClass;

  /// The `--preferred-supported-locales` argument.
  final String preferredSupportedLocales;

  /// The `--header-file` argument.
  ///
  /// A file containing the header to preprend to the generated
  /// Dart localizations.
  final Uri headerFile;

  /// The `--use-deferred-loading` argument.
  ///
  /// Whether to generate the Dart localization file with locales imported
  /// as deferred.
  final bool deferredLoading;
}

/// Parse the localizations configuration options from [file].
///
/// Throws [Exception] if any of the contents are invalid. Returns a
/// [LocalizationOptions] will all fields as `null` if the config file exists
/// but is empty.
LocalizationOptions parseLocalizationsOptions({
  @required File file,
  @required Logger logger,
}) {
  final String contents = file.readAsStringSync();
  if (contents.trim().isEmpty) {
    return const LocalizationOptions();
  }
  final YamlNode yamlNode = loadYamlNode(file.readAsStringSync());
  if (yamlNode is! YamlMap) {
    logger.printError('Expected ${file.path} to contain a map, instead was $yamlNode');
    throw Exception();
  }
  final YamlMap yamlMap = yamlNode as YamlMap;
  return LocalizationOptions(
    arbDirectory: _tryReadUri(yamlMap, 'arb-dir', logger),
    templateArbFile: _tryReadUri(yamlMap, 'template-arb-file', logger),
    outputLocalizationsFile: _tryReadUri(yamlMap, 'output-localization-file', logger),
    untranslatedMessagesFile: _tryReadUri(yamlMap, 'untranslated-messages-file', logger),
    header: _tryReadString(yamlMap, 'header', logger),
    outputClass: _tryReadString(yamlMap, 'output-class', logger),
    preferredSupportedLocales: _tryReadString(yamlMap, 'preferred-supported-locales', logger),
    headerFile: _tryReadUri(yamlMap, 'header-file', logger),
    deferredLoading: _tryReadBool(yamlMap, 'use-deferred-loading', logger),
  );
}

// Try to read a `bool` value or null from `yamlMap`, otherwise throw.
bool _tryReadBool(YamlMap yamlMap, String key, Logger logger) {
  final Object value = yamlMap[key];
  if (value == null) {
    return null;
  }
  if (value is! bool) {
    logger.printError('Expected "$key" to have a bool value, instead was "$value"');
    throw Exception();
  }
  return value as bool;
}

// Try to read a `String` value or null from `yamlMap`, otherwise throw.
String _tryReadString(YamlMap yamlMap, String key, Logger logger) {
  final Object value = yamlMap[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    logger.printError('Expected "$key" to have a String value, instead was "$value"');
    throw Exception();
  }
  return value as String;
}

// Try to read a valid `Uri` or null from `yamlMap`, otherwise throw.
Uri _tryReadUri(YamlMap yamlMap, String key, Logger logger) {
  final String value = _tryReadString(yamlMap, key, logger);
  if (value == null) {
    return null;
  }
  final Uri uri = Uri.tryParse(value);
  if (uri == null) {
    logger.printError('"$value" must be a relative file URI');
  }
  return uri;
}
