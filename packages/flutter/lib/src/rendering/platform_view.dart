// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'box.dart';
import 'layer.dart';
import 'object.dart';

/// How an embedded platform view behave during hit tests.
enum PlatformViewHitTestBehavior {
  /// Opaque targets can be hit by hit tests, causing them to both receive
  /// events within their bounds and prevent targets visually behind them from
  /// also receiving events.
  opaque,

  /// Translucent targets both receive events within their bounds and permit
  /// targets visually behind them to also receive events.
  translucent,

  /// Transparent targets don't receive events within their bounds and permit
  /// targets visually behind them to receive events.
  transparent,
}

enum _PlatformViewState {
  uninitialized,
  resizing,
  ready,
}

bool _factoryTypesSetEquals<T>(Set<Factory<T>>? a, Set<Factory<T>>? b) {
  if (a == b) {
    return true;
  }
  if (a == null ||  b == null) {
    return false;
  }
  return setEquals(_factoriesTypeSet(a), _factoriesTypeSet(b));
}

Set<Type> _factoriesTypeSet<T>(Set<Factory<T>> factories) {
  return factories.map<Type>((Factory<T> factory) => factory.type).toSet();
}

/// A render object for an Android view.
///
/// Requires Android API level 20 or greater.
///
/// [RenderAndroidView] is responsible for sizing, displaying and passing touch events to an
/// Android [View](https://developer.android.com/reference/android/view/View).
///
/// {@template flutter.rendering.RenderAndroidView.layout}
/// The render object's layout behavior is to fill all available space, the parent of this object must
/// provide bounded layout constraints.
/// {@endtemplate}
///
/// {@template flutter.rendering.RenderAndroidView.gestures}
/// The render object participates in Flutter's gesture arenas, and dispatches touch events to the
/// platform view iff it won the arena. Specific gestures that should be dispatched to the platform
/// view can be specified with factories in the `gestureRecognizers` constructor parameter or
/// by calling `updateGestureRecognizers`. If the set of gesture recognizers is empty, the gesture
/// will be dispatched to the platform view iff it was not claimed by any other gesture recognizer.
/// {@endtemplate}
///
/// See also:
///
///  * [AndroidView] which is a widget that is used to show an Android view.
///  * [PlatformViewsService] which is a service for controlling platform views.
class RenderAndroidView extends RenderBox with _PlatformViewGestureMixin {
  /// Creates a render object for an Android view.
  RenderAndroidView({
    required AndroidViewController viewController,
    required PlatformViewHitTestBehavior hitTestBehavior,
    required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
    Clip clipBehavior = Clip.hardEdge,
  }) : assert(viewController != null),
       assert(hitTestBehavior != null),
       assert(gestureRecognizers != null),
       assert(clipBehavior != null),
       _viewController = viewController,
       _clipBehavior = clipBehavior {
    _viewController.pointTransformer = (Offset offset) => globalToLocal(offset);
    updateGestureRecognizers(gestureRecognizers);
    _viewController.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
    this.hitTestBehavior = hitTestBehavior;
  }

  _PlatformViewState _state = _PlatformViewState.uninitialized;

