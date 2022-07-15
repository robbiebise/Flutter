// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'system_channels.dart';

/// A data structure representing a range of misspelled text and the suggested
/// replacements for this range.
///
/// For example, one [SuggestionSpan] of the
/// [List<SuggestionSpan>] suggestions of the [SpellCheckResults] corresponding
/// to "Hello, wrold!" may be:
/// ```dart
/// SuggestionSpan(TextRange(7, 12), List<String>.from["word, world, old"])
/// ```
@immutable
class SuggestionSpan {
  /// Creates a span representing a misspelled range of text and the replacements
  /// suggested by a spell checker.
  ///
  /// The [range] and replacement [suggestions] must all not
  /// be null.
  const SuggestionSpan(this.range, this.suggestions)
      : assert(range != null),
        assert(suggestions != null);

  /// The misspelled range of text.
  final TextRange range;

  /// The alternate suggestions for the misspelled range of text.
  final List<String> suggestions;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
        return true;
    }

    return other is SuggestionSpan &&
        other.range.start == range.start &&
        other.range.end == range.end &&
        listEquals<String>(other.suggestions, suggestions);
  }

  @override
  int get hashCode => Object.hash(range.start, range.end, Object.hashAll(suggestions));
}

/// A data structure grouping together the [SuggestionSpan]s and related text of
/// results returned by a spell checker.
@immutable
class SpellCheckResults {
  /// Creates results based off those received by spell checking some text input.
  const SpellCheckResults(this.spellCheckedText, this.suggestionSpans)
      : assert(spellCheckedText != null),
        assert(suggestionSpans != null);

  /// The text that the [suggestionSpans] correspond to.
  final String spellCheckedText;

  /// The spell check results of the [spellCheckedText].
  ///
  /// See also:
  ///
  ///  * [SuggestionSpan], the ranges of misspelled text and corresponding
  ///    replacement suggestions.
  final List<SuggestionSpan> suggestionSpans;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
        return true;
    }

    return other is SpellCheckResults &&
        other.spellCheckedText == spellCheckedText &&
        listEquals<SuggestionSpan>(other.suggestionSpans, suggestionSpans);
  }

  @override
  int get hashCode => Object.hash(spellCheckedText, Object.hashAll(suggestionSpans));
}

/// Determines how spell check results are received for text input.
abstract class SpellCheckService {
  /// Facilitates a spell check request.
  ///
  /// Returns a [Future] that resolves with a [List] of [SuggestionSpan]s for
  /// all misspelled words in [text] for the given [locale].
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale, String text
  );
}

/// The service used by default to fetch spell check results for text input.
///
/// Any widget may use this service to spell check text by calling
/// `fetchSpellCheckSuggestions(locale, text)` with an instance of this class.
/// This is currently only supported by Android.
///
/// See also:
///
///  * [SpellCheckService], the service that this implements and may be
///    overriden for use by [EditableText].
///  * [EditableText], which may use this service to fetch results.
class DefaultSpellCheckService implements SpellCheckService {
  /// Creates service to spell check text input by default via communcication
  /// over the spell check [MethodChannel].
  DefaultSpellCheckService() {
    spellCheckChannel = SystemChannels.spellCheck;
  }

  /// The last recieved [SuggestionSpan]s from the shell side.
  List<SuggestionSpan>? lastSavedSpans;

  /// The text corresponding to the [lastSavedSpans].
  String? lastSavedText;

  /// The channel used to communicate with the shell side to complete spell
  /// check requests.
  late MethodChannel spellCheckChannel;

  /// Merges two lists of spell check [SuggestionSpan]s.
  ///
  /// Used in cases where the text has not changed, but the spell check results
  /// received from the shell side have. This case is caused by IMEs (GBoard,
  /// for instance) that ignore the composing region when spell checking text.
  static List<SuggestionSpan> mergeResults(
      List<SuggestionSpan> oldResults, List<SuggestionSpan> newResults) {
    final List<SuggestionSpan> mergedResults = <SuggestionSpan>[];

    SuggestionSpan oldSpan;
    SuggestionSpan newSpan;
    int oldSpanPointer = 0;
    int newSpanPointer = 0;

    while (oldSpanPointer < oldResults.length &&
        newSpanPointer < newResults.length) {
      oldSpan = oldResults[oldSpanPointer];
      newSpan = newResults[newSpanPointer];

      if (oldSpan.range.start == newSpan.range.start) {
        mergedResults.add(oldSpan);
        oldSpanPointer++;
        newSpanPointer++;
      } else {
        if (oldSpan.range.start < newSpan.range.start) {
          mergedResults.add(oldSpan);
          oldSpanPointer++;
        } else {
          mergedResults.add(newSpan);
          newSpanPointer++;
        }
      }
    }

    mergedResults.addAll(oldResults.sublist(oldSpanPointer));
    mergedResults.addAll(newResults.sublist(newSpanPointer));

    return mergedResults;
  }

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
      Locale locale, String text) async {
    assert(locale != null);
    assert(text != null);

    final List<dynamic> rawResults;

    try {
      rawResults = await spellCheckChannel.invokeMethod(
        'SpellCheck.initiateSpellCheck',
        <String>[locale.toLanguageTag(), text],
      ) as List<dynamic>;
    } catch (e) {
      // Spell check request canceled due to pending request.
      return null;
    }

    List<SuggestionSpan> suggestionSpans = <SuggestionSpan>[];

    for (final dynamic result in rawResults) {
      Map<String, dynamic> resultMap = Map<String,dynamic>.from(result);
      suggestionSpans.add(
        SuggestionSpan(
          TextRange(
            start: resultMap['startIndex'],
            end: resultMap['endIndex']),
          resultMap['suggestions'].cast<String>(),
        )
      );
    }

    // Merge current and previous spell check results if between requests,
    // the text has not changed but the spell check results have.
    final bool textHasNotChanged = lastSavedText != null && lastSavedText == text;
    final bool spansHaveChanged =
        lastSavedSpans != null && !listEquals(lastSavedSpans, suggestionSpans);

    if (textHasNotChanged && spansHaveChanged) {
      suggestionSpans = mergeResults(lastSavedSpans!, suggestionSpans);
    }

    lastSavedSpans = suggestionSpans;
    lastSavedText = text;

    return suggestionSpans;
  }
}
