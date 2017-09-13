// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' as ui show Image, Gradient, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'basic_types.dart';
import 'border.dart';
import 'border_radius.dart';
import 'box_fit.dart';
import 'decoration.dart';
import 'edge_insets.dart';
import 'fractional_offset.dart';

export 'edge_insets.dart' show EdgeInsets;

/// A shadow cast by a box.
///
/// BoxShadow can cast non-rectangular shadows if the box is non-rectangular
/// (e.g., has a border radius or a circular shape).
///
/// This class is similar to CSS box-shadow.
@immutable
class BoxShadow {
  /// Creates a box shadow.
  ///
  /// By default, the shadow is solid black with zero [offset], [blurRadius],
  /// and [spreadRadius].
  const BoxShadow({
    this.color: const Color(0xFF000000),
    this.offset: Offset.zero,
    this.blurRadius: 0.0,
    this.spreadRadius: 0.0
  });

  /// The color of the shadow.
  final Color color;

  /// The displacement of the shadow from the box.
  final Offset offset;

  /// The standard deviation of the Gaussian to convolve with the box's shape.
  final double blurRadius;

  /// The amount the box should be inflated prior to applying the blur.
  final double spreadRadius;

  /// Converts a blur radius in pixels to sigmas.
  ///
  /// See the sigma argument to [MaskFilter.blur].
  //
  // See SkBlurMask::ConvertRadiusToSigma().
  // <https://github.com/google/skia/blob/bb5b77db51d2e149ee66db284903572a5aac09be/src/effects/SkBlurMask.cpp#L23>
  static double convertRadiusToSigma(double radius) {
    return radius * 0.57735 + 0.5;
  }

  /// The [blurRadius] in sigmas instead of logical pixels.
  ///
  /// See the sigma argument to [MaskFilter.blur].
  double get blurSigma => convertRadiusToSigma(blurRadius);

  /// Returns a new box shadow with its offset, blurRadius, and spreadRadius scaled by the given factor.
  BoxShadow scale(double factor) {
    return new BoxShadow(
      color: color,
      offset: offset * factor,
      blurRadius: blurRadius * factor,
      spreadRadius: spreadRadius * factor
    );
  }

  /// Linearly interpolate between two box shadows.
  ///
  /// If either box shadow is null, this function linearly interpolates from a
  /// a box shadow that matches the other box shadow in color but has a zero
  /// offset and a zero blurRadius.
  static BoxShadow lerp(BoxShadow a, BoxShadow b, double t) {
    if (a == null && b == null)
      return null;
    if (a == null)
      return b.scale(t);
    if (b == null)
      return a.scale(1.0 - t);
    return new BoxShadow(
      color: Color.lerp(a.color, b.color, t),
      offset: Offset.lerp(a.offset, b.offset, t),
      blurRadius: ui.lerpDouble(a.blurRadius, b.blurRadius, t),
      spreadRadius: ui.lerpDouble(a.spreadRadius, b.spreadRadius, t)
    );
  }

  /// Linearly interpolate between two lists of box shadows.
  ///
  /// If the lists differ in length, excess items are lerped with null.
  static List<BoxShadow> lerpList(List<BoxShadow> a, List<BoxShadow> b, double t) {
    if (a == null && b == null)
      return null;
    a ??= <BoxShadow>[];
    b ??= <BoxShadow>[];
    final List<BoxShadow> result = <BoxShadow>[];
    final int commonLength = math.min(a.length, b.length);
    for (int i = 0; i < commonLength; ++i)
      result.add(BoxShadow.lerp(a[i], b[i], t));
    for (int i = commonLength; i < a.length; ++i)
      result.add(a[i].scale(1.0 - t));
    for (int i = commonLength; i < b.length; ++i)
      result.add(b[i].scale(t));
    return result;
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other))
      return true;
    if (runtimeType != other.runtimeType)
      return false;
    final BoxShadow typedOther = other;
    return color == typedOther.color &&
           offset == typedOther.offset &&
           blurRadius == typedOther.blurRadius &&
           spreadRadius == typedOther.spreadRadius;
  }

  @override
  int get hashCode => hashValues(color, offset, blurRadius, spreadRadius);

  @override
  String toString() => 'BoxShadow($color, $offset, $blurRadius, $spreadRadius)';
}

/// A 2D gradient.
///
/// This is an interface that allows [LinearGradient] and [RadialGradient]
/// classes to be used interchangeably in [BoxDecoration]s.
@immutable
abstract class Gradient {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const Gradient();

  /// Creates a [Shader] for this gradient to fill the given rect.
  Shader createShader(Rect rect);
}

