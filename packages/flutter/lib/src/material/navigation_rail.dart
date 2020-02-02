import 'package:flutter/material.dart';

/// Defines the behavior of the labels of a [NavigationRail].
///
/// See also:
///
///   * [NavigationRail]
enum NavigationRailLabelType {
  /// Only the icons of a navigation rail item are shown.
  none,

  /// Only the selected navigation rail item will show its label.
  ///
  /// The label will animate in and out as new items are selected.
  selected,

  /// All navigation rail items will show their label.
  all,
}

/// Defines the alignment for the group of [NavigationRailDestination]s within
/// a [NavigationRail].
///
/// Navigation rail destinations can be aligned as a group to the [top],
/// [bottom], or [center] of a layout.
enum NavigationRailGroupAlignment {
  /// Place the [NavigationRailDestination]s at the top of the rail.
  top,

  /// Place the [NavigationRailDestination]s in the center of the rail.
  center,

  /// Place the [NavigationRailDestination]s at the bottom of the rail.
  bottom,
}

/// A description for an interactive button within a [NavigationRail].
///
/// See also:
///
///  * [NavigationRail]
class NavigationRailDestination {
  /// Creates an destination that is used with [NavigationRail.destinations].
  ///
  /// [icon] should not be null and [label] should not be null when this
  /// destination is used in the [NavigationRail].
  const NavigationRailDestination({
    @required this.icon,
    Widget activeIcon,
    this.label,
  }) : activeIcon = activeIcon ?? icon,
        assert(icon != null);
  /// The icon of the destination.
  ///
  /// Typically the icon is an [Icon] or an [ImageIcon] widget. If another type
  /// of widget is provided then it should configure itself to match the current
  /// [IconTheme] size and color.
  ///
  /// If [activeIcon] is provided, this will only be displayed when the
  /// destination is not selected.
  ///
  /// To make the [NavigationRail] more accessible, consider choosing an
  /// icon with a stroked and filled version, such as [Icons.cloud] and
  /// [Icons.cloud_queue]. [icon] should be set to the stroked version and
  /// [activeIcon] to the filled version.
  final Widget icon;

  /// An alternative icon displayed when this destination is selected.
  ///
  /// If this icon is not provided, the [NavigationRail] will display [icon] in
  /// either state.
  ///
  /// See also:
  ///
  ///  * [NavigationRailDestination.icon], for a description of how to pair
  ///    icons.
  final Widget activeIcon;

  /// The label for the destination.
  ///
  /// The label should be provided when used with the [NavigationRail], unless
  /// [NavigationRailLabelType.none] used and the rail will not be extended.
  final Widget label;
}

class _ExtendedNavigationRailAnimation extends InheritedWidget {
  const _ExtendedNavigationRailAnimation({
    Key key,
    @required this.animation,
    @required Widget child,
  }) : assert(child != null),
       super(key: key, child: child);

  final Animation<double> animation;

  static _ExtendedNavigationRailAnimation of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ExtendedNavigationRailAnimation>();
  }

  @override
  bool updateShouldNotify(_ExtendedNavigationRailAnimation old) => animation != old.animation;
}

/// TODO
class NavigationRail extends StatefulWidget {
  /// TODO
  NavigationRail({
    this.extended,
    this.leading,
    this.trailing,
    this.destinations,
    this.currentIndex,
    this.onDestinationSelected,
    this.groupAlignment = NavigationRailGroupAlignment.top,
    this.labelType = NavigationRailLabelType.none,
    this.labelTextStyle,
    this.selectedLabelTextStyle,
    this.iconTheme,
    this.selectedIconTheme,
    this.backgroundColor,
    this.extendedWidth = _extendedRailWidth,
  }) : assert(extendedWidth >= _railWidth);

  /// Indicates of the [NavigationRail] should be in the extended state.
  ///
  /// The rail will implicitly animate between the extended and normal state.
  ///
  /// If the rail is going to be in the extended state, then the [labelType]
  /// should be set to [NavigationRailLabelType.none].
  final bool extended;

  /// The leading widget in the rail that is placed above the destinations.
  ///
  /// This is commonly a [FloatingActionButton], but may also be a non-button,
  /// such as a logo.
  final Widget leading;

  /// The trailing widget in the rail that is placed below the destinations.
  ///
  /// This is commonly a list of additional options or destinations that is
  /// usually only rendered when [extended] is true.
  final Widget trailing;

  /// Defines the appearance of the button items that are arrayed within the
  /// navigation rail.
  final List<NavigationRailDestination> destinations;

  /// The index into [destinations] for the current active [NavigationRailDestination].
  final int currentIndex;

