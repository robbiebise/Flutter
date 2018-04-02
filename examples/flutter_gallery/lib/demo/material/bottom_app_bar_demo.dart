// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BottomAppBarDemo extends StatefulWidget {
  static const String routeName = '/material/bottom_app_bar';

  @override
  State createState() => new _BottomAppBarDemoState();
}

class _BottomAppBarDemoState extends State<BottomAppBarDemo> {

  int babFabIndex = 1;

  int fabShapeIndex = 0;

  final List<_FabShapeConfiguration> _fabShapeConfigurations =  <_FabShapeConfiguration>[
      const _FabShapeConfiguration('None', null),
      new _FabShapeConfiguration('Circular', 
        new Builder(builder: (BuildContext context) {
          return new FloatingActionButton(
            onPressed: () => _showSnackbar(context),
            child: const Icon(Icons.add),
            backgroundColor: Colors.orange,
          );
        }),
      ),
      new _FabShapeConfiguration(
        'Diamond',
        new Builder(builder: (BuildContext context) {
          return new DiamondFab(
            onPressed: () => _showSnackbar(context),
            child: const Icon(Icons.add),
          );
        }),
      ),
    ];

  Map<_BabMode, String> babModeToName = <_BabMode, String>{
    _BabMode.END_FAB: 'Right aligned floating action button',
    _BabMode.CENTER_FAB: 'Center aligned floating action button',
  };

  List<Color> babColors = <Color> [
    null,
    Colors.orange,
    Colors.green,
    Colors.lightBlue,
  ];

  Color babColor;

