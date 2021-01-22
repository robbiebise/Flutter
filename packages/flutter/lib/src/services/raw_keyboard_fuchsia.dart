// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'package:flutter/foundation.dart';

import 'keyboard_keys.dart';
import 'keyboard_maps.dart';
import 'raw_keyboard.dart';

/// Platform-specific key event data for Fuchsia.
///
/// This object contains information about key events obtained from Fuchsia's
/// `KeyData` interface.
///
/// See also:
///
///  * [RawKeyboard], which uses this interface to expose key data.
class RawKeyEventDataFuchsia extends RawKeyEventData {
  /// Creates a key event data structure specific for Fuchsia.
  ///
  /// The [hidUsage], [codePoint], and [modifiers] arguments must not be null.
  const RawKeyEventDataFuchsia({
    this.hidUsage = 0,
    this.codePoint = 0,
    this.modifiers = 0,
  }) : assert(hidUsage != null),
       assert(codePoint != null),
       assert(modifiers != null);

  /// The USB HID usage.
  ///
  /// See <http://www.usb.org/developers/hidpage/Hut1_12v2.pdf> for more
  /// information.
  final int hidUsage;

  /// The Unicode code point represented by the key event, if any.
  ///
  /// If there is no Unicode code point, this value is zero.
  ///
  /// Dead keys are represented as Unicode combining characters.
  final int codePoint;

  /// The modifiers that were present when the key event occurred.
  ///
  /// See <https://fuchsia.googlesource.com/garnet/+/master/public/fidl/fuchsia.ui.input/input_event_constants.fidl>
  /// for the numerical values of the modifiers. Many of these are also
  /// replicated as static constants in this class.
  ///
  /// See also:
  ///
  ///  * [modifiersPressed], which returns a Map of currently pressed modifiers
  ///    and their keyboard side.
  ///  * [isModifierPressed], to see if a specific modifier is pressed.
  ///  * [isControlPressed], to see if a CTRL key is pressed.
  ///  * [isShiftPressed], to see if a SHIFT key is pressed.
  ///  * [isAltPressed], to see if an ALT key is pressed.
  ///  * [isMetaPressed], to see if a META key is pressed.
  final int modifiers;

  // Fuchsia only reports a single code point for the key label.
  @override
  String get keyLabel => codePoint == 0 ? '' : String.fromCharCode(codePoint);

  @override
  LogicalKeyboardKey get logicalKey {
    // If the key has a printable representation, then make a logical key based
    // on that.
    if (codePoint != 0) {
      return LogicalKeyboardKey(
        LogicalKeyboardKey.unicodePlane | codePoint & LogicalKeyboardKey.valueMask,
        keyLabel: keyLabel,
        debugName: kReleaseMode ? null : 'Key $keyLabel',
      );
    }

    // Look to see if the hidUsage is one we know about and have a mapping for.
    LogicalKeyboardKey? newKey = kFuchsiaToLogicalKey[hidUsage | LogicalKeyboardKey.hidPlane];
    if (newKey != null) {
      return newKey;
    }

    // This is a non-printable key that we don't know about, so we mint a new
    // code with the autogenerated bit set.
    const int fuchsiaKeyIdPlane = 0x00300000000;
    newKey ??= LogicalKeyboardKey(
      fuchsiaKeyIdPlane | hidUsage | LogicalKeyboardKey.autogeneratedMask,
      debugName: kReleaseMode ? null : 'Ephemeral Fuchsia key code $hidUsage',
    );
    return newKey;
  }

  @override
  PhysicalKeyboardKey get physicalKey => kFuchsiaToPhysicalKey[hidUsage] ?? PhysicalKeyboardKey.none;

  bool _isLeftRightModifierPressed(KeyboardSide side, int anyMask, int leftMask, int rightMask) {
    if (modifiers & anyMask == 0) {
      return false;
    }
    switch (side) {
      case KeyboardSide.any:
        return true;
      case KeyboardSide.all:
        return modifiers & leftMask != 0 && modifiers & rightMask != 0;
      case KeyboardSide.left:
        return modifiers & leftMask != 0;
      case KeyboardSide.right:
        return modifiers & rightMask != 0;
    }
  }

