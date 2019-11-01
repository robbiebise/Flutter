// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'keyboard_key.dart';
import 'keyboard_maps.dart';
import 'raw_keyboard.dart';

/// Platform-specific key event data for macOS.
///
/// This object contains information about key events obtained from macOS's
/// `NSEvent` interface.
///
/// See also:
///
///  * [RawKeyboard], which uses this interface to expose key data.
class RawKeyEventDataMacOs extends RawKeyEventData {
  /// Creates a key event data structure specific for macOS.
  ///
  /// The [characters], [charactersIgnoringModifiers], and [modifiers], arguments
  /// must not be null.
  const RawKeyEventDataMacOs({
    this.characters = '',
    this.charactersIgnoringModifiers = '',
    this.keyCode = 0,
    this.modifiers = 0,
  }) : assert(characters != null),
       assert(charactersIgnoringModifiers != null),
       assert(keyCode != null),
       assert(modifiers != null);

  /// The Unicode characters associated with a key-up or key-down event.
  ///
  /// See also:
  ///
  ///   * [Apple's NSEvent documentation](https://developer.apple.com/documentation/appkit/nsevent/1534183-characters?language=objc)
  final String characters;

  /// The characters generated by a key event as if no modifier key (except for
  /// Shift) applies.
  ///
  /// See also:
  ///
  ///   * [Apple's NSEvent documentation](https://developer.apple.com/documentation/appkit/nsevent/1524605-charactersignoringmodifiers?language=objc)
  final String charactersIgnoringModifiers;

  /// The virtual key code for the keyboard key associated with a key event.
  ///
  /// See also:
  ///
  ///   * [Apple's NSEvent documentation](https://developer.apple.com/documentation/appkit/nsevent/1534513-keycode?language=objc)
  final int keyCode;

  /// A mask of the current modifiers using the values in Modifier Flags.
  ///
  /// See also:
  ///
  ///   * [Apple's NSEvent documentation](https://developer.apple.com/documentation/appkit/nsevent/1535211-modifierflags?language=objc)
  final int modifiers;

  @override
  String get keyLabel => charactersIgnoringModifiers.isEmpty ? null : charactersIgnoringModifiers;

  @override
  PhysicalKeyboardKey get physicalKey => kMacOsToPhysicalKey[keyCode] ?? PhysicalKeyboardKey.none;

