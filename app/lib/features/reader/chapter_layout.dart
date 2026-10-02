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
