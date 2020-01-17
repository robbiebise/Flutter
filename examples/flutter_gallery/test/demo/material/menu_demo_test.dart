// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_gallery/demo/material/menu_demo.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart' as prefix0;

void main() {
  testWidgets('Menu icon satisfies accessibility contrast ratio guidelines', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: const MenuDemo(),
    ));

    // await expectLater(tester, meetsGuideline(textContrastGuideline));

    final List<Element> elements = find.byIcon(Icons.more_vert).evaluate().toList();

    await expectLater(tester, meetsGuideline(CustomContrastGuideline(elements: elements)));

    /* for (final element in elements) {
      print((element.renderObject as RenderBox).localToGlobal(element.renderObject.paintBounds.topLeft));
    } */

  });
}

class CustomContrastGuideline extends AccessibilityGuideline {
  const CustomContrastGuideline({@required this.elements});

  static const double kMinimumRatio = 4.5;

  final List<Element> elements;

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    final RenderView renderView = tester.binding.renderView;
    final OffsetLayer layer = renderView.debugLayer as OffsetLayer;
    ui.Image image;
    final ByteData byteData = await tester.binding.runAsync<ByteData>(() async {
      // Needs to be the same pixel ratio otherwise our dimensions won't match the
      // last transform layer.
      image = await layer.toImage(renderView.paintBounds, pixelRatio: 1 / tester.binding.window.devicePixelRatio);
      return image.toByteData();
    });

    Evaluation evaluateElement(Element element) {
      final RenderBox renderObject = element.renderObject as RenderBox;

      final Rect paintBounds = Rect.fromPoints(
        renderObject.localToGlobal(element.renderObject.paintBounds.topLeft - const Offset(4.0, 4.0)),
        renderObject.localToGlobal(element.renderObject.paintBounds.bottomRight + const Offset(4.0, 4.0)),
      );

      if (_isNodeOffScreen(paintBounds, tester.binding.window)) {
        return const Evaluation.pass();
      }
      final List<int> subset = _subsetToRect(byteData, paintBounds, image.width, image.height);
      // Node was too far off screen.
      if (subset.isEmpty) {
        return const Evaluation.pass();
      }

      final _ContrastReport report = _ContrastReport(subset);
      final double contrastRatio = report.contrastRatio();
      const double delta = -0.01;
      if (contrastRatio - kMinimumRatio >= delta) {
        return const Evaluation.pass();
      }
      return Evaluation.fail(
          '$element:\nExpected contrast ratio of at least '
              '$kMinimumRatio but found ${contrastRatio.toStringAsFixed(2)} '
              'The computed light color was: ${report.lightColor}, '
              'The computed dark color was: ${report.darkColor}\n'
              'See also: https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html'
      );
    }

    Evaluation result = const Evaluation.pass();

    for (final Element element in elements) {
      result = result + evaluateElement(element);
    }

    return result;
  }

  // Skip routes which might have labels, and nodes without any text.
  bool _shouldSkipNode(SemanticsData data) {
    if (data.hasFlag(ui.SemanticsFlag.scopesRoute))
      return true;
    if (data.label?.trim()?.isEmpty == true && data.value?.trim()?.isEmpty == true)
      return true;
    return false;
  }

  // Returns a rect that is entirely on screen, or null if it is too far off.
  //
  // Given a pixel buffer based on the physical window size, can we actually
  // get all the data from this node? allow a small delta overlap before
  // culling the node.
  bool _isNodeOffScreen(Rect paintBounds, ui.Window window) {
    return paintBounds.top < -50.0
        || paintBounds.left <  -50.0
        || paintBounds.bottom > (window.physicalSize.height * window.devicePixelRatio) + 50.0
        || paintBounds.right > (window.physicalSize.width * window.devicePixelRatio)  + 50.0;
  }

  List<int> _subsetToRect(ByteData data, Rect paintBounds, int width, int height) {
    final int newWidth = paintBounds.size.width.ceil();
    final int newHeight = paintBounds.size.height.ceil();
    final int leftX = paintBounds.topLeft.dx.ceil();
    final int rightX = leftX + newWidth;
    final int topY = paintBounds.topLeft.dy.ceil();
    final int bottomY = topY + newHeight;
    final List<int> buffer = <int>[];

    // Data is stored in row major order.
    for (int i = 0; i < data.lengthInBytes; i+=4) {
      final int index = i ~/ 4;
      final int dx = index % width;
      final int dy = index ~/ width;
      if (dx >= leftX && dx <= rightX && dy >= topY && dy <= bottomY) {
        final int r = data.getUint8(i);
        final int g = data.getUint8(i + 1);
        final int b = data.getUint8(i + 2);
        final int a = data.getUint8(i + 3);
        final int color = (((a & 0xff) << 24) |
        ((r & 0xff) << 16) |
        ((g & 0xff) << 8)  |
        ((b & 0xff) << 0)) & 0xFFFFFFFF;
        buffer.add(color);
      }
    }
    return buffer;
  }

  @override
  String get description => 'Text contrast should follow WCAG guidelines';
}


class _ContrastReport {
  factory _ContrastReport(List<int> colors) {
    final Map<int, int> colorHistogram = <int, int>{};
    for (final int color in colors) {
      colorHistogram[color] = (colorHistogram[color] ?? 0) + 1;
    }
    if (colorHistogram.length == 1) {
      final Color hslColor = Color(colorHistogram.keys.first);
      return _ContrastReport._(hslColor, hslColor);
    }
    // to determine the lighter and darker color, partition the colors
    // by lightness and then choose the mode from each group.
    double averageLightness = 0.0;
    for (final int color in colorHistogram.keys) {
      final HSLColor hslColor = HSLColor.fromColor(Color(color));
      averageLightness += hslColor.lightness * colorHistogram[color];
    }
    averageLightness /= colors.length;
    assert(averageLightness != double.nan);
    int lightColor = 0;
    int darkColor = 0;
    int lightCount = 0;
    int darkCount = 0;
    // Find the most frequently occurring light and dark color.
    for (final MapEntry<int, int> entry in colorHistogram.entries) {
      final HSLColor color = HSLColor.fromColor(Color(entry.key));
      final int count = entry.value;
      if (color.lightness <= averageLightness && count > darkCount) {
        darkColor = entry.key;
        darkCount = count;
      } else if (color.lightness > averageLightness && count > lightCount) {
        lightColor = entry.key;
        lightCount = count;
      }
    }
    assert (lightColor != 0 && darkColor != 0);
    return _ContrastReport._(Color(lightColor), Color(darkColor));
  }

  const _ContrastReport._(this.lightColor, this.darkColor);

  final Color lightColor;
  final Color darkColor;

  /// Computes the contrast ratio as defined by the WCAG.
  ///
  /// source: https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html
  double contrastRatio() {
    return (_luminance(lightColor) + 0.05) / (_luminance(darkColor) + 0.05);
  }

  /// Relative luminance calculation.
  ///
  /// Based on https://www.w3.org/TR/2008/REC-WCAG20-20081211/#relativeluminancedef
  static double _luminance(Color color) {
    double r = color.red / 255.0;
    double g = color.green / 255.0;
    double b = color.blue / 255.0;
    if (r <= 0.03928)
      r /= 12.92;
    else
      r = math.pow((r + 0.055)/ 1.055, 2.4).toDouble();
    if (g <= 0.03928)
      g /= 12.92;
    else
      g = math.pow((g + 0.055)/ 1.055, 2.4).toDouble();
    if (b <= 0.03928)
      b /= 12.92;
    else
      b = math.pow((b + 0.055)/ 1.055, 2.4).toDouble();
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }
}