  /// The Android view controller for the Android view associated with this render object.
  AndroidViewController get viewController => _viewController;
  AndroidViewController _viewController;
  /// Sets a new Android view controller.
  ///
  /// `viewController` must not be null.
  set viewController(AndroidViewController viewController) {
    assert(_viewController != null);
    assert(viewController != null);
    if (_viewController == viewController)
      return;
    _viewController.removeOnPlatformViewCreatedListener(_onPlatformViewCreated);
    _viewController = viewController;
    _sizePlatformView();
    if (_viewController.isCreated) {
      markNeedsSemanticsUpdate();
    }
    _viewController.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
  }

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge], and must not be null.
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.hardEdge;
  set clipBehavior(Clip value) {
    assert(value != null);
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  void _onPlatformViewCreated(int id) {
    markNeedsSemanticsUpdate();
  }

  /// {@template flutter.rendering.RenderAndroidView.updateGestureRecognizers}
  /// Updates which gestures should be forwarded to the platform view.
  ///
  /// Gesture recognizers created by factories in this set participate in the gesture arena for each
  /// pointer that was put down on the render box. If any of the recognizers on this list wins the
  /// gesture arena, the entire pointer event sequence starting from the pointer down event
  /// will be dispatched to the Android view.
  ///
  /// The `gestureRecognizers` property must not contain more than one factory with the same [Factory.type].
  ///
  /// Setting a new set of gesture recognizer factories with the same [Factory.type]s as the current
  /// set has no effect, because the factories' constructors would have already been called with the previous set.
  /// {@endtemplate}
  ///
  /// Any active gesture arena the Android view participates in is rejected when the
  /// set of gesture recognizers is changed.
  void updateGestureRecognizers(Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers) {
    _updateGestureRecognizersWithCallBack(gestureRecognizers, _viewController.dispatchPointerEvent);
  }

  @override
  bool get sizedByParent => true;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  bool get isRepaintBoundary => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void performResize() {
    super.performResize();
    _sizePlatformView();
  }

  Size? _currentTextureBufferSize;

  Future<void> _sizePlatformView() async {
    // Android virtual displays cannot have a zero size.
    // Trying to size it to 0 crashes the app, which was happening when starting the app
    // with a locked screen (see: https://github.com/flutter/flutter/issues/20456).
    if (_state == _PlatformViewState.resizing || size.isEmpty) {
      return;
    }

    _state = _PlatformViewState.resizing;
    markNeedsPaint();

    Size targetSize;
    do {
      targetSize = size;
      _currentTextureBufferSize = await _viewController.setSize(targetSize);
      // We've resized the platform view to targetSize, but it is possible that
      // while we were resizing the render object's size was changed again.
      // In that case we will resize the platform view again.
    } while (size != targetSize);

    _state = _PlatformViewState.ready;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_viewController.textureId == null)
      return;

    _clipRectLayer.layer = context.pushClipRect(
      true,
      offset,
      offset & size,
      _paintTexture,
      clipBehavior: clipBehavior,
      oldLayer: _clipRectLayer.layer,
    );
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  void _paintTexture(PaintingContext context, Offset offset) {
    if (_currentTextureBufferSize == null)
      return;

    context.addLayer(TextureLayer(
      rect: offset & _currentTextureBufferSize!,
      textureId: _viewController.textureId!,
      freeze: _state == _PlatformViewState.resizing,
    ));
  }

  @override
  void describeSemanticsConfiguration (SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    config.isSemanticBoundary = true;

    if (_viewController.isCreated) {
      config.platformViewId = _viewController.viewId;
    }
  }
}

/// A render object for an iOS UIKit UIView.
///
/// {@template flutter.rendering.RenderUiKitView}
/// Embedding UIViews is still preview-quality. To enable the preview for an iOS app add a boolean
/// field with the key 'io.flutter.embedded_views_preview' and the value set to 'YES' to the
/// application's Info.plist file. A list of open issued with embedding UIViews is available on
/// [Github](https://github.com/flutter/flutter/issues?q=is%3Aopen+is%3Aissue+label%3A%22a%3A+platform-views%22+label%3Aplatform-ios+sort%3Acreated-asc)
/// {@endtemplate}
///
/// [RenderUiKitView] is responsible for sizing and displaying an iOS
/// [UIView](https://developer.apple.com/documentation/uikit/uiview).
///
/// UIViews are added as sub views of the FlutterView and are composited by Quartz.
///
/// {@macro flutter.rendering.RenderAndroidView.layout}
///
/// {@macro flutter.rendering.RenderAndroidView.gestures}
///
/// See also:
///
///  * [UiKitView] which is a widget that is used to show a UIView.
///  * [PlatformViewsService] which is a service for controlling platform views.
class RenderUiKitView extends RenderBox {
  /// Creates a render object for an iOS UIView.
  ///
  /// The `viewId`, `hitTestBehavior`, and `gestureRecognizers` parameters must not be null.
  RenderUiKitView({
    required UiKitViewController viewController,
    required this.hitTestBehavior,
    required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
  }) : assert(viewController != null),
       assert(hitTestBehavior != null),
       assert(gestureRecognizers != null),
       _viewController = viewController {
    updateGestureRecognizers(gestureRecognizers);
  }


