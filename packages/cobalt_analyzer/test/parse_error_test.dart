import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('toString names the error and carries the message', () async {
    final clazz = await classNamed('Widget', '''
class Widget {}
''');

    expect(
      CobaltParseError('something is wrong', clazz).toString(),
      'CobaltParseError: something is wrong',
    );
  });
}
