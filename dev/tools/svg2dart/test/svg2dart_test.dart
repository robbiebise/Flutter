// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:svg2dart/svg2dart.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

const String kPackagePath = '.';

void main() {

  test('parsePixels', () {
    expect(parsePixels('23px'), 23);
    expect(parsePixels('9px'), 9);
    expect(() { parsePixels('9pt'); }, throwsA(const isInstanceOf<ArgumentError>()));
  });

  test('parsePoints', () {
    expect(parsePoints('1.0, 2.0'),
        const <Point<double>> [const Point<double>(1.0, 2.0)]
    );
    expect(parsePoints('12.0, 34.0 5.0, 6.6'),
        const <Point<double>> [
          const Point<double>(12.0, 34.0),
          const Point<double>(5.0, 6.6),
        ]
    );
  });

  group('parseSvg', () {
    test('empty SVGs', () {
      interpretSvg(testAsset('empty_svg_1_48x48.svg'));
      interpretSvg(testAsset('empty_svg_2_100x50.svg'));
    });

    test('illegal SVGs', () {
      expect(
        () { interpretSvg(testAsset('illegal_svg_multiple_roots.svg')); },
        throwsA(anything)
      );
    });

    test('SVG size', () {
      expect(
          interpretSvg(testAsset('empty_svg_1_48x48.svg')).size,
          const Point<double>(48.0, 48.0)
      );

      expect(
          interpretSvg(testAsset('empty_svg_2_100x50.svg')).size,
          const Point<double>(100.0, 50.0)
      );
    });

    test('horizontal bar', () {
      final FrameData frameData = interpretSvg(testAsset('horizontal_bar.svg'));
      expect(frameData.paths, <SvgPath>[
        const SvgPath('path_1', const<SvgPathCommand> [
          const SvgPathCommand('M', const <Point<double>> [const Point<double>(0.0, 19.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(48.0, 19.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(48.0, 29.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(0.0, 29.0)]),
          const SvgPathCommand('Z', const <Point<double>> []),
        ]),
      ]);
    });

    test('SVG group', () {
      final FrameData frameData = interpretSvg(testAsset('bars_group.svg'));
      expect(frameData.paths, const <SvgPath> [
        const SvgPath('path_1', const<SvgPathCommand> [
          const SvgPathCommand('M', const <Point<double>> [const Point<double>(0.0, 19.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(48.0, 19.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(48.0, 29.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(0.0, 29.0)]),
          const SvgPathCommand('Z', const <Point<double>> []),
        ]),
        const SvgPath('path_2', const<SvgPathCommand> [
          const SvgPathCommand('M', const <Point<double>> [const Point<double>(0.0, 34.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(48.0, 34.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(48.0, 44.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(0.0, 44.0)]),
          const SvgPathCommand('Z', const <Point<double>> []),
        ]),
      ]);
    });

    test('SVG group translate', () {
      final FrameData frameData = interpretSvg(testAsset('bar_group_translate.svg'));
      expect(frameData.paths, const <SvgPath> [
        const SvgPath('path_1', const<SvgPathCommand> [
          const SvgPathCommand('M', const <Point<double>> [const Point<double>(0.0, 34.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(48.0, 34.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(48.0, 44.0)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(0.0, 44.0)]),
          const SvgPathCommand('Z', const <Point<double>> []),
        ]),
      ]);
    });

    test('SVG group scale', () {
      final FrameData frameData = interpretSvg(testAsset('bar_group_scale.svg'));
      expect(frameData.paths, const <SvgPath> [
        const SvgPath(
            'path_1', const<SvgPathCommand> [
          const SvgPathCommand('M', const <Point<double>> [const Point<double>(0.0, 9.5)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(24.0, 9.5)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(24.0, 14.5)]),
          const SvgPathCommand('L', const <Point<double>> [const Point<double>(0.0, 14.5)]),
          const SvgPathCommand('Z', const <Point<double>> []),
        ]),
      ]);
    });

    test('SVG group rotate scale', () {
      final FrameData frameData = interpretSvg(testAsset('bar_group_rotate_scale.svg'));
      expect(frameData.paths, const <PathMatcher> [
        const PathMatcher(
            const SvgPath(
                'path_1', const<SvgPathCommand> [
              const SvgPathCommand('L', const <Point<double>> [const Point<double>(29.0, 0.0)]),
              const SvgPathCommand('L', const <Point<double>> [const Point<double>(29.0, 48.0)]),
              const SvgPathCommand('L', const <Point<double>> [const Point<double>(19.0, 48.0)]),
              const SvgPathCommand('M', const <Point<double>> [const Point<double>(19.0, 0.0)]),
              const SvgPathCommand('Z', const <Point<double>> []),
            ]),
            margin: 0.000000001
        )
      ]);
    });

    test('SVG group opacity', () {
      final FrameData frameData = interpretSvg(testAsset('bar_group_opacity.svg'));
      expect(frameData.paths, const <SvgPath> [
        const SvgPath(
          'path_1',
          const<SvgPathCommand> [
            const SvgPathCommand('M', const <Point<double>> [const Point<double>(0.0, 19.0)]),
            const SvgPathCommand('L', const <Point<double>> [const Point<double>(48.0, 19.0)]),
            const SvgPathCommand('L', const <Point<double>> [const Point<double>(48.0, 29.0)]),
            const SvgPathCommand('L', const <Point<double>> [const Point<double>(0.0, 29.0)]),
            const SvgPathCommand('Z', const <Point<double>> []),
          ],
          opacity: 0.5,
        ),
      ]);
    });
  });
}

// Matches all path commands' points within an error margin.
class PathMatcher extends Matcher {
  const PathMatcher(this.actual, {this.margin = 0.0});

  final SvgPath actual;
  final double margin;

  @override
  Description describe(Description description) => description.add('$actual (±$margin)');

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item == null || actual == null)
      return item == actual;

    if (item.runtimeType != actual.runtimeType)
      return false;

    final SvgPath other = item;
    if (other.id != actual.id || other.opacity != actual.opacity)
      return false;

    if (other.commands.length != actual.commands.length)
      return false;

    for (int i = 0; i < other.commands.length; i += 1) {
      if (!commandsMatch(actual.commands[i], other.commands[i]))
        return false;
    }
    return true;
  }

  bool commandsMatch(SvgPathCommand actual, SvgPathCommand other) {
    if (other.points.length != actual.points.length)
      return false;

    for (int i = 0; i < other.points.length; i += 1) {
      if ((other.points[i].x - actual.points[i].x).abs() > margin)
        return false;
      if ((other.points[i].y - actual.points[i].y).abs() > margin)
        return false;
    }
    return true;
  }
}

String testAsset(String name) {
  return path.join(kPackagePath, 'test_assets', name);
}

