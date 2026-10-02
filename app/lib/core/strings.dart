import 'package:flutter/widgets.dart';

/// UI strings in Amharic (default) and English.
///
/// Kept as plain Dart so a missing translation is a compile error; add a
/// language by adding another [S] constant and listing it in [S.forLocale].
class S {
  const S._(this.locale, this._m);

  final Locale locale;
  final Map<String, String> _m;

  static const am = S._(Locale('am'), _am);
  static const en = S._(Locale('en'), _en);
  static const supported = [Locale('am'), Locale('en')];

  static S forLocale(Locale l) => l.languageCode == 'en' ? en : am;

  static S of(BuildContext context) => forLocale(Localizations.localeOf(context));

  bool get isAmharic => locale.languageCode == 'am';

  String _(String k) => _m[k] ?? _en[k]!;

  String get appName => _('appName');
  String get home => _('home');
  String get read => _('read');
  String get search => _('search');
  String get me => _('me');
  String get verseOfTheDay => _('verseOfTheDay');
  String get continueReading => _('continueReading');
  String get startReading => _('startReading');
  String get sampleBanner => _('sampleBanner');
  String get oldTestament => _('oldTestament');
  String get newTestament => _('newTestament');
  String get all => _('all');
  String get chapter => _('chapter');
  String get highlight => _('highlight');
  String get highlights => _('highlights');
  String get bookmark => _('bookmark');
  String get bookmarks => _('bookmarks');
  String get note => _('note');
  String get notes => _('notes');
  String get copy => _('copy');
  String get share => _('share');
  String get listen => _('listen');
  String get copied => _('copied');
  String get bookmarkAdded => _('bookmarkAdded');
  String get bookmarkRemoved => _('bookmarkRemoved');
  String get removeHighlight => _('removeHighlight');
  String get save => _('save');
  String get delete => _('delete');
  String get cancel => _('cancel');
  String get noteHint => _('noteHint');
  String get searchHint => _('searchHint');
  String get noResults => _('noResults');
  String get goTo => _('goTo');
  String get settings => _('settings');
  String get theme => _('theme');
  String get themeSystem => _('themeSystem');
  String get themeLight => _('themeLight');
  String get themeSepia => _('themeSepia');
  String get themeDark => _('themeDark');
  String get themeBlack => _('themeBlack');
  String get textSize => _('textSize');
  String get lineSpacing => _('lineSpacing');
  String get font => _('font');
  String get serif => _('serif');
  String get sans => _('sans');
  String get verseNumbers => _('verseNumbers');
  String get redLetters => _('redLetters');
  String get geezNumerals => _('geezNumerals');
  String get ethiopianCalendar => _('ethiopianCalendar');
  String get language => _('language');
  String get version => _('version');
  String get about => _('about');
  String get sources => _('sources');
  String get downloads => _('downloads');
  String get audioNotAvailable => _('audioNotAvailable');
  String get audioNotConfigured => _('audioNotConfigured');
  String get sleepTimer => _('sleepTimer');
  String get speed => _('speed');
  String get off => _('off');
  String get endOfChapter => _('endOfChapter');
  String get downloadBook => _('downloadBook');
  String get downloading => _('downloading');
  String get noDownloads => _('noDownloads');
  String get emptyHighlights => _('emptyHighlights');
  String get emptyBookmarks => _('emptyBookmarks');
  String get emptyNotes => _('emptyNotes');
  String get footnote => _('footnote');
  String get previousChapter => _('previousChapter');
  String get nextChapter => _('nextChapter');
  String get notInVersion => _('notInVersion');
  String get clear => _('clear');
  String get licenseUnverified => _('licenseUnverified');
  String get recentSearches => _('recentSearches');
  String get tapToSelectHint => _('tapToSelectHint');
  String get privacyNote => _('privacyNote');
  String get loadError => _('loadError');
  String get retry => _('retry');
  String get openSourceLicenses => _('openSourceLicenses');
  String get total => _('total');
  String get stopPlanConfirm => _('stopPlanConfirm');
  String get restartPlanConfirm => _('restartPlanConfirm');