/// A 2D linear gradient.
///
/// This class is used by [BoxDecoration] to represent gradients. This abstracts
/// out the arguments to the [new ui.Gradient.linear] constructor from the
/// `dart:ui` library.
///
/// A gradient has two anchor points, [begin] and [end]. The [begin] point
/// corresponds to 0.0, and the [end] point corresponds to 1.0. These points are
/// expressed in fractions, so that the same gradient can be reused with varying
/// sized boxes without changing the parameters. (This contrasts with [new
/// ui.Gradient.linear], whose arguments are expressed in logical pixels.)
///
/// The [colors] are described by a list of [Color] objects. There must be at
/// least two colors. If there are more than two, a [stops] list must be
/// provided. It must have the same length as [colors], and specifies the
/// position of each color stop between 0.0 and 1.0.
///
/// The region of the canvas before [begin] and after [end] is colored according
/// to [tileMode].
///
/// Typically this class is used with [BoxDecoration], which does the painting.
/// To use a [LinearGradient] to paint on a canvas directly, see [createShader].
///
/// ## Sample code
///
/// This sample draws a picture that looks like vertical window shades by having
/// a [Container] display a [BoxDecoration] with a [LinearGradient].
///
/// ```dart
/// new Container(
///   decoration: new BoxDecoration(
///     gradient: new LinearGradient(
///       begin: FractionalOffset.topLeft,
///       end: new FractionalOffset(0.1, 0.0), // 10% of the width, so there are ten blinds.
///       colors: [const Color(0xFFFFFFEE), const Color(0xFF999999)], // whitish to gray
///       tileMode: TileMode.repeated, // repeats the gradient over the canvas
///     ),
///   ),
/// )
/// ```
///
/// See also:
///
///  * [RadialGradient], which displays a gradient in concentric circles, and
///    has an example which shows a different way to use [Gradient] objects.
///  * [BoxDecoration], which can take a [LinearGradient] in its
///    [BoxDecoration.gradient] property.
class LinearGradient extends Gradient {
  /// Creates a linear graident.
  ///
  /// The [colors] argument must not be null. If [stops] is non-null, it must
  /// have the same length as [colors].
  const LinearGradient({
    this.begin: FractionalOffset.centerLeft,
    this.end: FractionalOffset.centerRight,
    @required this.colors,
    this.stops,
    this.tileMode: TileMode.clamp,
  }) : assert(begin != null),
       assert(end != null),
       assert(colors != null),
       assert(tileMode != null);

  /// The offset from coordinate (0.0,0.0) at which stop 0.0 of the
  /// gradient is placed, in a coordinate space that maps the top left
  /// of the paint box at (0.0,0.0) and the bottom right at (1.0,1.0).
  ///
  /// For example, a begin offset of (0.0,0.5) is half way down the
  /// left side of the box.
  final FractionalOffset begin;

  /// The offset from coordinate (0.0,0.0) at which stop 1.0 of the
  /// gradient is placed, in a coordinate space that maps the top left
  /// of the paint box at (0.0,0.0) and the bottom right at (1.0,1.0).
  ///
  /// For example, an end offset of (1.0,0.5) is half way down the
  /// right side of the box.
  final FractionalOffset end;

  /// The colors the gradient should obtain at each of the stops.
  ///
  /// If [stops] is non-null, this list must have the same length as [stops]. If
  /// [colors] has more than two colors, [stops] must be non-null.
  ///
  /// This list must have at least two colors in it (otherwise, it's not a
  /// gradient!).
  final List<Color> colors;

  /// A list of values from 0.0 to 1.0 that denote fractions of the vector from
  /// start to end.
  ///
  /// If non-null, this list must have the same length as [colors]. If
  /// [colors] has more than two colors, [stops] must be non-null.
  ///
  /// If the first value is not 0.0, then a stop with position 0.0 and a color
  /// equal to the first color in [colors] is implied.
  ///
  /// If the last value is not 1.0, then a stop with position 1.0 and a color
  /// equal to the last color in [colors] is implied.
  ///
  /// The values in the [stops] list must be in ascending order. If a value in
  /// the [stops] list is less than an earlier value in the list, then its value
  /// is assumed to equal the previous value.
  final List<double> stops;

