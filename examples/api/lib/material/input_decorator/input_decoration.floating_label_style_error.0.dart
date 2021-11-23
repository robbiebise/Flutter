// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Flutter code sample for InputDecorator

import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  static const String _title = 'Flutter Code Sample';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      home: Scaffold(
        appBar: AppBar(title: const Text(_title)),
        body: const Center(
          child: InputDecoratorExample(),
        ),
      ),
    );
  }
}

class InputDecoratorExample extends StatelessWidget {
  const InputDecoratorExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: 'Name',
        floatingLabelStyle: MaterialStateTextStyle.resolveWith(
                (Set<MaterialState> states) {
              final Color color = states.contains(MaterialState.error) ? Theme.of(context).errorColor: Colors.orange;
              return TextStyle(color: color, letterSpacing: 1.3);
            }
        ),
      ),
      validator: (String? value) {
        if (value == null || value == '') {
          return 'Enter name';
        }
      },
      autovalidateMode: AutovalidateMode.always,
    );
  }
}