  /// Called when one of the [destinations] is selected.
  ///
  /// The stateful widget that creates the navigation rail needs to keep
  /// track of the index of the selected [NavigationRailDestination] and call
  /// `setState` to rebuild the navigation rail with the new [currentIndex].
  final ValueChanged<int> onDestinationSelected;

  /// The alignment for the [NavigationRailDestination]s as they are positioned
  /// within the [NavigationRail].
  ///
  /// Navigation rail destinations can be aligned as a group to the [top],
  /// [bottom], or [center] of a layout.
  final NavigationRailGroupAlignment groupAlignment;

  /// Defines the layout and behavior of the labels in the [NavigationRail].
  ///
  /// See also:
  ///
  ///   * [NavigationRailLabelType] for information on the meaning of different
  ///   types.
  final NavigationRailLabelType labelType;

  /// The [TextStyle] of the [NavigationRailDestination] labels.
  ///
  /// This is the default [TextStyle] for all labels. When the
  /// [NavigationRailDestination] is selected, the [selectedLabelTextStyle] will be
  /// used instead.
  final TextStyle labelTextStyle;

  /// The [TextStyle] of the [NavigationRailDestination] labels when they are
  /// selected.
  ///
  /// This field overrides the [labelTextStyle] for selected items.
  ///
  /// When the [NavigationRailDestination] is not selected, [labelTextStyle] will be
  /// used.
  final TextStyle selectedLabelTextStyle;

  /// The default size, opacity, and color of the icon in the
  /// [NavigationRailDestination].
  ///
  /// If this field is not provided, or provided with any null properties, then
  ///a copy of the [IconThemeData.fallback] with a custom [NavigationRail]
  /// specific color will be used.
  final IconTheme iconTheme;

  /// The size, opacity, and color of the icon in the selected
  /// [NavigationRailDestination].
  ///
  /// This field overrides the [iconTheme] for selected items.
  ///
  /// When the [NavigationRailDestination] is not selected, [iconTheme] will be
  /// used.
  final IconTheme selectedIconTheme;

  /// Sets the color of the Container that holds all of the [NavigationRail]'s
  /// contents.
  final Color backgroundColor;

  /// The final width when the animation is complete for setting [extended] to
  /// true.
  ///
  /// The default value is 256.
  final double extendedWidth;

  /// Returns the animation that controls the [NavigationRail.extended] state.
  ///
  /// This can be used to synchronize animations in the [leading] or [trailing]
  /// widget, such as an animated menu or a [FloatingActionButton] animation.
  static Animation<double> extendedAnimation(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ExtendedNavigationRailAnimation>().animation;
  }

  @override
  _NavigationRailState createState() => _NavigationRailState();
}

class _NavigationRailState extends State<NavigationRail> with TickerProviderStateMixin {
  List<AnimationController> _destinationControllers = <AnimationController>[];
  List<Animation<double>> _destinationAnimations;

  AnimationController _extendedController;
  Animation<double> _extendedAnimation;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  void didUpdateWidget(NavigationRail oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.extended != oldWidget.extended) {
      if (widget.extended) {
        _extendedController.forward();
      } else {
        _extendedController.reverse();
      }
    }

    // No animated segue if the length of the items list changes.
    if (widget.destinations.length != oldWidget.destinations.length) {
      _resetState();
      return;
    }

