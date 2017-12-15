// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show SemanticsFlags;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

export 'package:flutter/rendering.dart' show SemanticsData;

const String _matcherHelp = 'Try dumping the semantics with debugDumpSemanticsTree(DebugSemanticsDumpOrder.inverseHitTest) from the package:flutter/rendering.dart library to see what the semantics tree looks like.';

/// Test semantics data that is compared against real semantics tree.
///
/// Useful with [hasSemantics] and [SemanticsTester] to test the contents of the
/// semantics tree.
class TestSemantics {
  /// Creates an object with some test semantics data.
  ///
  /// The [id] field is required. The root node has an id of zero. Other nodes
  /// are given a unique id when they are created, in a predictable fashion, and
  /// so these values can be hard-coded.
  ///
  /// The [rect] field is required and has no default. Convenient values are
  /// available:
  ///
  ///  * [TestSemantics.rootRect]: 2400x1600, the test screen's size in physical
  ///    pixels, useful for the node with id zero.
  ///
  ///  * [TestSemantics.fullScreen] 800x600, the test screen's size in logical
  ///    pixels, useful for other full-screen widgets.
  TestSemantics({
    this.id,
    this.flags: 0,
    this.actions: 0,
    this.label: '',
    this.value: '',
    this.increasedValue: '',
    this.decreasedValue: '',
    this.hint: '',
    this.textDirection,
    this.rect,
    this.transform,
    this.children: const <TestSemantics>[],
    Iterable<SemanticsTag> tags,
  }) : assert(flags is int || flags is List<SemanticsFlags>),
       assert(actions is int || actions is List<SemanticsAction>),
       assert(label != null),
       assert(value != null),
       assert(increasedValue != null),
       assert(decreasedValue != null),
       assert(hint != null),
       assert(children != null),
       tags = tags?.toSet() ?? new Set<SemanticsTag>();

  /// Creates an object with some test semantics data, with the [id] and [rect]
  /// set to the appropriate values for the root node.
  TestSemantics.root({
    this.flags: 0,
    this.actions: 0,
    this.label: '',
    this.value: '',
    this.increasedValue: '',
    this.decreasedValue: '',
    this.hint: '',
    this.textDirection,
    this.transform,
    this.children: const <TestSemantics>[],
    Iterable<SemanticsTag> tags,
  }) : id = 0,
       assert(flags is int || flags is List<SemanticsFlags>),
       assert(actions is int || actions is List<SemanticsAction>),
       assert(label != null),
       assert(increasedValue != null),
       assert(decreasedValue != null),
       assert(value != null),
       assert(hint != null),
       rect = TestSemantics.rootRect,
       assert(children != null),
       tags = tags?.toSet() ?? new Set<SemanticsTag>();

  /// Creates an object with some test semantics data, with the [id] and [rect]
  /// set to the appropriate values for direct children of the root node.
  ///
  /// The [transform] is set to a 3.0 scale (to account for the
  /// [Window.devicePixelRatio] being 3.0 on the test pseudo-device).
  ///
  /// The [rect] field is required and has no default. The
  /// [TestSemantics.fullScreen] property may be useful as a value; it describes
  /// an 800x600 rectangle, which is the test screen's size in logical pixels.
  TestSemantics.rootChild({
    this.id,
    this.flags: 0,
    this.actions: 0,
    this.label: '',
    this.hint: '',
    this.value: '',
    this.increasedValue: '',
    this.decreasedValue: '',
    this.textDirection,
    this.rect,
    Matrix4 transform,
    this.children: const <TestSemantics>[],
    Iterable<SemanticsTag> tags,
  }) : assert(flags is int || flags is List<SemanticsFlags>),
       assert(actions is int || actions is List<SemanticsAction>),
       assert(label != null),
       assert(value != null),
       assert(increasedValue != null),
       assert(decreasedValue != null),
       assert(hint != null),
       transform = _applyRootChildScale(transform),
       assert(children != null),
       tags = tags?.toSet() ?? new Set<SemanticsTag>();

  /// The unique identifier for this node.
  ///
  /// The root node has an id of zero. Other nodes are given a unique id when
  /// they are created.
  final int id;

