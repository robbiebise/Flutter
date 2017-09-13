// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'basic.dart';
import 'framework.dart';

/// A widget that describes this app in the operating system.
class Title extends StatelessWidget {
  /// Creates a widget that describes this app to the operating system.
  ///
  /// [title] will default to the empty string if not supplied.
  /// [color] must be an opaque color (i.e. color.alpha must be 255 (0xFF)).
  /// [color] and [child] are required arguments.
  Title({
    Key key,
    this.title: '',
    @required this.color,
    @required this.child,
  }) : assert(title != null),
       assert(color != null && color.alpha == 0xFF),
       super(key: key);

  /// A one-line description of this app for use in the window manager.
  /// Must not be null.
  final String title;

  /// A color that the window manager should use to identify this app.  Must be
  /// an opaque color (i.e. color.alpha must be 255 (0xFF)), and must not be
  /// null.
  final Color color;

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setApplicationSwitcherDescription(
      new ApplicationSwitcherDescription(
        label: title,
        primaryColor: color.value,
      )
    );
    return child;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(new StringProperty('title', title, defaultValue: ''));
    description.add(new DiagnosticsProperty<Color>('color', color, defaultValue: null));
  }
}
