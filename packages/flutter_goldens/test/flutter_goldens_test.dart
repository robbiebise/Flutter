// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_goldens/flutter_goldens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';

import 'json_templates.dart';

const String _kFlutterRoot = '/flutter';

// 1x1 transparent pixel
const List<int> _kTestPngBytes =
<int>[137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0,
  1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 11, 73, 68, 65, 84,
  120, 1, 99, 97, 0, 2, 0, 0, 25, 0, 5, 144, 240, 54, 245, 0, 0, 0, 0, 73, 69,
  78, 68, 174, 66, 96, 130];

// 1x1 colored pixel
const List<int> _kFailPngBytes =
<int>[137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0,
  1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84,
  120, 1, 99, 249, 207, 240, 255, 63, 0, 7, 18, 3, 2, 164, 147, 160, 197, 0,
  0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130];

void main() {
  MemoryFileSystem fs;
  FakePlatform platform;
  MockProcessManager process;
  MockHttpClient mockHttpClient;

  setUp(() {
    fs = MemoryFileSystem();
    platform = FakePlatform(
      environment: <String, String>{'FLUTTER_ROOT': _kFlutterRoot},
      operatingSystem: 'macos'
    );
    process = MockProcessManager();
    mockHttpClient = MockHttpClient();
    fs.directory(_kFlutterRoot).createSync(recursive: true);
  });

  group('SkiaGoldClient', () {
    SkiaGoldClient skiaClient;

    setUp(() {
      final Directory workDirectory = fs.directory('/workDirectory')
        ..createSync(recursive: true);
      skiaClient = SkiaGoldClient(
        workDirectory,
        fs: fs,
        process: process,
        platform: platform,
        httpClient: mockHttpClient,
      );
    });

    group('auth', () {
      test('performs minimal work if already authorized', () async {
        fs.file('/workDirectory/temp/auth_opt.json')
          ..createSync(recursive: true);
        when(process.run(any))
          .thenAnswer((_) => Future<ProcessResult>
            .value(ProcessResult(123, 0, '', '')));
        await skiaClient.auth();

        verifyNever(process.run(
            captureAny,
            workingDirectory: captureAnyNamed('workingDirectory'),
        ));
      });
    });

    group('Request Handling', () {
      String testName;
      String pullRequestNumber;
      Uri url;
      MockHttpClientRequest mockHttpRequest;

      setUp(() {
        testName = 'flutter.golden_test.1.png';
        pullRequestNumber = '1234';
        url = Uri.parse(
          'https://flutter-gold.skia.org/json/search?source_type%3Dflutter'
            '&head=true&include=true&pos=true&neg=false&unt=false'
            '&query=Platform%3Dmacos%26name%3Dflutter.golden_test.1%26'
        );
        mockHttpRequest = MockHttpClientRequest();
        when(mockHttpClient.getUrl(url))
          .thenAnswer((_) => Future<MockHttpClientRequest>.value(mockHttpRequest));
      });

      test('throws for triage breakdown when digests > 1', () async {
        final MockHttpClientResponse mockHttpResponse = MockHttpClientResponse(
          utf8.encode(digestResponseTemplate(includeExtraDigests: true))
        );
        when(mockHttpRequest.close())
          .thenAnswer((_) => Future<MockHttpClientResponse>.value(mockHttpResponse));

        try {
          await skiaClient.getMasterBytes(testName);
          fail('TestFailure expected but not thrown.');
        } catch (error) {
          expect(error.stderr, contains('There is more than one digest available'));
        }
      });

      test('returns empty bytes for new tests without a baseline', () async {
        final MockHttpClientResponse mockHttpResponse = MockHttpClientResponse(
          utf8.encode(digestResponseTemplate(returnEmptyDigest: true))
        );
        when(mockHttpRequest.close())
          .thenAnswer((_) => Future<MockHttpClientResponse>.value(mockHttpResponse));

        final List<int> imageBytes = await skiaClient.getMasterBytes(testName);
        expect(imageBytes, <int>[]);
      });

      test('validates SkiaDigest', () {
        final Map<String, dynamic> skiaJson = json.decode(digestResponseTemplate());
        final SkiaGoldDigest digest = SkiaGoldDigest.fromJson(skiaJson['digests'][0]);
        expect(digest.isValid(platform, 'flutter.golden_test.1'), isTrue);
      });

      test('detects invalid digests SkiaDigest', () {
        const String testName = 'flutter.golden_test.2';
        final Map<String, dynamic> skiaJson = json.decode(
          digestResponseTemplate());
        final SkiaGoldDigest digest = SkiaGoldDigest.fromJson(
          skiaJson['digests'][0]);
        expect(digest.isValid(platform, testName), isFalse);
      });

      test('throws for invalid SkiaDigest', () async {
        final MockHttpClientResponse mockHttpResponse = MockHttpClientResponse(
          utf8.encode(digestResponseTemplate(testName: 'flutter.golden_test.2'))
        );
        when(mockHttpRequest.close())
          .thenAnswer((_) => Future<MockHttpClientResponse>.value(mockHttpResponse));

        try {
          await skiaClient.getMasterBytes(testName);
          fail('TestFailure expected but not thrown.');
        } catch (error) {
          expect(error.stderr, contains('Invalid digest'));
        }
      });

      test('image bytes are processed properly', () async {
        final Uri imageUrl = Uri.parse(
          'https://flutter-gold.skia.org/img/images/88e2cc3398bd55b55df35cfe14d557c1.png'
        );
        final MockHttpClientResponse mockDigestResponse = MockHttpClientResponse(
          utf8.encode(digestResponseTemplate())
        );
        when(mockHttpRequest.close())
          .thenAnswer((_) => Future<MockHttpClientResponse>.value(mockDigestResponse));

        final MockHttpClientRequest mockImageRequest = MockHttpClientRequest();
        final MockHttpImageResponse mockImageResponse = MockHttpImageResponse(
          imageResponseTemplate()
        );
        when(mockHttpClient.getUrl(imageUrl))
          .thenAnswer((_) => Future<MockHttpClientRequest>.value(mockImageRequest));
        when(mockImageRequest.close())
          .thenAnswer((_) => Future<MockHttpImageResponse>.value(mockImageResponse));

        final List<int> masterBytes = await skiaClient.getMasterBytes(testName);

        expect(masterBytes, equals(_kTestPngBytes));
      });
      group('ignores', () {
        Uri url;
        MockHttpClientRequest mockHttpRequest;
        MockHttpClientResponse mockHttpResponse;

        setUp(() {
          url = Uri.parse('https://flutter-gold.skia.org/json/ignores');
          mockHttpRequest = MockHttpClientRequest();
          mockHttpResponse = MockHttpClientResponse(utf8.encode(
              ignoreResponseTemplate(pullRequestNumber: pullRequestNumber)
          ));
          when(mockHttpClient.getUrl(url))
            .thenAnswer((_) => Future<MockHttpClientRequest>.value(mockHttpRequest));
          when(mockHttpRequest.close())
            .thenAnswer((_) => Future<MockHttpClientResponse>.value(mockHttpResponse));
        });

        test('returns true for ignored test and ignored pull request number', () async {
          expect(
            await skiaClient.testIsIgnoredForPullRequest(
              pullRequestNumber,
              testName,
            ),
            isTrue,
          );
        });

        test('returns false for not ignored test and ignored pull request number', () async {
          expect(
            await skiaClient.testIsIgnoredForPullRequest(
              '5678',
              testName,
            ),
            isFalse,
          );
        });

        test('returns false for ignored test and not ignored pull request number', () async {
         expect(
            await skiaClient.testIsIgnoredForPullRequest(
              pullRequestNumber,
              'failure.png',
            ),
            isFalse,
          );
        });
      });
    });
  });

  group('FlutterGoldenFileComparator', () {
    FlutterSkiaGoldFileComparator comparator;

    setUp(() {
      final Directory basedir = fs.directory('flutter/test/library/')
        ..createSync(recursive: true);
      comparator = FlutterSkiaGoldFileComparator(
        basedir.uri,
        MockSkiaGoldClient(),
        fs: fs,
        platform: platform,
      );
    });

    test('calculates the basedir correctly from defaultComparator', () async {
      final MockLocalFileComparator defaultComparator = MockLocalFileComparator();
      final Directory flutterRoot = fs.directory(platform.environment['FLUTTER_ROOT'])
        ..createSync(recursive: true);
      when(defaultComparator.basedir).thenReturn(flutterRoot.childDirectory('baz').uri);
      final Directory basedir = FlutterGoldenFileComparator.getBaseDirectory(defaultComparator, platform);
      expect(basedir.uri, fs.directory('/flutter/bin/cache/pkg/skia_goldens/baz').uri);
    });

    test('ignores version number', () {
      final Uri key = comparator.getTestUri(Uri.parse('foo.png'), 1);
      expect(key, Uri.parse('foo.png'));
    });

    test('prefixes golden file names with enclosing library', () {
      final Uri prefixedTest = comparator.addPrefix(Uri.parse('foo.png'));
      expect(prefixedTest, Uri.parse('library.foo.png'));
    });

    group('Post-Submit', () {
      final MockSkiaGoldClient mockSkiaClient = MockSkiaGoldClient();

      setUp(() {
        final Directory basedir = fs.directory('flutter/test/library/')
          ..createSync(recursive: true);
        comparator = FlutterSkiaGoldFileComparator(
          basedir.uri,
          mockSkiaClient,
          fs: fs,
          platform: platform,
        );
      });

      test('correctly determines testing environment', () {
        platform = FakePlatform(
          environment: <String, String>{
            'FLUTTER_ROOT': _kFlutterRoot,
            'CIRRUS_CI' : 'true',
            'CIRRUS_PR' : '',
            'CIRRUS_BRANCH' : 'master',
            'GOLD_SERVICE_ACCOUNT' : 'service account...',
          },
          operatingSystem: 'macos'
        );
        expect(
          FlutterSkiaGoldFileComparator.isAvailableForEnvironment(platform),
          isTrue,
        );
      });
    });

    group('Pre-Submit', () {
      FlutterPreSubmitFileComparator comparator;
      final MockSkiaGoldClient mockSkiaClient = MockSkiaGoldClient();

      setUp(() {
        final Directory basedir = fs.directory('flutter/test/library/')
          ..createSync(recursive: true);
        comparator = FlutterPreSubmitFileComparator(
          basedir.uri,
          mockSkiaClient,
          fs: fs,
          platform: FakePlatform(
            environment: <String, String>{
              'FLUTTER_ROOT': _kFlutterRoot,
              'CIRRUS_CI' : 'true',
              'CIRRUS_PR' : '1234',
            },
            operatingSystem: 'macos'
          ),
        );
      });

      test('correctly determines testing environment', () {
        platform = FakePlatform(
          environment: <String, String>{
            'FLUTTER_ROOT': _kFlutterRoot,
            'CIRRUS_CI' : 'true',
            'CIRRUS_PR' : '1234',
          },
          operatingSystem: 'macos'
        );
        expect(
          FlutterPreSubmitFileComparator.isAvailableForEnvironment(platform),
          isTrue,
        );
      });

      test('comparison passes test that is ignored for this PR', () async {
        when(mockSkiaClient.getMasterBytes('library.test.png'))
          .thenAnswer((_) => Future<List<int>>.value(_kTestPngBytes));
        when(mockSkiaClient.testIsIgnoredForPullRequest('1234', 'library.test.png'))
          .thenAnswer((_) => Future<bool>.value(true));
        expect(
          await comparator.compare(
            Uint8List.fromList(_kFailPngBytes),
            Uri.parse('test.png'),
          ),
          isTrue,
        );
      });

      test('fails test that is not ignored for this PR', () async {
        when(mockSkiaClient.getMasterBytes('library.test.png'))
          .thenAnswer((_) => Future<List<int>>.value(_kTestPngBytes));
        when(mockSkiaClient.testIsIgnoredForPullRequest('1234', 'library.test.png'))
          .thenAnswer((_) => Future<bool>.value(false));
        expect(
          await comparator.compare(
            Uint8List.fromList(_kFailPngBytes),
            Uri.parse('test.png'),
          ),
          isFalse,
        );
      });

      test('passes non-existent baseline for new test', () async {
        when(mockSkiaClient.getMasterBytes('library.test.png'))
          .thenAnswer((_) => Future<List<int>>.value(<int>[]));
        when(mockSkiaClient.testIsIgnoredForPullRequest('1234', 'library.test.png'))
          .thenAnswer((_) => Future<bool>.value(true));
        expect(
          await comparator.compare(
            Uint8List.fromList(_kFailPngBytes),
            Uri.parse('test.png'),
          ),
          isTrue,
        );
      });
    });

    group('Local', () {
      FlutterLocalFileComparator comparator;
      final MockSkiaGoldClient mockSkiaClient = MockSkiaGoldClient();

      setUp(() {
        final Directory basedir = fs.directory('flutter/test/library/')
          ..createSync(recursive: true);
        comparator = FlutterLocalFileComparator(
          basedir.uri,
          mockSkiaClient,
          fs: fs,
          platform: FakePlatform(
            environment: <String, String>{'FLUTTER_ROOT': _kFlutterRoot},
            operatingSystem: 'macos'
          ),
        );
      });

      test('passes when bytes match', () async {
        when(mockSkiaClient.getMasterBytes('library.test.png'))
          .thenAnswer((_) => Future<List<int>>.value(_kTestPngBytes));
        expect(
          await comparator.compare(
            Uint8List.fromList(_kTestPngBytes),
            Uri.parse('test.png'),
          ),
          isTrue,
        );
      });

      test('fails when bytes do not match', () async {
        when(mockSkiaClient.getMasterBytes('library.test.png'))
          .thenAnswer((_) => Future<List<int>>.value(_kTestPngBytes));
        try {
          await comparator.compare(
            Uint8List.fromList(_kFailPngBytes),
            Uri.parse('test.png'),
          );
        } catch(error) {
          expect(error.message, contains('Pixel test failed'));
        }
      });

      test('passes non-existent baseline for new test', () async {
        when(mockSkiaClient.getMasterBytes('library.test.png'))
          .thenAnswer((_) => Future<List<int>>.value(<int>[]));
        expect(
          await comparator.compare(
            Uint8List.fromList(_kFailPngBytes),
            Uri.parse('test.png'),
          ),
          isTrue,
        );
      });
    });
  });
}

class MockProcessManager extends Mock implements ProcessManager {}

class MockSkiaGoldClient extends Mock implements SkiaGoldClient {}

class MockLocalFileComparator extends Mock implements LocalFileComparator {}

class MockHttpClient extends Mock implements HttpClient {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {
  MockHttpClientResponse(this.response);

  final Uint8List response;

  @override
  StreamSubscription<Uint8List> listen(
    void onData(Uint8List event), {
      Function onError,
      void onDone(),
      bool cancelOnError,
    }) {
    return Stream<Uint8List>.fromFuture(Future<Uint8List>.value(response))
      .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

class MockHttpImageResponse extends Mock implements HttpClientResponse {
  MockHttpImageResponse(this.response);

  final List<List<int>> response;

  @override
  Future<void> forEach(void action(List<int> element)) async {
    response.forEach(action);
  }
}
