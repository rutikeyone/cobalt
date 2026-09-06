// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name. The rule is off per file rather than through a
// `test/analysis_options.yaml`: that file had to `include` the repository
// root, and a copy of this package taken out of the tree — which
// tool/floor_check.sh does — cannot reach it.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/resource_is_never_closed.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ResourceIsNeverClosedTest);
  });
}

@reflectiveTest
class ResourceIsNeverClosedTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = ResourceIsNeverClosed();
    super.setUp();
  }

  void test_subscriptionWithNoWayToClose_isReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

import 'dart:async';

@cobaltInject
class Watcher {
  Watcher(Stream<int> source) {
    _sub = source.listen((_) {});
  }

  late final StreamSubscription<int> _sub;
}
''',
      [lint(104, 7)],
    );
  }

  /// The rule is structural, not a list of known types: anything with a
  /// teardown-shaped method counts, including a type this package has never
  /// heard of.
  void test_aTypeThisPackageHasNeverHeardOf_isReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

class VendorSocket {
  void close() {}
}

@cobaltInject
class Gateway {
  Gateway(this.socket);

  final VendorSocket socket;
}
''',
      [lint(124, 7)],
    );
  }

  /// A class that offers a teardown is the sibling rule's business — reporting
  /// it here too would send the reader to fix one thing twice.
  void test_aClassThatOffersATeardown_isLeftToTheSiblingRule() async {
    await assertNoDiagnostics('''
$cobaltImport

import 'dart:async';

@cobaltInject
class Watcher {
  late final StreamSubscription<int> sub;

  void dispose() {}
}
''');
  }

  void test_disposableHolder_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

import 'dart:async';

abstract class Disposable {
  void dispose();
}

@cobaltInject
class Watcher implements Disposable {
  late final StreamSubscription<int> sub;

  @override
  void dispose() {}
}
''');
  }

  /// The scope never retains a transient, so it was never going to close it.
  void test_transientHolder_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

import 'dart:async';

@cobaltTransient
class Watcher {
  late final StreamSubscription<int> sub;
}
''');
  }

  /// A field of a type the container registers and disposes on its own —
  /// singleton, lazy, or async — is not this class's to close. The scope
  /// releases the field's own registration independently, in its own turn of
  /// the teardown order; nothing about holding a reference to it obligates
  /// the holder.
  void test_fieldThatIsItsOwnRetainedRegistration_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltInject
class Log implements Disposable {
  @override
  void dispose() {}
}

abstract class Disposable {
  void dispose();
}

@cobaltInject
class Reporter {
  Reporter(this._log);
  final Log _log;
}
''');
  }

  /// A field whose type is registered but *transient* is never retained by
  /// the scope, so nobody else is going to close it — this class is still the
  /// one holding it and still has to say how.
  void test_fieldThatIsATransientRegistration_isStillReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

@cobaltTransient
class Ticket {
  Future<void> close() async {}
}

@cobaltInject
class Gateway {
  Gateway(this.ticket);
  final Ticket ticket;
}
''',
      [lint(149, 7)],
    );
  }

  void test_aFieldThatNeedsNoClosing_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltInject
class Plain {
  Plain(this.name);
  final String name;
}
''');
  }

  /// A registration naming its own teardown function has said how.
  void test_namedDisposeFunction_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

import 'dart:async';

void closeWatcher(Watcher it) {}

@CobaltInject(dispose: closeWatcher)
class Watcher {
  late final StreamSubscription<int> sub;
}
''');
  }
}
