// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/fixes/implement_disposable.dart';
import 'package:cobalt_lint/src/rules/registration_is_never_released.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'fix_support.dart';
import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ImplementDisposableTest);
  });
}

@reflectiveTest
class ImplementDisposableTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    stubCobaltRuntime(this);
    rule = RegistrationIsNeverReleased();
    super.setUp();
  }

  void test_dispose_implementsDisposable() async {
    expect(
      await fixed('''
$cobaltImport
$cobaltRuntimeImport

@cobaltInject
class Notes {
  void dispose() {}
}
''', ImplementDisposable.new),
      '''
$cobaltImport
$cobaltRuntimeImport

@cobaltInject
class Notes implements Disposable {
  void dispose() {}
}
''',
    );
  }

  void test_missingImport_isAdded() async {
    expect(
      await fixed('''
$cobaltImport

@cobaltInject
class Notes {
  void dispose() {}
}
''', ImplementDisposable.new),
      '''
$cobaltRuntimeImport
$cobaltImport

@cobaltInject
class Notes implements Disposable {
  void dispose() {}
}
''',
    );
  }

  void test_existingImplements_isAppendedTo() async {
    expect(
      await fixed('''
$cobaltImport
$cobaltRuntimeImport

abstract interface class Marker {}

@cobaltInject
class Notes extends Object implements Marker {
  void dispose() {}
}
''', ImplementDisposable.new),
      '''
$cobaltImport
$cobaltRuntimeImport

abstract interface class Marker {}

@cobaltInject
class Notes extends Object implements Marker, Disposable {
  void dispose() {}
}
''',
    );
  }

  void test_asyncClose_implementsAsyncDisposableAndDelegates() async {
    expect(
      await fixed('''
$cobaltImport
$cobaltRuntimeImport

@cobaltInject
class Session {
  final String id = '';

  Future<void> close() async {}

  String get label => id;
}
''', ImplementDisposable.new),
      '''
$cobaltImport
$cobaltRuntimeImport

@cobaltInject
class Session implements AsyncDisposable {
  final String id = '';

  Future<void> close() async {}

  @override
  Future<void> dispose() => close();

  String get label => id;
}
''',
    );
  }

  void test_inheritedClose_delegatesInAnEmptyBody() async {
    expect(
      await fixed('''
$cobaltImport
$cobaltRuntimeImport

abstract class Channel {
  void close() {}
}

@cobaltInject
class Notes extends Channel {}
''', ImplementDisposable.new),
      '''
$cobaltImport
$cobaltRuntimeImport

abstract class Channel {
  void close() {}
}

@cobaltInject
class Notes extends Channel implements Disposable {
  @override
  void dispose() => close();
}
''',
    );
  }

  void test_inheritedDispose_needsNoDelegate() async {
    expect(
      await fixed('''
$cobaltImport
$cobaltRuntimeImport

abstract class Notifier {
  void dispose() {}
}

@cobaltInject
class Notes extends Notifier {}
''', ImplementDisposable.new),
      '''
$cobaltImport
$cobaltRuntimeImport

abstract class Notifier {
  void dispose() {}
}

@cobaltInject
class Notes extends Notifier implements Disposable {}
''',
    );
  }

  void test_anotherDispose_isNotFixed() async {
    expect(
      await fixed('''
$cobaltImport
$cobaltRuntimeImport

@cobaltInject
class Notes {
  bool dispose(String reason) => true;

  void close() {}
}
''', ImplementDisposable.new),
      isNull,
    );
  }

  void test_futureOrTeardown_isNotFixed() async {
    expect(
      await fixed('''
import 'dart:async';

$cobaltImport
$cobaltRuntimeImport

@cobaltInject
class Notes {
  FutureOr<void> close() {}
}
''', ImplementDisposable.new),
      isNull,
    );
  }
}
