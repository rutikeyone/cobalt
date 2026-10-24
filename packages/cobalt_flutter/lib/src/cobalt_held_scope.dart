import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_flutter/src/cobalt_scope_provider.dart';
import 'package:flutter/widgets.dart';

/// Publishes the scope a [CobaltScopeHolder] holds to [child], and shows
/// [absent] while it holds nothing.
///
/// For a scope opened outside the widget tree, a session from
/// `holder.open` most often:
///
/// ```dart
/// CobaltHeldScope(
///   holder: session,
///   absent: const SignInScreen(),
///   child: const HomeScreen(),
/// )
/// ```
///
/// It rebuilds on every change of the held scope. When the holder starts
/// closing a scope, [absent] replaces [child] before that scope is torn down,
/// so nothing below keeps reading from it.
class CobaltHeldScope extends StatefulWidget {
  /// Publishes what [holder] holds to [child].
  const CobaltHeldScope({
    required this.holder,
    required this.child,
    this.absent = const SizedBox.shrink(),
    super.key,
  });

  /// The holder whose scope is published.
  final CobaltScopeHolder holder;

  /// Built below the held scope while there is one.
  final Widget child;

  /// Built while the holder holds nothing.
  final Widget absent;

  @override
  State<CobaltHeldScope> createState() => _CobaltHeldScopeState();
}

class _CobaltHeldScopeState extends State<CobaltHeldScope> {
  StreamSubscription<CobaltScope?>? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(CobaltHeldScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.holder, widget.holder)) return;
    unawaited(_subscription?.cancel());
    _listen();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _listen() {
    _subscription = widget.holder.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.holder.current;
    if (scope == null) return widget.absent;
    return CobaltScopeProvider(scope: scope, child: widget.child);
  }
}