  @override
  bool isModifierPressed(ModifierKey key, { KeyboardSide side = KeyboardSide.any }) {
    assert(side != null);
    switch (key) {
      case ModifierKey.controlModifier:
        return _isLeftRightModifierPressed(side, modifierControl, modifierLeftControl, modifierRightControl);
      case ModifierKey.shiftModifier:
        return _isLeftRightModifierPressed(side, modifierShift, modifierLeftShift, modifierRightShift);
      case ModifierKey.altModifier:
        return _isLeftRightModifierPressed(side, modifierAlt, modifierLeftAlt, modifierRightAlt);
      case ModifierKey.metaModifier:
        return _isLeftRightModifierPressed(side, modifierMeta, modifierLeftMeta, modifierRightMeta);
      case ModifierKey.capsLockModifier:
        return modifiers & modifierCapsLock != 0;
      case ModifierKey.numLockModifier:
      case ModifierKey.scrollLockModifier:
      case ModifierKey.functionModifier:
      case ModifierKey.symbolModifier:
        // Fuchsia doesn't have masks for these keys (yet).
        return false;
    }
  }

  @override
  KeyboardSide? getModifierSide(ModifierKey key) {
    KeyboardSide? findSide(int anyMask, int leftMask, int rightMask) {
      final int combined = modifiers & anyMask;
      if (combined == leftMask) {
        return KeyboardSide.left;
      } else if (combined == rightMask) {
        return KeyboardSide.right;
      } else if (combined == anyMask) {
        return KeyboardSide.all;
      }
      return null;
    }

    switch (key) {
      case ModifierKey.controlModifier:
        return findSide(modifierControl, modifierLeftControl, modifierRightControl, );
      case ModifierKey.shiftModifier:
        return findSide(modifierShift, modifierLeftShift, modifierRightShift);
      case ModifierKey.altModifier:
        return findSide(modifierAlt, modifierLeftAlt, modifierRightAlt);
      case ModifierKey.metaModifier:
        return findSide(modifierMeta, modifierLeftMeta, modifierRightMeta);
      case ModifierKey.capsLockModifier:
        return (modifiers & modifierCapsLock == 0) ? null : KeyboardSide.all;
      case ModifierKey.numLockModifier:
      case ModifierKey.scrollLockModifier:
      case ModifierKey.functionModifier:
      case ModifierKey.symbolModifier:
        // Fuchsia doesn't support these modifiers, so they can't be pressed.
        return null;
    }
  }

  // Keyboard modifier masks for Fuchsia modifiers.

  /// The [modifiers] field indicates that no modifier keys are pressed if it
  /// equals this value.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierNone = 0x0;

  /// This mask is used to check the [modifiers] field to test whether the CAPS
  /// LOCK modifier key is on.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierCapsLock = 0x1;

  /// This mask is used to check the [modifiers] field to test whether the left
  /// SHIFT modifier key is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierLeftShift = 0x2;

  /// This mask is used to check the [modifiers] field to test whether the right
  /// SHIFT modifier key is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierRightShift = 0x4;

  /// This mask is used to check the [modifiers] field to test whether one of
  /// the SHIFT modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierShift = modifierLeftShift | modifierRightShift;

  /// This mask is used to check the [modifiers] field to test whether the left
  /// CTRL modifier key is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierLeftControl = 0x8;

  /// This mask is used to check the [modifiers] field to test whether the right
  /// CTRL modifier key is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierRightControl = 0x10;

  /// This mask is used to check the [modifiers] field to test whether one of
  /// the CTRL modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierControl = modifierLeftControl | modifierRightControl;

  /// This mask is used to check the [modifiers] field to test whether the left
  /// ALT modifier key is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierLeftAlt = 0x20;

  /// This mask is used to check the [modifiers] field to test whether the right
  /// ALT modifier key is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierRightAlt = 0x40;

  /// This mask is used to check the [modifiers] field to test whether one of
  /// the ALT modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierAlt = modifierLeftAlt | modifierRightAlt;

  /// This mask is used to check the [modifiers] field to test whether the left
  /// META modifier key is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierLeftMeta = 0x80;

  /// This mask is used to check the [modifiers] field to test whether the right
  /// META modifier key is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierRightMeta = 0x100;

  /// This mask is used to check the [modifiers] field to test whether one of
  /// the META modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierMeta = modifierLeftMeta | modifierRightMeta;

  @override
  String toString() {
    return '${objectRuntimeType(this, 'RawKeyEventDataFuchsia')}(hidUsage: $hidUsage, codePoint: $codePoint, modifiers: $modifiers, '
        'modifiers down: $modifiersPressed)';
  }
}
