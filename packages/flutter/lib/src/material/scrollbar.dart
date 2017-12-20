// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

const double _kScrollbarThickness = 6.0;
const Duration _kScrollbarFadeDuration = const Duration(milliseconds: 300);
const Duration _kScrollbarTimeToFade = const Duration(milliseconds: 600);

/// A material design scrollbar.
///
/// A scrollbar indicates which portion of a [Scrollable] widget is actually
/// visible.
///
/// Dynamically changes to a iOS style scrollbar that looks like
/// [CupertinoScrollbar] on iOS platform.
///
/// To add a scrollbar to a [ScrollView], simply wrap the scroll view widget in
/// a [Scrollbar] widget.
///
/// See also:
///
///  * [ListView], which display a linear, scrollable list of children.
///  * [GridView], which display a 2 dimensional, scrollable array of children.
class Scrollbar extends StatefulWidget {
  /// Creates a material design scrollbar that wraps the given [child].
  ///
  /// The [child] should be a source of [ScrollNotification] notifications,
  /// typically a [Scrollable] widget.
  const Scrollbar({
    Key key,
    @required this.child,
  }) : super(key: key);

  /// The subtree to place inside the [Scrollbar].
  ///
  /// This should include a source of [ScrollNotification] notifications,
  /// typically a [Scrollable] widget.
  final Widget child;

  @override
  _ScrollbarState createState() => new _ScrollbarState();
}


class _ScrollbarState extends State<Scrollbar> with TickerProviderStateMixin {
  ScrollbarPainter _materialPainter;
  TargetPlatform _currentPlatform;
  TextDirection _textDirection;
  Color _themeColor;

  AnimationController _fadeoutAnimationController;
  Animation<double> _fadeoutOpacityAnimation;
  Timer _fadeoutTimer;

  @override
  void initState() {
    super.initState();
    _fadeoutAnimationController = new AnimationController(
      vsync: this,
      duration: _kScrollbarFadeDuration,
    );
    _fadeoutOpacityAnimation = new CurvedAnimation(
      parent: _fadeoutAnimationController,
      curve: Curves.fastOutSlowIn
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final ThemeData theme = Theme.of(context);
    _currentPlatform = theme.platform;

    if (_currentPlatform == TargetPlatform.iOS) {
      // On iOS, stop all local animations. CupertinoScrollbar has its own
      // animations.
      _fadeoutTimer?.cancel();
      _fadeoutTimer = null;
      _fadeoutAnimationController.reset();
     } else {
      _themeColor = theme.highlightColor.withOpacity(1.0);
      _textDirection = Directionality.of(context);
      _materialPainter = _buildMaterialScrollbarPainter();
    }
  }

  ScrollbarPainter _buildMaterialScrollbarPainter() {
    return new ScrollbarPainter(
        color: _themeColor,
        textDirection: _textDirection,
        thickness: _kScrollbarThickness,
        fadeoutOpacityAnimation: _fadeoutOpacityAnimation,
      );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // iOS sub-delegates to the CupertinoScrollbar instead and doesn't handle
    // scroll notifications here.
    if (_currentPlatform != TargetPlatform.iOS
        && (notification is ScrollUpdateNotification
            || notification is OverscrollNotification)) {
      if (_fadeoutAnimationController.status != AnimationStatus.forward) {
        _fadeoutAnimationController.forward();
      }

      _materialPainter.update(notification.metrics, notification.metrics.axisDirection);
      _fadeoutTimer?.cancel();
      _fadeoutTimer = new Timer(_kScrollbarTimeToFade, () {
        _fadeoutAnimationController.reverse();
        _fadeoutTimer = null;
      });
    }
    return false;
  }

  @override
  void dispose() {
    _materialPainter?.dispose();
    _fadeoutAnimationController.dispose();
    _fadeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPlatform == TargetPlatform.iOS) {
      return new CupertinoScrollbar(
        child: widget.child,
      );
    } else {
      return new NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: new RepaintBoundary(
          child: new CustomPaint(
            foregroundPainter: _materialPainter,
            child: new RepaintBoundary(
              child: widget.child,
            ),
          ),
        ),
      );
    }
  }
}
