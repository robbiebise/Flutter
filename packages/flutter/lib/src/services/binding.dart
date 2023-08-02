// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'asset_bundle.dart';
import 'binary_messenger.dart';
import 'hardware_keyboard.dart';
import 'message_codec.dart';
import 'restoration.dart';
import 'service_extensions.dart';
import 'system_channels.dart';
import 'text_input.dart';

export 'dart:ui' show ChannelBuffers, RootIsolateToken;

export 'binary_messenger.dart' show BinaryMessenger;
export 'hardware_keyboard.dart' show HardwareKeyboard, KeyEventManager;
export 'restoration.dart' show RestorationManager;

/// A callback that can be registered with [ServicesBinding.debugRegisterHotRestartCallback].
typedef DebugPreHotRestartCallback = FutureOr<void> Function();

/// Listens for platform messages and directs them to the [defaultBinaryMessenger].
///
/// The [ServicesBinding] also registers a [LicenseEntryCollector] that exposes
/// the licenses found in the `LICENSE` file stored at the root of the asset
/// bundle, and implements the `ext.flutter.evict` service extension (see
/// [evict]).
mixin ServicesBinding on BindingBase, SchedulerBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    _defaultBinaryMessenger = createBinaryMessenger();
    _restorationManager = createRestorationManager();
    _initKeyboard();
    initLicenses();
    SystemChannels.system.setMessageHandler((dynamic message) => handleSystemMessage(message as Object));
    SystemChannels.lifecycle.setMessageHandler(_handleLifecycleMessage);
    SystemChannels.platform.setMethodCallHandler(_handlePlatformMessage);
    TextInput.ensureInitialized();
    readInitialLifecycleStateFromNativeWindow();
    initializationComplete();
  }

  /// The current [ServicesBinding], if one has been created.
  ///
  /// Provides access to the features exposed by this mixin. The binding must
  /// be initialized before using this getter; this is typically done by calling
  /// [runApp] or [WidgetsFlutterBinding.ensureInitialized].
  static ServicesBinding get instance => BindingBase.checkInstance(_instance);
  static ServicesBinding? _instance;

  /// The global singleton instance of [HardwareKeyboard], which can be used to
  /// query keyboard states.
  HardwareKeyboard get keyboard => _keyboard;
  late final HardwareKeyboard _keyboard;

  /// The global singleton instance of [KeyEventManager], which is used
  /// internally to dispatch key messages.
  KeyEventManager get keyEventManager => _keyEventManager;
  late final KeyEventManager _keyEventManager;

  void _initKeyboard() {
    _keyboard = HardwareKeyboard();
    _keyEventManager = KeyEventManager(_keyboard, RawKeyboard.instance);
    _keyboard.syncKeyboardState().then((_) {
      platformDispatcher.onKeyData = _keyEventManager.handleKeyData;
      SystemChannels.keyEvent.setMessageHandler(_keyEventManager.handleRawKeyMessage);
    });
  }

  /// The default instance of [BinaryMessenger].
  ///
  /// This is used to send messages from the application to the platform, and
  /// keeps track of which handlers have been registered on each channel so
  /// it may dispatch incoming messages to the registered handler.
  ///
  /// The default implementation returns a [BinaryMessenger] that delivers the
  /// messages in the same order in which they are sent.
  BinaryMessenger get defaultBinaryMessenger => _defaultBinaryMessenger;
  late final BinaryMessenger _defaultBinaryMessenger;

  /// A token that represents the root isolate, used for coordinating with background
  /// isolates.
  ///
  /// This property is primarily intended for use with
  /// [BackgroundIsolateBinaryMessenger.ensureInitialized], which takes a
  /// [RootIsolateToken] as its argument. The value `null` is returned when
  /// executed from background isolates.
  static ui.RootIsolateToken? get rootIsolateToken => ui.RootIsolateToken.instance;

  /// The low level buffering and dispatch mechanism for messages sent by
  /// plugins on the engine side to their corresponding plugin code on
  /// the framework side.
  ///
  /// This exposes the [dart:ui.channelBuffers] object. Bindings can override
  /// this getter to intercept calls to the [ChannelBuffers] mechanism (for
  /// example, for tests).
  ///
  /// In production, direct access to this object should not be necessary.
  /// Messages are received and dispatched by the [defaultBinaryMessenger]. This
  /// object is primarily used to send mock messages in tests, via the
  /// [ChannelBuffers.push] method (simulating a plugin sending a message to the
  /// framework).
  ///
  /// See also:
  ///
  ///  * [PlatformDispatcher.sendPlatformMessage], which is used for sending
  ///    messages to plugins from the framework (the opposite of
  ///    [channelBuffers]).
  ///  * [platformDispatcher], the [PlatformDispatcher] singleton.
  ui.ChannelBuffers get channelBuffers => ui.channelBuffers;

  /// Creates a default [BinaryMessenger] instance that can be used for sending
  /// platform messages.
  ///
  /// Many Flutter framework components that communicate with the platform
  /// assume messages are received by the platform in the same order in which
  /// they are sent. When overriding this method, be sure the [BinaryMessenger]
  /// implementation guarantees FIFO delivery.
  @protected
  BinaryMessenger createBinaryMessenger() {
    return const _DefaultBinaryMessenger._();
  }

  /// Called when the operating system notifies the application of a memory
  /// pressure situation.
  ///
  /// This method exposes the `memoryPressure` notification from
  /// [SystemChannels.system].
  @protected
  @mustCallSuper
  void handleMemoryPressure() {
    rootBundle.clear();
  }

  /// Handler called for messages received on the [SystemChannels.system]
  /// message channel.
  ///
  /// Other bindings may override this to respond to incoming system messages.
  @protected
  @mustCallSuper
  Future<void> handleSystemMessage(Object systemMessage) async {
    final Map<String, dynamic> message = systemMessage as Map<String, dynamic>;
    final String type = message['type'] as String;
    switch (type) {
      case 'memoryPressure':
        handleMemoryPressure();
    }
    return;
  }

  /// Adds relevant licenses to the [LicenseRegistry].
  ///
  /// By default, the [ServicesBinding]'s implementation of [initLicenses] adds
  /// all the licenses collected by the `flutter` tool during compilation.
  @protected
  @mustCallSuper
  void initLicenses() {
    LicenseRegistry.addLicense(_addLicenses);
  }

  Stream<LicenseEntry> _addLicenses() {
    late final StreamController<LicenseEntry> controller;
    controller = StreamController<LicenseEntry>(
      onListen: () async {
        late final String rawLicenses;
        if (kIsWeb) {
          // NOTICES for web isn't compressed since we don't have access to
          // dart:io on the client side and it's already compressed between
          // the server and client.
          rawLicenses = await rootBundle.loadString('NOTICES', cache: false);
        } else {
          // The compressed version doesn't have a more common .gz extension
          // because gradle for Android non-transparently manipulates .gz files.
          final ByteData licenseBytes = await rootBundle.load('NOTICES.Z');
          final List<int> unzippedBytes = await compute<List<int>, List<int>>(gzip.decode, licenseBytes.buffer.asUint8List(), debugLabel: 'decompressLicenses');
          rawLicenses = await compute<List<int>, String>(utf8.decode, unzippedBytes, debugLabel: 'utf8DecodeLicenses');
        }
        final List<LicenseEntry> licenses = await compute<String, List<LicenseEntry>>(_parseLicenses, rawLicenses, debugLabel: 'parseLicenses');
        licenses.forEach(controller.add);
        await controller.close();
      },
    );
    return controller.stream;
  }

  // This is run in another isolate created by _addLicenses above.
  static List<LicenseEntry> _parseLicenses(String rawLicenses) {
    final String licenseSeparator = '\n${'-' * 80}\n';
    final List<LicenseEntry> result = <LicenseEntry>[];
    final List<String> licenses = rawLicenses.split(licenseSeparator);
    for (final String license in licenses) {
      final int split = license.indexOf('\n\n');
      if (split >= 0) {
        result.add(LicenseEntryWithLineBreaks(
          license.substring(0, split).split('\n'),
          license.substring(split + 2),
        ));
      } else {
        result.add(LicenseEntryWithLineBreaks(const <String>[], license));
      }
    }
    return result;
  }

  @override
  void initServiceExtensions() {
    super.initServiceExtensions();

    assert(() {
      registerStringServiceExtension(
        name: ServicesServiceExtensions.evict.name,
        getter: () async => '',
        setter: (String value) async {
          evict(value);
        },
      );

      registerServiceExtension(name: 'invokePreHotRestartCallbacks', callback: (Map<String, Object> params) async {
        Future<void> invokeAndWait(DebugPreHotRestartCallback callback, String label) async {
          developer.postEvent('preHotRestartCallback', <String, Object>{'label': label, 'finished': false});
          try {
            await Future<Object?>.value(callback());
          } catch (error, stack) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                context: ErrorSummary('Failed to invoke preHotRestartCallback "$label"'),
              )
            );
          } finally {
            developer.postEvent('preHotRestartCallback', <String, Object>{'label': label, 'finished': true});
          }
        }

        await Future.wait(<Future<void>>[
          for (final MapEntry<DebugPreHotRestartCallback, String> entry in _hotRestartCallbacks.entries)
            invokeAndWait(entry.key, entry.value),
        ]);
        return <String, Object>{};
      });
      return true;
    }());
  }

  /// Called in response to the `ext.flutter.evict` service extension.
  ///
  /// This is used by the `flutter` tool during hot reload so that any images
  /// that have changed on disk get cleared from caches.
  @protected
  @mustCallSuper
  void evict(String asset) {
    rootBundle.evict(asset);
  }

  // App life cycle

  /// Initializes the [lifecycleState] with the
  /// [dart:ui.PlatformDispatcher.initialLifecycleState].
  ///
  /// Once the [lifecycleState] is populated through any means (including this
  /// method), this method will do nothing. This is because the
  /// [dart:ui.PlatformDispatcher.initialLifecycleState] may already be stale
  /// and it no longer makes sense to use the initial state at dart vm startup
  /// as the current state anymore.
  ///
  /// The latest state should be obtained by subscribing to
  /// [WidgetsBindingObserver.didChangeAppLifecycleState].
  @protected
  void readInitialLifecycleStateFromNativeWindow() {
    if (lifecycleState != null || platformDispatcher.initialLifecycleState.isEmpty) {
      return;
    }
    _handleLifecycleMessage(platformDispatcher.initialLifecycleState);
  }

  Future<String?> _handleLifecycleMessage(String? message) async {
    final AppLifecycleState? state = _parseAppLifecycleMessage(message!);
    final List<AppLifecycleState> generated = _generateStateTransitions(lifecycleState, state!);
    generated.forEach(handleAppLifecycleStateChanged);
    return null;
  }

  List<AppLifecycleState> _generateStateTransitions(AppLifecycleState? previousState, AppLifecycleState state) {
    if (previousState == state) {
      return const <AppLifecycleState>[];
    }
    if (previousState == AppLifecycleState.paused && state == AppLifecycleState.detached) {
      // Handle the wrap-around from paused to detached
      return const <AppLifecycleState>[
        AppLifecycleState.detached,
      ];
    }
    final List<AppLifecycleState> stateChanges = <AppLifecycleState>[];
    if (previousState == null) {
      // If there was no previous state, just jump directly to the new state.
      stateChanges.add(state);
    } else {
      final int previousStateIndex = AppLifecycleState.values.indexOf(previousState);
      final int stateIndex = AppLifecycleState.values.indexOf(state);
      assert(previousStateIndex != -1, 'State $previousState missing in stateOrder array');
      assert(stateIndex != -1, 'State $state missing in stateOrder array');
      if (previousStateIndex > stateIndex) {
        for (int i = stateIndex; i < previousStateIndex; ++i) {
          stateChanges.insert(0, AppLifecycleState.values[i]);
        }
      } else {
        for (int i = previousStateIndex + 1; i <= stateIndex; ++i) {
          stateChanges.add(AppLifecycleState.values[i]);
        }
      }
    }
    assert((){
      AppLifecycleState? starting = previousState;
      for (final AppLifecycleState ending in stateChanges) {
        if (!_debugVerifyLifecycleChange(starting, ending)) {
          return false;
        }
        starting = ending;
      }
      return true;
    }(), 'Invalid lifecycle state transition generated from $previousState to $state (generated $stateChanges)');
    return stateChanges;
  }

  static bool _debugVerifyLifecycleChange(AppLifecycleState? starting, AppLifecycleState ending) {
    if (starting == null) {
      // Any transition from null is fine, since it is initializing the state.
      return true;
    }
    if (starting == ending) {
      // Any transition to itself shouldn't happen.
      return false;
    }
    switch (starting) {
      case AppLifecycleState.detached:
        if (ending == AppLifecycleState.resumed || ending == AppLifecycleState.paused) {
          return true;
        }
      case AppLifecycleState.resumed:
        // Can't go from resumed to detached directly (must go through paused).
        if (ending == AppLifecycleState.inactive) {
          return true;
        }
      case AppLifecycleState.inactive:
        if (ending == AppLifecycleState.resumed || ending == AppLifecycleState.hidden) {
          return true;
        }
      case AppLifecycleState.hidden:
        if (ending == AppLifecycleState.inactive || ending == AppLifecycleState.paused) {
          return true;
        }
      case AppLifecycleState.paused:
        if (ending == AppLifecycleState.hidden || ending == AppLifecycleState.detached) {
          return true;
        }
    }
    return false;
  }

  Future<dynamic> _handlePlatformMessage(MethodCall methodCall) async {
    final String method = methodCall.method;
    assert(method == 'SystemChrome.systemUIChange' || method == 'System.requestAppExit');
    switch (method) {
      case 'SystemChrome.systemUIChange':
        final List<dynamic> args = methodCall.arguments as List<dynamic>;
        if (_systemUiChangeCallback != null) {
          await _systemUiChangeCallback!(args[0] as bool);
        }
      case 'System.requestAppExit':
        return <String, dynamic>{'response': (await handleRequestAppExit()).name};
    }
  }

  static AppLifecycleState? _parseAppLifecycleMessage(String message) {
    switch (message) {
      case 'AppLifecycleState.resumed':
        return AppLifecycleState.resumed;
      case 'AppLifecycleState.inactive':
        return AppLifecycleState.inactive;
      case 'AppLifecycleState.hidden':
        return AppLifecycleState.hidden;
      case 'AppLifecycleState.paused':
        return AppLifecycleState.paused;
      case 'AppLifecycleState.detached':
        return AppLifecycleState.detached;
    }
    return null;
  }

  /// Handles any requests for application exit that may be received on the
  /// [SystemChannels.platform] method channel.
  ///
  /// By default, returns [ui.AppExitResponse.exit].
  ///
  /// {@template flutter.services.binding.ServicesBinding.requestAppExit}
  /// Not all exits are cancelable, so not all exits will call this function. Do
  /// not rely on this function as a place to save critical data, because you
  /// will be disappointed. There are a number of ways that the application can
  /// exit without letting the application know first: power can be unplugged,
  /// the battery removed, the application can be killed in a task manager or
  /// command line, or the device could have a rapid unplanned disassembly (i.e.
  /// it could explode). In all of those cases (and probably others), no
  /// notification will be given to the application that it is about to exit.
  /// {@endtemplate}
  ///
  /// {@tool sample}
  /// This examples shows how an application can cancel (or not) OS requests for
  /// quitting an application. Currently this is only supported on macOS and
  /// Linux.
  ///
  /// ** See code in examples/api/lib/services/binding/handle_request_app_exit.0.dart **
  /// {@end-tool}
  ///
  /// See also:
  ///
  /// * [WidgetsBindingObserver.didRequestAppExit], which can be overridden to
  ///   respond to this message.
  /// * [WidgetsBinding.handleRequestAppExit] which overrides this method to
  ///   notify its observers.
  Future<ui.AppExitResponse> handleRequestAppExit() async {
    return ui.AppExitResponse.exit;
  }

  /// Exits the application by calling the native application API method for
  /// exiting an application cleanly.
  ///
  /// This differs from calling `dart:io`'s [exit] function in that it gives the
  /// engine a chance to clean up resources so that it doesn't crash on exit, so
  /// calling this is always preferred over calling [exit]. It also optionally
  /// gives handlers of [handleRequestAppExit] a chance to cancel the
  /// application exit.
  ///
  /// The [exitType] indicates what kind of exit to perform. For
  /// [ui.AppExitType.cancelable] exits, the application is queried through a
  /// call to [handleRequestAppExit], where the application can optionally
  /// cancel the request for exit. If the [exitType] is
  /// [ui.AppExitType.required], then the application exits immediately without
  /// querying the application.
  ///
  /// For [ui.AppExitType.cancelable] exits, the returned response value is the
  /// response obtained from the application as to whether the exit was canceled
  /// or not. Practically, the response will never be [ui.AppExitResponse.exit],
  /// since the application will have already exited by the time the result
  /// would have been received.
  ///
  /// The optional [exitCode] argument will be used as the application exit code
  /// on platforms where an exit code is supported. On other platforms it may be
  /// ignored. It defaults to zero.
  ///
  /// See also:
  ///
  /// * [WidgetsBindingObserver.didRequestAppExit] for a handler you can
  ///   override on a [WidgetsBindingObserver] to receive exit requests.
  Future<ui.AppExitResponse> exitApplication(ui.AppExitType exitType, [int exitCode = 0]) async {
    final Map<String, Object?>? result = await SystemChannels.platform.invokeMethod<Map<String, Object?>>(
      'System.exitApplication',
      <String, Object?>{'type': exitType.name, 'exitCode': exitCode},
    );
    if (result == null ) {
      return ui.AppExitResponse.cancel;
    }
    switch (result['response']) {
      case 'cancel':
        return ui.AppExitResponse.cancel;
      case 'exit':
      default:
        // In practice, this will never get returned, because the application
        // will have exited before it returns.
        return ui.AppExitResponse.exit;
    }
  }

  /// The [RestorationManager] synchronizes the restoration data between
  /// engine and framework.
  ///
  /// See the docs for [RestorationManager] for a discussion of restoration
  /// state and how it is organized in Flutter.
  ///
  /// To use a different [RestorationManager] subclasses can override
  /// [createRestorationManager], which is called to create the instance
  /// returned by this getter.
  RestorationManager get restorationManager => _restorationManager;
  late RestorationManager _restorationManager;

  /// Creates the [RestorationManager] instance available via
  /// [restorationManager].
  ///
  /// Can be overridden in subclasses to create a different [RestorationManager].
  @protected
  RestorationManager createRestorationManager() {
    return RestorationManager();
  }

  SystemUiChangeCallback? _systemUiChangeCallback;

  /// Sets the callback for the `SystemChrome.systemUIChange` method call
  /// received on the [SystemChannels.platform] channel.
  ///
  /// This is typically not called directly. System UI changes that this method
  /// responds to are associated with [SystemUiMode]s, which are configured
  /// using [SystemChrome]. Use [SystemChrome.setSystemUIChangeCallback] to configure
  /// along with other SystemChrome settings.
  ///
  /// See also:
  ///
  ///   * [SystemChrome.setEnabledSystemUIMode], which specifies the
  ///     [SystemUiMode] to have visible when the application is running.
  // ignore: use_setters_to_change_properties, (API predates enforcing the lint)
  void setSystemUiChangeCallback(SystemUiChangeCallback? callback) {
    _systemUiChangeCallback = callback;
  }

  final Map<DebugPreHotRestartCallback, String> _hotRestartCallbacks = <DebugPreHotRestartCallback, String>{};

  /// Register a callback that will be invoked before a hot restart is called.
  ///
  /// In non-debug modes this method is a no-op. This can be used to release native
  /// resources acquired through platform channels or `dart:ffi`. Future returning
  /// callbacks will be awaited, allowing for async tear downs.
  ///
  /// {@tool snippet}
  /// The following sample code shows how to use debugRegisterHotRestartCallback to handle
  /// tearing down a native resource acquired through `dart:ffi`. In this example, if
  /// the `context` pointer is not passed through to the `_destroyContext` function before
  /// a hot restart, the application will crash after a hot restart.
  ///
  /// ```dart
  /// import 'dart:ffi';
  /// import 'package:flutter/foundation.dart';
  /// import 'package:flutter/widgets.dart';
  ///
  /// final DynamicLibrary _lib = DynamicLibrary.open('some_native_lib.dll');
  ///
  /// final Pointer<NativeType> Function() _createContext = _lib.lookupFunction<
  ///     Pointer<NativeType> Function(),
  ///     Pointer<NativeType> Function()>('Native_create');
  ///
  /// final void Function(Pointer<NativeType>) _destroyContext = _lib.lookupFunction<
  ///     Void Function(Pointer<NativeType>),
  ///     void Function(Pointer<NativeType>)>('Native_destroy');
  ///
  /// class NativeResourceService {
  ///   NativeResourceService() {
  ///     if (kDebugMode) {
  ///       ServicesBinding.instance.debugRegisterHotRestartCallback(
  ///           () => _destroyContext(_context),
  ///           debugLabel: 'NativeResourceService',
  ///       );
  ///     }
  ///   }
  ///
  ///   /// Acquire native resources that must be released before they can
  ///   /// be re-acquired.
  ///   late final Pointer<NativeType> _context = _createContext();
  /// }
  /// ```
  /// {@end-tool}
  void debugRegisterHotRestartCallback(DebugPreHotRestartCallback callback, {String debugLabel = 'unknown'}) {
    assert(kDebugMode, '''debugRegisterHotRestartCallback can only be called in debug mode. '''
                       '''Use kDebugMode or wrap the call in an assert.''');
    if (!kDebugMode) {
      throw StateError('debugRegisterHotRestartCallback can only be called in debug mode. '
                       'Use kDebugMode or wrap the call in an assert.');
    }
    _hotRestartCallbacks[callback] = debugLabel;
  }

  /// Alert the engine that the binding is registered. This instructs the engine to
  /// register its top level window handler on Windows. This signals that the app
  /// is able to process "System.requestAppExit" signals from the engine.
  @protected
  Future<void> initializationComplete() async {
    await SystemChannels.platform.invokeMethod('System.initializationComplete');
  }
}