  bool notchEnabled = true;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: const Text('FAB Location with Bottom App Bar'), 
        // Add 48dp of space onto the bottom of the appbar.
        // This gives space for the top-start location to attach to without
        // blocking the 'back' button.
        bottom: const PreferredSize(
          preferredSize: const Size.fromHeight(48.0), 
          child: const SizedBox(),
        ),
      ),
      body: new SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16.0),
        child: controls(context),
      ),
      bottomNavigationBar: new MyBottomAppBar(_babFabConfigurations[babFabIndex].babMode, babColor, notchEnabled),
      floatingActionButton: _fabShapeConfigurations[fabShapeIndex].fab,
      floatingActionButtonLocation: _babFabConfigurations[babFabIndex].fabLocation,
    );
  }

  Widget controls(BuildContext context) {
    return new Column(
      children: <Widget> [
        new Text(
          'Floating action button',
          style: Theme.of(context).textTheme.title,
        ),
        fabOptions(),
        const Divider(),
        new Text(
          'Bottom app bar mode',
          style: Theme.of(context).textTheme.title,
        ),
        babConfigModes(),
        const Divider(),
        new Text(
          'Bottom app bar options',
          style: Theme.of(context).textTheme.title,
        ),
        babColorSelection(),
        new CheckboxListTile(
          title: const Text('Enable notch'),
          value: notchEnabled,
          onChanged: (bool value) { setState(() { notchEnabled = value; }); },
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget fabOptions() {
    final List<Widget> options = <Widget>[];
    for (int i = 0; i < _fabShapeConfigurations.length; i++) {
      final _FabShapeConfiguration configuration = _fabShapeConfigurations[i];
      options.add(
        new RadioListTile<int>(
          title: new Text(configuration.name),
          value: i,
          groupValue: fabShapeIndex,
          onChanged: (int newIdx) { setState(() { fabShapeIndex = newIdx; }); },
        )
      );
    }
    return new Column(children: options);
  }

  Widget babConfigModes() {
    final List<Widget> modes = <Widget> [];
    for (int i = 0; i < _babFabConfigurations.length; i++) {
      final _BabFabConfiguration configuration = _babFabConfigurations[i];
      modes.add(
        new RadioListTile<int>(
          title: new Text(configuration.name),
          value: i,
          groupValue: babFabIndex,
          onChanged: (int newIdx) { setState(() { babFabIndex = newIdx; }); },
        )
      );
    }
    return new Column(children: modes);
  }

  Widget babColorSelection() {
    final List<Widget> colors = <Widget> [
      const Text('Color:'),
    ];
    for (Color color in babColors) {
      colors.add(
        new Radio<Color>(
          value: color,
          groupValue: babColor,
          onChanged: (Color color) { setState(() { babColor = color; }); },
        )
      );
      colors.add(new Container(
          decoration: new BoxDecoration(
            color: color,
            border: new Border.all(width:2.0, color: Colors.black),
          ),
          child: const SizedBox(width: 20.0, height: 20.0)
      ));
      colors.add(const Padding(padding: const EdgeInsets.only(left: 12.0)));
    }
    return new Row(
      children: colors,
      mainAxisAlignment: MainAxisAlignment.center,
    );
  }

  

  static void _showSnackbar(BuildContext context) {
    Scaffold.of(context).showSnackBar(const SnackBar(content: const Text(_explanatoryText)));
  }
}



const String _explanatoryText =
  "When the Scaffold's floating action button location changes, "
  'the floating action button animates to its new position.'
  'The BottomAppBar adapts its shape appropriately.';

enum _BabMode {
  END_FAB,
  CENTER_FAB
}

// Pairs the Bottom App Bar's menu mode with a Floating Action Button Location.
class _BabFabConfiguration {
  const _BabFabConfiguration(this.name, this.babMode, this.fabLocation);

  // The name of this configuration.
  final String name;

  // The _BabMode to place the menu in the bab with.
  final _BabMode babMode;

  // The location for the Floating Action Button.
  final FloatingActionButtonLocation fabLocation;
}

const List<_BabFabConfiguration> _babFabConfigurations = const <_BabFabConfiguration>[
  const _BabFabConfiguration('Center, undocked FAB', _BabMode.CENTER_FAB, FloatingActionButtonLocation.centerFloat),
  const _BabFabConfiguration('End, undocked FAB', _BabMode.END_FAB, FloatingActionButtonLocation.endFloat),
  const _BabFabConfiguration('Center, docked FAB', _BabMode.CENTER_FAB, const _CenterDockedFloatingActionButtonLocation()),
  const _BabFabConfiguration('End, docked FAB', _BabMode.END_FAB, const _EndDockedFloatingActionButtonLocation()),
  const _BabFabConfiguration('Start, FAB docked to the top app bar', _BabMode.CENTER_FAB, const _TopStartFloatingActionButtonLocation()),
];

// Map of names to the different shapes of Floating Action Button in this demo.
class _FabShapeConfiguration {
  const _FabShapeConfiguration(this.name, this.fab);

  final String name;
  final Widget fab;
}

class MyBottomAppBar extends StatelessWidget {
  const MyBottomAppBar(this.babMode, this.color, this.enableNotch);

  final _BabMode babMode;
  final Color color;
  final bool enableNotch;

  final Curve fadeOutCurve = const Interval(0.0, 0.3333);
  final Curve fadeInCurve = const Interval(0.3333, 1.0);

  @override
  Widget build(BuildContext context) {
    final bool showsFirst = babMode == _BabMode.END_FAB;
    return new BottomAppBar(
      color: color,
      hasNotch: enableNotch,
      child: new Row(
        children: <Widget> [
          new IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              showModalBottomSheet<Null>(context: context, builder: (BuildContext context) => const MyDrawer()); },
          ),
          new Expanded(
            child: new AnimatedCrossFade(
              duration: const Duration(milliseconds: 225),
              firstChild: babContents(context, _BabMode.END_FAB),
              firstCurve: showsFirst ? fadeOutCurve  : fadeInCurve,
              secondChild: babContents(context, _BabMode.CENTER_FAB),
              secondCurve: showsFirst ? fadeInCurve  : fadeOutCurve,
              crossFadeState: showsFirst ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            ),
          ),
        ],
      ),
    );
  }

  Widget babContents(BuildContext context, _BabMode babMode) {
    final List<Widget> rowContents = <Widget> [];
    if (babMode == _BabMode.CENTER_FAB) {
      rowContents.add(
        new Expanded(
          child: new
          ConstrainedBox(
            constraints:
            const BoxConstraints(maxHeight: 0.0),
          ),
        ),
      );
    }
    rowContents.addAll(<Widget> [
      new IconButton(
        icon: const Icon(Icons.search),
        onPressed: () {},
      ),
      new IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () {},
      )
    ]);
    return new Row(
      children: rowContents
    );
  }
}

class MyDrawer extends StatelessWidget {
  const MyDrawer();