  /// The [SemanticsFlags] set on this node.
  ///
  /// There are two ways to specify this property: as an `int` that encodes the
  /// flags as a bit field, or as a `List<SemanticsFlags>` that are _on_.
  ///
  /// Using `List<SemanticsFlags>` is recommended due to better readability.
  final dynamic flags;

  /// The [SemanticsAction]s set on this node.
  ///
  /// There are two ways to specify this property: as an `int` that encodes the
  /// actions as a bit field, or as a `List<SemanticsAction>`.
  ///
  /// Using `List<SemanticsAction>` is recommended due to better readability.
  ///
  /// The tester does not check the function corresponding to the action, but
  /// only its existence.
  final dynamic actions;

  /// A textual description of this node.
  final String label;

  /// A textual description for the value of this node.
  final String value;

  /// What [value] will become after [SemanticsAction.increase] has been
  /// performed.
  final String increasedValue;

  /// What [value] will become after [SemanticsAction.decrease] has been
  /// performed.
  final String decreasedValue;

  /// A brief textual description of the result of the action that can be
  /// performed on this node.
  final String hint;

  /// The reading direction of the [label].
  ///
  /// Even if this is not set, the [hasSemantics] matcher will verify that if a
  /// label is present on the [SemanticsNode], a [SemanticsNode.textDirection]
  /// is also set.
  final TextDirection textDirection;

  /// The bounding box for this node in its coordinate system.
  ///
  /// Convenient values are available:
  ///
  ///  * [TestSemantics.rootRect]: 2400x1600, the test screen's size in physical
  ///    pixels, useful for the node with id zero.
  ///
  ///  * [TestSemantics.fullScreen] 800x600, the test screen's size in logical
  ///    pixels, useful for other full-screen widgets.
  final Rect rect;

  /// The test screen's size in physical pixels, typically used as the [rect]
  /// for the node with id zero.
  ///
  /// See also [new TestSemantics.root], which uses this value to describe the
  /// root node.
  static final Rect rootRect = new Rect.fromLTWH(0.0, 0.0, 2400.0, 1800.0);

  /// The test screen's size in logical pixels, useful for the [rect] of
  /// full-screen widgets other than the root node.
  static final Rect fullScreen = new Rect.fromLTWH(0.0, 0.0, 800.0, 600.0);

  /// The transform from this node's coordinate system to its parent's coordinate system.
  ///
  /// By default, the transform is null, which represents the identity
  /// transformation (i.e., that this node has the same coordinate system as its
  /// parent).
  final Matrix4 transform;

  static Matrix4 _applyRootChildScale(Matrix4 transform) {
    final Matrix4 result = new Matrix4.diagonal3Values(3.0, 3.0, 1.0);
    if (transform != null)
      result.multiply(transform);
    return result;
  }

  /// The children of this node.
  final List<TestSemantics> children;

  /// The tags of this node.
  final Set<SemanticsTag> tags;

