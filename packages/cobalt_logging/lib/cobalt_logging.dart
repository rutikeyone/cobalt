/// `package:logging` adapter for Cobalt.
///
/// One class: [CobaltLoggingSink], which a `CobaltLogObserver` writes through.
/// Everything else — which events exist, how they are worded — lives in
/// `package:cobalt`.
library;

export 'package:cobalt_logging/src/cobalt_logging_sink.dart';
