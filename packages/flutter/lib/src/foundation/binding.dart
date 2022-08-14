// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;
import 'dart:developer' as developer;
import 'dart:io' show exit;
import 'dart:ui' as ui show Brightness, PlatformDispatcher, SingletonFlutterWindow, window;
// Before adding any more dart:ui imports, please read the README.

import 'package:meta/meta.dart';

import 'assertions.dart';
import 'basic_types.dart';
import 'constants.dart';
import 'debug.dart';
import 'object.dart';
import 'platform.dart';
import 'print.dart';

export 'dart:ui' show PlatformDispatcher, SingletonFlutterWindow;

export 'basic_types.dart' show AsyncCallback, AsyncValueGetter, AsyncValueSetter;

// Examples can assume:
// mixin BarBinding on BindingBase { }

/// Signature for service extensions.
///
/// The returned map must not contain the keys "type" or "method", as
/// they will be replaced before the value is sent to the client. The
/// "type" key will be set to the string `_extensionType` to indicate
/// that this is a return value from a service extension, and the
/// "method" key will be set to the full name of the method.
typedef ServiceExtensionCallback = Future<Map<String, dynamic>> Function(Map<String, String> parameters);

/// Base class for mixins that provide singleton services.
///
/// The Flutter engine ([dart:ui]) exposes some low-level services,
/// but these are typically not suitable for direct use, for example
/// because they only provide a single callback which an application
/// may wish to multiplex to allow multiple listeners.
///
/// Bindings provide the glue between these low-level APIs and the
/// higher-level framework APIs. They _bind_ the two together, whence
/// the name.
///
/// ## Implementing a binding mixin
///
/// A library would typically create a new binding mixin to expose a
/// feature in [dart:ui]. This is rare in general, but it is something
/// that an alternative framework would do, e.g. if a framework were
/// to replace the [widgets] library with an alternative API but still
/// wished to leverage the [services] and [foundation] libraries.
///
/// To create a binding mixin, declare a mixin `on` the [BindingBase] class
/// and whatever other bindings the concrete binding must implement for
/// this binding mixin to be useful.
///
/// The mixin is guaranteed to only be constructed once in the
/// lifetime of the app; this is handled by [initInstances].
///
/// A binding mixin must at a minimum implement the following features:
///
/// * The [initInstances] method, which must call `super.initInstances` and
///   set an `_instance` static field to `this`.
/// * An `instance` static getter, which must return that field using [checkInstance].
///
/// In addition, it should implement whatever singleton features the library needs.
///
/// As a general rule, the less can be placed in the binding, the
/// better. Prefer having APIs that takes objects rather than having
/// them refer to global singletons. Bindings are best limited to
/// exposing features that literally only exist once, for example, the
/// APIs in [dart:ui].
///
/// {@tool snippet}
///
/// Here is a basic example of a binding that implements these features. It relies on
/// another fictional binding called `BarBinding`.
///
/// ```dart
/// mixin FooBinding on BindingBase, BarBinding {
///   @override
///   void initInstances() {
///     super.initInstances();
///     _instance = this;
///     // ...binding initialization...
///   }
///
///   static FooBinding get instance => BindingBase.checkInstance(_instance);
///   static FooBinding? _instance;
///
///   // ...binding features...
/// }
/// ```
/// {@end-tool}
///
/// ## Implementing a binding class
///
/// The top-most layer used to write the application (e.g. the Flutter
/// [widgets] library) will have a concrete class that inherits from
/// [BindingBase] and uses all the various [BindingBase] mixins (such
/// as [ServicesBinding]). The [widgets] library in Flutter introduces
/// a binding called [WidgetsFlutterBinding].
///
/// A binding _class_ should mix in the relevant bindings from each
/// layer that it wishes to expose, and should have an
/// `ensureInitialized` method that constructs the class if that
/// layer's mixin's `_instance` field is null. This allows the binding
/// to be overriden by developers who have more specific needs, while
/// still allowing other code to call `ensureInitialized` when a binding
/// is needed.
///
/// {@tool snippet}
///
/// A typical binding class is shown below. The `ensureInitialized` method's
/// return type is the library's binding mixin, rather than the concrete
/// class.
///
/// ```dart
/// // continuing from previous example...
/// class FooLibraryBinding extends BindingBase with BarBinding, FooBinding {
///   static FooBinding ensureInitialized() {
///     if (FooBinding._instance == null) {
///       FooLibraryBinding();
///     }
///     return FooBinding.instance;
///   }
/// }
/// ```
/// {@end-tool}
abstract class BindingBase {
  /// Default abstract constructor for bindings.
  ///
  /// First calls [initInstances] to have bindings initialize their
  /// instance pointers and other state, then calls
  /// [initServiceExtensions] to have bindings initialize their
  /// observatory service extensions, if any.
  BindingBase() {
    developer.Timeline.startSync('Framework initialization');
    assert(() {
      _debugConstructed = true;
      return true;
    }());

    assert(_debugInitializedType == null);
    initInstances();
    assert(_debugInitializedType != null);

    assert(!_debugServiceExtensionsRegistered);
    initServiceExtensions();
    assert(_debugServiceExtensionsRegistered);

    developer.postEvent('Flutter.FrameworkInitialization', <String, String>{});

    developer.Timeline.finishSync();
  }

