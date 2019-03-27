

import 'package:flutter/src/foundation/collections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('binarySearch', () {
    final List<int> items = <int>[1, 2, 3];

    expect(binarySearch(items, 1), 0);
    expect(binarySearch(items, 2), 1);
    expect(binarySearch(items, 3), 2);
    expect(binarySearch(items, 12), -1);
  });
}