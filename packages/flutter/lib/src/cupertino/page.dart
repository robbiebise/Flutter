import 'package:flutter/widgets.dart';

const double _kMinFlingVelocity = 1.0;  // screen width per second

// Used for iOS.
class _CupertinoPageTransition extends AnimatedWidget {
  static final FractionalOffsetTween _kTween = new FractionalOffsetTween(
    begin: FractionalOffset.topRight,
    end: -FractionalOffset.topRight
  );

  _CupertinoPageTransition({
    Key key,
    Animation<double> animation,
    this.child
  }) : super(
    key: key,
    listenable: _kTween.animate(new CurvedAnimation(
      parent: animation,
      curve: new _CupertinoTransitionCurve(null)
    )
  ));

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // TODO(ianh): tell the transform to be un-transformed for hit testing
    // but not while being controlled by a gesture.
    return new SlideTransition(
      position: listenable,
      child: new Material(
        elevation: 6,
        child: child
      )
    );
  }
}

// Custom curve for iOS page transitions.
class _CupertinoTransitionCurve extends Curve {
  _CupertinoTransitionCurve(this.curve);

  Curve curve;

  @override
  double transform(double t) {
    // The input [t] is the average of the current and next route's animation.
    // This means t=0.5 represents when the route is fully onscreen. At
    // t > 0.5, it is partially offscreen to the left (which happens when there
    // is another route on top). At t < 0.5, the route is to the right.
    // We divide the range into two halves, each with a different transition,
    // and scale each half to the range [0.0, 1.0] before applying curves so that
    // each half goes through the full range of the curve.
    if (t > 0.5) {
      // Route is to the left of center.
      t = (t - 0.5) * 2.0;
      if (curve != null)
        t = curve.transform(t);
      t = t / 3.0;
      t = t / 2.0 + 0.5;
    } else {
      // Route is to the right of center.
      if (curve != null)
        t = curve.transform(t * 2.0) / 2.0;
    }
    return t;
  }
}

// This class responds to drag gestures to control the route's transition
// animation progress. Used for iOS back gesture.
class _CupertinoBackGestureController extends NavigationGestureController {
  _CupertinoBackGestureController({
    @required NavigatorState navigator,
    @required this.controller,
    @required this.onDisposed,
  }) : super(navigator) {
    assert(controller != null);
    assert(onDisposed != null);
  }

  AnimationController controller;
  final VoidCallback onDisposed;

  @override
  void dispose() {
    controller.removeStatusListener(handleStatusChanged);
    controller = null;
    onDisposed();
    super.dispose();
  }

  @override
  void dragUpdate(double delta) {
    // This assert can be triggered the Scaffold is reparented out of the route
    // associated with this gesture controller and continues to feed it events.
    // TODO(abarth): Change the ownership of the gesture controller so that the
    // object feeding it these events (e.g., the Scaffold) is responsible for
    // calling dispose on it as well.
    assert(controller != null);
    controller.value -= delta;
  }

  @override
  bool dragEnd(double velocity) {
    // This assert can be triggered the Scaffold is reparented out of the route
    // associated with this gesture controller and continues to feed it events.
    // TODO(abarth): Change the ownership of the gesture controller so that the
    // object feeding it these events (e.g., the Scaffold) is responsible for
    // calling dispose on it as well.
    assert(controller != null);

    if (velocity.abs() >= _kMinFlingVelocity) {
      controller.fling(velocity: -velocity);
    } else if (controller.value <= 0.5) {
      controller.fling(velocity: -1.0);
    } else {
      controller.fling(velocity: 1.0);
    }

    // Don't end the gesture until the transition completes.
    final AnimationStatus status = controller.status;
    handleStatusChanged(status);
    controller?.addStatusListener(handleStatusChanged);

    return (status == AnimationStatus.reverse || status == AnimationStatus.dismissed);
  }

  void handleStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      navigator.pop();
      assert(controller == null);
    } else if (status == AnimationStatus.completed) {
      dispose();
      assert(controller == null);
    }
  }
}