  @override
  Widget build(BuildContext context) {
    return new Drawer(
      child: new Column(
        children: const <Widget>[
          const ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search'),
          ),
          const ListTile(
            leading: const Icon(Icons.threed_rotation),
            title: const Text('3D'),
          ),
        ],
      ),
    );
  }
}

class DiamondFab extends StatefulWidget {
  const DiamondFab({
    this.child,
    this.notchMargin: 6.0,
    this.onPressed,
  });

  final Widget child;
  final double notchMargin;
  final VoidCallback onPressed;

  @override
  State createState() => new DiamondFabState();
}

class DiamondFabState extends State<DiamondFab> {

  VoidCallback _clearComputeNotch;

  @override
  Widget build(BuildContext context) {
    return new Material(
      shape: const DiamondBorder(),
      color: Colors.orange,
      //onPressed: widget.onPressed,
      child: new InkWell(
        onTap: widget.onPressed,
        child: new Container(
          width: 56.0,
          height: 56.0,
          child: IconTheme.merge(
            data: new IconThemeData(color: Theme.of(context).accentIconTheme.color),
            child: widget.child,
          ),
        ),
      ),
      elevation: 6.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clearComputeNotch = Scaffold.setFloatingActionButtonNotchFor(context, _computeNotch);
  }

  @override
  void deactivate() {
    if (_clearComputeNotch != null)
      _clearComputeNotch();
    super.deactivate();
  }

  Path _computeNotch(Rect host, Rect guest, Offset start, Offset end) {
    final Rect marginedGuest = guest.inflate(widget.notchMargin);
    if (!host.overlaps(marginedGuest))
      return new Path()..lineTo(end.dx, end.dy);

    final Rect intersection = marginedGuest.intersect(host);
    // We are computing a "V" shaped notch, as in this diagram:
    //    -----\****   /-----
    //          \     /
    //           \   /
    //            \ /
    //
    //  "-" marks the top edge of the bottom app bar.
    //  "\" and "/" marks the notch outline
    //
    //  notchToCenter is the horizontal distance between the guest's center and
    //  the host's top edge where the notch starts (marked with "*").
    //  We compute notchToCenter by similar triangles:
    final double notchToCenter =
      intersection.height * (marginedGuest.height / 2.0)
      / (marginedGuest.width / 2.0);

    return new Path()
      ..lineTo(marginedGuest.center.dx - notchToCenter, host.top)
      ..lineTo(marginedGuest.left + marginedGuest.width / 2.0, marginedGuest.bottom)
      ..lineTo(marginedGuest.center.dx + notchToCenter, host.top)
      ..lineTo(end.dx, end.dy);
  }
}

class DiamondBorder extends ShapeBorder {
  const DiamondBorder();

  @override
  EdgeInsetsGeometry get dimensions {
    return const EdgeInsets.only();
  }

  @override
  Path getInnerPath(Rect rect, { TextDirection textDirection }) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, { TextDirection textDirection }) {
    return new Path()
      ..moveTo(rect.left + rect.width / 2.0, rect.top)
      ..lineTo(rect.right, rect.top + rect.height / 2.0)
      ..lineTo(rect.left + rect.width  / 2.0, rect.bottom)
      ..lineTo(rect.left, rect.top + rect.height / 2.0)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, { TextDirection textDirection }) {}

  @override
  ShapeBorder scale(double t) {
    return null;
  }
}