  bool _matches(SemanticsNode node, Map<dynamic, dynamic> matchState, { bool ignoreRect: false, bool ignoreTransform: false, bool ignoreId: false }) {
    final SemanticsData nodeData = node.getSemanticsData();

    bool fail(String message) {
      matchState[TestSemantics] = '$message';
      return false;
    }

    if (node == null)
      return fail('could not find node with id $id.');
    if (!ignoreId && id != node.id)
      return fail('expected node id $id but found id ${node.id}.');

    final int flagsBitmask = flags is int
      ? flags
      : flags.fold<int>(0, (int bitmask, SemanticsFlags flag) => bitmask | flag.index);
    if (flagsBitmask != nodeData.flags)
      return fail('expected node id $id to have flags $flags but found flags ${nodeData.flags}.');

    final int actionsBitmask = actions is int
        ? actions
        : actions.fold<int>(0, (int bitmask, SemanticsAction action) => bitmask | action.index);
    if (actionsBitmask != nodeData.actions)
      return fail('expected node id $id to have actions $actions but found actions ${nodeData.actions}.');

    if (label != nodeData.label)
      return fail('expected node id $id to have label "$label" but found label "${nodeData.label}".');
    if (value != nodeData.value)
      return fail('expected node id $id to have value "$value" but found value "${nodeData.value}".');
    if (increasedValue != nodeData.increasedValue)
      return fail('expected node id $id to have increasedValue "$increasedValue" but found value "${nodeData.increasedValue}".');
    if (decreasedValue != nodeData.decreasedValue)
      return fail('expected node id $id to have decreasedValue "$decreasedValue" but found value "${nodeData.decreasedValue}".');
    if (hint != nodeData.hint)
      return fail('expected node id $id to have hint "$hint" but found hint "${nodeData.hint}".');
    if (textDirection != null && textDirection != nodeData.textDirection)
      return fail('expected node id $id to have textDirection "$textDirection" but found "${nodeData.textDirection}".');
    if ((nodeData.label != '' || nodeData.value != '' || nodeData.hint != '' || node.increasedValue != '' || node.decreasedValue != '') && nodeData.textDirection == null)
      return fail('expected node id $id, which has a label, value, or hint, to have a textDirection, but it did not.');
    if (!ignoreRect && rect != nodeData.rect)
      return fail('expected node id $id to have rect $rect but found rect ${nodeData.rect}.');
    if (!ignoreTransform && transform != nodeData.transform)
      return fail('expected node id $id to have transform $transform but found transform:\n${nodeData.transform}.');
    final int childrenCount = node.mergeAllDescendantsIntoThisNode ? 0 : node.childrenCount;
    if (children.length != childrenCount)
      return fail('expected node id $id to have ${children.length} child${ children.length == 1 ? "" : "ren" } but found $childrenCount.');

    if (children.isEmpty)
      return true;
    bool result = true;
    final Iterator<TestSemantics> it = children.iterator;
    node.visitChildren((SemanticsNode node) {
      it.moveNext();
      if (!it.current._matches(node, matchState, ignoreRect: ignoreRect, ignoreTransform: ignoreTransform, ignoreId: ignoreId)) {
        result = false;
        return false;
      }
      return true;
    });
    return result;
  }

  @override
  String toString([int indentAmount = 0]) {
    final String indent = '  ' * indentAmount;
    final StringBuffer buf = new StringBuffer();
    buf.writeln('$indent$runtimeType {');
    if (id != null)
      buf.writeln('$indent  id: $id');
    buf.writeln('$indent  flags: $flags');
    buf.writeln('$indent  actions: $actions');
    if (label != null)
      buf.writeln('$indent  label: "$label"');
    if (textDirection != null)
      buf.writeln('$indent  textDirection: $textDirection');
    if (rect != null)
      buf.writeln('$indent  rect: $rect');
    if (transform != null)
      buf.writeln('$indent  transform:\n${transform.toString().trim().split('\n').map((String line) => '$indent    $line').join('\n')}');
    buf.writeln('$indent  children: [');
    for (TestSemantics child in children) {
      buf.writeln(child.toString(indentAmount + 2));
    }
    buf.writeln('$indent  ]');
    buf.write('$indent}');
    return buf.toString();
  }
}

/// Ensures that the given widget tester has a semantics tree to test.
///
/// Useful with [hasSemantics] to test the contents of the semantics tree.
class SemanticsTester {
  /// Creates a semantics tester for the given widget tester.
  ///
  /// You should call [dispose] at the end of a test that creates a semantics
  /// tester.
  SemanticsTester(this.tester) {
    _semanticsHandle = tester.binding.pipelineOwner.ensureSemantics();
  }

  /// The widget tester that this object is testing the semantics of.
  final WidgetTester tester;
  SemanticsHandle _semanticsHandle;

  /// Release resources held by this semantics tester.
  ///
  /// Call this function at the end of any test that uses a semantics tester.
  @mustCallSuper
  void dispose() {
    _semanticsHandle.dispose();
    _semanticsHandle = null;
  }

  @override
  String toString() => 'SemanticsTester for ${tester.binding.pipelineOwner.semanticsOwner.rootSemanticsNode}';

  Iterable<SemanticsNode> nodesWith({
    String label,
    String value,
    TextDirection textDirection,
    List<SemanticsAction> actions,
    List<SemanticsFlags> flags,
  }) {
    bool checkNode(SemanticsNode node) {
      if (label != null && node.label != label)
        return false;
      if (value != null && node.value != value)
        return false;
      if (textDirection != null && node.textDirection != textDirection)
        return false;
      if (actions != null) {
        final int expectedActions = actions.fold(0, (int value, SemanticsAction action) => value | action.index);
        final int actualActions = node.getSemanticsData().actions;
        if (expectedActions != actualActions)
          return false;
      }
      if (flags != null) {
        final int expectedFlags = flags.fold(0, (int value, SemanticsFlags flag) => value | flag.index);
        final int actualFlags = node.getSemanticsData().flags;
        if (expectedFlags != actualFlags)
          return false;
      }
      return true;
    }

    final List<SemanticsNode> result = <SemanticsNode>[];
    bool visit(SemanticsNode node) {
      if (checkNode(node)) {
        result.add(node);
      }
      node.visitChildren(visit);
      return true;
    }
    visit(tester.binding.pipelineOwner.semanticsOwner.rootSemanticsNode);
    return result;
  }