  /// How this gradient should tile the plane beyond in the region before
  /// [begin] and after [end].
  ///
  /// For details, see [TileMode].
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/dart-ui/tile_mode_clamp_linear.png)
  /// ![](https://flutter.github.io/assets-for-api-docs/dart-ui/tile_mode_mirror_linear.png)
  /// ![](https://flutter.github.io/assets-for-api-docs/dart-ui/tile_mode_repeated_linear.png)
  final TileMode tileMode;

  @override
  Shader createShader(Rect rect) {
    return new ui.Gradient.linear(
      begin.withinRect(rect),
      end.withinRect(rect),
      colors, stops, tileMode,
    );
  }

  /// Returns a new [LinearGradient] with its properties scaled by the given
  /// factor.
  LinearGradient scale(double factor) {
    return new LinearGradient(
      begin: begin,
      end: end,
      colors: colors.map<Color>((Color color) => Color.lerp(null, color, factor)).toList(),
      stops: stops,
      tileMode: tileMode,
    );
  }

  /// Linearly interpolate between two [LinearGradient]s.
  ///
  /// If either gradient is null, this function linearly interpolates from a
  /// a gradient that matches the other gradient in [begin], [end], [stops] and
  /// [tileMode] and with the same [colors] but transparent.
  ///
  /// If neither gradient is null, they must have the same number of [colors].
  static LinearGradient lerp(LinearGradient a, LinearGradient b, double t) {
    if (a == null && b == null)
      return null;
    if (a == null)
      return b.scale(t);
    if (b == null)
      return a.scale(1.0 - t);
    // Interpolation is only possible when the lengths of colors and stops are
    // the same or stops is null for one.
    // TODO(xster): lerp unsimilar LinearGradients in the future by scaling
    // lists of LinearGradients.
    assert(a.colors.length == b.colors.length);
    assert(a.stops == null || b.stops == null || a.stops.length == b.stops.length);
    final List<Color> interpolatedColors = <Color>[];
    for (int i = 0; i < a.colors.length; i += 1)
      interpolatedColors.add(Color.lerp(a.colors[i], b.colors[i], t));
    List<double> interpolatedStops;
    if (a.stops != null && b.stops != null) {
      for (int i = 0; i < a.stops.length; i += 1)
        interpolatedStops.add(ui.lerpDouble(a.stops[i], b.stops[i], t));
    } else {
      interpolatedStops = a.stops ?? b.stops;
    }
    return new LinearGradient(
      begin: FractionalOffset.lerp(a.begin, b.begin, t),
      end: FractionalOffset.lerp(a.end, b.end, t),
      colors: interpolatedColors,
      stops: interpolatedStops,
      tileMode: t < 0.5 ? a.tileMode : b.tileMode,
    );
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other))
      return true;
    if (runtimeType != other.runtimeType)
      return false;
    final LinearGradient typedOther = other;
    if (begin != typedOther.begin ||
        end != typedOther.end ||
        tileMode != typedOther.tileMode ||
        colors?.length != typedOther.colors?.length ||
        stops?.length != typedOther.stops?.length)
      return false;
    if (colors != null) {
      assert(typedOther.colors != null);
      assert(colors.length == typedOther.colors.length);
      for (int i = 0; i < colors.length; i += 1) {
        if (colors[i] != typedOther.colors[i])
          return false;
      }
    }
    if (stops != null) {
      assert(typedOther.stops != null);
      assert(stops.length == typedOther.stops.length);
      for (int i = 0; i < stops.length; i += 1) {
        if (stops[i] != typedOther.stops[i])
          return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => hashValues(begin, end, tileMode, hashList(colors), hashList(stops));

  @override
  String toString() {
    return 'LinearGradient($begin, $end, $colors, $stops, $tileMode)';
  }
}

/// A 2D radial gradient.
///
/// This class is used by [BoxDecoration] to represent gradients. This abstracts
/// out the arguments to the [new ui.Gradient.radial] constructor from the
/// `dart:ui` library.
///
/// A gradient has a [center] and a [radius]. The [center] point corresponds to
/// 0.0, and the ring at [radius] from the center corresponds to 1.0. These
/// lengths are expressed in fractions, so that the same gradient can be reused
/// with varying sized boxes without changing the parameters. (This contrasts
/// with [new ui.Gradient.radial], whose arguments are expressed in logical
/// pixels.)
///
/// The [colors] are described by a list of [Color] objects. There must be at
/// least two colors. If there are more than two, a [stops] list must be
/// provided. It must have the same length as [colors], and specifies the
/// position of each color stop between 0.0 and 1.0.
///
/// The region of the canvas beyond [radius] from the [center] is colored
/// according to [tileMode].
///
/// Typically this class is used with [BoxDecoration], which does the painting.
/// To use a [RadialGradient] to paint on a canvas directly, see [createShader].
///
/// ## Sample code
///
/// This function draws a gradient that looks like a sun in a blue sky.
///
/// ```dart
/// void paintSky(Canvas canvas, Rect rect) {
///   var gradient = new RadialGradient(
///     center: const FractionalOffset(0.7, 0.2), // near the top right
///     radius: 0.2,
///     colors: [
///       const Color(0xFFFFFF00), // yellow sun
///       const Color(0xFF0099FF), // blue sky
///     ],
///     stops: [0.4, 1.0],
///   );
///   // rect is the area we are painting over
///   var paint = new Paint()
///     ..shader = gradient.createShader(rect);
///   canvas.drawRect(rect, paint);
/// }
/// ```
///
/// See also:
///
///  * [LinearGradient], which displays a gradient in parallel lines, and has an
///    example which shows a different way to use [Gradient] objects.
///  * [BoxDecoration], which can take a [RadialGradient] in its
///    [BoxDecoration.gradient] property.
///  * [CustomPainter], which shows how to use the above sample code in a custom
///    painter.
class RadialGradient extends Gradient {
  /// Creates a radial gradient.
  ///
  /// The [colors] argument must not be null. If [stops] is non-null, it must
  /// have the same length as [colors].
  const RadialGradient({
    this.center: FractionalOffset.center,
    this.radius: 0.5,
    @required this.colors,
    this.stops,
    this.tileMode: TileMode.clamp,
  }) : assert(center != null),
       assert(radius != null),
       assert(colors != null),
       assert(tileMode != null);

  /// The center of the gradient, as an offset into the unit square
  /// describing the gradient which will be mapped onto the paint box.
  ///
  /// For example, an offset of (0.5,0.5) will place the radial
  /// gradient in the center of the box.
  final FractionalOffset center;

  /// The radius of the gradient, as a fraction of the shortest side
  /// of the paint box.
  ///
  /// For example, if a radial gradient is painted on a box that is
  /// 100.0 pixels wide and 200.0 pixels tall, then a radius of 1.0
  /// will place the 1.0 stop at 100.0 pixels from the [center].
  final double radius;

  /// The colors the gradient should obtain at each of the stops.
  ///
  /// If [stops] is non-null, this list must have the same length as [stops]. If
  /// [colors] has more than two colors, [stops] must be non-null.
  ///
  /// This list must have at least two colors in it (otherwise, it's not a
  /// gradient!).
  final List<Color> colors;

  /// A list of values from 0.0 to 1.0 that denote concentric rings.
  ///
  /// The rings are centered at [center] and have a radius equal to the value of
  /// the stop times [radius].
  ///
  /// If non-null, this list must have the same length as [colors]. If
  /// [colors] has more than two colors, [stops] must be non-null.
  ///
  /// If the first value is not 0.0, then a stop with position 0.0 and a color
  /// equal to the first color in [colors] is implied.
  ///
  /// If the last value is not 1.0, then a stop with position 1.0 and a color
  /// equal to the last color in [colors] is implied.
  ///
  /// The values in the [stops] list must be in ascending order. If a value in
  /// the [stops] list is less than an earlier value in the list, then its value
  /// is assumed to equal the previous value.
  final List<double> stops;

  /// How this gradient should tile the plane beyond the outer ring at [radius]
  /// pixels from the [center].
  ///
  /// For details, see [TileMode].
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/dart-ui/tile_mode_clamp_radial.png)
  /// ![](https://flutter.github.io/assets-for-api-docs/dart-ui/tile_mode_mirror_radial.png)
  /// ![](https://flutter.github.io/assets-for-api-docs/dart-ui/tile_mode_repeated_radial.png)
  final TileMode tileMode;

  @override
  Shader createShader(Rect rect) {
    return new ui.Gradient.radial(
      center.withinRect(rect),
      radius * rect.shortestSide,
      colors, stops, tileMode
    );
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other))
      return true;
    if (runtimeType != other.runtimeType)
      return false;
    final RadialGradient typedOther = other;
    if (center != typedOther.center ||
        radius != typedOther.radius ||
        tileMode != typedOther.tileMode ||
        colors?.length != typedOther.colors?.length ||
        stops?.length != typedOther.stops?.length)
      return false;
    if (colors != null) {
      assert(typedOther.colors != null);
      assert(colors.length == typedOther.colors.length);
      for (int i = 0; i < colors.length; i += 1) {
        if (colors[i] != typedOther.colors[i])
          return false;
      }
    }
    if (stops != null) {
      assert(typedOther.stops != null);
      assert(stops.length == typedOther.stops.length);
      for (int i = 0; i < stops.length; i += 1) {
        if (stops[i] != typedOther.stops[i])
          return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => hashValues(center, radius, tileMode, hashList(colors), hashList(stops));

  @override
  String toString() {
    return 'RadialGradient($center, $radius, $colors, $stops, $tileMode)';
  }
}

/// How to paint any portions of a box not covered by an image.
enum ImageRepeat {
  /// Repeat the image in both the x and y directions until the box is filled.
  repeat,

  /// Repeat the image in the x direction until the box is filled horizontally.
  repeatX,

  /// Repeat the image in the y direction until the box is filled vertically.
  repeatY,

  /// Leave uncovered poritions of the box transparent.
  noRepeat
}

Iterable<Rect> _generateImageTileRects(Rect outputRect, Rect fundamentalRect, ImageRepeat repeat) sync* {
  if (repeat == ImageRepeat.noRepeat) {
    yield fundamentalRect;
    return;
  }

  int startX = 0;
  int startY = 0;
  int stopX = 0;
  int stopY = 0;
  final double strideX = fundamentalRect.width;
  final double strideY = fundamentalRect.height;

  if (repeat == ImageRepeat.repeat || repeat == ImageRepeat.repeatX) {
    startX = ((outputRect.left - fundamentalRect.left) / strideX).floor();
    stopX = ((outputRect.right - fundamentalRect.right) / strideX).ceil();
  }

  if (repeat == ImageRepeat.repeat || repeat == ImageRepeat.repeatY) {
    startY = ((outputRect.top - fundamentalRect.top) / strideY).floor();
    stopY = ((outputRect.bottom - fundamentalRect.bottom) / strideY).ceil();
  }

  for (int i = startX; i <= stopX; ++i) {
    for (int j = startY; j <= stopY; ++j)
      yield fundamentalRect.shift(new Offset(i * strideX, j * strideY));
  }
}

/// Paints an image into the given rectangle in the canvas.
///
///  * `canvas`: The canvas onto which the image will be painted.
///  * `rect`: The region of the canvas into which the image will be painted.
///    The image might not fill the entire rectangle (e.g., depending on the
///    `fit`). If `rect` is empty, nothing is painted.
///  * `image`: The image to paint onto the canvas.
///  * `colorFilter`: If non-null, the color filter to apply when painting the
///    image.
///  * `fit`: How the image should be inscribed into `rect`. If null, the
///    default behavior depends on `centerSlice`. If `centerSlice` is also null,
///    the default behavior is [BoxFit.scaleDown]. If `centerSlice` is
///    non-null, the default behavior is [BoxFit.fill]. See [BoxFit] for
///    details.
///  * `repeat`: If the image does not fill `rect`, whether and how the image
///    should be repeated to fill `rect`. By default, the image is not repeated.
///    See [ImageRepeat] for details.
///  * `centerSlice`: The image is drawn in nine portions described by splitting
///    the image by drawing two horizontal lines and two vertical lines, where
///    `centerSlice` describes the rectangle formed by the four points where
///    these four lines intersect each other. (This forms a 3-by-3 grid
///    of regions, the center region being described by `centerSlice`.)
///    The four regions in the corners are drawn, without scaling, in the four
///    corners of the destination rectangle defined by applying `fit`. The
///    remaining five regions are drawn by stretching them to fit such that they
///    exactly cover the destination rectangle while maintaining their relative
///    positions.
///  * `alignment`: How the destination rectangle defined by applying `fit` is
///    aligned within `rect`. For example, if `fit` is [BoxFit.contain] and
///    `alignment` is [FractionalOffset.bottomRight], the image will be as large
///    as possible within `rect` and placed with its bottom right corner at the
///    bottom right corner of `rect`.
void paintImage({
  @required Canvas canvas,
  @required Rect rect,
  @required ui.Image image,
  ColorFilter colorFilter,
  BoxFit fit,
  FractionalOffset alignment,
  Rect centerSlice,
  ImageRepeat repeat: ImageRepeat.noRepeat,
}) {
  assert(canvas != null);
  assert(image != null);
  if (rect.isEmpty)
    return;
  Size outputSize = rect.size;
  Size inputSize = new Size(image.width.toDouble(), image.height.toDouble());
  Offset sliceBorder;
  if (centerSlice != null) {
    sliceBorder = new Offset(
      centerSlice.left + inputSize.width - centerSlice.right,
      centerSlice.top + inputSize.height - centerSlice.bottom
    );
    outputSize -= sliceBorder;
    inputSize -= sliceBorder;
  }
  fit ??= centerSlice == null ? BoxFit.scaleDown : BoxFit.fill;
  assert(centerSlice == null || (fit != BoxFit.none && fit != BoxFit.cover));
  final FittedSizes fittedSizes = applyBoxFit(fit, inputSize, outputSize);
  final Size sourceSize = fittedSizes.source;
  Size destinationSize = fittedSizes.destination;
  if (centerSlice != null) {
    outputSize += sliceBorder;
    destinationSize += sliceBorder;
    // We don't have the ability to draw a subset of the image at the same time
    // as we apply a nine-patch stretch.
    assert(sourceSize == inputSize, 'centerSlice was used with a BoxFit that does not guarantee that the image is fully visible.');
  }
  if (repeat != ImageRepeat.noRepeat && destinationSize == outputSize) {
    // There's no need to repeat the image because we're exactly filling the
    // output rect with the image.
    repeat = ImageRepeat.noRepeat;
  }
  final Paint paint = new Paint()..isAntiAlias = false;
  if (colorFilter != null)
    paint.colorFilter = colorFilter;
  if (sourceSize != destinationSize) {
    // Use the "low" quality setting to scale the image, which corresponds to
    // bilinear interpolation, rather than the default "none" which corresponds
    // to nearest-neighbor.
    paint.filterQuality = FilterQuality.low;
  }
  final double dx = (outputSize.width - destinationSize.width) * (alignment?.dx ?? 0.5);
  final double dy = (outputSize.height - destinationSize.height) * (alignment?.dy ?? 0.5);
  final Offset destinationPosition = rect.topLeft.translate(dx, dy);
  final Rect destinationRect = destinationPosition & destinationSize;
  if (repeat != ImageRepeat.noRepeat) {
    canvas.save();
    canvas.clipRect(rect);
  }
  if (centerSlice == null) {
    final Rect sourceRect = (alignment ?? FractionalOffset.center).inscribe(
      fittedSizes.source, Offset.zero & inputSize
    );
    for (Rect tileRect in _generateImageTileRects(rect, destinationRect, repeat))
      canvas.drawImageRect(image, sourceRect, tileRect, paint);
  } else {
    for (Rect tileRect in _generateImageTileRects(rect, destinationRect, repeat))
      canvas.drawImageNine(image, centerSlice, tileRect, paint);
  }
  if (repeat != ImageRepeat.noRepeat)
    canvas.restore();
}

/// An image for a box decoration.
///
/// The image is painted using [paintImage], which describes the meanings of the
/// various fields on this class in more detail.
@immutable
class DecorationImage {
  /// Creates an image to show in a [BoxDecoration].
  ///
  /// The [image] argument must not be null.
  const DecorationImage({
    @required this.image,
    this.colorFilter,
    this.fit,
    this.alignment,
    this.centerSlice,
    this.repeat: ImageRepeat.noRepeat,
  }) : assert(image != null);

  /// The image to be painted into the decoration.
  ///
  /// Typically this will be an [AssetImage] (for an image shipped with the
  /// application) or a [NetworkImage] (for an image obtained from the network).
  final ImageProvider image;

  /// A color filter to apply to the image before painting it.
  final ColorFilter colorFilter;

  /// How the image should be inscribed into the box.
  ///
  /// The default is [BoxFit.scaleDown] if [centerSlice] is null, and
  /// [BoxFit.fill] if [centerSlice] is not null.
  ///
  /// See the discussion at [paintImage] for more details.
  final BoxFit fit;

  /// How to align the image within its bounds.
  ///
  /// An alignment of (0.0, 0.0) aligns the image to the top-left corner of its
  /// layout bounds.  An alignment of (1.0, 0.5) aligns the image to the middle
  /// of the right edge of its layout bounds.
  ///
  /// Defaults to [FractionalOffset.center].
  final FractionalOffset alignment;

  /// The center slice for a nine-patch image.
  ///
  /// The region of the image inside the center slice will be stretched both
  /// horizontally and vertically to fit the image into its destination. The
  /// region of the image above and below the center slice will be stretched
  /// only horizontally and the region of the image to the left and right of
  /// the center slice will be stretched only vertically.
  ///
  /// The stretching will be applied in order to make the image fit into the box
  /// specified by [fit]. When [centerSlice] is not null, [fit] defaults to
  /// [BoxFit.fill], which distorts the destination image size relative to the
  /// image's original aspect ratio. Values of [BoxFit] which do not distort the
  /// destination image size will result in [centerSlice] having no effect
  /// (since the nine regions of the image will be rendered with the same
  /// scaling, as if it wasn't specified).
  final Rect centerSlice;

  /// How to paint any portions of the box that would not otherwise be covered
  /// by the image.
  final ImageRepeat repeat;

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other))
      return true;
    if (runtimeType != other.runtimeType)
      return false;
    final DecorationImage typedOther = other;
    return image == typedOther.image
        && colorFilter == typedOther.colorFilter
        && fit == typedOther.fit
        && alignment == typedOther.alignment
        && centerSlice == typedOther.centerSlice
        && repeat == typedOther.repeat;
  }

  @override
  int get hashCode => hashValues(image, colorFilter, fit, alignment, centerSlice, repeat);

  @override
  String toString() {
    final List<String> properties = <String>[];
    properties.add('$image');
    if (colorFilter != null)
      properties.add('$colorFilter');
    if (fit != null &&
        !(fit == BoxFit.fill && centerSlice != null) &&
        !(fit == BoxFit.scaleDown && centerSlice == null))
      properties.add('$fit');
    if (alignment != null)
      properties.add('$alignment');
    if (centerSlice != null)
      properties.add('centerSlice: $centerSlice');
    if (repeat != ImageRepeat.noRepeat)
      properties.add('$repeat');
    return '$runtimeType(${properties.join(", ")})';
  }
}

