import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../domain/study.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';
import 'study_widgets.dart';

/// Word study: key words of the Bible's vocabulary (love, faith, grace…),
/// Greek then Hebrew, or the words matching what is typed: a Strong's number,
/// an original word or an English meaning. Each opens its word study.
class WordsScreen extends ConsumerStatefulWidget {
  const WordsScreen({super.key});

  @override
  ConsumerState<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends ConsumerState<WordsScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String q, {bool now = false}) {
    _debounce?.cancel();
    if (now) {
      setState(() => _query = q.trim());
    } else {
      _debounce = Timer(AppMotion.debounce, () {
        if (mounted) setState(() => _query = q.trim());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AppScaffold(
      pageTitle: s.wordStudy,
      titleWidget: AppSearchField(
        controller: _controller,
        hint: s.wordsSearchHint,
        clearTooltip: s.clear,
        onChanged: _search,
        onSubmitted: (q) => _search(q, now: true),
        onClear: () => _search('', now: true),
      ),
      body: ContentWidth(
        child: _query.length >= 2
            ? AsyncView(
                value: ref.watch(lexiconSearchProvider(_query)),
                data: (words) => words.isEmpty
                    ? EmptyState(message: s.noResults, icon: Icons.search_off)
                    : AppListView(children: [for (final w in words) WordTile(word: w)]),
              )
            : AsyncView(
                value: ref.watch(keyWordsProvider),
                data: (words) {
                  if (words.isEmpty) return EmptyState(message: s.wordStudyHint, icon: Icons.translate);
                  final greek = [
                    for (final w in words)
                      if (w.language == LexLanguage.greek) w,
                  ];
                  final hebrew = [
                    for (final w in words)
                      if (w.language != LexLanguage.greek) w,
                  ];
                  return AppListView(
                    children: [
                      if (greek.isNotEmpty) ...[
                        SectionHeader(s.greekWords, first: true),
                        for (final w in greek) WordTile(word: w),
                      ],
                      if (hebrew.isNotEmpty) ...[
                        SectionHeader(s.hebrewWords, first: greek.isEmpty),
                        for (final w in hebrew) WordTile(word: w),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }
}
