// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'about.dart';
import 'scales.dart';
import 'themes.dart';

class GalleryOptions {
  GalleryOptions({
    this.theme,
    this.textScaleFactor,
    this.textDirection = TextDirection.ltr,
    this.timeDilation = 1.0,
    this.platform,
    this.showOffscreenLayersCheckerboard = false,
    this.showRasterCacheImagesCheckerboard = false,
    this.showPerformanceOverlay = false,
  });

  final GalleryTheme theme;
  final GalleryTextScaleValue textScaleFactor;
  final TextDirection textDirection;
  final double timeDilation;
  final TargetPlatform platform;
  final bool showPerformanceOverlay;
  final bool showRasterCacheImagesCheckerboard;
  final bool showOffscreenLayersCheckerboard;

  GalleryOptions copyWith({
    GalleryTheme theme,
    GalleryTextScaleValue textScaleFactor,
    TextDirection textDirection,
    double timeDilation,
    TargetPlatform platform,
    bool showPerformanceOverlay,
    bool showRasterCacheImagesCheckerboard,
    bool showOffscreenLayersCheckerboard,
  }) {
    return new GalleryOptions(
      theme: theme ?? this.theme,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      textDirection: textDirection ?? this.textDirection,
      timeDilation: timeDilation ?? this.timeDilation,
      platform: platform ?? this.platform,
      showPerformanceOverlay: showPerformanceOverlay ?? this.showPerformanceOverlay,
      showOffscreenLayersCheckerboard: showOffscreenLayersCheckerboard ?? this.showOffscreenLayersCheckerboard,
      showRasterCacheImagesCheckerboard: showRasterCacheImagesCheckerboard ?? this.showRasterCacheImagesCheckerboard,
    );
  }

  @override
  bool operator ==(dynamic other) {
    if (runtimeType != other.runtimeType)
      return false;
    final GalleryOptions typedOther = other;
    return theme == typedOther.theme
        && textScaleFactor == typedOther.textScaleFactor
        && textDirection == typedOther.textDirection
        && platform == typedOther.platform
        && showPerformanceOverlay == typedOther.showPerformanceOverlay
        && showRasterCacheImagesCheckerboard == typedOther.showRasterCacheImagesCheckerboard
        && showOffscreenLayersCheckerboard == typedOther.showRasterCacheImagesCheckerboard;
  }

  @override
  int get hashCode => hashValues(
    theme,
    textScaleFactor,
    textDirection,
    timeDilation,
    platform,
    showPerformanceOverlay,
    showRasterCacheImagesCheckerboard,
    showOffscreenLayersCheckerboard,
  );

  @override
  String toString() {
    return '$runtimeType($theme)';
  }
}

const double _kItemHeight = 48.0;
const EdgeInsetsDirectional _kItemPadding = EdgeInsetsDirectional.only(start: 56.0);

