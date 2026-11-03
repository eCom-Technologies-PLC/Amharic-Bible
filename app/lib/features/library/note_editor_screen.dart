import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';

/// Create or edit a note attached to a verse range.
///
/// Leaving with unsaved changes asks first, and deleting a note (including
/// saving it empty) asks for confirmation, so no writing is lost by accident.
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
  final _tags = TextEditingController();
  bool _loaded = false;
  String _savedBody = '';
  String _savedTags = '';
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.noteId != null) {
      final notes = await ref.read(userRepositoryProvider).notesInRange(widget.vkeyStart, widget.vkeyEnd);
      final note = notes.where((n) => n.id == widget.noteId).firstOrNull;
      if (note != null) {
        _savedBody = note.body;
        _savedTags = note.tags.join(', ');
        _controller.text = _savedBody;
        _tags.text = _savedTags;
      }
    }
    // Listen only after loading, so filling in the saved note isn't a change.
    _controller.addListener(_onEdited);
    _tags.addListener(_onEdited);
    if (mounted) setState(() => _loaded = true);
  }

  void _onEdited() {
    final dirty = _controller.text.trim() != _savedBody.trim() || _tags.text.trim() != _savedTags.trim();
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<bool> _confirmDelete() {
    final s = S.of(context);
    return showConfirmDialog(
      context: context,
      title: s.deleteNoteConfirm,
      message: s.deleteNoteMessage,
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      destructive: true,
    );
  }

  Future<void> _save() async {
    final body = _controller.text.trim();
    final repo = ref.read(userRepositoryProvider);
    if (body.isEmpty) {
      // An empty new note has nothing to save; emptying an existing note
      // deletes it, which needs confirming.
      if (widget.noteId != null) {
        if (!await _confirmDelete()) return;
        await repo.deleteNote(widget.noteId!);
      }
    } else {
      await repo.saveNote(
        id: widget.noteId,
        vkeyStart: widget.vkeyStart,
        vkeyEnd: widget.vkeyEnd,
        body: body,
        tags: parseTags(_tags.text),
      );
    }
    invalidateUserData(ref);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    if (!await _confirmDelete()) return;
    await ref.read(userRepositoryProvider).deleteNote(widget.noteId!);
    invalidateUserData(ref);
    if (mounted) context.pop();
  }

  /// Back with unsaved changes: ask before throwing them away.
  Future<void> _onBackBlocked() async {
    final s = S.of(context);
    final leave = await showConfirmDialog(
      context: context,
      title: s.discardChanges,
      message: s.discardChangesMessage,
      confirmLabel: s.discard,
      cancelLabel: s.keepEditing,
      destructive: true,
    );
    if (leave && mounted) context.pop();
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

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackBlocked();
      },
      child: AppScaffold(
        title: title.isEmpty ? s.note : title,
        actions: [
          if (widget.noteId != null)
            IconButton(tooltip: s.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
          AppButton.ghost(label: s.save, size: AppButtonSize.sm, onPressed: _loaded ? _save : null),
        ],
        body: !_loaded
            ? const LoadingState()
            : ContentWidth(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  // The note field fills the space above the tags field and
                  // scrolls itself; the scaffold keeps both above the keyboard.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _controller,
                          hint: s.noteHint,
                          autofocus: true,
                          multiline: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(controller: _tags, label: s.tags, hint: s.tagsHint, prefixIcon: Icons.label_outline),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
