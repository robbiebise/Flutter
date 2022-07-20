// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Provides platform-specific acoustic and/or haptic feedback for certain
/// actions.
///
/// For example, to play the Android-typically click sound when a button is
/// tapped, call [forTap]. For the Android-specific vibration when long pressing
/// an element, call [forLongPress]. Alternatively, you can also wrap your
/// [GestureDetector.onTap] or [GestureDetector.onLongPress] callback in
/// [wrapForTap] or [wrapForLongPress] to achieve the same (see example code
/// below).
///
/// Calling any of these methods is a no-op on iOS as actions on that platform
/// typically don't provide haptic or acoustic feedback.
///
/// All methods in this class are usually called from within a
/// [StatelessWidget.build] method or from a [State]'s methods as you have to
/// provide a [BuildContext].
///
/// {@tool snippet}
///
/// To trigger platform-specific feedback before executing the actual callback:
///
/// ```dart
/// class WidgetWithWrappedHandler extends StatelessWidget {
///   const WidgetWithWrappedHandler({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     return GestureDetector(
///       onTap: Feedback.wrapForTap(_onTapHandler, context),
///       onLongPress: Feedback.wrapForLongPress(_onLongPressHandler, context),
///       child: const Text('X'),
///     );
///   }
///
///   void _onTapHandler() {
///     // Respond to tap.
///   }
///
///   void _onLongPressHandler() {
///     // Respond to long press.
///   }
/// }
/// ```
/// {@end-tool}
/// {@tool snippet}
///
/// Alternatively, you can also call [forTap] or [forLongPress] directly within
/// your tap or long press handler:
///
/// ```dart
/// class WidgetWithExplicitCall extends StatelessWidget {
///   const WidgetWithExplicitCall({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     return GestureDetector(
///       onTap: () {
///         // Do some work (e.g. check if the tap is valid)
///         Feedback.forTap(context);
///         // Do more work (e.g. respond to the tap)
///       },
///       onLongPress: () {
///         // Do some work (e.g. check if the long press is valid)
///         Feedback.forLongPress(context);
///         // Do more work (e.g. respond to the long press)
///       },
///       child: const Text('X'),
///     );
///   }
/// }
/// ```
/// {@end-tool}
class Feedback {
  // This class is not meant to be instantiated or extended; this constructor
  // prevents instantiation and extension.
  Feedback._();

  /// Provides platform-specific feedback for a tap.
  ///
  /// On Android the click system sound is played. On iOS this is a no-op.
  ///
  /// See also:
  ///
  ///  * [wrapForTap] to trigger platform-specific feedback before executing a
  ///    [GestureTapCallback].
  static Future<void> forTap(BuildContext context) async {
    context.findRenderObject()!.sendSemanticsEvent(const TapSemanticEvent());
    switch (_platform(context)) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return SystemSound.play(SystemSoundType.click);
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return Future<void>.value();
    }
  }

  /// Wraps a [GestureTapCallback] to provide platform specific feedback for a
  /// tap before the provided callback is executed.
  ///
  /// On Android the platform-typical click system sound is played. On iOS this
  /// is a no-op as that platform usually doesn't provide feedback for a tap.
  ///
  /// See also:
  ///
  ///  * [forTap] to just trigger the platform-specific feedback without wrapping
  ///    a [GestureTapCallback].
  static GestureTapCallback? wrapForTap(GestureTapCallback? callback, BuildContext context) {
    if (callback == null) {
      return null;
    }
    return () {
      Feedback.forTap(context);
      callback();
    };
  }

  /// Provides platform-specific feedback for a long press.
  ///
  /// On Android the platform-typical vibration is triggered. On iOS this is a
  /// no-op as that platform usually doesn't provide feedback for long presses.
  ///
  /// See also:
  ///
  ///  * [wrapForLongPress] to trigger platform-specific feedback before
  ///    executing a [GestureLongPressCallback].
  static Future<void> forLongPress(BuildContext context) {
    context.findRenderObject()!.sendSemanticsEvent(const LongPressSemanticsEvent());
    switch (_platform(context)) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return HapticFeedback.vibrate();
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return Future<void>.value();
    }
  }

  /// Wraps a [GestureLongPressCallback] to provide platform specific feedback
  /// for a long press before the provided callback is executed.
  ///
  /// On Android the platform-typical vibration is triggered. On iOS this
  /// is a no-op as that platform usually doesn't provide feedback for a long
  /// press.
  ///
  /// See also:
  ///
  ///  * [forLongPress] to just trigger the platform-specific feedback without
  ///    wrapping a [GestureLongPressCallback].
  static GestureLongPressCallback? wrapForLongPress(GestureLongPressCallback? callback, BuildContext context) {
    if (callback == null) {
      return null;
    }
    return () {
      Feedback.forLongPress(context);
      callback();
    };
  }

  static TargetPlatform _platform(BuildContext context) => Theme.of(context).platform;
}
