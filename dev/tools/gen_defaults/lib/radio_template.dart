// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'template.dart';

class RadioTemplate extends TokenTemplate {
  const RadioTemplate(super.blockName, super.fileName, super.tokens, {
    super.colorSchemePrefix = '_colors.',
  });

  @override
  String generate() => '''
class _${blockName}DefaultsM3 extends RadioThemeData {
  _${blockName}DefaultsM3(BuildContext context)
    : _theme = Theme.of(context),
      _colors = Theme.of(context).colorScheme;

  final ThemeData _theme;
  final ColorScheme _colors;

  @override
  MaterialStateProperty<Color> get fillColor {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.disabled)) {
        return ${componentColor('md.comp.radio-button.disabled.unselected.icon')};
      }
      if (states.contains(MaterialState.selected)) {
        return ${componentColor('md.comp.radio-button.selected.icon')};
      }
      if (states.contains(MaterialState.pressed)) {
        return ${componentColor('md.comp.radio-button.unselected.pressed.icon')};
      }
      if (states.contains(MaterialState.hovered)) {
        return ${componentColor('md.comp.radio-button.unselected.hover.icon')};
      }
      if (states.contains(MaterialState.focused)) {
        return ${componentColor('md.comp.radio-button.unselected.focus.icon')};
      }
      return ${componentColor('md.comp.radio-button.unselected.icon')};
    });
  }

  @override
  MaterialStateProperty<Color> get overlayColor {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        if (states.contains(MaterialState.pressed)) {
          return ${componentColor('md.comp.radio-button.selected.pressed.state-layer')};
        }
        if (states.contains(MaterialState.hovered)) {
          return ${componentColor('md.comp.radio-button.selected.hover.state-layer')};
        }
        if (states.contains(MaterialState.focused)) {
          return ${componentColor('md.comp.radio-button.selected.focus.state-layer')};
        }
        return Colors.transparent;
      }
      if (states.contains(MaterialState.pressed)) {
        return ${componentColor('md.comp.radio-button.unselected.pressed.state-layer')};
      }
      if (states.contains(MaterialState.hovered)) {
        return ${componentColor('md.comp.radio-button.unselected.hover.state-layer')};
      }
      if (states.contains(MaterialState.focused)) {
        return ${componentColor('md.comp.radio-button.unselected.hover.state-layer')};
      }
      return Colors.transparent;
    });
  }

  @override
  MaterialTapTargetSize get materialTapTargetSize => _theme.materialTapTargetSize;

  @override
  VisualDensity get visualDensity => _theme.visualDensity;
}
''';
}
