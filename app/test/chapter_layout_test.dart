import 'package:amharic_bible/domain/models.dart';
import 'package:amharic_bible/features/reader/chapter_layout.dart';
import 'package:flutter_test/flutter_test.dart';

const _book = Book(
  code: 'PSA',
  num: 19,
  ordinal: 1,
  name: 'መዝሙረ ዳዊት',
  shortName: 'መዝሙር',
  abbrev: 'መዝ',
  testament: 'OT',
  chapterCount: 150,
);

Verse _v(int n, String json) => Verse(vkey: 19023000 + n, text: '', markup: Tok.parseList(json));

void main() {
  test('poetry lines and headings become separate blocks', () {
    final c = ChapterContent(
      versionId: 'X',
      book: _book,
      chapter: 23,
      verses: [_v(1, '[["q",1],["t","one;"],["q",2],["t","two."]]'), _v(2, '[["q",1],["t","three;"]]')],
      headings: {
        19023001: [const Heading(19023001, 9, 'Title')],
      },
    );
    final layout = layoutChapter(c);
    expect(layout.blocks.first, isA<HeadingBlock>());
    final paras = layout.blocks.whereType<ParaBlock>().toList();
    expect(paras.map((p) => p.indent), [1, 2, 1]);
    expect(paras.first.segs.map((s) => s.toString()), ['num:1', 't:one;']);
    expect(layout.blockOfVerse, {19023001: 1, 19023002: 3});
  });

  test('prose verses flow into one paragraph until a break', () {
    final c = ChapterContent(
      versionId: 'X',
      book: _book,
      chapter: 23,
      verses: [_v(1, '[["p"],["t","a"]]'), _v(2, '[["t","b"],["n","note"]]'), _v(3, '[["p"],["wj","c"]]')],
      headings: const {},
    );
    final layout = layoutChapter(c);
    expect(layout.blocks, hasLength(2));
    expect((layout.blocks[0] as ParaBlock).segs.map((s) => s.toString()), ['num:1', 't:a', 'num:2', 't:b', 'n:note']);
    expect((layout.blocks[1] as ParaBlock).segs.map((s) => s.kind), ['num', 'wj']);
  });

  test('parallel layout pairs verses by key and keeps verses missing on either side', () {
    final a = ChapterContent(
      versionId: 'A',
      book: _book,
      chapter: 23,
      verses: [_v(1, '[["q",1],["t","one;"],["q",2],["t","two."]]'), _v(2, '[["t","three"]]')],
      headings: {
        19023001: [const Heading(19023001, 9, 'Title')],
      },
    );
    final b = ChapterContent(
      versionId: 'B',
      book: _book,
      chapter: 23,
      verses: [_v(1, '[["t","uno"]]'), _v(3, '[["t","tres"]]')],
      headings: const {},
    );
    final layout = parallelLayout(a, b);
    expect(layout.blocks.first, isA<HeadingBlock>());
    final pairs = layout.blocks.whereType<PairBlock>().toList();
    expect(pairs.map((p) => p.vkey), [19023001, 19023002, 19023003]);
    // Poetry breaks are dropped inside a paired verse.
    expect(pairs[0].primary.segs.map((s) => s.toString()), ['num:1', 't:one;', 't: ', 't:two.']);
    expect(pairs[0].secondary!.segs.map((s) => s.toString()), ['num:1', 't:uno']);
    expect(pairs[1].secondary, isNull);
    expect(pairs[2].primary.segs, isEmpty);
    expect(layout.blockOfVerse[19023003], 3);
  });
}