  String get readingPlans => _('readingPlans');
  String get todaysReading => _('todaysReading');
  String get startPlan => _('startPlan');
  String get stopPlan => _('stopPlan');
  String get restartPlan => _('restartPlan');
  String get planFinished => _('planFinished');
  String get markAsRead => _('markAsRead');
  String get myPlans => _('myPlans');
  String get morePlans => _('morePlans');
  String get sideBySide => _('sideBySide');
  String get secondVersion => _('secondVersion');
  String get none => _('none');
  String get shareImage => _('shareImage');
  String get image => _('image');
  String get background => _('background');
  String get account => _('account');
  String get signIn => _('signIn');
  String get signOut => _('signOut');
  String get email => _('email');
  String get sendCode => _('sendCode');
  String get enterCode => _('enterCode');
  String get verify => _('verify');
  String get invalidCode => _('invalidCode');
  String get syncNow => _('syncNow');
  String get syncing => _('syncing');
  String get lastSynced => _('lastSynced');
  String get never => _('never');
  String get syncFailed => _('syncFailed');
  String get accountOptional => _('accountOptional');
  String get accountsNotConfigured => _('accountsNotConfigured');
  String get exportData => _('exportData');
  String get deleteAccount => _('deleteAccount');
  String get deleteAccountConfirm => _('deleteAccountConfirm');

  String minutes(int n) => isAmharic ? '$n ደቂቃ' : '$n min';
  String results(int n) => isAmharic ? '$n ውጤቶች' : (n == 1 ? '1 result' : '$n results');
  String selected(int n) => isAmharic ? '$n ተመርጠዋል' : '$n selected';
  String day(int n) => isAmharic ? 'ቀን $n' : 'Day $n';
  String dayOf(int n, int total) => isAmharic ? 'ቀን $n ከ$total' : 'Day $n of $total';
  String dayRange(int a, int b) => isAmharic ? 'ቀን $a–$b' : 'Days $a–$b';
  String days(int n) => isAmharic ? '$n ቀናት' : '$n days';
  String behind(int n) => isAmharic ? '$n ቀናት ወደኋላ' : '$n days behind';
  String signedInAs(String email) => isAmharic ? 'በ$email ገብተዋል' : 'Signed in as $email';
  String chapterOf(String book, int c) => isAmharic ? '$book ምዕራፍ $c' : '$book $c';
}

