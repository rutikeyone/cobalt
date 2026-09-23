import 'package:cobalt/cobalt.dart';

@cobaltSingleton
class LicenseCheck {
  LicenseCheck() {
    built++;
  }

  static var built = 0;

  bool get isValid => true;
}