class _OptionsItem extends StatelessWidget {
  const _OptionsItem({ Key key, this.child }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double textScaleFactor = MediaQuery.textScaleFactorOf(context);

    return new MergeSemantics(
      child: new Container(
        constraints: new BoxConstraints(minHeight: _kItemHeight * textScaleFactor),
        padding: _kItemPadding,
        alignment: AlignmentDirectional.centerStart,
        child: new DefaultTextStyle(
          style: DefaultTextStyle.of(context).style,
          maxLines: 2,
          overflow: TextOverflow.fade,
          child: new IconTheme(
            data: Theme.of(context).primaryIconTheme,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _BooleanItem extends StatelessWidget {
  const _BooleanItem(this.title, this.value, this.onChanged, { this.switchKey });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  // [switchKey] is used for accessing the switch from driver tests.
  final Key switchKey;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return new _OptionsItem(
      child: new Row(
        children: <Widget>[
          new Expanded(child: new Text(title)),
          new Switch(
            key: switchKey,
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF39CEFD),
            activeTrackColor: isDark ? Colors.white30 : Colors.black26,
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem(this.text, this.onTap);

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return new _OptionsItem(
      child: new _TextButton(
        onPressed: onTap,
        child: new Text(text),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({ Key key, this.onPressed, this.child }) : super(key: key);

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return new TextButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: new DefaultTextStyle(
        style: Theme.of(context).primaryTextTheme.subhead,
        child: child,
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return new _OptionsItem(
      child: new DefaultTextStyle(
        style: theme.textTheme.body1.copyWith(
          fontFamily: 'GoogleSans',
          color: theme.accentColor,
        ),
        child: new Semantics(
          child: new Text(text),
          header: true,
        ),
      ),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem(this.options, this.onOptionsChanged);

  final GalleryOptions options;
  final ValueChanged<GalleryOptions> onOptionsChanged;

  @override
  Widget build(BuildContext context) {
    return new _BooleanItem(
      'Dark Theme',
      options.theme == kDarkGalleryTheme,
      (bool value) {
        onOptionsChanged(
          options.copyWith(
            theme: value ? kDarkGalleryTheme : kLightGalleryTheme,
          ),
        );
      },
      switchKey: const Key('dark_theme'),
    );
  }
}

class _TextScaleFactorItem extends StatelessWidget {
  const _TextScaleFactorItem(this.options, this.onOptionsChanged);

  final GalleryOptions options;
  final ValueChanged<GalleryOptions> onOptionsChanged;

  @override
  Widget build(BuildContext context) {
    return new _OptionsItem(
      child: new Row(
        children: <Widget>[
          new Expanded(
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Text size'),
                new Text(
                  '${options.textScaleFactor.label}',
                  style: Theme.of(context).primaryTextTheme.body1,
                ),
              ],
            ),
          ),
          new PopupMenuButton<GalleryTextScaleValue>(
            padding: const EdgeInsetsDirectional.only(end: 16.0),
            icon: const Icon(Icons.arrow_drop_down),
            itemBuilder: (BuildContext context) {
              return kAllGalleryTextScaleValues.map((GalleryTextScaleValue scaleValue) {
                return new PopupMenuItem<GalleryTextScaleValue>(
                  value: scaleValue,
                  child: new Text(scaleValue.label),
                );
              }).toList();
            },
            onSelected: (GalleryTextScaleValue scaleValue) {
              onOptionsChanged(
                options.copyWith(textScaleFactor: scaleValue),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TextDirectionItem extends StatelessWidget {
  const _TextDirectionItem(this.options, this.onOptionsChanged);

  final GalleryOptions options;
  final ValueChanged<GalleryOptions> onOptionsChanged;

  @override
  Widget build(BuildContext context) {
    return new _BooleanItem(
      'Force RTL',
      options.textDirection == TextDirection.rtl,
      (bool value) {
        onOptionsChanged(
          options.copyWith(
            textDirection: value ? TextDirection.rtl : TextDirection.ltr,
          ),
        );
      },
      switchKey: const Key('text_direction'),
    );
  }
}

class _TimeDilationItem extends StatelessWidget {
  const _TimeDilationItem(this.options, this.onOptionsChanged);

  final GalleryOptions options;
  final ValueChanged<GalleryOptions> onOptionsChanged;

  @override
  Widget build(BuildContext context) {
    return new _BooleanItem(
      'Slow motion',
      options.timeDilation != 1.0,
      (bool value) {
        onOptionsChanged(
          options.copyWith(
            timeDilation: value ? 20.0 : 1.0,
          ),
        );
      },
      switchKey: const Key('slow_motion'),
    );
  }
}

class _PlatformItem extends StatelessWidget {
  const _PlatformItem(this.options, this.onOptionsChanged);

  final GalleryOptions options;
  final ValueChanged<GalleryOptions> onOptionsChanged;

  String _platformLabel(TargetPlatform platform) {
    switch(platform) {
      case TargetPlatform.android:
        return 'Mountain View';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
      case TargetPlatform.iOS:
        return 'Cupertino';
    }
    assert(false);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return new _OptionsItem(
      child: new Row(
        children: <Widget>[
          new Expanded(
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Platform mechanics'),
                 new Text(
                   '${_platformLabel(options.platform)}',
                   style: Theme.of(context).primaryTextTheme.body1,
                 ),
              ],
            ),
          ),
          new PopupMenuButton<TargetPlatform>(
            padding: const EdgeInsetsDirectional.only(end: 16.0),
            icon: const Icon(Icons.arrow_drop_down),
            itemBuilder: (BuildContext context) {
              return TargetPlatform.values.map((TargetPlatform platform) {
                return new PopupMenuItem<TargetPlatform>(
                  value: platform,
                  child: new Text(_platformLabel(platform)),
                );
              }).toList();
            },
            onSelected: (TargetPlatform platform) {
              onOptionsChanged(
                options.copyWith(platform: platform),
              );
            },
          ),
        ],
      ),
    );
  }
}

class GalleryOptionsPage extends StatelessWidget {
  const GalleryOptionsPage({
    Key key,
    this.options,
    this.onOptionsChanged,
    this.onSendFeedback,
  }) : super(key: key);

  final GalleryOptions options;
  final ValueChanged<GalleryOptions> onOptionsChanged;
  final VoidCallback onSendFeedback;

  List<Widget> _enabledDiagnosticItems() {
    // Boolean showFoo options with a value of null: don't display
    // the showFoo option at all.
    if (null == options.showOffscreenLayersCheckerboard
             ?? options.showRasterCacheImagesCheckerboard
             ?? options.showPerformanceOverlay)
      return const <Widget>[];

    final List<Widget> items = <Widget>[
      const Divider(),
      const _Heading('Diagnostics'),
    ];

    if (options.showOffscreenLayersCheckerboard != null) {
      items.add(
        new _BooleanItem(
          'Highlight offscreen layers',
          options.showOffscreenLayersCheckerboard,
          (bool value) {
            onOptionsChanged(options.copyWith(showOffscreenLayersCheckerboard: value));
          }
        ),
      );
    }
    if (options.showRasterCacheImagesCheckerboard != null) {
      items.add(
        new _BooleanItem(
          'Highlight raster cache images',
          options.showRasterCacheImagesCheckerboard,
          (bool value) {
            onOptionsChanged(options.copyWith(showRasterCacheImagesCheckerboard: value));
          },
        ),
      );
    }
    if (options.showPerformanceOverlay != null) {
      items.add(
        new _BooleanItem(
          'Show performance overlay',
          options.showPerformanceOverlay,
          (bool value) {
            onOptionsChanged(options.copyWith(showPerformanceOverlay: value));
          },
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return new DefaultTextStyle(
      style: theme.primaryTextTheme.subhead,
      child: new ListView(
        padding: const EdgeInsets.only(bottom: 124.0),
        children: <Widget>[
          const _Heading('Display'),
          new _ThemeItem(options, onOptionsChanged),
          new _TextScaleFactorItem(options, onOptionsChanged),
          new _TextDirectionItem(options, onOptionsChanged),
          new _TimeDilationItem(options, onOptionsChanged),
          const Divider(),
          const _Heading('Platform mechanics'),
          new _PlatformItem(options, onOptionsChanged),
        ]..addAll(
          _enabledDiagnosticItems(),
        )..addAll(
          <Widget>[
            const Divider(),
            const _Heading('Flutter gallery'),
            new _ActionItem('About Flutter Gallery', () {
              showGalleryAboutDialog(context);
            }),
            new _ActionItem('Send feedback', onSendFeedback),
          ],
        ),
      ),
    );
  }
}