const _am = {
  'appName': 'መጽሐፍ ቅዱስ',
  'home': 'ቤት',
  'read': 'ንባብ',
  'search': 'ፍለጋ',
  'me': 'የእኔ',
  'verseOfTheDay': 'የዕለቱ ጥቅስ',
  'continueReading': 'ንባብ ቀጥል',
  'startReading': 'ማንበብ ጀምር',
  'sampleBanner': 'ይህ የሙከራ ጽሑፍ ነው። ሙሉ ጽሑፉ በሚለቀቀው ስሪት ውስጥ ይካተታል።',
  'oldTestament': 'ብሉይ ኪዳን',
  'newTestament': 'አዲስ ኪዳን',
  'all': 'ሁሉም',
  'chapter': 'ምዕራፍ',
  'highlight': 'አድምቅ',
  'highlights': 'የደመቁ',
  'bookmark': 'ዕልባት',
  'bookmarks': 'ዕልባቶች',
  'note': 'ማስታወሻ',
  'notes': 'ማስታወሻዎች',
  'copy': 'ቅዳ',
  'share': 'አጋራ',
  'listen': 'አዳምጥ',
  'copied': 'ተቀድቷል',
  'bookmarkAdded': 'ዕልባት ተጨምሯል',
  'bookmarkRemoved': 'ዕልባት ተወግዷል',
  'removeHighlight': 'ድምቀት አስወግድ',
  'save': 'አስቀምጥ',
  'delete': 'ሰርዝ',
  'cancel': 'ተው',
  'noteHint': 'ማስታወሻዎን እዚህ ይጻፉ…',
  'searchHint': 'ቃል ወይም ጥቅስ ይፈልጉ (ለምሳሌ ዮሐ 3፥16)',
  'noResults': 'ምንም አልተገኘም',
  'goTo': 'ወደዚህ ሂድ',
  'settings': 'ማስተካከያ',
  'theme': 'ገጽታ',
  'themeSystem': 'እንደ ስልኩ',
  'themeLight': 'ብሩህ',
  'themeSepia': 'ሴፒያ',
  'themeDark': 'ጨለማ',
  'themeBlack': 'ጥቁር',
  'textSize': 'የፊደል መጠን',
  'lineSpacing': 'የመስመር ክፍተት',
  'font': 'ፊደል',
  'serif': 'ሰሪፍ',
  'sans': 'ሳንስ',
  'verseNumbers': 'የቁጥር ምልክቶች',
  'redLetters': 'የኢየሱስ ቃላት በቀይ',
  'geezNumerals': 'የግዕዝ ቁጥሮች',
  'ethiopianCalendar': 'የኢትዮጵያ ዘመን አቆጣጠር',
  'language': 'ቋንቋ',
  'version': 'ትርጉም',
  'about': 'ስለ መተግበሪያው',
  'sources': 'ምንጮች',
  'downloads': 'የወረዱ',
  'audioNotAvailable': 'ለዚህ ትርጉም ድምፅ የለም',
  'audioNotConfigured': 'ድምፅ ገና አልተዘጋጀም',
  'sleepTimer': 'የእንቅልፍ ሰዓት',
  'speed': 'ፍጥነት',
  'off': 'አጥፋ',
  'endOfChapter': 'የምዕራፉ መጨረሻ',
  'downloadBook': 'መጽሐፉን አውርድ',
  'downloading': 'በማውረድ ላይ…',
  'noDownloads': 'ምንም የወረደ የለም',
  'emptyHighlights': 'ጥቅስ ለማድመቅ በንባብ ጊዜ ጥቅሱን ይንኩ',
  'emptyBookmarks': 'ገና ዕልባት የለም',
  'emptyNotes': 'ገና ማስታወሻ የለም',
  'footnote': 'የግርጌ ማስታወሻ',
  'previousChapter': 'ያለፈው ምዕራፍ',
  'nextChapter': 'ቀጣይ ምዕራፍ',
  'notInVersion': 'ይህ ክፍል በዚህ ትርጉም ውስጥ የለም',
  'clear': 'አጽዳ',
  'licenseUnverified': 'ፈቃዱ ገና አልተረጋገጠም',
  'recentSearches': 'የቅርብ ጊዜ ፍለጋዎች',
  'tapToSelectHint': 'ለማድመቅ፣ ለማጋራት ወይም ማስታወሻ ለመጻፍ ጥቅሱን ይንኩ',
  'privacyNote': 'ማስታወሻዎ እና ድምቀቶችዎ ካልገቡ በቀር በስልክዎ ላይ ብቻ ይቀመጣሉ። ማስታወቂያ ወይም መከታተያ የለም።',
  'readingPlans': 'የንባብ ዕቅዶች',
  'todaysReading': 'የዛሬ ንባብ',
  'startPlan': 'ዕቅዱን ጀምር',
  'stopPlan': 'ዕቅዱን አቁም',
  'restartPlan': 'እንደገና ጀምር',
  'planFinished': 'ዕቅዱን ጨርሰዋል። እንኳን ደስ አለዎት!',
  'markAsRead': 'እንደተነበበ ምልክት አድርግ',
  'myPlans': 'የእኔ ዕቅዶች',
  'morePlans': 'ሌሎች ዕቅዶች',
  'sideBySide': 'ጎን ለጎን',
  'secondVersion': 'ሁለተኛ ትርጉም',
  'none': 'የለም',
  'shareImage': 'እንደ ምስል አጋራ',
  'image': 'ምስል',
  'background': 'ዳራ',
  'account': 'መለያ',
  'signIn': 'ግባ',
  'signOut': 'ውጣ',
  'email': 'ኢሜይል',
  'sendCode': 'ኮድ ላክ',
  'enterCode': 'ወደ ኢሜይልዎ የተላከውን ኮድ ያስገቡ',
  'verify': 'አረጋግጥ',
  'invalidCode': 'ኮዱ ትክክል አይደለም',
  'syncNow': 'አሁን አመሳስል',
  'syncing': 'በማመሳሰል ላይ…',
  'lastSynced': 'መጨረሻ የተመሳሰለው',
  'never': 'ገና አልተመሳሰለም',
  'syncFailed': 'ማመሳሰል አልተሳካም',
  'accountOptional': 'መለያ መክፈት አማራጭ ነው። ከገቡ ድምቀቶችዎ፣ ዕልባቶችዎ፣ ማስታወሻዎችዎ እና ዕቅዶችዎ በስልኮችዎ መካከል ይመሳሰላሉ።',
  'accountsNotConfigured': 'መለያዎች ገና አልተዘጋጁም',
  'exportData': 'ውሂቤን ላክ',
  'deleteAccount': 'መለያዬን ሰርዝ',
  'deleteAccountConfirm': 'መለያዎ እና በአገልጋዩ ላይ ያለው ውሂብዎ ይሰረዛል። በዚህ ስልክ ላይ ያለው ውሂብ ይቀራል።',
  'loadError': 'ይህን መጫን አልተቻለም።',
  'retry': 'እንደገና ሞክር',
  'openSourceLicenses': 'የክፍት ምንጭ ፈቃዶች',
  'total': 'ጠቅላላ',
  'stopPlanConfirm': 'ይህን ዕቅድ ማቆም ይፈልጋሉ? ዕቅዱ ከዕቅዶችዎ ይወገዳል።',
  'restartPlanConfirm': 'እስካሁን ምልክት ያደረጉባቸው ቀናት ይጠፋሉ፤ ዕቅዱ ከዛሬ ይጀምራል።',
};