  /// Generates an expression that creates a [TestSemantics] reflecting the
  /// current tree of [SemanticsNode]s.
  ///
  /// Use this method to generate code for unit tests. It works similar to
  /// screenshot testing. The very first time you add semantics to a widget you
  /// verify manually that the widget behaves correctly. You then use ths method
  /// to generate test code for this widget.
  ///
  /// Example:
  ///
  /// ```dart
  /// testWidgets('generate code for MyWidget', (WidgetTester tester) async {
  ///   var semantics = new SemanticsTester(tester);
  ///   await tester.pumpWidget(new MyWidget());
  ///   print(semantics.generateTestSemanticsExpressionForCurrentSemanticsTree());
  ///   semantics.dispose();
  /// });
  /// ```
  ///
  /// You can now copy the code printed to the console into a unit test:
  ///
  /// ```dart
  /// testWidgets('generate code for MyWidget', (WidgetTester tester) async {
  ///   var semantics = new SemanticsTester(tester);
  ///   await tester.pumpWidget(new MyWidget());
  ///   expect(semantics, hasSemantics(
  ///     // Generated code:
  ///     new TestSemantics(
  ///       ... properties and child nodes ...
  ///     ),
  ///     ignoreRect: true,
  ///     ignoreTransform: true,
  ///     ignoreId: true,
  ///   ));
  ///   semantics.dispose();
  /// });
  ///
  /// At this point the unit test should automatically pass because it was
  /// generated from the actual [SemanticsNode]s. Next time the semantics tree
  /// changes, the test code may either be updated manually, or regenerated and
  /// replaced using this method again.
  ///
  /// Avoid submitting huge piles of generated test code. This will make test
  /// code hard to review and it will make it tempting to regenerate test code
  /// every time and ignore potential regressions. Make sure you do not
  /// over-test. Prefer breaking your widgets into smaller widgets and test them
  /// individually.
  String generateTestSemanticsExpressionForCurrentSemanticsTree() {
    final SemanticsNode node = tester.binding.pipelineOwner.semanticsOwner.rootSemanticsNode;
    return _generateSemanticsTestForNode(node, 0);
  }

  String _flagsToSemanticsFlagsExpression(int bitmap) {
    return SemanticsFlags.values.values
        .where((SemanticsFlags flag) => (flag.index & bitmap) != 0)
        .join(', ');
  }

  String _actionsToSemanticsActionExpression(int bitmap) {
    return SemanticsAction.values.values
        .where((SemanticsAction action) => (action.index & bitmap) != 0)
        .join(', ');
  }

  /// Recursively generates [TestSemantics] code for [node] and its children,
  /// indenting the expression by `indentAmount`.
  String _generateSemanticsTestForNode(SemanticsNode node, int indentAmount) {
    final String indent = '  ' * indentAmount;
    final StringBuffer buf = new StringBuffer();
    final SemanticsData nodeData = node.getSemanticsData();
    buf.writeln('new TestSemantics(');
    if (nodeData.flags != 0)
      buf.writeln('  flags: <SemanticsFlags>[${_flagsToSemanticsFlagsExpression(nodeData.flags)}],');
    if (nodeData.actions != 0)
      buf.writeln('  actions: <SemanticsAction>[${_actionsToSemanticsActionExpression(nodeData.actions)}],');
    if (node.label != null && node.label.isNotEmpty)
      buf.writeln('  label: r\'${node.label}\',');
    if (node.value != null && node.value.isNotEmpty)
      buf.writeln('  value: r\'${node.value}\',');
    if (node.increasedValue != null && node.increasedValue.isNotEmpty)
      buf.writeln('  increasedValue: r\'${node.increasedValue}\',');
    if (node.decreasedValue != null && node.decreasedValue.isNotEmpty)
      buf.writeln('  decreasedValue: r\'${node.decreasedValue}\',');
    if (node.hint != null && node.hint.isNotEmpty)
      buf.writeln('  hint: r\'${node.hint}\',');
    if (node.textDirection != null)
      buf.writeln('  textDirection: ${node.textDirection},');

    if (node.hasChildren) {
      buf.writeln('  children: <TestSemantics>[');
      node.visitChildren((SemanticsNode child) {
        buf
          ..write(_generateSemanticsTestForNode(child, 2))
          ..writeln(',');
        return true;
      });
      buf.writeln('  ],');
    }

    buf.write(')');
    return buf.toString().split('\n').map((String l) => '$indent$l').join('\n');
  }
}

