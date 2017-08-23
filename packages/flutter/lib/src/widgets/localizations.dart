// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

import 'binding.dart';
import 'container.dart';
import 'framework.dart';

// Examples can assume:
// class Intl { static String message(String s, { String name, String locale }) => ''; }
// Future<Null> initializeMessages(String locale) => null;

// A utility function used by Localizations to generate one future
// that completes when all of the LocalizationsDelegate.load() futures
// complete. The returned map is indexed by the type of each input
// future's value.
//
// The input future values must have distinct types.
//
// The returned Future<Map> will resolve when all of the input map's
// future values have resolved. If all of the input map's values are
// SynchronousFutures then a SynchronousFuture will be returned
// immediately.
//
// This is more complicated than just applying Future.wait to input
// because some of the input.values may be SynchronousFutures. We don't want
// to Future.wait for the synchronous futures.
Future<Map<Type, dynamic>> _loadAll(Iterable<Future<dynamic>> inputValues) {
  final Map<Type, dynamic> output = <Type, dynamic>{};
  List<Future<dynamic>> outputFutures;

  for (Future<dynamic> inputValue in inputValues) {
    dynamic completedValue;
    final Future<dynamic> futureValue = inputValue.then<dynamic>((dynamic value) {
      return completedValue = value;
    });
    if (completedValue != null) { // inputValue was a SynchronousFuture
      final Type type = completedValue.runtimeType;
      assert(!output.containsKey(type));
      output[type] = completedValue;
    } else {
      outputFutures ??= <Future<dynamic>>[];
      outputFutures.add(futureValue);
    }
  }

  // All of the input.values were synchronous futures, we're done.
  if (outputFutures == null)
    return new SynchronousFuture<Map<Type, dynamic>>(output);

  // Some of input.values were asynchronous futures. Wait for them.
  return Future.wait<dynamic>(outputFutures).then<Map<Type, dynamic>>((List<dynamic> values) {
    for (dynamic value in values) {
      final Type type = value.runtimeType;
      assert(!output.containsKey(type));
      output[type] = value;
     }
    return output;
  });
}

/// A factory for a set of localized resources of type `T`, to be loaded by a
/// [Localizations] widget.
///
/// Typical applications have one [Localizations] widget which is
/// created by the [WidgetsApp] and configured with the app's
/// `localizationsDelegates` parameter.
abstract class LocalizationsDelegate<T> {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const LocalizationsDelegate();

  /// Start loading the resources for `locale`. The returned future completes
  /// when the resources have finished loading.
  ///
  /// It's assumed that the this method will return an object that contains
  /// a collection of related resources (typically defined with one method per
  /// resource). The object will be retrieved with [Localizations.of].
  Future<T> load(Locale locale);

  /// Returns true if the resources for this delegate should be loaded
  /// again by calling the [load] method.
  ///
  /// This method is called whenever its [Localizations] widget is
  /// rebuilt. If it returns true then dependent widgets will be rebuilt
  /// after [load] has completed.
  bool shouldReload(covariant LocalizationsDelegate<T> old) {
    return old == null || runtimeType != old.runtimeType;
  }
}

class _LocalizationsScope extends InheritedWidget {
  _LocalizationsScope ({
    Key key,
    @required this.locale,
    @required this.localizationsState,
    Widget child,
  }) : super(key: key, child: child) {
    assert(localizationsState != null);
  }

  final Locale locale;
  final _LocalizationsState localizationsState;

  @override
  bool updateShouldNotify(_LocalizationsScope old) {
    // Changes in Localizations.locale trigger a load(), see _LocalizationsState.didUpdateWidget()
    return false;
  }
}

