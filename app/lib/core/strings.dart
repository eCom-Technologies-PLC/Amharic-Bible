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
  String get readingStreak => _('readingStreak');
  String get readingActivity => _('readingActivity');
  String get currentStreak => _('currentStreak');
  String get bestStreak => _('bestStreak');
  String get daysRead => _('daysRead');
  String get chaptersRead => _('chaptersRead');
  String get showStreak => _('showStreak');
  String get restDay => _('restDay');
  String get restDayHint => _('restDayHint');
  String get streakStart => _('streakStart');
  String get streakKeepGoing => _('streakKeepGoing');
  String get streakDoneToday => _('streakDoneToday');
  String get previousMonth => _('previousMonth');
  String get nextMonth => _('nextMonth');
  String get dayReadLabel => _('dayReadLabel');
  String get allPlans => _('allPlans');
  String get periodWeek => _('periodWeek');
  String get periodMonth => _('periodMonth');
  String get periodThreeMonths => _('periodThreeMonths');
  String get periodSixMonths => _('periodSixMonths');
  String get periodYear => _('periodYear');
  String get paceLight => _('paceLight');
  String get paceSteady => _('paceSteady');
  String get paceIntensive => _('paceIntensive');
  String get noPlansForPeriod => _('noPlansForPeriod');
  String get makeYourOwnPlan => _('makeYourOwnPlan');
  String get makeYourOwnPlanHint => _('makeYourOwnPlanHint');
  String get newPlan => _('newPlan');
  String get createPlan => _('createPlan');
  String get planName => _('planName');
  String get whatToRead => _('whatToRead');
  String get scopeAll => _('scopeAll');
  String get scopeGospels => _('scopeGospels');
  String get scopePsalmsProverbs => _('scopePsalmsProverbs');
  String get chooseBooks => _('chooseBooks');
  String get howLong => _('howLong');
  String get chooseEndDate => _('chooseEndDate');
  String get byChaptersADay => _('byChaptersADay');
  String get readingDays => _('readingDays');
  String get everyDay => _('everyDay');
  String get mondayToFriday => _('mondayToFriday');
  String get exceptSunday => _('exceptSunday');
  String get chooseDays => _('chooseDays');
  String get startDate => _('startDate');
  String get today => _('today');
  String get tomorrow => _('tomorrow');
  String get chooseDate => _('chooseDate');
  String get done => _('done');
  String get preview => _('preview');
  String get tooManyDays => _('tooManyDays');
  String get heavyPlan => _('heavyPlan');
  String get noBooksChosen => _('noBooksChosen');
  String get noReadingDays => _('noReadingDays');
  String get planTooLong => _('planTooLong');
  String get endBeforeStart => _('endBeforeStart');
  String get yourOwnPlan => _('yourOwnPlan');
  String get replan => _('replan');
  String get replanTitle => _('replanTitle');
  String get keepEndDate => _('keepEndDate');
  String get oneMoreWeek => _('oneMoreWeek');
  String get oneMoreMonth => _('oneMoreMonth');
  String get behindHint => _('behindHint');
  String get planUpdated => _('planUpdated');
  String get deletePlan => _('deletePlan');
  String get deletePlanConfirm => _('deletePlanConfirm');
  String get scopeWisdom => _('scopeWisdom');
  String get helpMeChoose => _('helpMeChoose');
  String get helpMeChooseHint => _('helpMeChooseHint');
  String get planningAssistant => _('planningAssistant');
  String get assistantIntro => _('assistantIntro');
  String get timeADay => _('timeADay');
  String get tapToAnswer => _('tapToAnswer');
  String get recommendedForYou => _('recommendedForYou');
  String get fitGood => _('fitGood');
  String get fitLight => _('fitLight');
  String get fitStretch => _('fitStretch');
  String get readsEveryDay => _('readsEveryDay');
  String get buildMyOwn => _('buildMyOwn');
  String get buildMyOwnHint => _('buildMyOwnHint');
  String get noMatchingPlans => _('noMatchingPlans');
  String get catchUpHint => _('catchUpHint');
  String get catchUp => _('catchUp');
  String get dailyReminder => _('dailyReminder');
  String get remindersSection => _('remindersSection');
  String get dailyReminderHint => _('dailyReminderHint');
  String get reminderTime => _('reminderTime');
  String get notificationsBlocked => _('notificationsBlocked');
  String get reminderGeneric => _('reminderGeneric');
  String get reminderChannel => _('reminderChannel');
  List<String> get weekdayNames => isAmharic
      ? const ['ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሑድ']
      : const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  List<String> get weekdayInitials =>
      isAmharic ? const ['ሰ', 'ማ', 'ረ', 'ሐ', 'ዓ', 'ቅ', 'እ'] : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  String minutes(int n) => isAmharic ? '$n ደቂቃ' : '$n min';
  String results(int n) => isAmharic ? '$n ውጤቶች' : (n == 1 ? '1 result' : '$n results');
  String selected(int n) => isAmharic ? '$n ተመርጠዋል' : '$n selected';
  String day(int n) => isAmharic ? 'ቀን $n' : 'Day $n';
  String dayOf(int n, int total) => isAmharic ? 'ቀን $n ከ$total' : 'Day $n of $total';
  String dayRange(int a, int b) => isAmharic ? 'ቀን $a–$b' : 'Days $a–$b';
  String days(int n) => isAmharic ? '$n ቀናት' : '$n days';
  String behind(int n) => isAmharic ? '$n ቀናት ወደኋላ' : '$n days behind';
  String signedInAs(String email) => isAmharic ? 'በ$email ገብተዋል' : 'Signed in as $email';
  String minutesPerDay(int n) => isAmharic ? 'በቀን ~$n ደቂቃ' : '~$n min a day';
  String chaptersADay(int n) => isAmharic ? 'በቀን $n ምዕራፍ' : (n == 1 ? '1 chapter a day' : '$n chapters a day');
  String aboutChaptersADay(String n) => isAmharic ? 'በቀን ~$n ምዕራፍ' : '~$n chapters a day';
  String readingDayCount(int n) => isAmharic ? '$n የንባብ ቀናት' : (n == 1 ? '1 reading day' : '$n reading days');
  String finishesOn(String date) => isAmharic ? 'የሚያልቀው፦ $date' : 'Finishes $date';
  String until(String date) => isAmharic ? 'እስከ $date' : 'Until $date';
  String booksChosen(int n) => isAmharic ? '$n መጻሕፍት' : (n == 1 ? '1 book' : '$n books');
  String chaptersLeft(int n) => isAmharic ? '$n ምዕራፎች ቀርተዋል' : (n == 1 ? '1 chapter left' : '$n chapters left');
  String chaptersCarried(int n) => isAmharic ? '$n ምዕራፎች ቀድመው ተነበዋል' : '$n chapters read before re-planning';
  String minutesOption(int n) => n >= 45 ? (isAmharic ? '$n+ ደቂቃ' : '$n+ min') : minutes(n);
  String tooMuchReading(int minutes, String chapters) => isAmharic
      ? 'ይህ በቀን ~$minutes ደቂቃ (~$chapters ምዕራፍ) ነው፤ ከጊዜዎ ይበልጣል።'
      : "That's about $minutes min a day (~$chapters chapters), more than your time.";
  String tryPeriod(String period) => isAmharic ? '$period ይሞክሩ' : 'Try $period';
  String reminderToday(String readings) => isAmharic ? 'ዛሬ፦ $readings' : 'Today: $readings';
  String reminderStreak(int n) =>
      isAmharic ? 'ለ$n ቀናት በተከታታይ አንብበዋል፤ ዛሬም ይቀጥሉ።' : "You've read $n days in a row. Keep it going today.";
  String streakDays(int n) => isAmharic ? '$n ቀን' : (n == 1 ? '1 day' : '$n days');
  String bestStreakIs(int n) => isAmharic ? 'ምርጥ፦ $n ቀን' : 'Best: ${streakDays(n)}';
  String daysThisWeek(int n) => isAmharic ? 'ባለፉት 7 ቀናት $n ቀን' : '$n of the last 7 days';
  String streakMilestone(int n) => isAmharic ? '$n ቀን በተከታታይ አንብበዋል። በርቱ!' : '$n days in a row. Keep going!';
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
  'readingStreak': 'ተከታታይ ንባብ',
  'readingActivity': 'የንባብ እንቅስቃሴ',
  'currentStreak': 'የአሁኑ ተከታታይ',
  'bestStreak': 'ምርጥ ተከታታይ',
  'daysRead': 'ያነበቡባቸው ቀናት',
  'chaptersRead': 'የተከፈቱ ምዕራፎች',
  'showStreak': 'ተከታታይ ንባብን አሳይ',
  'restDay': 'የዕረፍት ቀን',
  'restDayHint': 'በሳምንት አንድ ያመለጠ ቀን ተከታታይነቱን አያቋርጥም',
  'streakStart': 'ዛሬ አንድ ምዕራፍ በማንበብ ይጀምሩ',
  'streakKeepGoing': 'ዛሬ በማንበብ ይቀጥሉ',
  'streakDoneToday': 'የዛሬው ንባብ ተቆጥሯል',
  'previousMonth': 'ያለፈው ወር',
  'nextMonth': 'የሚቀጥለው ወር',
  'dayReadLabel': 'ተነቧል',
  'allPlans': 'ሁሉም',
  'periodWeek': '1 ሳምንት',
  'periodMonth': '1 ወር',
  'periodThreeMonths': '3 ወራት',
  'periodSixMonths': '6 ወራት',
  'periodYear': '1 ዓመት',
  'paceLight': 'ቀላል',
  'paceSteady': 'መካከለኛ',
  'paceIntensive': 'ጠንካራ',
  'noPlansForPeriod': 'በዚህ ርዝመት ሌላ ዕቅድ የለም',
  'makeYourOwnPlan': 'የራስዎን ዕቅድ ያዘጋጁ',
  'makeYourOwnPlanHint': 'የሚያነቡትን፣ የሚፈጀውን ጊዜና የንባብ ቀናትን ይምረጡ',
  'newPlan': 'አዲስ ዕቅድ',
  'createPlan': 'ዕቅዱን ፍጠር',
  'planName': 'የዕቅዱ ስም',
  'whatToRead': 'ምን ያነባሉ?',
  'scopeAll': 'ሙሉው መጽሐፍ ቅዱስ',
  'scopeGospels': 'ወንጌላት',
  'scopePsalmsProverbs': 'መዝሙረ ዳዊትና ምሳሌ',
  'chooseBooks': 'መጻሕፍትን ይምረጡ…',
  'howLong': 'ለምን ያህል ጊዜ?',
  'chooseEndDate': 'የማብቂያ ቀን ይምረጡ…',
  'byChaptersADay': 'በቀን በምዕራፍ ብዛት…',
  'readingDays': 'የንባብ ቀናት',
  'everyDay': 'በየቀኑ',
  'mondayToFriday': 'ከሰኞ እስከ ዓርብ',
  'exceptSunday': 'ከእሑድ በስተቀር በየቀኑ',
  'chooseDays': 'ቀናትን ይምረጡ…',
  'startDate': 'የሚጀምርበት ቀን',
  'today': 'ዛሬ',
  'tomorrow': 'ነገ',
  'chooseDate': 'ቀን ይምረጡ…',
  'done': 'ጨርስ',
  'preview': 'ቅድመ እይታ',
  'tooManyDays': 'ከምዕራፎቹ ብዛት በላይ ቀናት ስለመረጡ፣ ዕቅዱ ቀደም ብሎ ያልቃል።',
  'heavyPlan': 'ይህ በቀን ብዙ ንባብ ነው። ረዘም ያለ ጊዜ መምረጥ ያስቡበት።',
  'noBooksChosen': 'ቢያንስ አንድ መጽሐፍ ይምረጡ።',
  'noReadingDays': 'ቢያንስ አንድ የንባብ ቀን ይምረጡ።',
  'planTooLong': 'ዕቅድ ከሁለት ዓመት መብለጥ አይችልም።',
  'endBeforeStart': 'የማብቂያው ቀን ከመጀመሪያው ቀን በኋላ መሆን አለበት።',
  'yourOwnPlan': 'የራስዎ ዕቅድ',
  'replan': 'ዕቅዱን እንደገና አስተካክል',
  'replanTitle': 'የቀረውን እንደገና ያከፋፍሉ',
  'keepEndDate': 'የማብቂያውን ቀን ጠብቅ',
  'oneMoreWeek': 'አንድ ሳምንት ጨምር',
  'oneMoreMonth': 'አንድ ወር ጨምር',
  'behindHint': 'ወደኋላ ቀርተዋል? ያነበቡትን ሳያጡ ዕቅዱን እንደገና ያስተካክሉ።',
  'planUpdated': 'ዕቅዱ ተስተካክሏል',
  'deletePlan': 'ዕቅዱን ሰርዝ',
  'deletePlanConfirm': 'ይህ ዕቅድና እድገቱ ይሰረዛል።',
  'scopeWisdom': 'መዝሙረ ዳዊትና የጥበብ መጻሕፍት',
  'helpMeChoose': 'ዕቅድ እንድመርጥ እርዳኝ',
  'helpMeChooseHint': 'ለአራት አጭር ጥያቄዎች ይመልሱ፤ የሚስማማዎትን እንጠቁማለን',
  'planningAssistant': 'የዕቅድ ረዳት',
  'assistantIntro': 'ለአራት አጭር ጥያቄዎች ይመልሱ። ከጊዜዎ ጋር የሚስማሙ ዕቅዶችን እንጠቁማለን።',
  'timeADay': 'በቀን ምን ያህል ጊዜ አለዎት?',
  'tapToAnswer': 'ለመመለስ ይንኩ',
  'recommendedForYou': 'ለእርስዎ የሚስማሙ',
  'fitGood': 'ይስማማል',
  'fitLight': 'ቀለል ያለ',
  'fitStretch': 'ትንሽ ይከብዳል',
  'readsEveryDay': 'በየቀኑ ይነበባል',
  'buildMyOwn': 'የራሴን አዘጋጅ',
  'buildMyOwnHint': 'በመልሶችዎ የተሞላ፤ ማንኛውንም ማስተካከል ይችላሉ',
  'noMatchingPlans': 'ከመልሶችዎ ጋር የሚስማማ ዝግጁ ዕቅድ የለም፤ ከታች የራስዎን ያዘጋጁ።',
  'catchUpHint': 'ወደኋላ ቀርተዋል? ይህን ዕቅድ የራስዎ አድርገው እንደገና ያስተካክሉ፤ ያነበቡት አይጠፋም።',
  'catchUp': 'አስተካክል',
  'dailyReminder': 'የዕለት ንባብ ማስታወሻ',
  'dailyReminderHint': 'ዛሬ ካላነበቡ በመረጡት ሰዓት ያስታውሰዎታል',
  'reminderTime': 'የማስታወሻ ሰዓት',
  'notificationsBlocked': 'ማሳወቂያዎች ለዚህ መተግበሪያ ጠፍተዋል። በስልክዎ ቅንብሮች ውስጥ ያብሯቸው።',
  'reminderGeneric': 'የዛሬው የንባብ ጊዜ ደርሷል።',
  'reminderChannel': 'የንባብ ማስታወሻዎች',
  'remindersSection': 'ማስታወሻዎች',
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
  'readingStreak': 'Reading streak',
  'readingActivity': 'Reading activity',
  'currentStreak': 'Current streak',
  'bestStreak': 'Best streak',
  'daysRead': 'Days read',
  'chaptersRead': 'Chapters opened',
  'showStreak': 'Show reading streak',
  'restDay': 'Rest day',
  'restDayHint': 'One missed day a week keeps your streak',
  'streakStart': 'Read a chapter today to start a streak',
  'streakKeepGoing': 'Read today to keep it going',
  'streakDoneToday': "Today's reading is counted",
  'previousMonth': 'Previous month',
  'nextMonth': 'Next month',
  'dayReadLabel': 'Read',
  'allPlans': 'All',
  'periodWeek': '1 week',
  'periodMonth': '1 month',
  'periodThreeMonths': '3 months',
  'periodSixMonths': '6 months',
  'periodYear': '1 year',
  'paceLight': 'Light',
  'paceSteady': 'Steady',
  'paceIntensive': 'Intensive',
  'noPlansForPeriod': 'No other plans of this length',
  'makeYourOwnPlan': 'Make your own plan',
  'makeYourOwnPlanHint': 'Choose what to read, how long, and which days',
  'newPlan': 'New plan',
  'createPlan': 'Create plan',
  'planName': 'Plan name',
  'whatToRead': 'What to read',
  'scopeAll': 'The whole Bible',
  'scopeGospels': 'The Gospels',
  'scopePsalmsProverbs': 'Psalms and Proverbs',
  'chooseBooks': 'Choose books…',
  'howLong': 'How long',
  'chooseEndDate': 'Choose an end date…',
  'byChaptersADay': 'By chapters a day…',
  'readingDays': 'Reading days',
  'everyDay': 'Every day',
  'mondayToFriday': 'Monday to Friday',
  'exceptSunday': 'Every day except Sunday',
  'chooseDays': 'Choose days…',
  'startDate': 'Start',
  'today': 'Today',
  'tomorrow': 'Tomorrow',
  'chooseDate': 'Choose a date…',
  'done': 'Done',
  'preview': 'Preview',
  'tooManyDays': 'There are more days than chapters, so the plan finishes sooner.',
  'heavyPlan': "That's a lot of reading a day. Consider a longer plan.",
  'noBooksChosen': 'Choose at least one book.',
  'noReadingDays': 'Choose at least one reading day.',
  'planTooLong': 'A plan can run for two years at most.',
  'endBeforeStart': 'The end date must be after the start.',
  'yourOwnPlan': 'Your own plan',
  'replan': 'Re-plan',
  'replanTitle': 'Spread out what is left',
  'keepEndDate': 'Keep the end date',
  'oneMoreWeek': 'One more week',
  'oneMoreMonth': 'One more month',
  'behindHint': "Fallen behind? Re-plan to catch up; what you've read is kept.",
  'planUpdated': 'Plan updated',
  'deletePlan': 'Delete plan',
  'deletePlanConfirm': 'This plan and its progress will be deleted.',
  'scopeWisdom': 'Psalms and wisdom books',
  'helpMeChoose': 'Help me choose a plan',
  'helpMeChooseHint': 'Answer four quick questions for plans that fit',
  'planningAssistant': 'Planning assistant',
  'assistantIntro': 'Answer four short questions and we will suggest plans that fit your time.',
  'timeADay': 'Time a day',
  'tapToAnswer': 'Tap to answer',
  'recommendedForYou': 'Recommended for you',
  'fitGood': 'Good fit',
  'fitLight': 'Lighter',
  'fitStretch': 'A stretch',
  'readsEveryDay': 'Reads every day',
  'buildMyOwn': 'Build my own',
  'buildMyOwnHint': 'Pre-filled with your answers; change anything',
  'noMatchingPlans': 'No ready-made plan matches your answers; build your own below.',
  'catchUpHint': "Fallen behind? Make this plan your own and re-plan it; what you've read is kept.",
  'catchUp': 'Catch up',
  'dailyReminder': 'Daily reading reminder',
  'dailyReminderHint': "A nudge at your time, skipped once you've read that day",
  'reminderTime': 'Reminder time',
  'notificationsBlocked': "Notifications are off for this app. Turn them on in your phone's settings.",
  'reminderGeneric': "Time for today's reading.",
  'reminderChannel': 'Reading reminders',
  'remindersSection': 'Reminders',
};
