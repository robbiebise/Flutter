// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

void main() => runApp(const MagnifierExampleApp());

class MagnifierExampleApp extends StatefulWidget {
  const MagnifierExampleApp({super.key});

  @override
  State<MagnifierExampleApp> createState() => _MagnifierExampleAppState();
}

class _MagnifierExampleAppState extends State<MagnifierExampleApp> {
  Offset dragGesturePosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: kAllDraggableScrollBehavior,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('Drag on the logo!'),
              RepaintBoundary(
                child: Stack(
                  children: <Widget>[
                    GestureDetector(
                      onPanUpdate: (DragUpdateDetails details) => setState(
                        () {
                          dragGesturePosition = details.localPosition;
                        },
                      ),
                      child: const FlutterLogo(size: 200),
                    ),
                    Positioned(
                      left: dragGesturePosition.dx,
                      top: dragGesturePosition.dy,
                      child: const RawMagnifier(
                        decoration: MagnifierDecoration(
                          shape: CircleBorder(
                            side: BorderSide(color: Colors.pink, width: 3),
                          ),
                        ),
                        size: Size(100, 100),
                        magnificationScale: 2,
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
