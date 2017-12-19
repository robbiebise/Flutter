// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'debug.dart';
import 'framework.dart';

/// [NavigationToolbar] is a layout helper to position 3 widgets or groups of
/// widgets along a horizontal axis that's sensible for an application's
/// navigation bar such as in Material Design and in iOS.
///
/// The [leading] and [trailing] widgets occupy the edges of the widget with
/// reasonable size constraints while the [middle] widget occupies the remaining
/// space in either a center aligned or start aligned fashion.
///
/// Either directly use the themed app bars such as the Material [AppBar] or
/// the iOS [CupertinoNavigationBar] or wrap this widget with more theming
/// specifications for your own custom app bar.
class NavigationToolbar extends StatelessWidget {

  /// Creates a widget that lays out its children in a manner suitable for a
  /// toolbar.
  const NavigationToolbar({
    Object debugLocation, Key key,
    this.leading,
    this.middle,
    this.trailing,
    this.centerMiddle: true,
    this.middleSpacing: kMiddleSpacing,
  }) : assert(centerMiddle != null),
       assert(middleSpacing != null),
       super(debugLocation: debugLocation, key: key);

  /// The default spacing around the [middle] widget in dp.
  static const double kMiddleSpacing = 16.0;

  /// Widget to place at the start of the horizontal toolbar.
  final Widget leading;

  /// Widget to place in the middle of the horizontal toolbar, occupying
  /// as much remaining space as possible.
  final Widget middle;

  /// Widget to place at the end of the horizontal toolbar.
  final Widget trailing;

  /// Whether to align the [middle] widget to the center of this widget or
  /// next to the [leading] widget when false.
  final bool centerMiddle;

  /// The spacing around the [middle] widget on horizontal axis.
  ///
  /// Defaults to [kMiddleSpacing].
  final double middleSpacing;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    final List<Widget> children = <Widget>[];

    if (leading != null)
      children.add(new LayoutId(id: _ToolbarSlot.leading, child: leading));

    if (middle != null)
      children.add(new LayoutId(id: _ToolbarSlot.middle, child: middle));

    if (trailing != null)
      children.add(new LayoutId(id: _ToolbarSlot.trailing, child: trailing));

    final TextDirection textDirection = Directionality.of(context);
    return new CustomMultiChildLayout(
      delegate: new _ToolbarLayout(
        centerMiddle: centerMiddle,
        middleSpacing: middleSpacing,
        textDirection: textDirection,
      ),
      children: children,
    );
  }
}

enum _ToolbarSlot {
  leading,
  middle,
  trailing,
}

class _ToolbarLayout extends MultiChildLayoutDelegate {
  _ToolbarLayout({
    this.centerMiddle,
    @required this.middleSpacing,
    @required this.textDirection,
  }) : assert(middleSpacing != null),
       assert(textDirection != null);

  // If false the middle widget should be start-justified within the space
  // between the leading and trailing widgets.
  // If true the middle widget is centered within the toolbar (not within the horizontal
  // space between the leading and trailing widgets).
  final bool centerMiddle;

  /// The spacing around middle widget on horizontal axis.
  final double middleSpacing;

  final TextDirection textDirection;

  @override
  void performLayout(Size size) {
    double leadingWidth = 0.0;
    double trailingWidth = 0.0;

    if (hasChild(_ToolbarSlot.leading)) {
      final BoxConstraints constraints = new BoxConstraints(
        minWidth: 0.0,
        maxWidth: size.width / 3.0, // The leading widget shouldn't take up more than 1/3 of the space.
        minHeight: size.height, // The height should be exactly the height of the bar.
        maxHeight: size.height,
      );
      leadingWidth = layoutChild(_ToolbarSlot.leading, constraints).width;
      double leadingX;
      switch (textDirection) {
        case TextDirection.rtl:
          leadingX = size.width - leadingWidth;
          break;
        case TextDirection.ltr:
          leadingX = 0.0;
          break;
      }
      positionChild(_ToolbarSlot.leading, new Offset(leadingX, 0.0));
    }

    if (hasChild(_ToolbarSlot.trailing)) {
      final BoxConstraints constraints = new BoxConstraints.loose(size);
      final Size trailingSize = layoutChild(_ToolbarSlot.trailing, constraints);
      double trailingX;
      switch (textDirection) {
        case TextDirection.rtl:
          trailingX = 0.0;
          break;
        case TextDirection.ltr:
          trailingX = size.width - trailingSize.width;
          break;
      }
      final double trailingY = (size.height - trailingSize.height) / 2.0;
      trailingWidth = trailingSize.width;
      positionChild(_ToolbarSlot.trailing, new Offset(trailingX, trailingY));
    }

    if (hasChild(_ToolbarSlot.middle)) {
      final double maxWidth = math.max(size.width - leadingWidth - trailingWidth - middleSpacing * 2.0, 0.0);
      final BoxConstraints constraints = new BoxConstraints.loose(size).copyWith(maxWidth: maxWidth);
      final Size middleSize = layoutChild(_ToolbarSlot.middle, constraints);

      final double middleStartMargin = leadingWidth + middleSpacing;
      double middleStart = middleStartMargin;
      final double middleY = (size.height - middleSize.height) / 2.0;
      // If the centered middle will not fit between the leading and trailing
      // widgets, then align its left or right edge with the adjacent boundary.
      if (centerMiddle) {
        middleStart = (size.width - middleSize.width) / 2.0;
        if (middleStart + middleSize.width > size.width - trailingWidth)
          middleStart = size.width - trailingWidth - middleSize.width;
        else if (middleStart < middleStartMargin)
          middleStart = middleStartMargin;
      }

      double middleX;
      switch (textDirection) {
        case TextDirection.rtl:
          middleX = size.width - middleSize.width - middleStart;
          break;
        case TextDirection.ltr:
          middleX = middleStart;
          break;
      }

      positionChild(_ToolbarSlot.middle, new Offset(middleX, middleY));
    }
  }

  @override
  bool shouldRelayout(_ToolbarLayout oldDelegate) {
    return oldDelegate.centerMiddle != centerMiddle
        || oldDelegate.middleSpacing != middleSpacing
        || oldDelegate.textDirection != textDirection;
  }
}