const _en = {
  'appName': 'Amharic Bible',
  'home': 'Home',
  'read': 'Read',
  'search': 'Search',
  'me': 'Me',
  'verseOfTheDay': 'Verse of the day',
  'continueReading': 'Continue reading',
  'startReading': 'Start reading',
  'sampleBanner': 'This build contains sample text only. Release builds include the full text.',
  'oldTestament': 'Old Testament',
  'newTestament': 'New Testament',
  'all': 'All',
  'chapter': 'Chapter',
  'highlight': 'Highlight',
  'highlights': 'Highlights',
  'bookmark': 'Bookmark',
  'bookmarks': 'Bookmarks',
  'note': 'Note',
  'notes': 'Notes',
  'copy': 'Copy',
  'share': 'Share',
  'listen': 'Listen',
  'copied': 'Copied',
  'bookmarkAdded': 'Bookmark added',
  'bookmarkRemoved': 'Bookmark removed',
  'removeHighlight': 'Remove highlight',
  'save': 'Save',
  'delete': 'Delete',
  'cancel': 'Cancel',
  'noteHint': 'Write your note…',
  'searchHint': 'Search words or a reference (e.g. John 3:16)',
  'noResults': 'No results',
  'goTo': 'Go to',
  'settings': 'Settings',
  'theme': 'Theme',
  'themeSystem': 'System',
  'themeLight': 'Light',
  'themeSepia': 'Sepia',
  'themeDark': 'Dark',
  'themeBlack': 'Black',
  'textSize': 'Text size',
  'lineSpacing': 'Line spacing',
  'font': 'Font',
  'serif': 'Serif',
  'sans': 'Sans',
  'verseNumbers': 'Verse numbers',
  'redLetters': 'Words of Jesus in red',
  'geezNumerals': "Ge'ez numerals",
  'ethiopianCalendar': 'Ethiopian calendar',
  'language': 'Language',
  'version': 'Version',
  'about': 'About',
  'sources': 'Sources',
  'downloads': 'Downloads',
  'audioNotAvailable': 'No audio for this version',
  'audioNotConfigured': 'Audio is not set up yet',
  'sleepTimer': 'Sleep timer',
  'speed': 'Speed',
  'off': 'Off',
  'endOfChapter': 'End of chapter',
  'downloadBook': 'Download book',
  'downloading': 'Downloading…',
  'noDownloads': 'Nothing downloaded',
  'emptyHighlights': 'Tap a verse while reading to highlight it',
  'emptyBookmarks': 'No bookmarks yet',
  'emptyNotes': 'No notes yet',
  'footnote': 'Footnote',
  'previousChapter': 'Previous chapter',
  'nextChapter': 'Next chapter',
  'notInVersion': 'This passage is not in this version',
  'clear': 'Clear',
  'licenseUnverified': 'License not yet confirmed',
  'recentSearches': 'Recent searches',
  'tapToSelectHint': 'Tap a verse to highlight, share or add a note',
  'privacyNote': 'Your notes and highlights stay on this device unless you sign in to sync. No ads, no tracking.',
  'readingPlans': 'Reading plans',
  'todaysReading': "Today's reading",
  'startPlan': 'Start plan',
  'stopPlan': 'Stop plan',
  'restartPlan': 'Start over',
  'planFinished': 'Plan complete. Well done!',
  'markAsRead': 'Mark as read',
  'myPlans': 'My plans',
  'morePlans': 'More plans',
  'sideBySide': 'Side by side',
  'secondVersion': 'Second version',
  'none': 'None',
  'shareImage': 'Share as image',
  'image': 'Image',
  'background': 'Background',
  'account': 'Account',
  'signIn': 'Sign in',
  'signOut': 'Sign out',
  'email': 'Email',
  'sendCode': 'Send code',
  'enterCode': 'Enter the code we emailed you',
  'verify': 'Verify',
  'invalidCode': 'That code is not valid',
  'syncNow': 'Sync now',
  'syncing': 'Syncing…',
  'lastSynced': 'Last synced',
  'never': 'Never',
  'syncFailed': 'Sync failed',
  'accountOptional':
      'An account is optional. Signing in syncs your highlights, bookmarks, notes and plans across your devices.',
  'accountsNotConfigured': 'Accounts are not set up yet',
  'exportData': 'Export my data',
  'deleteAccount': 'Delete account',
  'deleteAccountConfirm': 'Your account and its data on the server will be deleted. Data on this phone is kept.',
  'loadError': "Couldn't load this.",
  'retry': 'Try again',
  'openSourceLicenses': 'Open-source licenses',
  'total': 'Total',
  'stopPlanConfirm': 'Stop this plan? It will be removed from your plans.',
  'restartPlanConfirm': 'Your checked days will be cleared and the plan will start again today.',
};
