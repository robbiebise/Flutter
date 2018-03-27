// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_tools/src/base/context.dart';
import 'package:test/test.dart';

void main() {
  group('AppContext', () {
    group('global getter', () {
      test('returns non-null context in the root zone', () {
        expect(context, isNotNull);
      });

      test('returns root context in child of root zone if zone was manually created', () {
        final Zone rootZone = Zone.current;
        final AppContext rootContext = context;
        runZoned(() {
          expect(Zone.current, isNot(rootZone));
          expect(Zone.current.parent, rootZone);
          expect(context, rootContext);
        });
      });

      test('returns child context after run', () {
        final AppContext rootContext = context;
        rootContext.run(name: 'child', body: () {
          expect(context, isNot(rootContext));
          expect(context.name, 'child');
        });
      });

      test('returns grandchild context after nested run', () {
        final AppContext rootContext = context;
        rootContext.run(name: 'child', body: () {
          final AppContext childContext = context;
          childContext.run(name: 'grandchild', body: () {
            expect(context, isNot(rootContext));
            expect(context, isNot(childContext));
            expect(context.name, 'grandchild');
          });
        });
      });

      test('scans up zone hierarchy for first context', () {
        final AppContext rootContext = context;
        rootContext.run(name: 'child', body: () {
          final AppContext childContext = context;
          runZoned(() {
            expect(context, isNot(rootContext));
            expect(context, same(childContext));
            expect(context.name, 'child');
          });
        });
      });
    });

    group('operator[]', () {
      test('still finds values if async code runs after body has finished', () async {
        final Completer<void> outer = new Completer<void>();
        final Completer<void> inner = new Completer<void>();
        String value;
        context.run<void>(
          body: () {
            outer.future.then((_) {
              value = context[String];
              inner.complete();
            });
          },
          fallbacks: <Type, Generator>{
            String: () => 'value',
          },
        );
        expect(value, isNull);
        outer.complete();
        await inner.future;
        expect(value, 'value');
      });

      test('caches generated override values', () {
        int consultationCount = 0;
        String value;
        context.run(
          body: () {
            final StringBuffer buf = new StringBuffer(context[String]);
            buf.write(context[String]);
            context.run(body: () {
              buf.write(context[String]);
            });
            value = buf.toString();
          },
          overrides: <Type, Generator>{
            String: () {
              consultationCount++;
              return 'v';
            },
          },
        );
        expect(value, 'vvv');
        expect(consultationCount, 1);
      });

      test('caches generated fallback values', () {
        int consultationCount = 0;
        String value;
        context.run(
          body: () {
            final StringBuffer buf = new StringBuffer(context[String]);
            buf.write(context[String]);
            context.run(body: () {
              buf.write(context[String]);
            });
            value = buf.toString();
          },
          fallbacks: <Type, Generator>{
            String: () {
              consultationCount++;
              return 'v';
            },
          },
        );
        expect(value, 'vvv');
        expect(consultationCount, 1);
      });

      test('returns null if generated value is null', () {
        final String value = context.run(
          body: () => context[String],
          overrides: <Type, Generator>{
            String: () => null,
          },
        );
        expect(value, isNull);
      });

      test('throws if generator has dependency cycle', () async {
        final Future<String> value = context.run<Future<String>>(
          body: () async {
            return context[String];
          },
          fallbacks: <Type, Generator>{
            int: () => int.parse(context[String]),
            String: () => '${context[double]}',
            double: () => context[int] * 1.0,
          },
        );
        try {
          await value;
          fail('ContextDependencyCycleException expected but not thrown.');
        } on ContextDependencyCycleException catch (e) {
          expect(e.cycle, <Type>[String, double, int]);
          expect(e.toString(), 'Dependency cycle detected: String -> double -> int');
        }
      });
    });

    group('run', () {
      test('returns the value returned by body', () async {
        expect(context.run<int>(body: () => 123), 123);
        expect(context.run<String>(body: () => 'value'), 'value');
        expect(await context.run<Future<int>>(body: () async => 456), 456);
      });

      test('passes name to child context', () {
        context.run(name: 'child', body: () {
          expect(context.name, 'child');
        });
      });

      group('fallbacks', () {
        bool called;

        setUp(() {
          called = false;
        });

        test('are applied after parent context is consulted', () {
          final String value = context.run<String>(
            body: () {
              return context.run<String>(
                body: () {
                  called = true;
                  return context[String];
                },
                fallbacks: <Type, Generator>{
                  String: () => 'child',
                },
              );
            },
          );
          expect(called, isTrue);
          expect(value, 'child');
        });

        test('are not applied if parent context supplies value', () {
          bool childConsulted = false;
          final String value = context.run<String>(
            body: () {
              return context.run<String>(
                body: () {
                  called = true;
                  return context[String];
                },
                fallbacks: <Type, Generator>{
                  String: () {
                    childConsulted = true;
                    return 'child';
                  },
                },
              );
            },
            fallbacks: <Type, Generator>{
              String: () => 'parent',
            },
          );
          expect(called, isTrue);
          expect(value, 'parent');
          expect(childConsulted, isFalse);
        });

        test('may depend on one another', () {
          final String value = context.run<String>(
            body: () {
              return context[String];
            },
            fallbacks: <Type, Generator>{
              int: () => 123,
              String: () => '-${context[int]}-',
            },
          );
          expect(value, '-123-');
        });
      });

      group('overrides', () {
        test('intercept consultation of parent context', () {
          bool parentConsulted = false;
          final String value = context.run<String>(
            body: () {
              return context.run<String>(
                body: () => context[String],
                overrides: <Type, Generator>{
                  String: () => 'child',
                },
              );
            },
            fallbacks: <Type, Generator>{
              String: () {
                parentConsulted = true;
                return 'parent';
              },
            },
          );
          expect(value, 'child');
          expect(parentConsulted, isFalse);
        });
      });
    });
  });
}