  bool _debugConstructed = false;
  static Type? _debugInitializedType;
  static bool _debugServiceExtensionsRegistered = false;

  /// Additional configuration used by the framework during hot reload.
  ///
  /// See also:
  ///
  ///  * [DebugReassembleConfig], which describes the configuration.
  static DebugReassembleConfig? debugReassembleConfig;

  /// The main window to which this binding is bound.
  ///
  /// A number of additional bindings are defined as extensions of
  /// [BindingBase], e.g., [ServicesBinding], [RendererBinding], and
  /// [WidgetsBinding]. Each of these bindings define behaviors that interact
  /// with a [ui.SingletonFlutterWindow].
  ///
  /// Each of these other bindings could individually access a
  /// [ui.SingletonFlutterWindow] statically, but that would preclude the
  /// ability to test its behaviors with a fake window for verification
  /// purposes.  Therefore, [BindingBase] exposes this
  /// [ui.SingletonFlutterWindow] for use by other bindings.  A subclass of
  /// [BindingBase], such as [TestWidgetsFlutterBinding], can override this
  /// accessor to return a different [ui.SingletonFlutterWindow] implementation,
  /// such as a [TestWindow].
  ///
  /// The `window` is a singleton meant for use by applications that only have a
  /// single main window. In addition to the properties of [ui.FlutterWindow],
  /// `window` provides access to platform-specific properties and callbacks
  /// available on the [platformDispatcher].
  ///
  /// For applications designed for more than one main window, prefer using the
  /// [platformDispatcher] to access available views via
  /// [ui.PlatformDispatcher.views].
  ///
  /// However, multiple window support is not yet implemented, so currently this
  /// provides access to the one and only window.
  // TODO(gspencergoog): remove the preceding note once multi-window support is
  // active.
  ui.SingletonFlutterWindow get window => ui.window;

  /// The [ui.PlatformDispatcher] to which this binding is bound.
  ///
  /// A number of additional bindings are defined as extensions of
  /// [BindingBase], e.g., [ServicesBinding], [RendererBinding], and
  /// [WidgetsBinding]. Each of these bindings define behaviors that interact
  /// with a [ui.PlatformDispatcher], e.g., [ServicesBinding] registers
  /// listeners with the [ChannelBuffers], and [RendererBinding]
  /// registers [ui.PlatformDispatcher.onMetricsChanged],
  /// [ui.PlatformDispatcher.onTextScaleFactorChanged],
  /// [ui.PlatformDispatcher.onSemanticsEnabledChanged], and
  /// [ui.PlatformDispatcher.onSemanticsAction] handlers.
  ///
  /// Each of these other bindings could individually access a
  /// [ui.PlatformDispatcher] statically, but that would preclude the ability to
  /// test these behaviors with a fake platform dispatcher for verification
  /// purposes. Therefore, [BindingBase] exposes this [ui.PlatformDispatcher]
  /// for use by other bindings. A subclass of [BindingBase], such as
  /// [TestWidgetsFlutterBinding], can override this accessor to return a
  /// different [ui.PlatformDispatcher] implementation.
  ui.PlatformDispatcher get platformDispatcher => ui.PlatformDispatcher.instance;

