 // Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class TestNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

void main() {
  testWidgets('ChangeNotifier', (WidgetTester tester) async {
    final List<String> log = <String>[];
    final VoidCallback listener = () { log.add('listener'); };
    final VoidCallback listener1 = () { log.add('listener1'); };
    final VoidCallback listener2 = () { log.add('listener2'); };
    final VoidCallback badListener = () { log.add('badListener'); throw null; };

    final TestNotifier test = new TestNotifier();

    test.addListener(listener);
    test.addListener(listener);
    test.notify();
    expect(log, <String>['listener', 'listener']);
    log.clear();

    test.removeListener(listener);
    test.notify();
    expect(log, <String>['listener']);
    log.clear();

    test.removeListener(listener);
    test.notify();
    expect(log, <String>[]);
    log.clear();

    test.removeListener(listener);
    test.notify();
    expect(log, <String>[]);
    log.clear();

    test.addListener(listener);
    test.notify();
    expect(log, <String>['listener']);
    log.clear();

    test.addListener(listener1);
    test.notify();
    expect(log, <String>['listener', 'listener1']);
    log.clear();

    test.addListener(listener2);
    test.notify();
    expect(log, <String>['listener', 'listener1', 'listener2']);
    log.clear();

    test.removeListener(listener1);
    test.notify();
    expect(log, <String>['listener', 'listener2']);
    log.clear();

    test.addListener(listener1);
    test.notify();
    expect(log, <String>['listener', 'listener2', 'listener1']);
    log.clear();

    test.addListener(badListener);
    test.notify();
    expect(log, <String>['listener', 'listener2', 'listener1', 'badListener']);
    expect(tester.takeException(), isNullThrownError);
    log.clear();

    test.addListener(listener1);
    test.removeListener(listener);
    test.removeListener(listener1);
    test.removeListener(listener2);
    test.addListener(listener2);
    test.notify();
    expect(log, <String>['badListener', 'listener1', 'listener2']);
    expect(tester.takeException(), isNullThrownError);
    log.clear();
  });

  test('ChangeNotifier with mutating listener', () {
    final TestNotifier test = new TestNotifier();
    final List<String> log = <String>[];

    final VoidCallback listener1 = () { log.add('listener1'); };
    final VoidCallback listener3 = () { log.add('listener3'); };
    final VoidCallback listener4 = () { log.add('listener4'); };
    final VoidCallback listener2 = () {
      log.add('listener2');
      test.removeListener(listener1);
      test.removeListener(listener3);
      test.addListener(listener4);
    };

    test.addListener(listener1);
    test.addListener(listener2);
    test.addListener(listener3);
    test.notify();
    expect(log, <String>['listener1', 'listener2']);
    log.clear();

    test.notify();
    expect(log, <String>['listener2', 'listener4']);
    log.clear();

    test.notify();
    expect(log, <String>['listener2', 'listener4', 'listener4']);
    log.clear();
  });

  test('Merging change notifiers', () {
    final TestNotifier source1 = new TestNotifier();
    final TestNotifier source2 = new TestNotifier();
    final TestNotifier source3 = new TestNotifier();
    final List<String> log = <String>[];

    final Listenable merged = new Listenable.merge(<Listenable>[source1, source2]);
    final VoidCallback listener1 = () { log.add('listener1'); };
    final VoidCallback listener2 = () { log.add('listener2'); };

    merged.addListener(listener1);
    source1.notify();
    source2.notify();
    source3.notify();
    expect(log, <String>['listener1', 'listener1']);
    log.clear();

    merged.removeListener(listener1);
    source1.notify();
    source2.notify();
    source3.notify();
    expect(log, isEmpty);
    log.clear();

    merged.addListener(listener1);
    merged.addListener(listener2);
    source1.notify();
    source2.notify();
    source3.notify();
    expect(log, <String>['listener1', 'listener2', 'listener1', 'listener2']);
    log.clear();
  });

  test('Merging change notifiers ignores null', () {
    final TestNotifier source1 = new TestNotifier();
    final TestNotifier source2 = new TestNotifier();
    final List<String> log = <String>[];

    final Listenable merged = new Listenable.merge(<Listenable>[null, source1, null, source2, null]);
    final VoidCallback listener = () { log.add('listener'); };

    merged.addListener(listener);
    source1.notify();
    source2.notify();
    expect(log, <String>['listener', 'listener']);
    log.clear();
  });

  test('Can dispose merged notifier', () {
    final TestNotifier source1 = new TestNotifier();
    final TestNotifier source2 = new TestNotifier();
    final List<String> log = <String>[];

    final ChangeNotifier merged = new Listenable.merge(<Listenable>[source1, source2]);
    final VoidCallback listener = () { log.add('listener'); };

    merged.addListener(listener);
    source1.notify();
    source2.notify();
    expect(log, <String>['listener', 'listener']);
    log.clear();
    merged.dispose();

    source1.notify();
    source2.notify();
    expect(log, isEmpty);
  });

  test('Cannot use a disposed ChangeNotifier', () {
    final TestNotifier source = new TestNotifier();
    source.dispose();
    expect(() { source.addListener(null); }, throwsFlutterError);
    expect(() { source.removeListener(null); }, throwsFlutterError);
    expect(() { source.dispose(); }, throwsFlutterError);
    expect(() { source.notify(); }, throwsFlutterError);
  });

  test('Value notifier', () {
    final ValueNotifier<double> notifier = new ValueNotifier<double>(2.0);

    final List<double> log = <double>[];
    final VoidCallback listener = () { log.add(notifier.value); };

    notifier.addListener(listener);
    notifier.value = 3.0;

    expect(log, equals(<double>[ 3.0 ]));
    log.clear();

    notifier.value = 3.0;
    expect(log, isEmpty);
  });
}