class _HasSemantics extends Matcher {
  const _HasSemantics(this._semantics, { this.ignoreRect: false, this.ignoreTransform: false, this.ignoreId: false }) : assert(_semantics != null), assert(ignoreRect != null), assert(ignoreId != null), assert(ignoreTransform != null);

  final TestSemantics _semantics;
  final bool ignoreRect;
  final bool ignoreTransform;
  final bool ignoreId;

  @override
  bool matches(covariant SemanticsTester item, Map<dynamic, dynamic> matchState) {
    return _semantics._matches(item.tester.binding.pipelineOwner.semanticsOwner.rootSemanticsNode, matchState, ignoreTransform: ignoreTransform, ignoreRect: ignoreRect, ignoreId: ignoreId);
  }

  @override
  Description describe(Description description) {
    return description.add('semantics node matching:\n$_semantics');
  }

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription, Map<dynamic, dynamic> matchState, bool verbose) {
    return mismatchDescription
        .add('${matchState[TestSemantics]}\n')
        .add(
          'Current SemanticsNode tree:\n'
        )
        .add(RendererBinding.instance?.renderView?.debugSemantics?.toStringDeep(childOrder: DebugSemanticsDumpOrder.inverseHitTest));
  }
}

/// Asserts that a [SemanticsTester] has a semantics tree that exactly matches the given semantics.
Matcher hasSemantics(TestSemantics semantics, {
  bool ignoreRect: false,
  bool ignoreTransform: false,
  bool ignoreId: false,
}) => new _HasSemantics(semantics, ignoreRect: ignoreRect, ignoreTransform: ignoreTransform, ignoreId: ignoreId);

class _IncludesNodeWith extends Matcher {
  const _IncludesNodeWith({
    this.label,
    this.value,
    this.textDirection,
    this.actions,
    this.flags,
}) : assert(label != null || value != null || actions != null || flags != null);

  final String label;
  final String value;
  final TextDirection textDirection;
  final List<SemanticsAction> actions;
  final List<SemanticsFlags> flags;

  @override
  bool matches(covariant SemanticsTester item, Map<dynamic, dynamic> matchState) {
    return item.nodesWith(
      label: label,
      value: value,
      textDirection: textDirection,
      actions: actions,
      flags: flags,
    ).isNotEmpty;
  }

  @override
  Description describe(Description description) {
    return description.add('includes node with $_configAsString');
  }

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription, Map<dynamic, dynamic> matchState, bool verbose) {
    return mismatchDescription.add('could not find node with $_configAsString.\n$_matcherHelp');
  }

  String get _configAsString {
    final List<String> strings = <String>[];
    if (label != null)
      strings.add('label "$label"');
    if (value != null)
      strings.add('value "$value"');
    if (textDirection != null)
      strings.add(' (${describeEnum(textDirection)})');
    if (actions != null)
      strings.add('actions "${actions.join(', ')}"');
    if (flags != null)
      strings.add('flags "${flags.join(', ')}"');
    return strings.join(', ');
  }
}

/// Asserts that a node in the semantics tree of [SemanticsTester] has `label`,
/// `textDirection`, and `actions`.
///
/// If null is provided for an argument, it will match against any value.
Matcher includesNodeWith({
  String label,
  String value,
  TextDirection textDirection,
  List<SemanticsAction> actions,
  List<SemanticsFlags> flags,
}) {
  return new _IncludesNodeWith(
    label: label,
    value: value,
    textDirection: textDirection,
    actions: actions,
    flags: flags,
  );
}
