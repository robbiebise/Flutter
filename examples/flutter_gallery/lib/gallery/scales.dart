// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

class GalleryTextScaleValue {
  const GalleryTextScaleValue(this.scale, this.label);

  final double scale;
  final String label;

  @override
  bool operator ==(dynamic other) {
    if (runtimeType != other.runtimeType)
      return false;
    return other is GalleryTextScaleValue
        && other.scale == scale
        && other.label == label;
  }

  @override
  int get hashCode => hashValues(scale, label);

  @override
  String toString() {
    return '$runtimeType($label)';
  }

}

const List<GalleryTextScaleValue> kAllGalleryTextScaleValues = <GalleryTextScaleValue>[
  GalleryTextScaleValue(null, 'System Default'),
  GalleryTextScaleValue(0.8, 'Small'),
  GalleryTextScaleValue(1.0, 'Normal'),
  GalleryTextScaleValue(1.3, 'Large'),
  GalleryTextScaleValue(2.0, 'Huge'),
];

class GalleryVisualDensityValue {
  const GalleryVisualDensityValue(this.visualDensity, this.label);

  final VisualDensity visualDensity;
  final String label;

  @override
  bool operator ==(dynamic other) {
    if (runtimeType != other.runtimeType)
      return false;
    final GalleryVisualDensityValue typedOther = other;
    return visualDensity == typedOther.visualDensity && label == typedOther.label;
  }

  @override
  int get hashCode => hashValues(visualDensity, label);

  @override
  String toString() {
    return '$runtimeType($label)';
  }

}

const List<GalleryVisualDensityValue> kAllGalleryVisualDensityValues = <GalleryVisualDensityValue>[
  GalleryVisualDensityValue(VisualDensity(), 'System Default'),
  GalleryVisualDensityValue(VisualDensity.comfortable, 'Comfortable'),
  GalleryVisualDensityValue(VisualDensity.compact, 'Compact'),
  GalleryVisualDensityValue(VisualDensity(horizontal: -3, vertical: -3), 'Very Compact'),
];