/// Defines the [Locale] for its `child` and the localized resources that the
/// child depends on.
///
/// Localized resources are loaded by the list of [LocalizationsDelegate]
/// `delegates`. Each delegate is essentially a factory for a collection
/// of localized resources. There are multiple delegates because there are
/// multiple sources for localizations within an app.
///
/// Delegates are typically simple subclasses of [LocalizationsDelegate] that
/// override [LocalizationsDelegate.load]. For example a delegate for the
/// `MyLocalizations` class defined below would be:
///
/// ```dart
/// class _MyDelegate extends LocalizationsDelegate<MyLocalizations> {
///   @override
///   Future<MyLocalizations> load(Locale locale) => MyLocalizations.load(locale);
///}
/// ```
///
/// Each delegate can be viewed as a factory for objects that encapsulate a
/// a set of localized resources. These objects are retrieved with
/// by runtime type with [Localizations.of].
///
/// The [WidgetsApp] class creates a `Localizations` widget so most apps
/// will not need to create one. The widget app's `Localizations` delegates can
/// be initialized with [WidgetsApp.localizationsDelegates]. The [MaterialApp]
/// class also provides a `localizationsDelegates` parameter that's just
/// passed along to the [WidgetsApp].
///
/// Apps should retrieve collections of localized resources with
/// `Localizations.of<MyLocalizations>(context, MyLocalizations)`,
/// where MyLocalizations is an app specific class defines one function per
/// resource. This is conventionally done by a static `.of` method on the
/// MyLocalizations class.
///
/// For example, using the `MyLocalizations` class defined below, one would
/// lookup a localized title string like this:
/// ```dart
/// MyLocalizations.of(context).title()
/// ```
/// If `Localizations` were to be rebuilt with a new `locale` then
/// the widget subtree that corresponds to [BuildContext] `context` would
/// be rebuilt after the corresponding resources had been loaded.
///
/// This class is effectively an [InheritedWidget]. If it's rebuilt with
/// a new `locale` or a different list of delegates or any of its
/// delegates' [LocalizationDelegate.shouldReload()] methods returns true,
/// then widgets that have created a dependency by calling
/// `Localizations.of(context)` will be rebuilt after the resources
/// for the new locale have been loaded.
///
/// ## Sample code
///
/// This following class is defined in terms of the
/// [Dart `intl` package](https://github.com/dart-lang/intl). Using the `intl`
/// package isn't required.
///
/// ```dart
/// class MyLocalizations {
///   MyLocalizations(this.locale);
///
///   final Locale locale;
///
///   static Future<MyLocalizations> load(Locale locale) {
///     return initializeMessages(locale.toString())
///       .then((Null _) {
///         return new MyLocalizations(locale);
///       });
///   }
///
///   static MyLocalizations of(BuildContext context) {
///     return Localizations.of<MyLocalizations>(context, MyLocalizations);
///   }
///
///   String title() => Intl.message('<title>', name: 'title', locale: locale.toString());
///   // ... more Intl.message() methods like title()
/// }
/// ```
/// A class based on the `intl` package imports a generated message catalog that provides
/// the `initializeMessages()` function and the per-locale backing store for `Intl.message()`.
/// The message catalog is produced by an `intl` tool that analyzes the source code for
/// classes that contain `Intl.message()` calls. In this case that would just be the
/// `MyLocalizations` class.
///
/// One could choose another approach for loading localized resources and looking them up while
/// still conforming to the structure of this example.
class Localizations extends StatefulWidget {
  Localizations({
    Key key,
    @required this.locale,
    this.delegates,
    this.child
  }) : super(key: key) {
    assert(locale != null);
  }

  /// The resources returned by [Localizations.of] will be specific to this locale.
  final Locale locale;

  /// This list collectively defines the localized resources objects that can
  /// be retrieved with [ Localizations.of].
  final Iterable<LocalizationsDelegate<dynamic>> delegates;

  /// The widget below this widget in the tree.
  final Widget child;

  /// The locale of the Localizations widget for the widget tree that
  /// corresponds to [BuildContext] `context`.
  static Locale localeOf(BuildContext context) {
    assert(context != null);
    final _LocalizationsScope scope = context.inheritFromWidgetOfExactType(_LocalizationsScope);
    return scope.localizationsState.locale;
  }

