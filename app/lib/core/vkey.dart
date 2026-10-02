/// Verse keys: BBCCCVVV (global book number, chapter, verse).
/// John 3:16 = 43003016. Matches pipeline/abible/catalog.py.
int vkey(int book, int chapter, int verse) => book * 1000000 + chapter * 1000 + verse;

int vkeyBook(int key) => key ~/ 1000000;
int vkeyChapter(int key) => key ~/ 1000 % 1000;
int vkeyVerse(int key) => key % 1000;

/// First and last possible keys of a chapter (inclusive).
(int, int) chapterRange(int book, int chapter) => (vkey(book, chapter, 0), vkey(book, chapter, 999));

/// Old Testament books are 1..39, New Testament 40..66 (66-book canon).
bool isOldTestament(int book) => book <= 39;