  /// The unique identifier of the UIView controlled by this controller.
  ///
  /// Typically generated by [PlatformViewsRegistry.getNextPlatformViewId], the UIView
  /// must have been created by calling [PlatformViewsService.initUiKitView].
  UiKitViewController get viewController => _viewController;
  UiKitViewController _viewController;
  set viewController(UiKitViewController viewController) {
    assert(viewController != null);
    final bool needsSemanticsUpdate = _viewController.id != viewController.id;
    _viewController = viewController;
    markNeedsPaint();
    if (needsSemanticsUpdate) {
      markNeedsSemanticsUpdate();
    }
  }

  /// How to behave during hit testing.
  // The implicit setter is enough here as changing this value will just affect
  // any newly arriving events there's nothing we need to invalidate.
  PlatformViewHitTestBehavior hitTestBehavior;

  /// {@macro flutter.rendering.RenderAndroidView.updateGestureRecognizers}
  void updateGestureRecognizers(Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers) {
    assert(gestureRecognizers != null);
    assert(
      _factoriesTypeSet(gestureRecognizers).length == gestureRecognizers.length,
      'There were multiple gesture recognizer factories for the same type, there must only be a single '
      'gesture recognizer factory for each gesture recognizer type.',
    );
    if (_factoryTypesSetEquals(gestureRecognizers, _gestureRecognizer?.gestureRecognizerFactories)) {
      return;
    }
    _gestureRecognizer?.dispose();
    _gestureRecognizer = _UiKitViewGestureRecognizer(viewController, gestureRecognizers);
  }

  @override
  bool get sizedByParent => true;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  bool get isRepaintBoundary => true;

  _UiKitViewGestureRecognizer? _gestureRecognizer;

  PointerEvent? _lastPointerDownEvent;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.addLayer(PlatformViewLayer(
      rect: offset & size,
      viewId: _viewController.id,
    ));
  }

  @override
  bool hitTest(BoxHitTestResult result, { Offset? position }) {
    if (hitTestBehavior == PlatformViewHitTestBehavior.transparent || !size.contains(position!))
      return false;
    result.add(BoxHitTestEntry(this, position));
    return hitTestBehavior == PlatformViewHitTestBehavior.opaque;
  }

  @override
  bool hitTestSelf(Offset position) => hitTestBehavior != PlatformViewHitTestBehavior.transparent;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is! PointerDownEvent) {
      return;
    }
    _gestureRecognizer!.addPointer(event);
    _lastPointerDownEvent = event.original ?? event;
  }

  // This is registered as a global PointerRoute while the render object is attached.
  void _handleGlobalPointerEvent(PointerEvent event) {
    if (event is! PointerDownEvent) {
      return;
    }
    if (!(Offset.zero & size).contains(globalToLocal(event.position))) {
      return;
    }
    if ((event.original ?? event) != _lastPointerDownEvent) {
      // The pointer event is in the bounds of this render box, but we didn't get it in handleEvent.
      // This means that the pointer event was absorbed by a different render object.
      // Since on the platform side the FlutterTouchIntercepting view is seeing all events that are
      // within its bounds we need to tell it to reject the current touch sequence.
      _viewController.rejectGesture();
    }
    _lastPointerDownEvent = null;
  }

  @override
  void describeSemanticsConfiguration (SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.platformViewId = _viewController.id;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointerEvent);
  }

  @override
  void detach() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalPointerEvent);
    _gestureRecognizer!.reset();
    super.detach();
  }
}

// This recognizer constructs gesture recognizers from a set of gesture recognizer factories
// it was give, adds all of them to a gesture arena team with the _UiKitViewGestureRecognizer
// as the team captain.
// When the team wins a gesture the recognizer notifies the engine that it should release
// the touch sequence to the embedded UIView.
class _UiKitViewGestureRecognizer extends OneSequenceGestureRecognizer {
  _UiKitViewGestureRecognizer(
    this.controller,
    this.gestureRecognizerFactories, {
    Set<PointerDeviceKind>? supportedDevices,
  }) : super(supportedDevices: supportedDevices) {
    team = GestureArenaTeam()
      ..captain = this;
    _gestureRecognizers = gestureRecognizerFactories.map(
      (Factory<OneSequenceGestureRecognizer> recognizerFactory) {
        final OneSequenceGestureRecognizer gestureRecognizer = recognizerFactory.constructor();
        gestureRecognizer.team = team;
        // The below gesture recognizers requires at least one non-empty callback to
        // compete in the gesture arena.
        // https://github.com/flutter/flutter/issues/35394#issuecomment-562285087
        if (gestureRecognizer is LongPressGestureRecognizer) {
          gestureRecognizer.onLongPress ??= (){};
        } else if (gestureRecognizer is DragGestureRecognizer) {
          gestureRecognizer.onDown ??= (_){};
        } else if (gestureRecognizer is TapGestureRecognizer) {
          gestureRecognizer.onTapDown ??= (_){};
        }
        return gestureRecognizer;
      },
    ).toSet();
  }