// Places the Floating Action Button at the top of the content area of the
// app, on the border between the body and the app bar.
class _TopStartFloatingActionButtonLocation extends FloatingActionButtonLocation {
  const _TopStartFloatingActionButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    // First, we'll place the X coordinate for the Floating Action Button
    // at the start of the screen, based on the text direction.
    double fabX;
    assert(scaffoldGeometry.textDirection != null);
    switch (scaffoldGeometry.textDirection) {
      case TextDirection.rtl:
        // In RTL layouts, the start of the screen is on the right side,
        // and the end of the screen is on the left.
        //
        // We need to align the right edge of the floating action button with
        // the right edge of the screen, then move it inwards by the designated padding.
        //
        // The Scaffold's origin is at its top-left, so we need to offset fabX
        // by the Scaffold's width to get the right edge of the screen.
        //
        // The Floating Action Button's origin is at its top-left, so we also need
        // to subtract the Floating Action Button's width to align the right edge
        // of the Floating Action Button instead of the left edge.
        final double startPadding = kFloatingActionButtonMargin + scaffoldGeometry.minInsets.right;
        fabX = scaffoldGeometry.scaffoldSize.width - scaffoldGeometry.floatingActionButtonSize.width - startPadding;
        break;
      case TextDirection.ltr:
        // In LTR layouts, the start of the screen is on the left side,
        // and the end of the screen is on the right.
        //
        // Placing the fabX at 0.0 will align the left edge of the
        // Floating Action Button with the left edge of the screen, so all
        // we need to do is offset fabX by the designated padding.
        final double startPadding = kFloatingActionButtonMargin + scaffoldGeometry.minInsets.left;
        fabX = startPadding;
        break;
    }
    // Finally, we'll place the Y coordinate for the Floating Action Button 
    // at the top of the content body.
    //
    // We want to place the middle of the Floating Action Button on the
    // border between the Scaffold's app bar and its body. To do this,
    // we place fabY at the scaffold geometry's contentTop, then subtract
    // half of the Floating Action Button's height to place the center
    // over the contentTop.
    //
    // We don't have to worry about which way is the top like we did
    // for left and right, so we place fabY in this one-liner.
    final double fabY = scaffoldGeometry.contentTop - (scaffoldGeometry.floatingActionButtonSize.height / 2.0);
    return new Offset(fabX, fabY);
  }
}

/// Provider of common logic for [FloatingActionButtonLocation]s that
/// dock to the [BottomAppBar].
abstract class _DockedFloatingActionButtonLocation extends FloatingActionButtonLocation {
  const _DockedFloatingActionButtonLocation();

  /// Positions the Y coordinate of the [FloatingActionButton] at a height
  /// where it docks to the [BottomAppBar].
  /// 
  /// If there is no [BottomAppBar], this could go off the bottom of the screen.
  @protected
  double getDockedY(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double contentBottom = scaffoldGeometry.contentBottom;
    final double bottomSheetHeight = scaffoldGeometry.bottomSheetSize.height;
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;
    final double snackBarHeight = scaffoldGeometry.snackBarSize.height;

    double fabY = contentBottom - fabHeight / 2.0;
    // The FAB should sit with a margin between it and the snack bar.
    if (snackBarHeight > 0.0)
      fabY = math.min(fabY, contentBottom - snackBarHeight - fabHeight - kFloatingActionButtonMargin);
    // The FAB should sit with its center in front of the top of the bottom sheet.
    if (bottomSheetHeight > 0.0)
      fabY = math.min(fabY, contentBottom - bottomSheetHeight - fabHeight / 2.0);
    return fabY;
  }
}

// Places the Floating Action Button at the end of the screen, docked on top
// of the Bottom App Bar.
//
// This positioning logic is the opposite of the _TopStartFloatingActionButtonPositioner
class _EndDockedFloatingActionButtonLocation extends _DockedFloatingActionButtonLocation {
  const _EndDockedFloatingActionButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    // Compute the x-axis offset.
    double fabX;
    assert(scaffoldGeometry.textDirection != null);
    switch (scaffoldGeometry.textDirection) {
      case TextDirection.rtl:
        // In RTL, the end of the screen is the left.
        final double endPadding = scaffoldGeometry.minInsets.left;
        fabX = kFloatingActionButtonMargin + endPadding;
        break;
      case TextDirection.ltr:
        // In LTR, the end of the screen is the right.
        final double endPadding = scaffoldGeometry.minInsets.right;
        fabX = scaffoldGeometry.scaffoldSize.width - scaffoldGeometry.floatingActionButtonSize.width - kFloatingActionButtonMargin - endPadding;
      break;
    }
    // Return an offset with a docked Y coordinate.
    return new Offset(fabX, getDockedY(scaffoldGeometry));
  }
}

class _CenterDockedFloatingActionButtonLocation extends _DockedFloatingActionButtonLocation {
  const _CenterDockedFloatingActionButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = (scaffoldGeometry.scaffoldSize.width - scaffoldGeometry.floatingActionButtonSize.width) / 2.0;
    // Return an offset with a docked Y coordinate.
    return new Offset(fabX, getDockedY(scaffoldGeometry));
  }

}
