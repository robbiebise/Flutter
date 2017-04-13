// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This example shows how to draw some bi-directional text using the raw
// interface to the engine.

import 'dart:typed_data';
import 'dart:ui' as ui;

// A paragraph represents a rectangular region that contains some text.
ui.Paragraph paragraph;

ui.Picture paint(ui.Rect paintBounds) {
  final ui.PictureRecorder recorder = new ui.PictureRecorder();
  final ui.Canvas canvas = new ui.Canvas(recorder, paintBounds);

  final double devicePixelRatio = ui.window.devicePixelRatio;
  final ui.Size logicalSize = ui.window.physicalSize / devicePixelRatio;

  canvas.translate(logicalSize.width / 2.0, logicalSize.height / 2.0);
  canvas.drawRect(new ui.Rect.fromLTRB(-100.0, -100.0, 100.0, 100.0),
                  new ui.Paint()..color = const ui.Color.fromARGB(255, 0, 255, 0));

  // The paint method of Pargraph draws the contents of the paragraph unto the
  // given canvas.
  canvas.drawParagraph(paragraph, new ui.Offset(paragraph.width / -2.0, (paragraph.width / 2.0) - 125));

  return recorder.endRecording();
}

ui.Scene composite(ui.Picture picture, ui.Rect paintBounds) {
  final double devicePixelRatio = ui.window.devicePixelRatio;
  final Float64List deviceTransform = new Float64List(16)
    ..[0] = devicePixelRatio
    ..[5] = devicePixelRatio
    ..[10] = 1.0
    ..[15] = 1.0;
  final ui.SceneBuilder sceneBuilder = new ui.SceneBuilder()
    ..pushTransform(deviceTransform)
    ..addPicture(ui.Offset.zero, picture)
    ..pop();
  return sceneBuilder.build();
}

void beginFrame(Duration timeStamp) {
  final ui.Rect paintBounds = ui.Offset.zero & (ui.window.physicalSize / ui.window.devicePixelRatio);
  final ui.Picture picture = paint(paintBounds);
  final ui.Scene scene = composite(picture, paintBounds);
  ui.window.render(scene);
}

void main() {
  // To create a paragraph of text, we use ParagraphBuilder.
  final ui.ParagraphBuilder builder = new ui.ParagraphBuilder(new ui.ParagraphStyle())
    // We first push a style that turns the text blue.
    ..pushStyle(new ui.TextStyle(color: const ui.Color(0xFF0000FF)))
    ..addText('Hello, ')
    // The next run of text will be bold.
    ..pushStyle(new ui.TextStyle(fontWeight: ui.FontWeight.bold))
    ..addText('world. ')
    // The pop() command signals the end of the bold styling.
    ..pop()
    // We add text to the paragraph in logical order. The paragraph object
    // understands bi-directional text and will compute the visual ordering
    // during layout.
    ..addText('هذا هو قليلا طويلة من النص الذي يجب التفاف .')
    // The second pop() removes the blue color.
    ..pop()
    // We can add more text with the default styling.
    ..addText(' و أكثر قليلا لجعله أطول. ')
    ..addText('สวัสดี');
  // When we're done adding styles and text, we build the Paragraph object, at
  // which time we can apply styling that affects the entire paragraph, such as
  // left, right, or center alignment. Once built, the contents of the paragraph
  // cannot be altered, but sizing and positioning information can be updated.
  paragraph = builder.build()
    // Next, we supply a width that the text is permitted to occupy and we ask
    // the paragraph to the visual position of each its glyphs as well as its
    // overall size, subject to its sizing constraints.
    ..layout(new ui.ParagraphConstraints(width: 180.0));

  // Finally, we register our beginFrame callback and kick off the first frame.
  ui.window.onBeginFrame = beginFrame;
  ui.window.scheduleFrame();
}
