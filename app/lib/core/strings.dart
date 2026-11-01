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

  String get study => _('study');
  String get verseStudy => _('verseStudy');
  String get originalText => _('originalText');
  String get interlinear => _('interlinear');
  String get interlinearHint => _('interlinearHint');
  String get wordStudy => _('wordStudy');
  String get definition => _('definition');
  String get derivation => _('derivation');
  String get kjvUsage => _('kjvUsage');
  String get grammarHeading => _('grammar');
  String get pronunciation => _('pronunciation');
  String get occurrences => _('occurrences');
  String get textualVariants => _('textualVariants');
  String get variantsNote => _('variantsNote');
  String get thisText => _('thisText');
  String get omitsVerse => _('omitsVerse');
  String get omitsWords => _('omitsWords');
  String get addsWords => _('addsWords');
  String get crossReferences => _('crossReferences');
  String get peoplePlacesEvents => _('peoplePlacesEvents');
  String get person => _('person');
  String get place => _('place');
  String get event => _('event');
  String get commentary => _('commentary');
  String get commentaryNote => _('commentaryNote');
  String get showMore => _('showMore');
  String get showLess => _('showLess');
  String get mentionedIn => _('mentionedIn');
  String get coordinates => _('coordinates');
  String get datesApproximate => _('datesApproximate');
  String get noStudyData => _('noStudyData');
  String get words => _('words');
  String get bibleDictionary => _('bibleDictionary');
  String get studySources => _('studySources');
  String get notScripture => _('notScripture');

  /// A grammatical term from lib/domain/morphology.dart ("noun", "aorist", …).
  String grammar(String key) => _m['g.$key'] ?? _en['g.$key'] ?? key;

  /// A textual-variant source ("NA", "ECM", "qere", …).
  String variantSource(String key) => _m['v.$key'] ?? _en['v.$key'] ?? key;

  String occurrenceCount(int n) => isAmharic ? 'በ$n ቦታዎች ይገኛል' : (n == 1 ? 'Occurs once' : 'Occurs $n times');
  String year(int y) =>
      y < 0 ? (isAmharic ? 'ከክርስቶስ ልደት በፊት ${-y}' : '${-y} BC') : (isAmharic ? 'ከክርስቶስ ልደት በኋላ $y' : 'AD $y');

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
  'study': 'ጥናት',
  'verseStudy': 'የጥቅስ ጥናት',
  'originalText': 'በመጀመሪያው ቋንቋ',
  'interlinear': 'ቃል በቃል',
  'interlinearHint': 'የዕብራይስጥ ወይም የግሪክ ቃላትን ከትርጉማቸው ጋር አሳይ',
  'wordStudy': 'የቃል ጥናት',
  'definition': 'ትርጉም',
  'derivation': 'የቃሉ ምንጭ',
  'kjvUsage': 'በኪንግ ጀምስ ትርጉም የተተረጎመበት',
  'grammar': 'ሰዋስው',
  'pronunciation': 'አጠራር',
  'occurrences': 'የሚገኝባቸው ጥቅሶች',
  'textualVariants': 'የጽሑፍ ልዩነቶች',
  'variantsNote': 'ሌሎች እትሞች ወይም ቅጂዎች በተለየ የሚያነቡባቸው ቦታዎች።',
  'thisText': 'ይህ ጽሑፍ',
  'omitsVerse': 'ይህን ጥቅስ አይጨምርም',
  'omitsWords': 'እነዚህን ቃላት አይጨምርም',
  'addsWords': 'ይጨምራል',
  'crossReferences': 'ተዛማጅ ጥቅሶች',
  'peoplePlacesEvents': 'ሰዎች፣ ቦታዎች እና ክስተቶች',
  'person': 'ሰው',
  'place': 'ቦታ',
  'event': 'ክስተት',
  'commentary': 'ማብራሪያ',
  'commentaryNote': 'የታሪካዊ ተርጓሚዎች ማብራሪያ ነው። እያንዳንዱ የጸሐፊውን አመለካከት ያሳያል፤ መጽሐፍ ቅዱስ አይደለም።',
  'showMore': 'ተጨማሪ አሳይ',
  'showLess': 'ያነሰ አሳይ',
  'mentionedIn': 'የተጠቀሰባቸው ጥቅሶች',
  'coordinates': 'መገኛ',
  'datesApproximate': 'ቀኖቹ ግምታዊ ናቸው፤ አንድ ባህላዊ የዘመን አቆጣጠርን ይከተላሉ።',
  'noStudyData': 'ለዚህ ጥቅስ እስካሁን የጥናት መረጃ የለም።',
  'words': 'ቃላት',
  'bibleDictionary': 'የመጽሐፍ ቅዱስ መዝገበ ቃላት',
  'studySources': 'የጥናት ምንጮች',
  'notScripture': 'መጽሐፍ ቅዱስ አይደለም',
  'g.noun': 'ስም',
  'g.properNoun': 'የተጸውኦ ስም',
  'g.verb': 'ግስ',
  'g.adjective': 'ቅጽል',
  'g.adverb': 'ተውሳከ ግስ',
  'g.pronoun': 'ተውላጠ ስም',
  'g.preposition': 'መስተዋድድ',
  'g.conjunction': 'መስተጻምር',
  'g.conditional': 'የሁኔታ መስተጻምር',
  'g.particle': 'ቅንጣት',
  'g.article': 'መወሰኛ',
  'g.suffix': 'ቅጥያ',
  'g.interjection': 'ቃለ አጋኖ',
  'g.numeral': 'ቁጥር',
  'g.aramaicWord': 'የአረማይክ ቃል',
  'g.hebrewWord': 'የዕብራይስጥ ቃል',
  'g.unknown': 'ያልታወቀ',
  'g.genderBoth': 'ተባዕታይ ወይም አንስታይ',
  'g.genderCommon': 'የጋራ ጾታ',
  'g.feminine': 'አንስታይ',
  'g.masculine': 'ተባዕታይ',
  'g.neuter': 'ገለልተኛ',
  'g.dual': 'ሁለትዮሽ',
  'g.plural': 'ብዙ ቁጥር',
  'g.singular': 'ነጠላ ቁጥር',
  'g.absolute': 'ነጻ ሁኔታ (absolute)',
  'g.construct': 'ጥምር ሁኔታ (construct)',
  'g.determined': 'የተወሰነ (determined)',
  'g.person1': 'አንደኛ መደብ',
  'g.person2': 'ሁለተኛ መደብ',
  'g.person3': 'ሦስተኛ መደብ',
  'g.perfect': 'የተፈጸመ (perfect)',
  'g.sequentialPerfect': 'ተከታታይ የተፈጸመ (weqatal)',
  'g.imperfect': 'ያልተፈጸመ (imperfect)',
  'g.sequentialImperfect': 'ተከታታይ ያልተፈጸመ (wayyiqtol)',
  'g.cohortative': 'የማበረታቻ (cohortative)',
  'g.jussive': 'የምኞት ትእዛዝ (jussive)',
  'g.imperative': 'ትእዛዝ',
  'g.participleActive': 'ገቢር ተሳታፊ ቅርጽ (participle)',
  'g.participlePassive': 'ተገብሮ ተሳታፊ ቅርጽ (participle)',
  'g.infinitiveAbsolute': 'ነጻ ሳቢ ዘር (infinitive absolute)',
  'g.infinitiveConstruct': 'ጥምር ሳቢ ዘር (infinitive construct)',
  'g.gentilic': 'የወገን ስም',
  'g.cardinal': 'መደበኛ ቁጥር',
  'g.ordinal': 'የደረጃ ቁጥር',
  'g.demonstrative': 'አመልካች',
  'g.indefinite': 'ያልተወሰነ',
  'g.interrogative': 'ጠያቂ',
  'g.personal': 'የሰው',
  'g.relative': 'አያያዥ',
  'g.reciprocal': 'የእርስ በርስ',
  'g.correlative': 'ተዛማጅ',
  'g.correlativeInterrogative': 'ተዛማጅ ጠያቂ',
  'g.reflexive': 'ራስ አመልካች',
  'g.possessive': 'የባለቤትነት',
  'g.directionalHe': 'የአቅጣጫ ሄ',
  'g.paragogicHe': 'ተጨማሪ ሄ',
  'g.paragogicNun': 'ተጨማሪ ኑን',
  'g.pronominal': 'ተውላጠ ስማዊ',
  'g.affirmation': 'ማረጋገጫ',
  'g.exhortation': 'ማበረታቻ',
  'g.negative': 'አሉታ',
  'g.objectMarker': 'የተሳቢ ምልክት',
  'g.withArticle': 'ከመወሰኛ ጋር',
  'g.nominative': 'ባለቤት ሁኔታ (nominative)',
  'g.genitive': 'የባለቤትነት ሁኔታ (genitive)',
  'g.dative': 'ተቀባይ ሁኔታ (dative)',
  'g.accusative': 'ተሳቢ ሁኔታ (accusative)',
  'g.vocative': 'የጥሪ ሁኔታ (vocative)',
  'g.present': 'የአሁን ጊዜ',
  'g.imperfectTense': 'ቀጣይ ኃላፊ (imperfect)',
  'g.future': 'የወደፊት ጊዜ',
  'g.aorist': 'ኃላፊ (aorist)',
  'g.perfectTense': 'ፍጹም (perfect)',
  'g.pluperfect': 'ቀደምት ፍጹም (pluperfect)',
  'g.second': 'ሁለተኛ',
  'g.active': 'ገቢር',
  'g.middle': 'መካከለኛ',
  'g.passive': 'ተገብሮ',
  'g.middleOrPassive': 'መካከለኛ ወይም ተገብሮ',
  'g.middleDeponent': 'መካከለኛ (deponent)',
  'g.passiveDeponent': 'ተገብሮ (deponent)',
  'g.middleOrPassiveDeponent': 'መካከለኛ ወይም ተገብሮ (deponent)',
  'g.impersonalActive': 'ግላዊ ያልሆነ ገቢር',
  'g.noVoice': 'ድምፅ የሌለው',
  'g.indicative': 'ዐዋጅ (indicative)',
  'g.subjunctive': 'ምኞታዊ (subjunctive)',
  'g.optative': 'ተመኝ (optative)',
  'g.imperativeMood': 'ትእዛዝ',
  'g.infinitive': 'ሳቢ ዘር (infinitive)',
  'g.participle': 'ተሳታፊ ቅርጽ (participle)',
  'g.imperativeParticiple': 'የትእዛዝ ተሳታፊ ቅርጽ',
  'g.comparative': 'ንጽጽር',
  'g.superlative': 'ከፍተኛ ንጽጽር',
  'g.indeclinable': 'የማይለወጥ',
  'g.hebrew': 'ዕብራይስጥ',
  'g.aramaic': 'አረማይክ',
  'g.greek': 'ግሪክ',
  'v.qere': 'የማሶሬት ቄሬ',
  'v.NA': 'ኔስትሌ-አላንድ',
  'v.NA27': 'ኔስትሌ-አላንድ 27',
  'v.NA28': 'ኔስትሌ-አላንድ 28',
  'v.NA27/28': 'ኔስትሌ-አላንድ 27/28',
  'v.ECM': 'ኤዲቲዮ ክሪቲካ ማዮር',
  'v.Byz': 'የባይዛንታይን ቅጂዎች',
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
  'study': 'Study',
  'verseStudy': 'Verse study',
  'originalText': 'Original text',
  'interlinear': 'Interlinear',
  'interlinearHint': 'Show Hebrew or Greek words with their meanings',
  'wordStudy': 'Word study',
  'definition': 'Definition',
  'derivation': 'Origin',
  'kjvUsage': 'Translated in the King James Version as',
  'grammar': 'Grammar',
  'pronunciation': 'Pronunciation',
  'occurrences': 'Occurrences',
  'textualVariants': 'Textual variants',
  'variantsNote': 'Places where other editions or manuscripts read differently.',
  'thisText': 'This text',
  'omitsVerse': 'leaves out this verse',
  'omitsWords': 'leaves out these words',
  'addsWords': 'adds',
  'crossReferences': 'Cross-references',
  'peoplePlacesEvents': 'People, places and events',
  'person': 'Person',
  'place': 'Place',
  'event': 'Event',
  'commentary': 'Commentary',
  'commentaryNote': 'Comments from historical interpreters. Each one shows its author\'s view and is not Scripture.',
  'showMore': 'Show more',
  'showLess': 'Show less',
  'mentionedIn': 'Mentioned in',
  'coordinates': 'Location',
  'datesApproximate': 'Dates are approximate and follow one traditional chronology.',
  'noStudyData': 'No study material for this verse yet.',
  'words': 'Words',
  'bibleDictionary': 'Bible dictionary',
  'studySources': 'Study sources',
  'notScripture': 'Not Scripture',
  'g.noun': 'noun',
  'g.properNoun': 'proper noun',
  'g.verb': 'verb',
  'g.adjective': 'adjective',
  'g.adverb': 'adverb',
  'g.pronoun': 'pronoun',
  'g.preposition': 'preposition',
  'g.conjunction': 'conjunction',
  'g.conditional': 'conditional',
  'g.particle': 'particle',
  'g.article': 'article',
  'g.suffix': 'suffix',
  'g.interjection': 'interjection',
  'g.numeral': 'numeral',
  'g.aramaicWord': 'Aramaic word',
  'g.hebrewWord': 'Hebrew word',
  'g.unknown': 'unknown',
  'g.genderBoth': 'either gender',
  'g.genderCommon': 'common gender',
  'g.feminine': 'feminine',
  'g.masculine': 'masculine',
  'g.neuter': 'neuter',
  'g.dual': 'dual',
  'g.plural': 'plural',
  'g.singular': 'singular',
  'g.absolute': 'absolute',
  'g.construct': 'construct',
  'g.determined': 'determined',
  'g.person1': '1st person',
  'g.person2': '2nd person',
  'g.person3': '3rd person',
  'g.perfect': 'perfect',
  'g.sequentialPerfect': 'sequential perfect',
  'g.imperfect': 'imperfect',
  'g.sequentialImperfect': 'sequential imperfect',
  'g.cohortative': 'cohortative',
  'g.jussive': 'jussive',
  'g.imperative': 'imperative',
  'g.participleActive': 'active participle',
  'g.participlePassive': 'passive participle',
  'g.infinitiveAbsolute': 'infinitive absolute',
  'g.infinitiveConstruct': 'infinitive construct',
  'g.gentilic': 'gentilic',
  'g.cardinal': 'cardinal',
  'g.ordinal': 'ordinal',
  'g.demonstrative': 'demonstrative',
  'g.indefinite': 'indefinite',
  'g.interrogative': 'interrogative',
  'g.personal': 'personal',
  'g.relative': 'relative',
  'g.reciprocal': 'reciprocal',
  'g.correlative': 'correlative',
  'g.correlativeInterrogative': 'correlative or interrogative',
  'g.reflexive': 'reflexive',
  'g.possessive': 'possessive',
  'g.directionalHe': 'directional he',
  'g.paragogicHe': 'paragogic he',
  'g.paragogicNun': 'paragogic nun',
  'g.pronominal': 'pronominal',
  'g.affirmation': 'affirmation',
  'g.exhortation': 'exhortation',
  'g.negative': 'negative',
  'g.objectMarker': 'object marker',
  'g.withArticle': 'with article',
  'g.nominative': 'nominative',
  'g.genitive': 'genitive',
  'g.dative': 'dative',
  'g.accusative': 'accusative',
  'g.vocative': 'vocative',
  'g.present': 'present',
  'g.imperfectTense': 'imperfect',
  'g.future': 'future',
  'g.aorist': 'aorist',
  'g.perfectTense': 'perfect',
  'g.pluperfect': 'pluperfect',
  'g.second': 'second',
  'g.active': 'active',
  'g.middle': 'middle',
  'g.passive': 'passive',
  'g.middleOrPassive': 'middle or passive',
  'g.middleDeponent': 'middle deponent',
  'g.passiveDeponent': 'passive deponent',
  'g.middleOrPassiveDeponent': 'middle or passive deponent',
  'g.impersonalActive': 'impersonal active',
  'g.noVoice': 'no voice',
  'g.indicative': 'indicative',
  'g.subjunctive': 'subjunctive',
  'g.optative': 'optative',
  'g.imperativeMood': 'imperative',
  'g.infinitive': 'infinitive',
  'g.participle': 'participle',
  'g.imperativeParticiple': 'imperative participle',
  'g.comparative': 'comparative',
  'g.superlative': 'superlative',
  'g.indeclinable': 'indeclinable',
  'g.hebrew': 'Hebrew',
  'g.aramaic': 'Aramaic',
  'g.greek': 'Greek',
  'v.qere': 'Masoretic qere',
  'v.NA': 'Nestle-Aland',
  'v.NA27': 'Nestle-Aland 27',
  'v.NA28': 'Nestle-Aland 28',
  'v.NA27/28': 'Nestle-Aland 27/28',
  'v.ECM': 'Editio Critica Maior',
  'v.Byz': 'Byzantine manuscripts',
};
