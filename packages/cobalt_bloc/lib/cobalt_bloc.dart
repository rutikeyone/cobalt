/// Lets a Cobalt scope close the blocs it built.
///
/// Pure Dart on `bloc` rather than `flutter_bloc`, the same split
/// [`cobalt_talker`](https://pub.dev/packages/cobalt_talker) makes: nothing here
/// needs widgets, and a bloc registered in a scope is a bloc whether or not
/// Flutter is present.
library;

export 'package:cobalt_bloc/src/cobalt_bloc_mixin.dart';
export 'package:cobalt_bloc/src/close_bloc.dart';
