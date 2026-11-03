import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../domain/study.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';
import 'verse_study_screen.dart' show EntityTile;

/// People, places and events: the most mentioned first, or those whose name
/// starts with what is typed (names are in English, as in the source data).
/// Each opens its page.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  EntityKind? _kind;

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
    final searching = _query.length >= 2;
    final entities = searching
        ? ref.watch(entitySearchProvider((query: _query, kind: _kind)))
        : ref.watch(topEntitiesProvider(_kind));
    return AppScaffold(
      pageTitle: s.peopleAndPlaces,
      titleWidget: AppSearchField(
        controller: _controller,
        hint: s.peopleSearchHint,
        clearTooltip: s.clear,
        onChanged: _search,
        onSubmitted: (q) => _search(q, now: true),
        onClear: () => _search('', now: true),
      ),
      body: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilterBar<EntityKind?>(
              selected: _kind,
              onSelected: (k) => setState(() => _kind = k),
              options: [
                FilterOption(null, s.all),
                FilterOption(EntityKind.person, s.people),
                FilterOption(EntityKind.place, s.places),
                FilterOption(EntityKind.event, s.events),
              ],
            ),
            Expanded(
              child: AsyncView(
                value: entities,
                data: (list) => list.isEmpty
                    ? EmptyState(message: s.noResults, icon: Icons.search_off)
                    : AppListView(
                        children: [
                          if (!searching) SectionHeader(s.mostMentioned, first: true),
                          for (final e in list) EntityTile(entity: e),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