  // We use OneSequenceGestureRecognizers as they support gesture arena teams.
  // TODO(amirh): get a list of GestureRecognizers here.
  // https://github.com/flutter/flutter/issues/20953
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizerFactories;
  late Set<OneSequenceGestureRecognizer> _gestureRecognizers;

  final UiKitViewController controller;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    for (final OneSequenceGestureRecognizer recognizer in _gestureRecognizers) {
      recognizer.addPointer(event);
    }
  }

  @override
  String get debugDescription => 'UIKit view';

  @override
  void didStopTrackingLastPointer(int pointer) { }

  @override
  void handleEvent(PointerEvent event) {
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void acceptGesture(int pointer) {
    controller.acceptGesture();
  }

  @override
  void rejectGesture(int pointer) {
    controller.rejectGesture();
  }

  void reset() {
    resolve(GestureDisposition.rejected);
  }
}

typedef _HandlePointerEvent = Future<void> Function(PointerEvent event);

// This recognizer constructs gesture recognizers from a set of gesture recognizer factories
// it was give, adds all of them to a gesture arena team with the _PlatformViewGestureRecognizer
// as the team captain.
// As long as the gesture arena is unresolved, the recognizer caches all pointer events.
// When the team wins, the recognizer sends all the cached pointer events to `_handlePointerEvent`, and
// sets itself to a "forwarding mode" where it will forward any new pointer event to `_handlePointerEvent`.
class _PlatformViewGestureRecognizer extends OneSequenceGestureRecognizer {
  _PlatformViewGestureRecognizer(
    _HandlePointerEvent handlePointerEvent,
    this.gestureRecognizerFactories, {
    Set<PointerDeviceKind>? supportedDevices,
  }) : super(supportedDevices: supportedDevices) {
    team = GestureArenaTeam()
      ..captain = this;
    _gestureRecognizers = gestureRecognizerFactories.map(
      (Factory<OneSequenceGestureRecognizer> recognizerFactory) {
        final OneSequenceGestureRecognizer gestureRecognizer = recognizerFactory.constructor();
        gestureRecognizer.team = team;
        // The below gesture recognizers requires at least one non-empty callback to
        // compete in the gesture arena.
        // https://github.com/flutter/flutter/issues/35394#issuecomment-562285087
        if (gestureRecognizer is LongPressGestureRecognizer) {
          gestureRecognizer.onLongPress ??= (){};
        } else if (gestureRecognizer is DragGestureRecognizer) {
          gestureRecognizer.onDown ??= (_){};
        } else if (gestureRecognizer is TapGestureRecognizer) {
          gestureRecognizer.onTapDown ??= (_){};
        }
        return gestureRecognizer;
      },
    ).toSet();
    _handlePointerEvent = handlePointerEvent;
  }

  late _HandlePointerEvent _handlePointerEvent;

  // Maps a pointer to a list of its cached pointer events.
  // Before the arena for a pointer is resolved all events are cached here, if we win the arena
  // the cached events are dispatched to `_handlePointerEvent`, if we lose the arena we clear the cache for
  // the pointer.
  final Map<int, List<PointerEvent>> cachedEvents = <int, List<PointerEvent>>{};

  // Pointer for which we have already won the arena, events for pointers in this set are
  // immediately dispatched to `_handlePointerEvent`.
  final Set<int> forwardedPointers = <int>{};

