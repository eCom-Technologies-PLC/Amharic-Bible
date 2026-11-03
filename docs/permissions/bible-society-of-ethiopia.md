# Letter to the Bible Society of Ethiopia (draft)

Purpose: confirm the app's use of the 1962 (1954 E.C.) Amharic Bible, and ask for its Old Testament in digital form.
Send it from the project's own address, filling in the bracketed parts. An Amharic version may be better received;
the English text below can be the basis for it.

Status: not sent yet. Record the date sent and the reply here, and update `content/versions.json` (AMH1962) to match.

---

To: The General Secretary, The Bible Society of Ethiopia, Addis Ababa
[The Society's email or postal address, from its website]

Subject: Permission to use the 1962 Amharic Bible in a free Bible app, and a request for the Old Testament text

Dear General Secretary,

We are building **መጽሐፍ ቅዱስ · Amharic Bible**, a free Bible app for Android, iPhone and the web, for Amharic readers
in Ethiopia and abroad. It works without an internet connection, reads aloud, searches Amharic with its spelling
variants (ሀ/ሐ/ኀ, ሰ/ሠ, ጸ/ፀ) and Ge'ez numerals, and offers reading plans. It is **non-commercial**: it costs nothing,
it carries no advertising, and it has nothing for sale.

**What we use today.** The app includes the New Testament of the 1962 (1954 E.C.) Amharic translation, as published on
eBible.org (Copyright © 1962, 2003 United Bible Societies; digitized by the Lapsley/Brooks Foundation, Unicode edition by
Dirk Röckmann), under the terms given there: non-commercial works may use it if they include the full copyright
statement. The app shows that statement:

> Copyright © 1962, 2003 United Bible Societies. With kind permission of the Bible Society of Ethiopia.

on its About page, at the end of every chapter, and on each chapter's page on the app's website.

**What we ask.**

1. **Confirmation** that this use is acceptable to the Society: a free app distributed through Google Play, Apple's App
   Store and a website, including one plain web page per chapter (so the text can be found by search engines and
   opened in the app). If the Society would like a different wording or placement of the notice, a link to the
   Society, or any other condition, we will follow it.
2. **The Old Testament.** Only the New Testament is available to us in digital form. Would the Society provide, or
   allow us to use, the Old Testament of the same translation (for example the Lapsley/Brooks digitization or the
   Society's own files), so that readers have the whole Bible? We will report any errors readers find back to the
   Society.

We would be glad to credit the Society wherever it wishes, to link readers to the Society for printed Bibles, to send
a copy of the app for review before release, and to change or remove anything at the Society's request.

Thank you for your work in bringing the Scriptures to Ethiopia's languages.

Yours sincerely,

[Name]
[Role, organization or church, if any]
[Email] · [Phone]
[Website or project link]

---

## Notes for whoever sends it

- The terms quoted are from <https://ebible.org/amh/copyright.htm> (checked 2026-11-03): "Every non-commercial work using
  this data in any form must fully include this copyright statement!" and "Every commercial use of parts or the complete
  data in any form needs written permission of the Bible Society of Ethiopia!"
- Until the Society answers, the app must stay free, with no advertising and nothing for sale. Any of those needs the
  Society's written permission first (`CLAUDE.md`, rules specific to this app).
- If the Society supplies the Old Testament, add it as the AMH1962 source in `content/versions.json`, rebuild with
  `pipeline/build_db.py`, and check the content report for missing books and chapters.