/// An immutable description of how to paint a box.
///
/// The [BoxDecoration] class provides a variety of ways to draw a box.
///
/// The box has a [border], a body, and may cast a [boxShadow].
///
/// The [shape] of the box can be a circle or a rectangle. If it is a rectangle,
/// then the [borderRadius] property controls the roundness of the corners.
///
/// The body of the box is painted in layers. The bottom-most layer is the
/// [color], which fills the box. Above that is the [gradient], which also fills
/// the box. Finally there is the [image], the precise alignment of which is
/// controlled by the [DecorationImage] class.
///
/// The [border] paints over the body; the [boxShadow], naturally, paints below it.
///
/// ## Sample code
///
/// The following example uses the [Container] widget from the widgets layer to
/// draw an image with a border:
///
/// ```dart
/// new Container(
///   decoration: new BoxDecoration(
///     color: const Color(0xff7c94b6),
///     image: new DecorationImage(
///       image: new ExactAssetImage('images/flowers.jpeg'),
///       fit: BoxFit.cover,
///     ),
///     border: new Border.all(
///       color: Colors.black,
///       width: 8.0,
///     ),
///   ),
/// )
/// ```
///
/// See also:
///
///  * [DecoratedBox] and [Container], widgets that can be configured with
///    [BoxDecoration] objects.
///  * [CustomPaint], a widget that lets you draw arbitrary graphics.
///  * [Decoration], the base class which lets you define other decorations.
class BoxDecoration extends Decoration {
  /// Creates a box decoration.
  ///
  /// * If [color] is null, this decoration does not paint a background color.
  /// * If [image] is null, this decoration does not paint a background image.
  /// * If [border] is null, this decoration does not paint a border.
  /// * If [borderRadius] is null, this decoration uses more efficient background
  ///   painting commands. The [borderRadius] argument must be be null if [shape] is
  ///   [BoxShape.circle].
  /// * If [boxShadow] is null, this decoration does not paint a shadow.
  /// * If [gradient] is null, this decoration does not paint gradients.
  const BoxDecoration({
    this.color,
    this.image,
    this.border,
    this.borderRadius,
    this.boxShadow,
    this.gradient,
    this.shape: BoxShape.rectangle,
  });

