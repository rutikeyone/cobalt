import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/bootstrap/boot_log.dart';

import 'support.dart';

/// One snapshot per environment the app is built for, kept in
/// `test/snapshots/`. A change to what an environment registers — a fake
/// swapped in, a step dropped — is a changed line in review, and the files
/// side by side say how `dev` and `prod` differ.
///
/// Accept an intended change with `COBALT_UPDATE_SNAPSHOTS=1`.
void main() {
  setUp(BootLog.reset);

  test('each environment registers what its snapshot says', () async {
    await expectGraphSnapshots(
      (environment) => startNotesGraph(environment: environment),
      environments: {
        CobaltEnvironment.dev,
        CobaltEnvironment.stage,
        CobaltEnvironment.prod,
        CobaltEnvironment.test,
      },
      directory: 'test/snapshots',
    );
  });
}
