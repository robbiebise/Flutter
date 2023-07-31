// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/*member: whileLoop:declared={a, b}, assigned={a, b}*/
whileLoop(int a, int b) {
  /*assigned={a, b}*/ while ((a = 0) != 0) {
    b = 0;
  }
}