  @override
  bool debugAssertIsValid() {
    assert(shape != BoxShape.circle ||
           borderRadius == null); // Can't have a border radius if you're a circle.
    return super.debugAssertIsValid();
  }

  /// The color to fill in the background of the box.
  ///
  /// The color is filled into the shape of the box (e.g., either a rectangle,
  /// potentially with a border radius, or a circle).
  final Color color;

  /// An image to paint above the background color. If [shape] is [BoxShape.circle]
  /// then the image is clipped to the circle's boundary.
  final DecorationImage image;

  /// A border to draw above the background [color] or [image].
  final Border border;

  /// If non-null, the corners of this box are rounded by this [BorderRadius].
  ///
  /// Applies only to boxes with rectangular shapes.
  final BorderRadius borderRadius;

  /// A list of shadows cast by this box behind the box.
  ///
  /// The shadow follows the [shape] of the box.
  final List<BoxShadow> boxShadow;

  /// A gradient to use when filling the box.
  final Gradient gradient;

  /// The shape to fill the background [color] into and to cast as the [boxShadow].
  final BoxShape shape;

  /// The inset space occupied by the border.
  @override
  EdgeInsets get padding => border?.dimensions;

  /// Returns a new box decoration that is scaled by the given factor.
  BoxDecoration scale(double factor) {
    // TODO(abarth): Scale ALL the things.
    return new BoxDecoration(
      color: Color.lerp(null, color, factor),
      image: image,
      border: Border.lerp(null, border, factor),
      borderRadius: BorderRadius.lerp(null, borderRadius, factor),
      boxShadow: BoxShadow.lerpList(null, boxShadow, factor),
      gradient: gradient,
      shape: shape,
    );
  }

