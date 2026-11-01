import 'models.dart';

/// Labels for the export, in the reader's language (from lib/core/strings.dart).
class NotesExportLabels {
  const NotesExportLabels({required this.title, required this.exported, required this.tags, required this.scripture});
  final String title;
  final String exported;
  final String tags;
  final String scripture;
}

/// Notes as a Markdown document: one section per note in Bible order, with
/// the passage quoted from [verseTexts] and its source cited at the end.
String notesMarkdown(
  List<Note> notes, {
  required String Function(Note) reference,
  required Map<String, String> verseTexts, // note id -> passage text
  required String versionName,
  required String attribution,
  required NotesExportLabels labels,
  required DateTime now,
}) {
  final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final out = StringBuffer('# ${labels.title}\n\n_${labels.exported}: ${date}_\n');
  final sorted = [...notes]..sort((a, b) => a.vkeyStart.compareTo(b.vkeyStart));
  for (final n in sorted) {
    out.write('\n## ${reference(n)}\n\n');
    if (n.tags.isNotEmpty) out.write('_${labels.tags}: ${n.tags.join(', ')}_\n\n');
    final text = verseTexts[n.id];
    if (text != null && text.isNotEmpty) out.write('> $text\n\n');
    out.write('${n.body.trim()}\n');
  }
  out.write('\n---\n\n${labels.scripture}: $versionName. $attribution\n');
  return out.toString();
}
