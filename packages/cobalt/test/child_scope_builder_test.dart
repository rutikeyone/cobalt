import 'package:cobalt/cobalt.dart';
import 'package:test/test.dart';

final class Session {}

final class SessionScope extends CobaltChildScopeBuilder {
  const SessionScope(this.user, {this.environment});

  final String user;
  final CobaltEnvironment? environment;

  @override
  Type get marker => Session;

  @override
  List<Object?> get markerValues => [user, environment];

  @override
  void build(CobaltScope scope) {}
}

final class OtherSessionScope extends CobaltChildScopeBuilder {
  const OtherSessionScope(this.user);

  final String user;

  @override
  Type get marker => Session;

  @override
  List<Object?> get markerValues => [user];

  @override
  void build(CobaltScope scope) {}
}

final class SilentScope extends CobaltChildScopeBuilder {
  const SilentScope(this.user);

  final String user;

  @override
  Type get marker => Session;

  @override
  void build(CobaltScope scope) {}
}

void main() {
  group('a child scope builder', () {
    test('equals one of its class with equal values', () {
      const ada = SessionScope('ada');

      expect(SessionScope('ada'), ada);
      expect(SessionScope('ada').hashCode, ada.hashCode);
    });

    test('differs from one with other values', () {
      const ada = SessionScope('ada');

      expect(const SessionScope('bob'), isNot(ada));
      expect(
        const SessionScope('ada', environment: CobaltEnvironment.dev),
        isNot(ada),
      );
    });

    test('differs from one of another class with the same values', () {
      expect(const OtherSessionScope('ada'), isNot(const SessionScope('ada')));
      expect(const SessionScope('ada'), isNot(const OtherSessionScope('ada')));
    });

    test('that does not name its values equals only itself', () {
      final ada = SilentScope('ada');

      expect(ada, ada);
      expect(SilentScope('ada'), isNot(ada));
    });
  });
}