  @override
  bool get isComplex => boxShadow != null;

  /// Linearly interpolate between two box decorations.
  ///
  /// Interpolates each parameter of the box decoration separately.
  ///
  /// See also [Decoration.lerp].
  static BoxDecoration lerp(BoxDecoration a, BoxDecoration b, double t) {
    if (a == null && b == null)
      return null;
    if (a == null)
      return b.scale(t);
    if (b == null)
      return a.scale(1.0 - t);
    // TODO(abarth): lerp ALL the fields.
    return new BoxDecoration(
      color: Color.lerp(a.color, b.color, t),
      image: b.image,
      border: Border.lerp(a.border, b.border, t),
      borderRadius: BorderRadius.lerp(a.borderRadius, b.borderRadius, t),
      boxShadow: BoxShadow.lerpList(a.boxShadow, b.boxShadow, t),
      gradient: b.gradient,
      shape: b.shape,
    );
  }

  @override
  BoxDecoration lerpFrom(Decoration a, double t) {
    if (a is! BoxDecoration)
      return BoxDecoration.lerp(null, this, t);
    return BoxDecoration.lerp(a, this, t);
  }

  @override
  BoxDecoration lerpTo(Decoration b, double t) {
    if (b is! BoxDecoration)
      return BoxDecoration.lerp(this, null, t);
    return BoxDecoration.lerp(this, b, t);
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other))
      return true;
    if (runtimeType != other.runtimeType)
      return false;
    final BoxDecoration typedOther = other;
    return color == typedOther.color &&
           image == typedOther.image &&
           border == typedOther.border &&
           borderRadius == typedOther.borderRadius &&
           boxShadow == typedOther.boxShadow &&
           gradient == typedOther.gradient &&
           shape == typedOther.shape;
  }

  @override
  int get hashCode {
    return hashValues(
      color,
      image,
      border,
      borderRadius,
      boxShadow,
      gradient,
      shape,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..defaultDiagnosticsTreeStyle = DiagnosticsTreeStyle.whitespace
      ..emptyBodyDescription = '<no decorations specified>';

    properties.add(new DiagnosticsProperty<Color>('color', color, defaultValue: null));
    properties.add(new DiagnosticsProperty<DecorationImage>('image', image, defaultValue: null));
    properties.add(new DiagnosticsProperty<Border>('border', border, defaultValue: null));
    properties.add(new DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius, defaultValue: null));
    properties.add(new IterableProperty<BoxShadow>('boxShadow', boxShadow, defaultValue: null, style: DiagnosticsTreeStyle.whitespace));
    properties.add(new DiagnosticsProperty<Gradient>('gradient', gradient, defaultValue: null));
    properties.add(new EnumProperty<BoxShape>('shape', shape, defaultValue: BoxShape.rectangle));
  }

  @override
  bool hitTest(Size size, Offset position) {
    assert(shape != null);
    assert((Offset.zero & size).contains(position));
    switch (shape) {
      case BoxShape.rectangle:
        if (borderRadius != null) {
          final RRect bounds = borderRadius.toRRect(Offset.zero & size);
          return bounds.contains(position);
        }
        return true;
      case BoxShape.circle:
        // Circles are inscribed into our smallest dimension.
        final Offset center = size.center(Offset.zero);
        final double distance = (position - center).distance;
        return distance <= math.min(size.width, size.height) / 2.0;
    }
    assert(shape != null);
    return null;
  }

  @override
  _BoxDecorationPainter createBoxPainter([VoidCallback onChanged]) {
    assert(onChanged != null || image == null);
    return new _BoxDecorationPainter(this, onChanged);
  }
}

