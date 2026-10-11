import 'package:cobalt/cobalt.dart';
import 'package:notes_app/core/event_log.dart';
import 'package:notes_app/features/note_detail/ui/note_detail.dart';

@CobaltInject(scope: NoteDetail)
class NoteDraft implements Disposable {
  NoteDraft(this._log);

  final EventLog _log;

  var text = '';
  var isDiscarded = false;

  @override
  void dispose() {
    isDiscarded = true;
    _log.record('draft discarded');
  }
}
