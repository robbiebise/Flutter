// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

const String emptyPubspecTemplate = '''
# Generated by the flutter tool
name: synthetic_package
description: The Flutter application's synthetic package.
''';

const String fileTemplate = '''
@(header)
import 'dart:async';

// ignore: unused_import
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

@(messageClassImports)

/// Callers can lookup localized strings with an instance of @(class) returned
/// by `@(class).of(context)`.
///
/// Applications need to include `@(class).delegate()` in their app's
/// localizationDelegates list, and the locales they support in the app's
/// supportedLocales list. For example:
///
/// ```
/// import '@(importFile)';
///
/// return MaterialApp(
///   localizationsDelegates: @(class).localizationsDelegates,
///   supportedLocales: @(class).supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the @(class).supportedLocales
/// property.
abstract class @(class) {
  @(class)(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  // ignore: unused_field
  final String localeName;

  static @(class)? of(BuildContext context) {
    return Localizations.of<@(class)>(context, @(class));
  }

  static const LocalizationsDelegate<@(class)> delegate = _@(class)Delegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    @(supportedLocales)
  ];

@(methods)}

@(delegateClass)
''';

const String numberFormatPositionalTemplate = '''
    final intl.NumberFormat @(placeholder)NumberFormat = intl.NumberFormat.@(format)(localeName);
    final String @(placeholder)String = @(placeholder)NumberFormat.format(@(placeholder));
''';

const String numberFormatNamedTemplate = '''
    final intl.NumberFormat @(placeholder)NumberFormat = intl.NumberFormat.@(format)(
      locale: localeName,
      @(parameters)
    );
    final String @(placeholder)String = @(placeholder)NumberFormat.format(@(placeholder));
''';

const String dateFormatTemplate = '''
    final intl.DateFormat @(placeholder)DateFormat = intl.DateFormat.@(format)(localeName);
    final String @(placeholder)String = @(placeholder)DateFormat.format(@(placeholder));
''';

const String getterTemplate = '''
  @override
  String get @(name) => @(message);''';

const String methodTemplate = '''
  @override
  String @(name)(@(parameters)) {
    return @(message);
  }''';

const String formatMethodTemplate = '''
  @override
  String @(name)(@(parameters)) {
@(dateFormatting)
@(numberFormatting)
    return @(message);
  }''';

const String pluralMethodTemplate = '''
  @override
  String @(name)(@(parameters)) {
@(dateFormatting)
@(numberFormatting)
    return intl.Intl.pluralLogic(
      @(count),
      locale: localeName,
@(pluralLogicArgs),
    );
  }''';

const String classFileTemplate = '''
@(header)

@(requiresIntlImport)
import '@(fileName)';

/// The translations for @(language) (`@(localeName)`).
class @(class) extends @(baseClass) {
  @(class)([String locale = '@(localeName)']) : super(locale);

@(methods)
}
@(subclasses)''';

const String subclassTemplate = '''

/// The translations for @(language) (`@(localeName)`).
class @(class) extends @(baseLanguageClassName) {
  @(class)(): super('@(localeName)');

@(methods)
}
''';

const String baseClassGetterTemplate = '''
  /// @(comment)
  ///
@(templateLocaleTranslationComment)
  String get @(name);
''';

const String baseClassMethodTemplate = '''
  /// @(comment)
  ///
@(templateLocaleTranslationComment)
  String @(name)(@(parameters));
''';

// DELEGATE CLASS TEMPLATES

const String delegateClassTemplate = '''
class _@(class)Delegate extends LocalizationsDelegate<@(class)> {
  const _@(class)Delegate();

  @override
  Future<@(class)> load(Locale locale) {
    @(loadBody)
  }

  @override
  bool isSupported(Locale locale) => <String>[@(supportedLanguageCodes)].contains(locale.languageCode);

  @override
  bool shouldReload(_@(class)Delegate old) => false;
}

@(lookupFunction)''';

const String loadBodyTemplate = '''return SynchronousFuture<@(class)>(@(lookupName)(locale));''';

const String loadBodyDeferredLoadingTemplate = '''return @(lookupName)(locale);''';

// DELEGATE LOOKUP TEMPLATES

const String lookupFunctionTemplate = r'''
@(class) @(lookupName)(Locale locale) {
  @(lookupBody)

  throw FlutterError(
    '@(class).delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}''';

const String lookupFunctionDeferredLoadingTemplate = r'''
Future<@(class)> @(lookupName)(Locale locale) {
  @(lookupBody)

  throw FlutterError(
    '@(class).delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}''';

const String lookupBodyTemplate = '''
@(lookupAllCodesSpecified)
@(lookupScriptCodeSpecified)
@(lookupCountryCodeSpecified)
@(lookupLanguageCodeSpecified)''';

const String switchClauseTemplate = '''case '@(case)': return @(localeClass)();''';

const String switchClauseDeferredLoadingTemplate = '''case '@(case)': return @(library).loadLibrary().then((dynamic _) => @(library).@(localeClass)());''';

const String nestedSwitchTemplate = '''
case '@(languageCode)': {
  switch (locale.@(code)) {
    @(switchClauses)
  }
  break;
}''';

const String languageCodeSwitchTemplate = '''
@(comment)
switch (locale.languageCode) {
  @(switchClauses)
}
''';

const String allCodesLookupTemplate = '''
// Lookup logic when language+script+country codes are specified.
switch (locale.toString()) {
  @(allCodesSwitchClauses)
}
''';
