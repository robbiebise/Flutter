// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import '../base/utils.dart';
import 'flutter_manifest.dart';
import 'parse_result.dart';

/// Represents an entry under the `assets` section of a pubspec.
@immutable
class AssetsEntry {
  const AssetsEntry({
    required this.uri,
    this.flavors = const <String>{},
  });

  final Uri uri;
  final Set<String> flavors;

  static const String _pathKey = 'path';
  static const String _flavorKey = 'flavors';

  static ParseResult<AssetsEntry?> parseFromYaml(Object? yaml) {

    (Uri?, String?) tryParseUri(String uri) {
      try {
        return (Uri(pathSegments: uri.split('/')), null);
      } on FormatException {
        return (null, 'Asset manifest contains invalid uri: $uri.');
      }
    }

    if (yaml == null || yaml == '') {
      return const ErrorParseResult<AssetsEntry>(<String>['Asset manifest contains a null or empty uri.']);
    }

    if (yaml is String) {
      final (Uri? uri, String? error) = tryParseUri(yaml);
      if (uri == null) {
        return ErrorParseResult<AssetsEntry>(<String>[error!]);
      }
      return ValueParseResult<AssetsEntry>(AssetsEntry(uri: uri));
    }

    if (yaml is Map) {
      if (yaml.keys.isEmpty) {
        return const ValueParseResult<AssetsEntry?>(null);
      }

      final Object? path = yaml[_pathKey];
      final Object? flavorsYaml = yaml[_flavorKey];

      if (path == null || path is! String) {
        final String message = 'Asset manifest entry is malformed. '
          'Expected asset entry to be either a string or a map '
          'containing a "$_pathKey" entry. Got ${path.runtimeType} instead.';
        return ErrorParseResult<AssetsEntry>(<String>[message]);
      }

      final Uri uri = Uri(pathSegments: path.split('/'));

      if (flavorsYaml == null) {
        return ValueParseResult<AssetsEntry>(AssetsEntry(uri: uri));
      }

      final ParseResult<List<String>> flavorsParseResult = parseList<String>(
        flavorsYaml,
        'flavors list of assets entry "$path"',
        'String',
      );

      late Set<String> flavors;
      switch (flavorsParseResult) {
        case ValueParseResult<List<String>>():
          flavors = Set<String>.from(flavorsParseResult.value);
        case ErrorParseResult<List<String>>():
          return ErrorParseResult<AssetsEntry>(flavorsParseResult.errors);
      }

      final AssetsEntry entry = AssetsEntry(
        uri: Uri(pathSegments: path.split('/')),
        flavors: flavors,
      );

      return ValueParseResult<AssetsEntry>(entry);
    }

    final String message = 'Assets entry had unexpected shape. '
      'Expected a string or an object. Got ${yaml.runtimeType} instead.';
    return ErrorParseResult<AssetsEntry>(<String>[message]);
  }

  @override
  bool operator ==(Object other) {
    if (other is! AssetsEntry) {
      return false;
    }

    return uri == other.uri && setEquals(flavors, other.flavors);
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    uri.hashCode,
    Object.hashAllUnordered(flavors),
  ]);

  @override
  String toString() => 'AssetsEntry(uri: $uri, flavors: $flavors)';
}
