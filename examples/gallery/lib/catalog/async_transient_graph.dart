import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/foundation.dart';

/// The graph the async transient entry looks at, owned by that entry alone.

/// Counts the builds and keeps what came back, so the screen can show that
/// every call is a build of its own.
class ReportDesk extends ChangeNotifier {
  var _built = 0;
  final _received = <Report>[];

  int get built => _built;

  List<Report> get received => List.unmodifiable(_received);

  int nextNumber() {
    _built++;
    notifyListeners();
    return _built;
  }

  void receive(Report report) {
    _received.add(report);
    notifyListeners();
  }
}

/// Assembled on request, and wanted fresh by whoever asks — an async
/// transient.
class Report {
  Report(this.number);

  final int number;
}

final class ReportFactory implements CobaltAsyncFactory<Report> {
  const ReportFactory();

  /// Long enough to see on a device. Only a tap starts it, so no test that
  /// merely opens the entry is left with a pending timer.
  static const buildTime = Duration(milliseconds: 500);

  @override
  Future<Report> create(CobaltResolver resolver) async {
    final number = resolver.get<ReportDesk>().nextNumber();
    await Future<void>.delayed(buildTime);
    return Report(number);
  }
}

/// What the entry owns for as long as it is open.
final class AsyncTransientScope implements CobaltScopeBuilder {
  const AsyncTransientScope();

  @override
  void build(CobaltScope scope) {
    scope.registerSingleton<ReportDesk>(ReportDesk());
    scope.registerAsyncFactory<Report>(const ReportFactory());
  }
}
