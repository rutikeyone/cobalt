import 'package:cobalt/cobalt.dart';
import 'package:notes_app/features/formatting/domain/note_formatter.dart';
import 'package:notes_app/features/note_detail/ui/note_detail.dart';

@CobaltInject(scope: NoteDetail)
class NoteTitleCard {
  NoteTitleCard(@Named('markdown') this._formatter, @cobaltParam this.title);

  final NoteFormatter _formatter;
  final String title;

  String get rendered => _formatter.format(title);
}
