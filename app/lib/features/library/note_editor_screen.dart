import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';

/// Create or edit a note attached to a verse range.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.vkeyStart, required this.vkeyEnd, this.noteId});

  final int vkeyStart;
  final int vkeyEnd;
  final String? noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _controller = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.noteId != null) {
      final notes = await ref.read(userRepositoryProvider).notesInRange(widget.vkeyStart, widget.vkeyEnd);
      final note = notes.where((n) => n.id == widget.noteId).firstOrNull;
      if (note != null) _controller.text = note.body;
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = _controller.text.trim();
    final repo = ref.read(userRepositoryProvider);
    if (body.isEmpty) {
      if (widget.noteId != null) await repo.deleteNote(widget.noteId!);
    } else {
      await repo.saveNote(id: widget.noteId, vkeyStart: widget.vkeyStart, vkeyEnd: widget.vkeyEnd, body: body);
    }
    invalidateUserData(ref);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    await ref.read(userRepositoryProvider).deleteNote(widget.noteId!);
    invalidateUserData(ref);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final version = ref.watch(currentVersionProvider).value;
    final books = version != null ? ref.watch(booksProvider(version.id)).value ?? const <Book>[] : const <Book>[];
    final sameChapter = widget.vkeyStart ~/ 1000 == widget.vkeyEnd ~/ 1000;
    final keys = sameChapter
        ? [for (var k = widget.vkeyStart; k <= widget.vkeyEnd; k++) k]
        : [widget.vkeyStart, widget.vkeyEnd];
    final title = formatKeys(books, keys, amharic: s.isAmharic);

    return AppScaffold(
      title: title.isEmpty ? s.note : title,
      actions: [
        if (widget.noteId != null)
          IconButton(tooltip: s.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
        AppButton.ghost(label: s.save, size: AppButtonSize.sm, onPressed: _loaded ? _save : null),
      ],
      body: !_loaded
          ? const LoadingState()
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: AppTextField(controller: _controller, hint: s.noteHint, autofocus: true, multiline: true),
            ),
    );
  }
}
