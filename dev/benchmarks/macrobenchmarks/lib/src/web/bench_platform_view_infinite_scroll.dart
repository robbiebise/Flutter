// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

// TODO(mdebbar): flutter/flutter#55000 Remove this conditional import once
// web-only dart:ui_web APIs are exposed from a dedicated place.
import 'platform_views/non_web.dart'
    if (dart.library.js_interop) 'platform_views/web.dart';
import 'recorder.dart';

const String benchmarkViewType = 'benchmark_element';

void _registerFactory() {
  platformViewRegistry.registerViewFactory(benchmarkViewType, (int viewId) {
    final web.HTMLElement htmlElement = web.document.createElement('div'.toJS)
        as web.HTMLDivElement;
    htmlElement.id = '${benchmarkViewType}_$viewId'.toJS;
    htmlElement.innerText = 'Google'.toJS;
    htmlElement.style
      ..setProperty('width'.toJS, '100%'.toJS)
      ..setProperty('height'.toJS, '100%'.toJS)
      ..setProperty('color'.toJS, 'black'.toJS)
      ..setProperty('backgroundColor'.toJS, 'rgba(0, 255, 0, .5)'.toJS)
      ..setProperty('textAlign'.toJS, 'center'.toJS)
      ..setProperty('border'.toJS, '1px solid black'.toJS);
    return htmlElement;
  });
}

/// Creates an infinite list of Link widgets and scrolls it.
class BenchPlatformViewInfiniteScroll extends WidgetRecorder {
  BenchPlatformViewInfiniteScroll.forward()
      : initialOffset = 0.0,
        finalOffset = 30000.0,
        super(name: benchmarkName) {
    _registerFactory();
  }

  BenchPlatformViewInfiniteScroll.backward()
      : initialOffset = 30000.0,
        finalOffset = 0.0,
        super(name: benchmarkNameBackward) {
    _registerFactory();
  }

  static const String benchmarkName = 'bench_platform_view_infinite_scroll';
  static const String benchmarkNameBackward =
      'bench_platform_view_infinite_scroll_backward';

  final double initialOffset;
  final double finalOffset;

  @override
  Widget createWidget() => MaterialApp(
        title: 'Infinite Platform View Scroll Benchmark',
        home: _InfiniteScrollPlatformViews(initialOffset, finalOffset),
      );
}

class _InfiniteScrollPlatformViews extends StatefulWidget {
  const _InfiniteScrollPlatformViews(this.initialOffset, this.finalOffset);

  final double initialOffset;
  final double finalOffset;

  @override
  State<_InfiniteScrollPlatformViews> createState() => _InfiniteScrollPlatformViewsState();
}

class _InfiniteScrollPlatformViewsState extends State<_InfiniteScrollPlatformViews> {
  static const Duration stepDuration = Duration(seconds: 20);

  late ScrollController scrollController;
  late double offset;

  @override
  void initState() {
    super.initState();

    offset = widget.initialOffset;

    scrollController = ScrollController(
      initialScrollOffset: offset,
    );

    // Without the timer the animation doesn't begin.
    Timer.run(() async {
      await scrollController.animateTo(
        widget.finalOffset,
        curve: Curves.linear,
        duration: stepDuration,
      );
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemExtent: 100.0,
      itemBuilder: (BuildContext context, int index) {
        return const SizedBox(
          height: 100.0,
          child: HtmlElementView(viewType: benchmarkViewType),
        );
      },
    );
  }
}