/// An object that paints a [BoxDecoration] into a canvas.
class _BoxDecorationPainter extends BoxPainter {
  _BoxDecorationPainter(this._decoration, VoidCallback onChange)
    : assert(_decoration != null),
      super(onChange);

  final BoxDecoration _decoration;

  Paint _cachedBackgroundPaint;
  Rect _rectForCachedBackgroundPaint;
  Paint _getBackgroundPaint(Rect rect) {
    assert(rect != null);
    if (_cachedBackgroundPaint == null ||
        (_decoration.gradient == null && _rectForCachedBackgroundPaint != null) ||
        (_decoration.gradient != null && _rectForCachedBackgroundPaint != rect)) {
      final Paint paint = new Paint();

      if (_decoration.color != null)
        paint.color = _decoration.color;

      if (_decoration.gradient != null) {
        paint.shader = _decoration.gradient.createShader(rect);
        _rectForCachedBackgroundPaint = rect;
      } else {
        _rectForCachedBackgroundPaint = null;
      }

      _cachedBackgroundPaint = paint;
    }

    return _cachedBackgroundPaint;
  }

  void _paintBox(Canvas canvas, Rect rect, Paint paint) {
    switch (_decoration.shape) {
      case BoxShape.circle:
        assert(_decoration.borderRadius == null);
        final Offset center = rect.center;
        final double radius = rect.shortestSide / 2.0;
        canvas.drawCircle(center, radius, paint);
        break;
      case BoxShape.rectangle:
        if (_decoration.borderRadius == null) {
          canvas.drawRect(rect, paint);
        } else {
          canvas.drawRRect(_decoration.borderRadius.toRRect(rect), paint);
        }
        break;
    }
  }