  @override
  LogicalKeyboardKey get logicalKey {
    // Look to see if the keyCode is a printable number pad key, so that a
    // difference between regular keys (e.g. "=") and the number pad version
    // (e.g. the "=" on the number pad) can be determined.
    final LogicalKeyboardKey numPadKey = kMacOsNumPadMap[keyCode];
    if (numPadKey != null) {
      return numPadKey;
    }
    // If this key is printable, generate the LogicalKeyboardKey from its Unicode value.
    // Control keys such as ESC, CRTL, and SHIFT are not printable. HOME, DEL, arrow keys, and function
    // keys are considered modifier function keys, which generate invalid Unicode scalar values.
    if (keyLabel != null &&
        !LogicalKeyboardKey.isControlCharacter(keyLabel) &&
        !_isUnprintableKey(keyLabel)) {
      // Given that charactersIgnoringModifiers can contain a String of arbitrary length,
      // limit to a maximum of two Unicode scalar values. It is unlikely that a keyboard would produce a code point
      // bigger than 32 bits, but it is still worth defending against this case.
      assert(charactersIgnoringModifiers.length <= 2);
      int codeUnit = charactersIgnoringModifiers.codeUnitAt(0);
      if (charactersIgnoringModifiers.length == 2) {
        final int secondCode = charactersIgnoringModifiers.codeUnitAt(1);
        codeUnit = (codeUnit << 16) | secondCode;
      }

      final int keyId = LogicalKeyboardKey.unicodePlane | (codeUnit & LogicalKeyboardKey.valueMask);
      return LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(
        keyId,
        keyLabel: keyLabel,
        debugName: kReleaseMode ? null : 'Key ${keyLabel.toUpperCase()}',
      );
    }

    // Control keys like "backspace" and movement keys like arrow keys don't have a printable representation,
    // but are present on the physical keyboard. Since there is no logical keycode map for macOS
    // (macOS uses the keycode to reference physical keys), a LogicalKeyboardKey is created with
    // the physical key's HID usage and debugName. This avoids duplicating the physical
    // key map.
    if (physicalKey != PhysicalKeyboardKey.none) {
      final int keyId = physicalKey.usbHidUsage | LogicalKeyboardKey.hidPlane;
      return LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(
        keyId,
        keyLabel: physicalKey.debugName,
        debugName: physicalKey.debugName,
      );
    }

    // This is a non-printable key that we don't know about, so we mint a new
    // code with the autogenerated bit set.
    const int macOsKeyIdPlane = 0x00500000000;

    return LogicalKeyboardKey(
      macOsKeyIdPlane | keyCode | LogicalKeyboardKey.autogeneratedMask,
      debugName: kReleaseMode ? null : 'Unknown macOS key code $keyCode',
    );
  }

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
    return false;
  }

  @override
  bool isModifierPressed(ModifierKey key, {KeyboardSide side = KeyboardSide.any}) {
    final int independentModifier = modifiers & deviceIndependentMask;
    switch (key) {
      case ModifierKey.controlModifier:
        return _isLeftRightModifierPressed(side, independentModifier & modifierControl, modifierLeftControl, modifierRightControl);
      case ModifierKey.shiftModifier:
        return _isLeftRightModifierPressed(side, independentModifier & modifierShift, modifierLeftShift, modifierRightShift);
      case ModifierKey.altModifier:
        return _isLeftRightModifierPressed(side, independentModifier & modifierOption, modifierLeftOption, modifierRightOption);
      case ModifierKey.metaModifier:
        return _isLeftRightModifierPressed(side, independentModifier & modifierCommand, modifierLeftCommand, modifierRightCommand);
      case ModifierKey.capsLockModifier:
        return independentModifier & modifierCapsLock != 0;
      case ModifierKey.numLockModifier:
      case ModifierKey.functionModifier:
      case ModifierKey.symbolModifier:
      case ModifierKey.scrollLockModifier:
        // These modifier masks are not used in macOS keyboards.
        return false;
    }
    return false;
  }

  @override
  KeyboardSide getModifierSide(ModifierKey key) {
    KeyboardSide findSide(int leftMask, int rightMask) {
      final int combinedMask = leftMask | rightMask;
      final int combined = modifiers & combinedMask;
      if (combined == leftMask) {
        return KeyboardSide.left;
      } else if (combined == rightMask) {
        return KeyboardSide.right;
      } else if (combined == combinedMask) {
        return KeyboardSide.all;
      }
      return null;
    }

    switch (key) {
      case ModifierKey.controlModifier:
        return findSide(modifierLeftControl, modifierRightControl);
      case ModifierKey.shiftModifier:
        return findSide(modifierLeftShift, modifierRightShift);
      case ModifierKey.altModifier:
        return findSide(modifierLeftOption, modifierRightOption);
      case ModifierKey.metaModifier:
        return findSide(modifierLeftCommand, modifierRightCommand);
      case ModifierKey.capsLockModifier:
      case ModifierKey.numLockModifier:
      case ModifierKey.scrollLockModifier:
      case ModifierKey.functionModifier:
      case ModifierKey.symbolModifier:
        return KeyboardSide.all;
    }

    assert(false, 'Not handling $key type properly.');
    return null;
  }

  /// Returns true if the given label represents an unprintable key.
  ///
  /// Examples of unprintable keys are "NSUpArrowFunctionKey = 0xF700"
  /// or "NSHomeFunctionKey = 0xF729".
  ///
  /// See <https://developer.apple.com/documentation/appkit/1535851-function-key_unicodes?language=objc> for more
  /// information.
  ///
  /// Used by [RawKeyEvent] subclasses to help construct IDs.
  static bool _isUnprintableKey(String label) {
    if (label.length > 1) {
      return false;
    }
    final int codeUnit = label.codeUnitAt(0);
    return codeUnit >= 0xF700 && codeUnit <= 0xF8FF;
  }

  // Modifier key masks. See Apple's NSEvent documentation
  // https://developer.apple.com/documentation/appkit/nseventmodifierflags?language=objc
  // https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-86/IOHIDSystem/IOKit/hidsystem/IOLLEvent.h.auto.html

  /// This mask is used to check the [modifiers] field to test whether the CAPS
  /// LOCK modifier key is on.
  ///
  /// {@template flutter.services.logicalKeyboardKey.modifiers}
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  /// {@endtemplate}
  static const int modifierCapsLock = 0x10000;

  /// This mask is used to check the [modifiers] field to test whether one of the
  /// SHIFT modifier keys is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierShift = 0x20000;

  /// This mask is used to check the [modifiers] field to test whether the left
  /// SHIFT modifier key is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierLeftShift = 0x02;

  /// This mask is used to check the [modifiers] field to test whether the right
  /// SHIFT modifier key is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierRightShift = 0x04;

  /// This mask is used to check the [modifiers] field to test whether one of the
  /// CTRL modifier keys is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierControl = 0x40000;

  /// This mask is used to check the [modifiers] field to test whether the left
  /// CTRL modifier key is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierLeftControl = 0x01;

  /// This mask is used to check the [modifiers] field to test whether the right
  /// CTRL modifier key is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierRightControl = 0x2000;

  /// This mask is used to check the [modifiers] field to test whether one of the
  /// ALT modifier keys is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierOption = 0x80000;

  /// This mask is used to check the [modifiers] field to test whether the left
  /// ALT modifier key is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierLeftOption = 0x20;

  /// This mask is used to check the [modifiers] field to test whether the right
  /// ALT modifier key is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierRightOption = 0x40;

  /// This mask is used to check the [modifiers] field to test whether one of the
  /// CMD modifier keys is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierCommand = 0x100000;

  /// This mask is used to check the [modifiers] field to test whether the left
  /// CMD modifier keys is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierLeftCommand = 0x08;

  /// This mask is used to check the [modifiers] field to test whether the right
  /// CMD modifier keys is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierRightCommand = 0x10;

  /// This mask is used to check the [modifiers] field to test whether any key in
  /// the numeric keypad is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierNumericPad = 0x200000;

  /// This mask is used to check the [modifiers] field to test whether the
  /// HELP modifier key is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierHelp = 0x400000;

  /// This mask is used to check the [modifiers] field to test whether one of the
  /// FUNCTION modifier keys is pressed.
  ///
  /// {@macro flutter.services.logicalKeyboardKey.modifiers}
  static const int modifierFunction = 0x800000;

  /// Used to retrieve only the device-independent modifier flags, allowing
  /// applications to mask off the device-dependent modifier flags, including
  /// event coalescing information.
  static const int deviceIndependentMask = 0xffff0000;

  @override
  String toString() {
    return '$runtimeType(keyLabel: $keyLabel, keyCode: $keyCode, characters: $characters,'
        ' unmodifiedCharacters: $charactersIgnoringModifiers, modifiers: $modifiers, '
        'modifiers down: $modifiersPressed)';
  }
}
