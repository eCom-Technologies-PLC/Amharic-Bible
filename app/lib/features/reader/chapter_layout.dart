import '../../domain/models.dart';

/// A run of text inside a paragraph, belonging to one verse.
class Seg {
  const Seg(this.vkey, this.kind, this.text);

  final int vkey;
  final String kind; // num | t | wj | n
  final String text;

  @override
  String toString() => '$kind:$text';
}

sealed class Block {
  const Block();
}

class HeadingBlock extends Block {
  const HeadingBlock(this.heading);
  final Heading heading;
}

/// A prose paragraph (indent 0) or one poetry line (indent 1..3).
class ParaBlock extends Block {
  const ParaBlock(this.segs, {this.indent = 0, this.poetry = false});

  final List<Seg> segs;
  final int indent;
  final bool poetry;

  Set<int> get vkeys => {for (final s in segs) s.vkey};
}

class ChapterLayout {
  const ChapterLayout(this.blocks, this.blockOfVerse);

  final List<Block> blocks;

  /// Index of the block where each verse starts (for scrolling to a verse).
  final Map<int, int> blockOfVerse;
}

/// Groups a chapter's verses into paragraphs and poetry lines, following the
/// source's \p and \q markers, so the reader shows flowing text instead of one
/// verse per line.
ChapterLayout layoutChapter(ChapterContent c) {
  final blocks = <Block>[];
  final blockOfVerse = <int, int>{};
  List<Seg>? cur;
  var indent = 0;
  var poetry = false;

  void close() {
    if (cur != null && cur!.isNotEmpty) {
      blocks.add(ParaBlock(List.unmodifiable(cur!), indent: indent, poetry: poetry));
    }
    cur = null;
  }

  void open(int newIndent, bool isPoetry) {
    close();
    cur = [];
    indent = newIndent;
    poetry = isPoetry;
  }

  for (final v in c.verses) {
    final headings = c.headings[v.vkey];
    if (headings != null) {
      close();
      for (final h in headings) {
        blocks.add(HeadingBlock(h));
      }
    }
    var numberPending = true;
    for (final tok in v.markup) {
      if (tok.kind == 'p') {
        open(0, false);
        continue;
      }
      if (tok.kind == 'q') {
        open(tok.level, true);
        continue;
      }
      if (cur == null) open(0, false);
      if (numberPending) {
        blockOfVerse[v.vkey] = blocks.length;
        cur!.add(Seg(v.vkey, 'num', v.displayNumber));
        numberPending = false;
      }
      cur!.add(Seg(v.vkey, tok.kind, tok.text));
    }
  }
  close();
  return ChapterLayout(blocks, blockOfVerse);
}

/// One verse in two versions, shown side by side (wide screens) or one
/// under the other (phones).
class PairBlock extends Block {
  const PairBlock(this.vkey, this.primary, this.secondary);

  final int vkey;
  final ParaBlock primary;
  final ParaBlock? secondary; // null when the verse is missing in that version
}

/// The verse as a single block: number plus text runs. Paragraph and poetry
/// breaks become spaces so the two columns line up verse by verse.
ParaBlock verseBlock(Verse v) {
  final segs = [Seg(v.vkey, 'num', v.displayNumber)];
  for (final t in v.markup) {
    if (t.isBreak) {
      if (segs.length > 1) segs.add(Seg(v.vkey, 't', ' '));
    } else {
      segs.add(Seg(v.vkey, t.kind, t.text));
    }
  }
  return ParaBlock(segs);
}

/// Verse-by-verse layout of [primary] with [secondary] aligned by verse key.
/// Verses only in the secondary version are appended after their neighbours
/// so nothing is silently dropped.
ChapterLayout parallelLayout(ChapterContent primary, ChapterContent secondary) {
  final blocks = <Block>[];
  final blockOfVerse = <int, int>{};
  final other = {for (final v in secondary.verses) v.vkey: v};
  final keys = {...primary.verses.map((v) => v.vkey), ...other.keys}.toList()..sort();
  final mine = {for (final v in primary.verses) v.vkey: v};
  for (final k in keys) {
    for (final h in primary.headings[k] ?? const <Heading>[]) {
      blocks.add(HeadingBlock(h));
    }
    final a = mine[k], b = other[k];
    blockOfVerse[k] = blocks.length;
    blocks.add(
      a != null
          ? PairBlock(k, verseBlock(a), b != null ? verseBlock(b) : null)
          : PairBlock(k, const ParaBlock([]), verseBlock(b!)),
    );
  }
  return ChapterLayout(blocks, blockOfVerse);
}