    if (widget.currentIndex != oldWidget.currentIndex) {
      _destinationControllers[oldWidget.currentIndex].reverse();
      _destinationControllers[widget.currentIndex].forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget leading = widget.leading;
    final Widget trailing = widget.trailing;
    final double currentWidth = _railWidth + (widget.extendedWidth - _railWidth) * _extendedAnimation.value;
    final MainAxisAlignment destinationsAlignemnt = _resolveMainAxisAlignment();
    return _ExtendedNavigationRailAnimation(
      animation: _extendedAnimation,
      child: DefaultTextStyle(
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
        child: Container(
          width: currentWidth,
          color: widget.backgroundColor ?? Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _verticalSpacing,
              if (leading != null)
                ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(_spacing),
                    child: leading,
                  ),
                  _verticalSpacing,
                ],
              Expanded(
                child: Column(
                  mainAxisAlignment: destinationsAlignemnt,
                  children: <Widget>[
                    for (int i = 0; i < widget.destinations.length; i++)
                      _RailDestinationBox(
                        animation: _destinationAnimations[i],
                        labelKind: widget.labelType,
                        selected: widget.currentIndex == i,
                        icon: widget.currentIndex == i
                            ? widget.destinations[i].activeIcon
                            : widget.destinations[i].icon,
                        label: DefaultTextStyle(
                          style: TextStyle(
                              color: widget.currentIndex == i
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.64)),
                          child: widget.destinations[i].label,
                        ),
                        onTap: () {
                          widget.onDestinationSelected(i);
                        },
                        extended: _extendedAnimation.value > 0,
                        width: _railWidth,
                        height: _railWidth,
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  MainAxisAlignment _resolveMainAxisAlignment() {
    switch (widget.groupAlignment) {
      case NavigationRailGroupAlignment.top:
        return MainAxisAlignment.start;
      case NavigationRailGroupAlignment.center:
        return MainAxisAlignment.center;
      case NavigationRailGroupAlignment.bottom:
        return MainAxisAlignment.end;
    }
    return MainAxisAlignment.start;
  }

  void _disposeControllers() {
    for (final AnimationController controller in _destinationControllers)
      controller.dispose();
    _extendedController.dispose();
  }

  void _initControllers() {
    _destinationControllers = List<AnimationController>.generate(widget.destinations.length, (int index) {
      return AnimationController(
        duration: kThemeAnimationDuration,
        vsync: this,
      )..addListener(_rebuild);
    });
    _destinationAnimations = _destinationControllers.map((AnimationController controller) => controller.view).toList();
    _destinationControllers[widget.currentIndex].value = 1.0;
    _extendedController = AnimationController(
      duration: kThemeAnimationDuration,
      vsync: this,

    );
    _extendedAnimation = CurvedAnimation(
      parent: _extendedController,
      curve: Curves.easeInOut,
    );
    _extendedController.addListener(() {
      setState(() {
        // Rebuild.
      });
    });
  }

  void _resetState() {
    _disposeControllers();
    _initControllers();
  }

  void _rebuild() {
    setState(() {
      // Rebuilding when any of the controllers tick, i.e. when the items are
      // animated.
    });
  }
}

class _RailDestinationBox extends StatelessWidget {
  _RailDestinationBox({
    this.animation,
    this.labelKind = NavigationRailLabelType.all,
    this.selected,
    this.icon,
    this.label,
    this.onTap,
    this.extended,
    this.width,
    this.height,
  }) : assert(labelKind != null),
       _positionAnimation = CurvedAnimation(
          parent: ReverseAnimation(animation),
          curve: Curves.easeInOut,
          reverseCurve: Curves.easeInOut.flipped,
       );

  final Animation<double> animation;
  final NavigationRailLabelType labelKind;
  final bool selected;
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;
  final bool extended;
  final double width;
  final double height;

  final Animation<double> _positionAnimation;

  double _fadeInValue() {
    if (animation.value < 0.25) {
      return 0;
    } else if (animation.value < 0.75) {
      return (animation.value - 0.25) * 2;
    } else {
      return 1;
    }
  }

  double _fadeOutValue() {
    if (animation.value > 0.75) {
      return (animation.value - 0.75) * 4;
    } else {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (extended) {
      content = SizedBox(
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            Positioned(
              child: SizedBox(
                width: width,
                height: height,
                child: icon,
              ),
            ),
            Positioned(
              left: width,
              child: Container(
                alignment: AlignmentDirectional.centerStart,
                height: height,
                child: label,
              ),
            ),
          ],
        ),
      );
    } else {
      switch (labelKind) {
        case NavigationRailLabelType.none:
          content = icon;
          break;
        case NavigationRailLabelType.selected:
          content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: _positionAnimation.value * height / 4),
              icon,
              Opacity(
                alwaysIncludeSemantics: true,
                opacity: selected ? _fadeInValue() : _fadeOutValue(),
                child: label,
              ),
            ],
          );
          break;
        case NavigationRailLabelType.all:
          content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              icon,
              label,
            ],
          );
          break;
      }
      content = SizedBox(
        width: width,
        height: height,
        child: content,
      );
    }

    final ColorScheme colors = Theme.of(context).colorScheme;
    return IconTheme(
      data: IconThemeData(
        color: selected ? colors.primary : colors.onSurface.withOpacity(0.64),
      ),
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.none,
        child: InkResponse(
          onTap: onTap,
          onHover: (_) {},
          highlightShape: BoxShape.rectangle,
//            highlightShape: extended ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: BorderRadius.all(Radius.circular(width / 2)),
          containedInkWell: true,
          splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.04),
          child: content,
        ),
      ),
    );
  }
}

const double _railWidth = 72;
const double _extendedRailWidth = 256;
const double _spacing = 8;
const Widget _verticalSpacing = SizedBox(height: _spacing);