  /// The initialization method. Subclasses override this method to hook into
  /// the platform and otherwise configure their services. Subclasses must call
  /// "super.initInstances()".
  ///
  /// The binding is not fully initialized when this method runs (for
  /// example, other binding mixins may not yet have run their
  /// [initInstances] method). For this reason, code in this method
  /// should avoid invoking callbacks or synchronously triggering any
  /// code that would normally assume that the bindings are ready.
  ///
  /// {@tool snippet}
  ///
  /// By convention, if the service is to be provided as a singleton,
  /// it should be exposed as `MixinClassName.instance`, a static
  /// getter with a non-nullable return type that returns
  /// `MixinClassName._instance`, a static field that is set by
  /// `initInstances()`. To improve the developer experience, the
  /// return value should actually be
  /// `BindingBase.checkInstance(_instance)` (see [checkInstance]), as
  /// in the example below.
  ///
  /// ```dart
  /// mixin BazBinding on BindingBase {
  ///   @override
  ///   void initInstances() {
  ///     super.initInstances();
  ///     _instance = this;
  ///     // ...binding initialization...
  ///   }
  ///
  ///   static BazBinding get instance => BindingBase.checkInstance(_instance);
  ///   static BazBinding? _instance;
  ///
  ///   // ...binding features...
  /// }
  /// ```
  /// {@end-tool}
  @protected
  @mustCallSuper
  void initInstances() {
    assert(_debugInitializedType == null);
    assert(() {
      _debugInitializedType = runtimeType;
      return true;
    }());
  }