  // We use OneSequenceGestureRecognizers as they support gesture arena teams.
  // TODO(amirh): get a list of GestureRecognizers here.
  // https://github.com/flutter/flutter/issues/20953
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizerFactories;
  late Set<OneSequenceGestureRecognizer> _gestureRecognizers;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    for (final OneSequenceGestureRecognizer recognizer in _gestureRecognizers) {
      recognizer.addPointer(event);
    }
  }

  @override
  String get debugDescription => 'Platform view';

  @override
  void didStopTrackingLastPointer(int pointer) { }

  @override
  void handleEvent(PointerEvent event) {
    if (!forwardedPointers.contains(event.pointer)) {
      _cacheEvent(event);
    } else {
      _handlePointerEvent(event);
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void acceptGesture(int pointer) {
    _flushPointerCache(pointer);
    forwardedPointers.add(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
    cachedEvents.remove(pointer);
  }

  void _cacheEvent(PointerEvent event) {
    if (!cachedEvents.containsKey(event.pointer)) {
      cachedEvents[event.pointer] = <PointerEvent> [];
    }
    cachedEvents[event.pointer]!.add(event);
  }

  void _flushPointerCache(int pointer) {
    cachedEvents.remove(pointer)?.forEach(_handlePointerEvent);
  }

  @override
  void stopTrackingPointer(int pointer) {
    super.stopTrackingPointer(pointer);
    forwardedPointers.remove(pointer);
  }

  void reset() {
    forwardedPointers.forEach(super.stopTrackingPointer);
    forwardedPointers.clear();
    cachedEvents.keys.forEach(super.stopTrackingPointer);
    cachedEvents.clear();
    resolve(GestureDisposition.rejected);
  }
}

/// A render object for embedding a platform view onto the widget tree.
/// This is the render object of [PlatformViewSurface].
class PlatformViewRenderBox extends RenderBox with _PlatformViewGestureMixin {
  /// Creating a render object for a [PlatformViewSurface].
  PlatformViewRenderBox({
    required PlatformViewController controller,
    required PlatformViewHitTestBehavior hitTestBehavior,
    required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
  }) :  assert(controller != null && controller.viewId != null && controller.viewId > -1),
        assert(hitTestBehavior != null),
        assert(gestureRecognizers != null),
        _controller = controller {
    this.hitTestBehavior = hitTestBehavior;
    updateGestureRecognizers(gestureRecognizers);
    controller.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
    _setOffset();
  }

  bool _useTextureLayer() {
    return _controller is TextureAndroidViewController;
  }

  // Sets the offset of the underlaying platform view on the platform side.
  // When a PlatformViewLayer is used, the offset can be inferred from the
  // transform stack provided by the layer tree.
  void _setOffset() {
    // If a platform view layer is used, the offset is set by the external view embedder
    // in the engine via JNI.
    // TODO(egarciad): Eliminate this case.
    if (!_useTextureLayer())
      return;

    SchedulerBinding.instance!.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _controller.setOffset(localToGlobal(Offset.zero));
        // Schedule a new callback.
        _setOffset();
      }
    });
  }

  /// The controller for this render object.
  PlatformViewController get controller => _controller;
  PlatformViewController _controller;
  /// This value must not be null, and setting it to a new value will result in a repaint.
  set controller(PlatformViewController controller) {
    assert(controller != null);
    assert(controller.viewId != null && controller.viewId > -1);

    if ( _controller == controller)
      return;
    final bool needsSemanticsUpdate = _controller.viewId != controller.viewId;

    _controller.removeOnPlatformViewCreatedListener(_onPlatformViewCreated);
    controller.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
    _controller = controller;
    markNeedsPaint();
    if (needsSemanticsUpdate) {
      markNeedsSemanticsUpdate();
    }
    _sizePlatformView();
  }

  /// {@macro  flutter.rendering.RenderAndroidView.updateGestureRecognizers}
  ///
  /// Any active gesture arena the `PlatformView` participates in is rejected when the
  /// set of gesture recognizers is changed.
  void updateGestureRecognizers(Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers) {
    _updateGestureRecognizersWithCallBack(gestureRecognizers, _controller.dispatchPointerEvent);
  }

  @override
  bool get sizedByParent => true;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  bool get isRepaintBoundary => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  _PlatformViewState _state = _PlatformViewState.uninitialized;

  // Whether this render object has been disposed.
  bool _isDisposed = false;

  // The size of the buffer set in the embedding.
  Size? _currentTextureBufferSize;

  // Clips the [TextureLayer] since the texture layer is only resized when
  // the new requested size is smaller than the current size.
  // This clip layer ensures that this render object has the intended size from
  // a consumer perspective.
  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void performResize() {
    super.performResize();
    _sizePlatformView();
  }

  Future<void> _sizePlatformView() async {
    // This isn't relevant when a PlatformViewLayer is used because the
    // size of the platform view is set by the external view embedder via JNI in the engine.
    // This case should be ultimately removed since the goal is to only have
    // an instance of TextureAndroidViewController.
    // TODO(egarciad): Eliminate this case.
    if (_controller is! TextureAndroidViewController)
      return;

    if (_state == _PlatformViewState.resizing || size.isEmpty)
      return;

    _state = _PlatformViewState.resizing;

    markNeedsPaint();

    Size targetSize;
    do {
      targetSize = size;
      // The buffer size is only resized if the current buffer size is smaller
      // than the new size of this render object.
      _currentTextureBufferSize = await _controller.setSize(targetSize);
      // We've resized the platform view to targetSize, but it is possible that
      // while we were resizing the render object's size was changed again.
      // In that case we will resize the platform view again.
    } while (size != targetSize);

    _state = _PlatformViewState.ready;
    markNeedsPaint();
  }

  void _onPlatformViewCreated(int id) {
    markNeedsSemanticsUpdate();
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_useTextureLayer()) {
      _clipRectLayer.layer = context.pushClipRect(
        true,
        offset,
        offset & size,
        _paintTexture,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      assert(_controller.viewId != null);
      context.addLayer(PlatformViewLayer(
        rect: offset & size,
        viewId: _controller.viewId,
      ));
    }
  }

  void _paintTexture(PaintingContext context, Offset offset) {
    final int? textureId = (_controller as TextureAndroidViewController).textureId;
    if (textureId == null || _currentTextureBufferSize == null)
      return;

    context.addLayer(TextureLayer(
      rect: offset & _currentTextureBufferSize!,
      textureId: textureId,
    ));
  }

  @override
  void dispose() {
    _isDisposed = true;
    _clipRectLayer.layer = null;
    super.dispose();
  }


  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    assert(_controller.viewId != null);
    config.isSemanticBoundary = true;
    config.platformViewId = _controller.viewId;
  }
}