  /// Returns the 'type' localized resources for the widget tree that
  /// corresponds to [BuildContext] `context`.
  ///
  /// This method is typically used by a static factory method on the 'type'
  /// class. For example Flutter's MaterialLocalizations class looks up Material
  /// resources with a method defined like this:
  ///
  /// ```dart
  /// static MaterialLocalizations of(BuildContext context) {
  ///    return Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
  /// }
  /// ```
  static T of<T>(BuildContext context, Type type) {
    assert(context != null);
    assert(type != null);
    final _LocalizationsScope scope = context.inheritFromWidgetOfExactType(_LocalizationsScope);
    return scope.localizationsState.resourcesFor<T>(type);
  }

  @override
  _LocalizationsState createState() => new _LocalizationsState();
}

class _LocalizationsState extends State<Localizations> {
  final GlobalKey _localizedResourcesScopeKey = new GlobalKey();
  Map<Type, dynamic> _typeToResources = <Type, dynamic>{};

  Locale get locale => _locale;
  Locale _locale;

  @override
  void initState() {
    super.initState();
    load(widget.locale);
  }

  bool _anyDelegatesShouldReload(Localizations old) {
    if (widget.delegates.length != old.delegates.length)
      return true;
    final List<LocalizationsDelegate<dynamic>> delegates = widget.delegates.toList();
    final List<LocalizationsDelegate<dynamic>> oldDelegates = old.delegates.toList();
    for (int i = 0; i < delegates.length; i++) {
      if (delegates[i].shouldReload(oldDelegates[i]))
        return true;
    }
    return false;
  }

  @override
  void didUpdateWidget(Localizations old) {
    super.didUpdateWidget(old);
    if (widget.locale != old.locale
        || (widget.delegates == null && old.delegates != null)
        || (widget.delegates != null && old.delegates == null)
        || (widget.delegates != null && _anyDelegatesShouldReload(old)))
      load(widget.locale);
  }

  void load(Locale locale) {
    final Iterable<LocalizationsDelegate<dynamic>> delegates = widget.delegates;
    if (delegates == null || delegates.isEmpty) {
      _locale = locale;
      return;
    }

    final Iterable<Future<dynamic>> allResources = delegates.map((LocalizationsDelegate<dynamic> delegate) {
      return delegate.load(locale);
    });

    Map<Type, dynamic> typeToResources;
    final Future<Map<Type, dynamic>> typeToResourcesFuture = _loadAll(allResources)
      .then((Map<Type, dynamic> value) {
        return typeToResources = value;
      });

    if (typeToResources != null) {
      // All of the delegates' resources loaded synchronously.
      _typeToResources = typeToResources;
      _locale = locale;
    } else {
      // - Don't rebuild the dependent widgets until the resources for the new locale
      // have finished loading. Until then the old locale will continue to be used.
      // - If we're running at app startup time then defer reporting the first
      // "useful" frame until after the async load has completed.
      WidgetsBinding.instance.deferFirstFrameReport();
      typeToResourcesFuture.then((Map<Type, dynamic> value) {
        WidgetsBinding.instance.allowFirstFrameReport();
        if (!mounted)
          return;
        setState(() {
          _typeToResources = value;
          _locale = locale;
        });
        final InheritedElement scopeElement = _localizedResourcesScopeKey.currentContext;
        scopeElement?.dispatchDidChangeDependencies();
      });
    }
  }

  T resourcesFor<T>(Type type) {
    assert(type != null);
    final dynamic resources = _typeToResources[type];
    assert(resources.runtimeType == type);
    return resources;
  }

  @override
  Widget build(BuildContext context) {
    return new _LocalizationsScope(
      key: _localizedResourcesScopeKey,
      locale: widget.locale,
      localizationsState: this,
      child: _locale != null ? widget.child : new Container(),
    );
  }
}