  /// A method that shows a useful error message if the given binding
  /// instance is not initialized.
  ///
  /// See [initInstances] for advice on using this method.
  ///
  /// This method either returns the argument or throws an exception.
  /// In release mode it always returns the argument.
  ///
  /// The type argument `T` should be the kind of binding mixin (e.g.
  /// `SchedulerBinding`) that is calling the method. It is used in
  /// error messages.
  @protected
  static T checkInstance<T extends BindingBase>(T? instance) {
    assert(() {
      if (_debugInitializedType == null && instance == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Binding has not yet been initialized.'),
          ErrorDescription('The "instance" getter on the $T binding mixin is only available once that binding has been initialized.'),
          ErrorHint(
            'Typically, this is done by calling "WidgetsFlutterBinding.ensureInitialized()" or "runApp()" (the '
            'latter calls the former). Typically this call is done in the "void main()" method. The "ensureInitialized" method '
            'is idempotent; calling it multiple times is not harmful. After calling that method, the "instance" getter will '
            'return the binding.',
          ),
          ErrorHint(
            'In a test, one can call "TestWidgetsFlutterBinding.ensureInitialized()" as the first line in the test\'s "main()" method '
            'to initialize the binding.',
          ),
          ErrorHint(
            'If $T is a custom binding mixin, there must also be a custom binding class, like WidgetsFlutterBinding, '
            'but that mixes in the selected binding, and that is the class that must be constructed before using the "instance" getter.',
          ),
        ]);
      }
      if (instance == null) {
        assert(_debugInitializedType == null);
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Binding mixin instance is null but bindings are already initialized.'),
          ErrorDescription(
            'The "instance" property of the $T binding mixin was accessed, but that binding was not initialized when '
            'the "initInstances()" method was called.',
          ),
          ErrorHint(
            'This probably indicates that the $T mixin was not mixed into the class that was used to initialize the binding. '
            'If this is a custom binding mixin, there must also be a custom binding class, like WidgetsFlutterBinding, '
            'but that mixes in the selected binding. If this is a test binding, check that the binding being initialized '
            'is the same as the one into which the test binding is mixed.',
          ),
          ErrorHint(
            'It is also possible that $T does not implement "initInstances()" to assign a value to "instance". See the '
            'documentation of the BaseBinding class for more details.',
          ),
          ErrorHint(
            'The binding that was initialized was of the type "$_debugInitializedType". '
          ),
        ]);
      }
      try {
        assert(instance != null);
        if (instance._debugConstructed && _debugInitializedType == null) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Binding initialized without calling initInstances.'),
            ErrorDescription('An instance of $T is non-null, but BindingBase.initInstances() has not yet been called.'),
            ErrorHint(
              'This could happen because a binding mixin was somehow used outside of the normal binding mechanisms, or because '
              'the binding\'s initInstances() method did not call "super.initInstances()".',
            ),
            ErrorHint(
              'This could also happen if some code was invoked that used the binding while the binding was initializing, '
              'for example if the "initInstances" method invokes a callback. Bindings should not invoke callbacks before '
              '"initInstances" has completed.',
            ),
          ]);
        }
        if (!instance._debugConstructed) {
          // The state of _debugInitializedType doesn't matter in this failure mode.
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Binding did not complete initialization.'),
            ErrorDescription('An instance of $T is non-null, but the BindingBase() constructor has not yet been called.'),
            ErrorHint(
              'This could also happen if some code was invoked that used the binding while the binding was initializing, '
              "for example if the binding's constructor itself invokes a callback. Bindings should not invoke callbacks "
              'before "initInstances" has completed.',
            ),
          ]);
        }
      } on NoSuchMethodError {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Binding does not extend BindingBase'),
          ErrorDescription('An instance of $T was created but the BindingBase constructor was not called.'),
          ErrorHint(
            'This could happen because the binding was implemented using "implements" rather than "extends" or "with". '
            'Concrete binding classes must extend or mix in BindingBase.',
          ),
        ]);
      }
      return true;
    }());
    return instance!;
  }

  /// In debug builds, the type of the current binding, if any, or else null.
  ///
  /// This may be useful in asserts to verify that the binding has not been initialized
  /// before the point in the application code that wants to initialize the binding, or
  /// to verify that the binding is the one that is expected.
  ///
  /// For example, if an application uses [Zone]s to report uncaught exceptions, it may
  /// need to ensure that `ensureInitialized()` has not yet been invoked on any binding
  /// at the point where it configures the zone and initializes the binding.
  ///
  /// If this returns null, the binding has not been initialized.
  ///
  /// If this returns a non-null value, it returns the type of the binding instance.
  ///
  /// To obtain the binding itself, consider the `instance` getter on the [BindingBase]
  /// subclass or mixin.
  ///
  /// This method only returns a useful value in debug builds. In release builds, the
  /// return value is always null; to improve startup performance, the type of the
  /// binding is not tracked in release builds.
  ///
  /// See also:
  ///
  ///  * [BindingBase], whose class documentation describes the conventions for dealing
  ///    with bindings.
  ///  * [initInstances], whose documentation details how to create a binding mixin.
  static Type? debugBindingType() {
    return _debugInitializedType;
  }

  /// Called when the binding is initialized, to register service
  /// extensions.
  ///
  /// Bindings that want to expose service extensions should overload
  /// this method to register them using calls to
  /// [registerSignalServiceExtension],
  /// [registerBoolServiceExtension],
  /// [registerNumericServiceExtension], and
  /// [registerServiceExtension] (in increasing order of complexity).
  ///
  /// Implementations of this method must call their superclass
  /// implementation.
  ///
  /// {@macro flutter.foundation.BindingBase.registerServiceExtension}
  ///
  /// See also:
  ///
  ///  * <https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md#rpcs-requests-and-responses>
  @protected
  @mustCallSuper
  void initServiceExtensions() {
    assert(!_debugServiceExtensionsRegistered);

    assert(() {
      registerSignalServiceExtension(
        name: 'reassemble',
        callback: reassembleApplication,
      );
      return true;
    }());

    if (!kReleaseMode) {
      if (!kIsWeb) {
        registerSignalServiceExtension(
          name: 'exit',
          callback: _exitApplication,
        );
      }
      // These service extensions are used in profile mode applications.
      registerStringServiceExtension(
        name: 'connectedVmServiceUri',
        getter: () async => connectedVmServiceUri ?? '',
        setter: (String uri) async {
          connectedVmServiceUri = uri;
        },
      );
      registerStringServiceExtension(
        name: 'activeDevToolsServerAddress',
        getter: () async => activeDevToolsServerAddress ?? '',
        setter: (String serverAddress) async {
          activeDevToolsServerAddress = serverAddress;
        },
      );
    }

    assert(() {
      const String platformOverrideExtensionName = 'platformOverride';
      registerServiceExtension(
        name: platformOverrideExtensionName,
        callback: (Map<String, String> parameters) async {
          if (parameters.containsKey('value')) {
            switch (parameters['value']) {
              case 'android':
                debugDefaultTargetPlatformOverride = TargetPlatform.android;
                break;
              case 'fuchsia':
                debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
                break;
              case 'iOS':
                debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
                break;
              case 'linux':
                debugDefaultTargetPlatformOverride = TargetPlatform.linux;
                break;
              case 'macOS':
                debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
                break;
              case 'windows':
                debugDefaultTargetPlatformOverride = TargetPlatform.windows;
                break;
              case 'default':
              default:
                debugDefaultTargetPlatformOverride = null;
            }
            _postExtensionStateChangedEvent(
              platformOverrideExtensionName,
              defaultTargetPlatform.toString().substring('$TargetPlatform.'.length),
            );
            await reassembleApplication();
          }
          return <String, dynamic>{
            'value': defaultTargetPlatform
                     .toString()
                     .substring('$TargetPlatform.'.length),
          };
        },
      );

      const String brightnessOverrideExtensionName = 'brightnessOverride';
      registerServiceExtension(
        name: brightnessOverrideExtensionName,
        callback: (Map<String, String> parameters) async {
          if (parameters.containsKey('value')) {
            switch (parameters['value']) {
              case 'Brightness.light':
                debugBrightnessOverride = ui.Brightness.light;
                break;
              case 'Brightness.dark':
                debugBrightnessOverride = ui.Brightness.dark;
                break;
              default:
                debugBrightnessOverride = null;
            }
            _postExtensionStateChangedEvent(
              brightnessOverrideExtensionName,
              (debugBrightnessOverride ?? platformDispatcher.platformBrightness).toString(),
            );
            await reassembleApplication();
          }
          return <String, dynamic>{
            'value': (debugBrightnessOverride ?? platformDispatcher.platformBrightness).toString(),
          };
        },
      );
      return true;
    }());
    assert(() {
      _debugServiceExtensionsRegistered = true;
      return true;
    }());
  }

  /// Whether [lockEvents] is currently locking events.
  ///
  /// Binding subclasses that fire events should check this first, and if it is
  /// set, queue events instead of firing them.
  ///
  /// Events should be flushed when [unlocked] is called.
  @protected
  bool get locked => _lockCount > 0;
  int _lockCount = 0;

  /// Locks the dispatching of asynchronous events and callbacks until the
  /// callback's future completes.
  ///
  /// This causes input lag and should therefore be avoided when possible. It is
  /// primarily intended for use during non-user-interactive time such as to
  /// allow [reassembleApplication] to block input while it walks the tree
  /// (which it partially does asynchronously).
  ///
  /// The [Future] returned by the `callback` argument is returned by [lockEvents].
  @protected
  Future<void> lockEvents(Future<void> Function() callback) {
    final developer.TimelineTask timelineTask = developer.TimelineTask()..start('Lock events');

    assert(callback != null);
    _lockCount += 1;
    final Future<void> future = callback();
    assert(future != null, 'The lockEvents() callback returned null; it should return a Future<void> that completes when the lock is to expire.');
    future.whenComplete(() {
      _lockCount -= 1;
      if (!locked) {
        timelineTask.finish();
        unlocked();
      }
    });
    return future;
  }

  /// Called by [lockEvents] when events get unlocked.
  ///
  /// This should flush any events that were queued while [locked] was true.
  @protected
  @mustCallSuper
  void unlocked() {
    assert(!locked);
  }

  /// Cause the entire application to redraw, e.g. after a hot reload.
  ///
  /// This is used by development tools when the application code has changed,
  /// to cause the application to pick up any changed code. It can be triggered
  /// manually by sending the `ext.flutter.reassemble` service extension signal.
  ///
  /// This method is very computationally expensive and should not be used in
  /// production code. There is never a valid reason to cause the entire
  /// application to repaint in production. All aspects of the Flutter framework
  /// know how to redraw when necessary. It is only necessary in development
  /// when the code is literally changed on the fly (e.g. in hot reload) or when
  /// debug flags are being toggled.
  ///
  /// While this method runs, events are locked (e.g. pointer events are not
  /// dispatched).
  ///
  /// Subclasses (binding classes) should override [performReassemble] to react
  /// to this method being called. This method itself should not be overridden.
  Future<void> reassembleApplication() {
    return lockEvents(performReassemble);
  }

  /// This method is called by [reassembleApplication] to actually cause the
  /// application to reassemble, e.g. after a hot reload.
  ///
  /// Bindings are expected to use this method to re-register anything that uses
  /// closures, so that they do not keep pointing to old code, and to flush any
  /// caches of previously computed values, in case the new code would compute
  /// them differently. For example, the rendering layer triggers the entire
  /// application to repaint when this is called.
  ///
  /// Do not call this method directly. Instead, use [reassembleApplication].
  @mustCallSuper
  @protected
  Future<void> performReassemble() {
    FlutterError.resetErrorCount();
    return Future<void>.value();
  }

  /// Registers a service extension method with the given name (full
  /// name "ext.flutter.name"), which takes no arguments and returns
  /// no value.
  ///
  /// Calls the `callback` callback when the service extension is called.
  ///
  /// {@macro flutter.foundation.BindingBase.registerServiceExtension}
  @protected
  void registerSignalServiceExtension({
    required String name,
    required AsyncCallback callback,
  }) {
    assert(name != null);
    assert(callback != null);
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        await callback();
        return <String, dynamic>{};
      },
    );
  }

  /// Registers a service extension method with the given name (full
  /// name "ext.flutter.name"), which takes a single argument
  /// "enabled" which can have the value "true" or the value "false"
  /// or can be omitted to read the current value. (Any value other
  /// than "true" is considered equivalent to "false". Other arguments
  /// are ignored.)
  ///
  /// Calls the `getter` callback to obtain the value when
  /// responding to the service extension method being called.
  ///
  /// Calls the `setter` callback with the new value when the
  /// service extension method is called with a new value.
  ///
  /// {@macro flutter.foundation.BindingBase.registerServiceExtension}
  @protected
  void registerBoolServiceExtension({
    required String name,
    required AsyncValueGetter<bool> getter,
    required AsyncValueSetter<bool> setter,
  }) {
    assert(name != null);
    assert(getter != null);
    assert(setter != null);
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        if (parameters.containsKey('enabled')) {
          await setter(parameters['enabled'] == 'true');
          _postExtensionStateChangedEvent(name, await getter() ? 'true' : 'false');
        }
        return <String, dynamic>{'enabled': await getter() ? 'true' : 'false'};
      },
    );
  }

  /// Registers a service extension method with the given name (full
  /// name "ext.flutter.name"), which takes a single argument with the
  /// same name as the method which, if present, must have a value
  /// that can be parsed by [double.parse], and can be omitted to read
  /// the current value. (Other arguments are ignored.)
  ///
  /// Calls the `getter` callback to obtain the value when
  /// responding to the service extension method being called.
  ///
  /// Calls the `setter` callback with the new value when the
  /// service extension method is called with a new value.
  ///
  /// {@macro flutter.foundation.BindingBase.registerServiceExtension}
  @protected
  void registerNumericServiceExtension({
    required String name,
    required AsyncValueGetter<double> getter,
    required AsyncValueSetter<double> setter,
  }) {
    assert(name != null);
    assert(getter != null);
    assert(setter != null);
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        if (parameters.containsKey(name)) {
          await setter(double.parse(parameters[name]!));
          _postExtensionStateChangedEvent(name, (await getter()).toString());
        }
        return <String, dynamic>{name: (await getter()).toString()};
      },
    );
  }

  /// Sends an event when a service extension's state is changed.
  ///
  /// Clients should listen for this event to stay aware of the current service
  /// extension state. Any service extension that manages a state should call
  /// this method on state change.
  ///
  /// `value` reflects the newly updated service extension value.
  ///
  /// This will be called automatically for service extensions registered via
  /// [registerBoolServiceExtension], [registerNumericServiceExtension], or
  /// [registerStringServiceExtension].
  void _postExtensionStateChangedEvent(String name, dynamic value) {
    postEvent(
      'Flutter.ServiceExtensionStateChanged',
      <String, dynamic>{
        'extension': 'ext.flutter.$name',
        'value': value,
      },
    );
  }

  /// All events dispatched by a [BindingBase] use this method instead of
  /// calling [developer.postEvent] directly so that tests for [BindingBase]
  /// can track which events were dispatched by overriding this method.
  @protected
  void postEvent(String eventKind, Map<String, dynamic> eventData) {
    developer.postEvent(eventKind, eventData);
  }

  /// Registers a service extension method with the given name (full name
  /// "ext.flutter.name"), which optionally takes a single argument with the
  /// name "value". If the argument is omitted, the value is to be read,
  /// otherwise it is to be set. Returns the current value.
  ///
  /// Calls the `getter` callback to obtain the value when
  /// responding to the service extension method being called.
  ///
  /// Calls the `setter` callback with the new value when the
  /// service extension method is called with a new value.
  ///
  /// {@macro flutter.foundation.BindingBase.registerServiceExtension}
  @protected
  void registerStringServiceExtension({
    required String name,
    required AsyncValueGetter<String> getter,
    required AsyncValueSetter<String> setter,
  }) {
    assert(name != null);
    assert(getter != null);
    assert(setter != null);
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        if (parameters.containsKey('value')) {
          await setter(parameters['value']!);
          _postExtensionStateChangedEvent(name, await getter());
        }
        return <String, dynamic>{'value': await getter()};
      },
    );
  }

  /// Registers a service extension method with the given name (full name
  /// "ext.flutter.name").
  ///
  /// The given callback is called when the extension method is called. The
  /// callback must return a [Future] that either eventually completes to a
  /// return value in the form of a name/value map where the values can all be
  /// converted to JSON using `json.encode()` (see [JsonEncoder]), or fails. In
  /// case of failure, the failure is reported to the remote caller and is
  /// dumped to the logs.
  ///
  /// The returned map will be mutated.
  ///
  /// {@template flutter.foundation.BindingBase.registerServiceExtension}
  /// A registered service extension can only be activated if the vm-service
  /// is included in the build, which only happens in debug and profile mode.
  /// Although a service extension cannot be used in release mode its code may
  /// still be included in the Dart snapshot and blow up binary size if it is
  /// not wrapped in a guard that allows the tree shaker to remove it (see
  /// sample code below).
  ///
  /// {@tool snippet}
  /// The following code registers a service extension that is only included in
  /// debug builds.
  ///
  /// ```dart
  /// void myRegistrationFunction() {
  ///   assert(() {
  ///     // Register your service extension here.
  ///     return true;
  ///   }());
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// A service extension registered with the following code snippet is
  /// available in debug and profile mode.
  ///
  /// ```dart
  /// void myOtherRegistrationFunction() {
  ///   // kReleaseMode is defined in the 'flutter/foundation.dart' package.
  ///   if (!kReleaseMode) {
  ///     // Register your service extension here.
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// Both guards ensure that Dart's tree shaker can remove the code for the
  /// service extension in release builds.
  /// {@endtemplate}
  @protected
  void registerServiceExtension({
    required String name,
    required ServiceExtensionCallback callback,
  }) {
    assert(name != null);
    assert(callback != null);
    final String methodName = 'ext.flutter.$name';
    developer.registerExtension(methodName, (String method, Map<String, String> parameters) async {
      assert(method == methodName);
      assert(() {
        if (debugInstrumentationEnabled) {
          debugPrint('service extension method received: $method($parameters)');
        }
        return true;
      }());

      // VM service extensions are handled as "out of band" messages by the VM,
      // which means they are handled at various times, generally ASAP.
      // Notably, this includes being handled in the middle of microtask loops.
      // While this makes sense for some service extensions (e.g. "dump current
      // stack trace", which explicitly doesn't want to wait for a loop to
      // complete), Flutter extensions need not be handled with such high
      // priority. Further, handling them with such high priority exposes us to
      // the possibility that they're handled in the middle of a frame, which
      // breaks many assertions. As such, we ensure they we run the callbacks
      // on the outer event loop here.
      await debugInstrumentAction<void>('Wait for outer event loop', () {
        return Future<void>.delayed(Duration.zero);
      });

      late Map<String, dynamic> result;
      try {
        result = await callback(parameters);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          context: ErrorDescription('during a service extension callback for "$method"'),
        ));
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          json.encode(<String, String>{
            'exception': exception.toString(),
            'stack': stack.toString(),
            'method': method,
          }),
        );
      }
      result['type'] = '_extensionType';
      result['method'] = method;
      return developer.ServiceExtensionResponse.result(json.encode(result));
    });
  }

  @override
  String toString() => '<${objectRuntimeType(this, 'BindingBase')}>';
}

/// Terminate the Flutter application.
Future<void> _exitApplication() async {
  exit(0);
}

/// Additional configuration used for hot reload reassemble optimizations.
///
/// Do not extend, implement, or mixin this class. This may only be instantiated
/// in debug mode.
class DebugReassembleConfig {
  /// Create a new [DebugReassembleConfig].
  ///
  /// Throws a [FlutterError] if this is called in profile or release mode.
  DebugReassembleConfig({
    this.widgetName,
  }) {
    if (!kDebugMode) {
      throw FlutterError('Cannot instantiate DebugReassembleConfig in profile or release mode.');
    }
  }

  /// The name of the widget that was modified, or `null` if the change was elsewhere.
  final String? widgetName;
}