/// The Mixin handling the pointer events and gestures of a platform view render box.
mixin _PlatformViewGestureMixin on RenderBox implements MouseTrackerAnnotation {

  /// How to behave during hit testing.
  // Changing _hitTestBehavior might affect which objects are considered hovered over.
  set hitTestBehavior(PlatformViewHitTestBehavior value) {
    if (value != _hitTestBehavior) {
      _hitTestBehavior = value;
      if (owner != null)
        markNeedsPaint();
    }
  }
  PlatformViewHitTestBehavior? _hitTestBehavior;

  _HandlePointerEvent? _handlePointerEvent;

  /// {@macro  flutter.rendering.RenderAndroidView.updateGestureRecognizers}
  ///
  /// Any active gesture arena the `PlatformView` participates in is rejected when the
  /// set of gesture recognizers is changed.
  void _updateGestureRecognizersWithCallBack(Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers, _HandlePointerEvent handlePointerEvent) {
    assert(gestureRecognizers != null);
    assert(
      _factoriesTypeSet(gestureRecognizers).length == gestureRecognizers.length,
      'There were multiple gesture recognizer factories for the same type, there must only be a single '
      'gesture recognizer factory for each gesture recognizer type.',
    );
    if (_factoryTypesSetEquals(gestureRecognizers, _gestureRecognizer?.gestureRecognizerFactories)) {
      return;
    }
    _gestureRecognizer?.dispose();
    _gestureRecognizer = _PlatformViewGestureRecognizer(handlePointerEvent, gestureRecognizers);
    _handlePointerEvent = handlePointerEvent;
  }

  _PlatformViewGestureRecognizer? _gestureRecognizer;

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    if (_hitTestBehavior == PlatformViewHitTestBehavior.transparent || !size.contains(position)) {
      return false;
    }
    result.add(BoxHitTestEntry(this, position));
    return _hitTestBehavior == PlatformViewHitTestBehavior.opaque;
  }

  @override
  bool hitTestSelf(Offset position) => _hitTestBehavior != PlatformViewHitTestBehavior.transparent;

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => null;

  @override
  MouseCursor get cursor => MouseCursor.uncontrolled;

  @override
  bool get validForMouseTracker => true;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) {
      _gestureRecognizer!.addPointer(event);
    }
    if (event is PointerHoverEvent) {
      _handlePointerEvent?.call(event);
    }
  }

  @override
  void detach() {
    _gestureRecognizer!.reset();
    super.detach();
  }
}
