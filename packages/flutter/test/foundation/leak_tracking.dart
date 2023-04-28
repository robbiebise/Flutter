// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:meta/meta.dart';

/// Set of objects, references weakly.
class _WeakObjects {
  /// Maps object's hash code to the list of weak references to the object.
  ///
  /// The list size is more than one in case of hash code duplicates.
  final Map<int, List<WeakReference<Object>>> _objects = <int, List<WeakReference<Object>>>{};

  void add(Object object) {
    if (contains(object)) {
      return;
    }

    final List<WeakReference<Object>> list =
      _objects.putIfAbsent(identityHashCode(object), () => <WeakReference<Object>>[]);
    list.add(WeakReference<Object>(object));
  }

  bool contains(Object object) {
    final List<WeakReference<Object>>? list = _objects[identityHashCode(object)];
    if (list == null) {
      return false;
    }
    for (final WeakReference<Object> ref in list) {
      if (ref.target == object) {
        return true;
      }
    }
    return false;
  }
}


class _TestAdjustments {
  _TestAdjustments(WidgetTester tester);

  bool get isGCed => tester.target == null;

  bool isMatch(WidgetTester tester) => tester == this.tester.target;

  final WeakReference<WidgetTester> tester;
  final _WeakObjects heldObjects = _WeakObjects();
}

extension LeakTrackerAdjustments on WidgetTester {

  static final List<_TestAdjustments> _adjustments = <_TestAdjustments>[];

  T addHeldObject<T>(T object){
    Set<WeakReference<Object>>? objects = _cleanHeldObjectsAndFindThis();
    if (objects == null) {
      objects = <WeakReference<Object>>{};
      _heldObjects[WeakReference<WidgetTester>(this)] = objects;
    }



    return object;
  }

  /// Cleans garbage collected items from [_heldObjects] and adds value for [this] if needed.
  ///
  /// Returns adjustements for [this].
  _TestAdjustments? _cleanAdjustmentsAndFindThis(){
    // Most expected case.
    if (_adjustments.length == 1 && _adjustments.first.isMatch(this)) {
      return _adjustments.last;
    }

    if (_adjustments.isEmpty) {
      _adjustments.add(_TestAdjustments(this));
    }

    for (final _TestAdjustments adj in _adjustments) {
      if (adj.isGCed) {
        _adjustments.remove(adj);
      }
      if (adj.isMatch(this)) {
        return adj;
      }
    }

    final List<WeakReference<WidgetTester>> keys = <WeakReference<WidgetTester>>[..._heldObjects.keys];
    Set<WeakReference<Object>>? result;

    for (final WeakReference<WidgetTester> ref in keys) {
      if (ref.target == null) {
        _heldObjects.remove(ref);
      }

      if (ref.target == this) {
        result = _heldObjects[ref];
      }
    }
    assert(_heldObjects.length < 100, 'As tests do not nest, the size of the array is expected to be very small');
    return result;
  }
}

/// Wrapper for [testWidgets] with leak tracking.
///
/// This method is temporal with the plan:
///
/// 1. For each occurence of [testWidgets] in flutter framework, do one of three:
/// * replace [testWidgets] with [testWidgetsWithLeakTracking]
/// * comment why leak tracking is not needed
/// * link bug about memory leak
///
/// 2. Enable [testWidgets] to track leaks, disabled by default for users,
/// and may be enabled by default for flutter framework.
///
/// 3. Replace [testWidgetsWithLeakTracking] with [testWidgets]
///
/// See https://github.com/flutter/devtools/issues/3951 for details.
@isTest
void testWidgetsWithLeakTracking(
  String description,
  WidgetTesterCallback callback, {
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
  LeakTrackingTestConfig leakTrackingConfig = const LeakTrackingTestConfig(),
}) {
  Future<void> wrappedCallback(WidgetTester tester) async {
    await _withFlutterLeakTracking(
      () async => callback(tester),
      tester,
      leakTrackingConfig,
    );
  }

  testWidgets(
    description,
    wrappedCallback,
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: tags,
  );
}

bool _webWarningPrinted = false;

/// Wrapper for [withLeakTracking] with Flutter specific functionality.
///
/// The method will fail if wrapped code contains memory leaks.
///
/// See details in documentation for `withLeakTracking` at
/// https://github.com/dart-lang/leak_tracker/blob/main/lib/src/orchestration.dart#withLeakTracking
///
/// The Flutter related enhancements are:
/// 1. Listens to [MemoryAllocations] events.
/// 2. Uses `tester.runAsync` for leak detection if [tester] is provided.
///
/// Pass [config] to troubleshoot or exempt leaks. See [LeakTrackingTestConfig]
/// for details.
Future<void> _withFlutterLeakTracking(
  DartAsyncCallback callback,
  WidgetTester tester,
  LeakTrackingTestConfig config,
) async {
  // Leak tracker does not work for web platform.
  if (kIsWeb) {
    final bool shouldPrintWarning = !_webWarningPrinted && LeakTrackingTestConfig.warnForNonSupportedPlatforms;
    if (shouldPrintWarning) {
      _webWarningPrinted = true;
      debugPrint('Leak tracking is not supported on web platform.\nTo turn off this message, set `LeakTrackingTestConfig.warnForNonSupportedPlatforms` to false.');
    }
    await callback();
    return;
  }

  void flutterEventToLeakTracker(ObjectEvent event) {
    return dispatchObjectEvent(event.toMap());
  }

  return TestAsyncUtils.guard<void>(() async {
    MemoryAllocations.instance.addListener(flutterEventToLeakTracker);
    Future<void> asyncCodeRunner(DartAsyncCallback action) async => tester.runAsync(action);

    try {
      Leaks leaks = await withLeakTracking(
        callback,
        asyncCodeRunner: asyncCodeRunner,
        stackTraceCollectionConfig: config.stackTraceCollectionConfig,
        shouldThrowOnLeaks: false,
      );

      leaks = _cleanUpLeaks(leaks, config);

      if (leaks.total > 0) {
        config.onLeaks?.call(leaks);
        if (config.failTestOnLeaks) {
          expect(leaks, isLeakFree, reason: 'Set allow lists in $LeakTrackingTestConfig to ignore leaks.');
        }
      }
    } finally {
      MemoryAllocations.instance.removeListener(flutterEventToLeakTracker);
    }
  });
}

/// Removes leaks that are allowed by [config].
Leaks _cleanUpLeaks(Leaks leaks, LeakTrackingTestConfig config) {
  final Map<LeakType, List<LeakReport>> cleaned = <LeakType, List<LeakReport>>{
    LeakType.notGCed: <LeakReport>[],
    LeakType.notDisposed: <LeakReport>[],
    LeakType.gcedLate: <LeakReport>[],
  };

  for (final LeakReport leak in leaks.notGCed) {
    if (!config.notGCedAllowList.contains(leak.type)) {
      cleaned[LeakType.notGCed]!.add(leak);
    }
  }

  for (final LeakReport leak in leaks.gcedLate) {
    if (!config.notGCedAllowList.contains(leak.type)) {
      cleaned[LeakType.gcedLate]!.add(leak);
    }
  }

  for (final LeakReport leak in leaks.notDisposed) {
    if (!config.notDisposedAllowList.contains(leak.type)) {
      cleaned[LeakType.notDisposed]!.add(leak);
    }
  }
  return Leaks(cleaned);
}