/// Signature for listening to changes in the [SystemUiMode].
///
/// Set by [SystemChrome.setSystemUIChangeCallback].
typedef SystemUiChangeCallback = Future<void> Function(bool systemOverlaysAreVisible);

/// The default implementation of [BinaryMessenger].
///
/// This messenger sends messages from the app-side to the platform-side and
/// dispatches incoming messages from the platform-side to the appropriate
/// handler.
class _DefaultBinaryMessenger extends BinaryMessenger {
  const _DefaultBinaryMessenger._();

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? message,
    ui.PlatformMessageResponseCallback? callback,
  ) async {
    ui.channelBuffers.push(channel, message, (ByteData? data) {
      if (callback != null) {
        callback(data);
      }
    });
  }

  @override
  Future<ByteData?> send(String channel, ByteData? message) {
    final Completer<ByteData?> completer = Completer<ByteData?>();
    // ui.PlatformDispatcher.instance is accessed directly instead of using
    // ServicesBinding.instance.platformDispatcher because this method might be
    // invoked before any binding is initialized. This issue was reported in
    // #27541. It is not ideal to statically access
    // ui.PlatformDispatcher.instance because the PlatformDispatcher may be
    // dependency injected elsewhere with a different instance. However, static
    // access at this location seems to be the least bad option.
    // TODO(ianh): Use ServicesBinding.instance once we have better diagnostics
    // on that getter.
    ui.PlatformDispatcher.instance.sendPlatformMessage(channel, message, (ByteData? reply) {
      try {
        completer.complete(reply);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'services library',
          context: ErrorDescription('during a platform message response callback'),
        ));
      }
    });
    return completer.future;
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null) {
      ui.channelBuffers.clearListener(channel);
    } else {
      ui.channelBuffers.setListener(channel, (ByteData? data, ui.PlatformMessageResponseCallback callback) async {
        ByteData? response;
        try {
          response = await handler(data);
        } catch (exception, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'services library',
            context: ErrorDescription('during a platform message callback'),
          ));
        } finally {
          callback(response);
        }
      });
    }
  }
}