  void _paintShadows(Canvas canvas, Rect rect) {
    if (_decoration.boxShadow == null)
      return;
    for (BoxShadow boxShadow in _decoration.boxShadow) {
      final Paint paint = new Paint()
        ..color = boxShadow.color
        ..maskFilter = new MaskFilter.blur(BlurStyle.normal, boxShadow.blurSigma);
      final Rect bounds = rect.shift(boxShadow.offset).inflate(boxShadow.spreadRadius);
      _paintBox(canvas, bounds, paint);
    }
  }

  void _paintBackgroundColor(Canvas canvas, Rect rect) {
    if (_decoration.color != null || _decoration.gradient != null)
      _paintBox(canvas, rect, _getBackgroundPaint(rect));
  }

  ImageStream _imageStream;
  ImageInfo _image;

  void _paintBackgroundImage(Canvas canvas, Rect rect, ImageConfiguration configuration) {
    final DecorationImage backgroundImage = _decoration.image;
    if (backgroundImage == null)
      return;
    final ImageStream newImageStream = backgroundImage.image.resolve(configuration);
    if (newImageStream.key != _imageStream?.key) {
      _imageStream?.removeListener(_imageListener);
      _imageStream = newImageStream;
      _imageStream.addListener(_imageListener);
    }
    final ui.Image image = _image?.image;
    if (image == null)
      return;

    Path clipPath;
    if (_decoration.shape == BoxShape.circle)
      clipPath = new Path()..addOval(rect);
    else if (_decoration.borderRadius != null)
      clipPath = new Path()..addRRect(_decoration.borderRadius.toRRect(rect));
    if (clipPath != null) {
      canvas.save();
      canvas.clipPath(clipPath);
    }

    paintImage(
      canvas: canvas,
      rect: rect,
      image: image,
      colorFilter: backgroundImage.colorFilter,
      fit: backgroundImage.fit,
      alignment: backgroundImage.alignment,
      centerSlice: backgroundImage.centerSlice,
      repeat: backgroundImage.repeat,
    );

    if (clipPath != null)
      canvas.restore();
  }

  void _imageListener(ImageInfo value, bool synchronousCall) {
    if (_image == value)
      return;
    _image = value;
    assert(onChanged != null);
    if (!synchronousCall)
      onChanged();
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_imageListener);
    _imageStream = null;
    _image = null;
    super.dispose();
  }

  /// Paint the box decoration into the given location on the given canvas
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration != null);
    assert(configuration.size != null);
    final Rect rect = offset & configuration.size;
    _paintShadows(canvas, rect);
    _paintBackgroundColor(canvas, rect);
    _paintBackgroundImage(canvas, rect, configuration);
    _decoration.border?.paint(
      canvas,
      rect,
      shape: _decoration.shape,
      borderRadius: _decoration.borderRadius
    );
  }
}
