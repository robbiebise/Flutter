// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TextPainter caret test', () {
    final TextPainter painter = TextPainter()
      ..textDirection = TextDirection.ltr;

    String text = 'A';
    painter.text = TextSpan(text: text);
    painter.layout();

    Offset caretOffset = painter.getOffsetForCaret(
      const ui.TextPosition(offset: 0),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, 0);
    caretOffset = painter.getOffsetForCaret(ui.TextPosition(offset: text.length), ui.Rect.zero);
    expect(caretOffset.dx, painter.width);

    // Check that getOffsetForCaret handles a character that is encoded as a surrogate pair.
    text = 'A\u{1F600}';
    painter.text = TextSpan(text: text);
    painter.layout();
    caretOffset = painter.getOffsetForCaret(ui.TextPosition(offset: text.length), ui.Rect.zero);
    expect(caretOffset.dx, painter.width);
  });

  test('TextPainter error test', () {
    final TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
    expect(() { painter.paint(null, Offset.zero); }, throwsFlutterError);
  });

  test('TextPainter requires textDirection', () {
    final TextPainter painter1 = TextPainter(text: const TextSpan(text: ''));
    expect(() { painter1.layout(); }, throwsAssertionError);
    final TextPainter painter2 = TextPainter(text: const TextSpan(text: ''), textDirection: TextDirection.rtl);
    expect(() { painter2.layout(); }, isNot(throwsException));
  });

  test('TextPainter size test', () {
    final TextPainter painter = TextPainter(
      text: const TextSpan(
        text: 'X',
        style: TextStyle(
          inherit: false,
          fontFamily: 'Ahem',
          fontSize: 123.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    expect(painter.size, const Size(123.0, 123.0));
  });

  test('TextPainter textScaleFactor test', () {
    final TextPainter painter = TextPainter(
      text: const TextSpan(
        text: 'X',
        style: TextStyle(
          inherit: false,
          fontFamily: 'Ahem',
          fontSize: 10.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaleFactor: 2.0,
    );
    painter.layout();
    expect(painter.size, const Size(20.0, 20.0));
  });

  test('TextPainter default text height is 14 pixels', () {
    final TextPainter painter = TextPainter(
      text: const TextSpan(text: 'x'),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    expect(painter.preferredLineHeight, 14.0);
    expect(painter.size, const Size(14.0, 14.0));
  });

  test('TextPainter sets paragraph size from root', () {
    final TextPainter painter = TextPainter(
      text: const TextSpan(text: 'x', style: TextStyle(fontSize: 100.0)),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    expect(painter.preferredLineHeight, 100.0);
    expect(painter.size, const Size(100.0, 100.0));
  });

  test('TextPainter intrinsic dimensions', () {
    const TextStyle style = TextStyle(
      inherit: false,
      fontFamily: 'Ahem',
      fontSize: 10.0,
    );
    TextPainter painter;

    painter = TextPainter(
      text: const TextSpan(
        text: 'X X X',
        style: style,
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    expect(painter.size, const Size(50.0, 10.0));
    expect(painter.minIntrinsicWidth, 10.0);
    expect(painter.maxIntrinsicWidth, 50.0);

    painter = TextPainter(
      text: const TextSpan(
        text: 'X X X',
        style: style,
      ),
      textDirection: TextDirection.ltr,
      ellipsis: 'e',
    );
    painter.layout();
    expect(painter.size, const Size(50.0, 10.0));
    expect(painter.minIntrinsicWidth, 50.0);
    expect(painter.maxIntrinsicWidth, 50.0);

    painter = TextPainter(
      text: const TextSpan(
        text: 'X X XXXX',
        style: style,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    );
    painter.layout();
    expect(painter.size, const Size(80.0, 10.0));
    expect(painter.minIntrinsicWidth, 40.0);
    expect(painter.maxIntrinsicWidth, 80.0);

    painter = TextPainter(
      text: const TextSpan(
        text: 'X X XXXX XX',
        style: style,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    );
    painter.layout();
    expect(painter.size, const Size(110.0, 10.0));
    expect(painter.minIntrinsicWidth, 70.0);
    expect(painter.maxIntrinsicWidth, 110.0);

    painter = TextPainter(
      text: const TextSpan(
        text: 'XXXXXXXX XXXX XX X',
        style: style,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    );
    painter.layout();
    expect(painter.size, const Size(180.0, 10.0));
    expect(painter.minIntrinsicWidth, 90.0);
    expect(painter.maxIntrinsicWidth, 180.0);

    painter = TextPainter(
      text: const TextSpan(
        text: 'X XX XXXX XXXXXXXX',
        style: style,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    );
    painter.layout();
    expect(painter.size, const Size(180.0, 10.0));
    expect(painter.minIntrinsicWidth, 90.0);
    expect(painter.maxIntrinsicWidth, 180.0);
  }, skip: true); // https://github.com/flutter/flutter/issues/13512

  test('TextPainter handles newlines properly', () {
    final TextPainter painter = TextPainter()
      ..textDirection = TextDirection.ltr;

    String text = 'aaa';
    const double SIZE_OF_A = 14.0; // square size of "a" character
    painter.text = TextSpan(text: text);
    painter.layout();

    int offset = 0;
    Offset caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    caretOffset = painter.getOffsetForCaret(ui.TextPosition(offset: text.length), ui.Rect.zero);
    expect(caretOffset.dx, painter.width);
    expect(caretOffset.dy, closeTo(0.0, 0.0001));

    // getOffsetForCaret in a plain one-line string is the same for either affinity.
    text = 'aaa';
    painter.text = TextSpan(text: text);
    painter.layout();
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(SIZE_OF_A * offset, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: ui.TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(SIZE_OF_A * offset, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));
    offset = 1;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(SIZE_OF_A * offset, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: ui.TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(SIZE_OF_A * offset, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));
    offset = 2;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(SIZE_OF_A * offset, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: ui.TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(SIZE_OF_A * offset, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));

    // For explicit newlines, getOffsetForCaret places the caret at the location
    // indicated by offset regardless of affinity.
    text = '\n\n';
    painter.text = TextSpan(text: text);
    painter.layout();
    offset = 0;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: ui.TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));
    offset = 1;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.0001));
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: ui.TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.0001));
    offset = 2;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A * 2, 0.0001));
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: ui.TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A * 2, 0.0001));

    // getOffsetForCaret in an unwrapped string with explicit newlines is the
    // same for either affinity.
    text = '\naaa';
    painter.text = TextSpan(text: text);
    painter.layout();
    offset = 0;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: ui.TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));
    offset = 1;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.0001));
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: ui.TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.0001));

    // When text wraps on its own, getOffsetForCaret disambiguates between the
    // end of one line and start of next using affinity.
    text = 'aaaaaaaa'; // Just enough to wrap one character down to second line
    painter.text = TextSpan(text: text);
    painter.layout(maxWidth: 100);
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: text.length - 1),
      ui.Rect.zero,
    );
    // When affinity is downstream, cursor is at beginning of second line
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.0001));
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: text.length - 1, affinity: ui.TextAffinity.upstream),
      ui.Rect.zero,
    );
    // When affinity is upstream, cursor is at end of first line
    expect(caretOffset.dx, closeTo(98.0, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));

    // When given a string with a newline at the end, getOffsetForCaret puts
    // the cursor at the start of the next line regardless of affinity
    text = 'aaa\n';
    painter.text = TextSpan(text: text);
    painter.layout();
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: text.length),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.0001));
    offset = text.length;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.0001));

    // Check that getOffsetForCaret handles being at the end when affinity is
    // downstream and align is right.
    painter.textAlign = TextAlign.right;
    text = 'aaa';
    painter.text = TextSpan(text: text);
    painter.layout();
    offset = 0;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));
    painter.textAlign = TextAlign.left;

    // When given an offset after a newline in the middle of a string,
    // getOffsetForCaret returns the start of the next line regardless of
    // affinity.
    text = 'aaa\naaa';
    painter.text = TextSpan(text: text);
    painter.layout();
    offset = 4;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.0001));
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.0001));

    // Correctly handles multiple trailing newlines with the same offset
    // regardless of affinity.
    text = 'aaa\n\n\n';
    painter.text = TextSpan(text: text);
    painter.layout();
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.001));

    offset = 5;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A * 2, 0.001));

    offset = 6;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A * 3, 0.0001));

    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A * 3, 0.0001));

    offset = 5;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A * 2, 0.0001));

    offset = 4;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.0001));

    offset = 3;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(SIZE_OF_A * 3, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));

    // Correctly handles multiple leading newlines with the same offset
    // regardless of affinity.
    text = '\n\n\naaa';
    painter.text = TextSpan(text: text);
    painter.layout();

    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A * 3, 0.0001));

    offset = 2;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A * 2, 0.0001));

    offset = 1;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy,closeTo(SIZE_OF_A, 0.0001));

    offset = 0;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));

    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(0.0, 0.0001));

    offset = 1;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A, 0.0001));

    offset = 2;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A * 2, 0.0001));

    offset = 3;
    caretOffset = painter.getOffsetForCaret(
      ui.TextPosition(offset: offset, affinity: TextAffinity.upstream),
      ui.Rect.zero,
    );
    expect(caretOffset.dx, closeTo(0.0, 0.0001));
    expect(caretOffset.dy, closeTo(SIZE_OF_A * 3, 0.0001));
  });
}
