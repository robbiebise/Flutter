// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io' show Platform;

const String _tab1Text = 'tab 1';
const String _tab2Text = 'tab 2';
const String _tab3Text = 'tab 3';
const String _tab4Text = 'tab 4';
const String _tab5Text = 'tab 5';
const String _tab6Text = 'tab 6';
const String _tab7Text = 'tab 7';

final Key _painterKey = UniqueKey();

const List<Tab> _tabs = <Tab>[
  Tab(text: _tab1Text, icon: Icon(Icons.looks_one)),
  Tab(text: _tab2Text, icon: Icon(Icons.looks_two)),
  Tab(text: _tab3Text, icon: Icon(Icons.looks_3)),
  Tab(text: _tab4Text, icon: Icon(Icons.looks_4)),
  Tab(text: _tab5Text, icon: Icon(Icons.looks_5)),
  Tab(text: _tab6Text, icon: Icon(Icons.looks_6)),
  Tab(text: _tab7Text, icon: Icon(Icons.looks)),
];

Widget _buildTabBar({ List<Tab> tabs = _tabs }) {
  final TabController _tabController =
    TabController(length: 7, vsync: const TestVSync());

  return RepaintBoundary(
      key: _painterKey,
      child: TabBar(tabs: tabs, controller: _tabController),
  );
}

Widget _withTheme(TabBarTheme theme) {
  return MaterialApp(
      theme: ThemeData(tabBarTheme: theme),
      home: Scaffold(body: _buildTabBar())
  );
}

void main() {
  testWidgets('Tab bar theme overrides label color (selected)', (WidgetTester tester) async {
    const Color dummyColor = Colors.black;
    const TabBarTheme tabBarTheme = TabBarTheme(labelColor: dummyColor);

    await tester.pumpWidget(_withTheme(tabBarTheme));

    final RenderParagraph renderObject = find.text(_tab1Text).evaluate().single.renderObject;
    expect(renderObject.text.style.color, equals(dummyColor));
  });

  testWidgets('Tab bar theme overrides label color (unselected)', (WidgetTester tester) async {
    const Color dummyColor = Colors.black;
    const TabBarTheme tabBarTheme = TabBarTheme(unselectedLabelColor: dummyColor);

    await tester.pumpWidget(_withTheme(tabBarTheme));

    final RenderParagraph renderObject = find.text(_tab2Text).evaluate().single.renderObject;
    expect(renderObject.text.style.color, equals(dummyColor));
  });

  testWidgets('Tab bar theme overrides tab indicator size (tab)', (WidgetTester tester) async {
    const TabBarTheme tabBarTheme = TabBarTheme(indicatorSize: TabBarIndicatorSize.tab);

    await tester.pumpWidget(_withTheme(tabBarTheme));

    await expectLater(
      find.byKey(_painterKey),
      matchesGoldenFile('tab_bar_theme.tab_indicator_size_tab.png'),
      skip: !Platform.isLinux,
    ); // 54 = _kTabHeight(46) + indicatorWeight(8.0)
  });

  testWidgets('Tab bar theme overrides tab indicator size (label)', (WidgetTester tester) async {
    const TabBarTheme tabBarTheme = TabBarTheme(indicatorSize: TabBarIndicatorSize.label);

    await tester.pumpWidget(_withTheme(tabBarTheme));

    await expectLater(
      find.byKey(_painterKey),
      matchesGoldenFile('tab_bar_theme.tab_indicator_size_label.png'),
      skip: !Platform.isLinux,
    ); // 54 = _kTabHeight(46) + indicatorWeight(8.0)
  });

  testWidgets('Tab bar theme - custom tab indicator', (WidgetTester tester) async {
    final TabBarTheme tabBarTheme = TabBarTheme(
      indicator: BoxDecoration(
        border: Border.all(color: Colors.black),
        shape: BoxShape.rectangle,
      )
    );

    await tester.pumpWidget(_withTheme(tabBarTheme));

    await expectLater(
      find.byKey(_painterKey),
      matchesGoldenFile('tab_bar_theme.custom_tab_indicator.png'),
      skip: !Platform.isLinux,
    ); // 54 = _kTabHeight(46) + indicatorWeight(8.0)
  });
}
