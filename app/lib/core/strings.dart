import 'package:flutter/widgets.dart';

/// UI strings in Amharic (default) and English.
///
/// Kept as plain Dart; `test/strings_test.dart` fails when a key is missing in
/// either language. Add a language by adding another [S] constant and listing
/// it in [S.forLocale].
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
  String get undo => _('undo');
  String get library => _('library');
  String get discardChanges => _('discardChanges');
  String get discardChangesMessage => _('discardChangesMessage');
  String get discard => _('discard');
  String get keepEditing => _('keepEditing');
  String get deleteNoteConfirm => _('deleteNoteConfirm');
  String get deleteNoteMessage => _('deleteNoteMessage');
  String get deletePostConfirm => _('deletePostConfirm');
  String get deletePostMessage => _('deletePostMessage');
  String get removeAudioMessage => _('removeAudioMessage');
  String get somethingWentWrong => _('somethingWentWrong');
  String get emptyTimeline => _('emptyTimeline');
  String get play => _('play');
  String get pause => _('pause');
  String get stopAudio => _('stopAudio');
  String get back10 => _('back10');
  String get forward10 => _('forward10');
  String get smallerText => _('smallerText');
  String get largerText => _('largerText');
  String get spacingCompact => _('spacingCompact');
  String get spacingNormal => _('spacingNormal');
  String get spacingRelaxed => _('spacingRelaxed');
  String get shapeSquare => _('shapeSquare');
  String get shapeStory => _('shapeStory');
  String get pageNotFound => _('pageNotFound');
  String get today => _('today');
  String get plans => _('plans');
  String get groupsIntro => _('groupsIntro');
  String get thisWeek => _('thisWeek');
  String get startAPlan => _('startAPlan');
  String get startPlanHint => _('startPlanHint');
  String get skip => _('skip');
  String get next => _('next');
  String get chooseLanguage => _('chooseLanguage');
  String get readingComfort => _('readingComfort');
  String get readingComfortHint => _('readingComfortHint');
  String get whereToBegin => _('whereToBegin');
  String get beginJohn => _('beginJohn');
  String get beginJohnHint => _('beginJohnHint');
  String get beginPlan => _('beginPlan');
  String get beginPlanHint => _('beginPlanHint');
  String get beginToday => _('beginToday');
  String get beginTodayHint => _('beginTodayHint');

  String get readingLook => _('readingLook');
  String get openInReader => _('openInReader');
  String get copiedForSharing => _('copiedForSharing');
  String get studyPanelHint => _('studyPanelHint');
  String get goToHint => _('goToHint');
  String get noVoiceBrowser => _('noVoiceBrowser');
  String get studyPacksAppOnly => _('studyPacksAppOnly');
  String get planDayRead => _('planDayRead');

  /// "Listen to ዮሐንስ 3".
  String listenTo(String chapter) => isAmharic ? '$chapter ያዳምጡ' : 'Listen to $chapter';
  String get readerTip => _('readerTip');
  String get gotIt => _('gotIt');
  String get moreActions => _('moreActions');
  String get holdToSelectHint => _('holdToSelectHint');
  String get guest => _('guest');
  String get syncOn => _('syncOn');
  String get signInToSync => _('signInToSync');
  String get notesOnDevice => _('notesOnDevice');
  String get appSection => _('appSection');

  /// "Step 2 of 3", for screen readers on the welcome steps.
  String stepOf(int n, int total) => isAmharic ? 'ደረጃ $n ከ$total' : 'Step $n of $total';

  /// A greeting for the time of day, in the polite form ("እንደምን አደሩ").
  String greeting(int hour) {
    if (hour >= 5 && hour < 12) return isAmharic ? 'እንደምን አደሩ' : 'Good morning';
    if (hour >= 12 && hour < 18) return isAmharic ? 'እንደምን ዋሉ' : 'Good afternoon';
    return isAmharic ? 'እንደምን አመሹ' : 'Good evening';
  }

  static const _weekdaysAm = ['እሑድ', 'ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ'];
  static const _weekdaysEn = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  /// The name of [DateTime.weekday] (Monday 1 … Sunday 7).
  String weekdayName(int weekday) => (isAmharic ? _weekdaysAm : _weekdaysEn)[weekday % 7];

  /// One-letter initial of the [i]th day of the week, Sunday first.
  String weekdayInitial(int i) => (isAmharic ? _weekdaysAm : _weekdaysEn)[i].substring(0, 1);
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

  String get askAi => _('askAi');
  String get aiAssistant => _('aiAssistant');
  String get aiDisclaimer => _('aiDisclaimer');
  String get aiNotConfigured => _('aiNotConfigured');
  String get aiExplain => _('aiExplain');
  String get aiSummarize => _('aiSummarize');
  String get aiQuestions => _('aiQuestions');
  String get aiSermon => _('aiSermon');
  String get aiAskQuestion => _('aiAskQuestion');
  String get aiQuestionHint => _('aiQuestionHint');
  String get aiLevelSimple => _('aiLevelSimple');
  String get aiLevelScholar => _('aiLevelScholar');
  String get aiPerspective => _('aiPerspective');
  String get perspectiveGeneral => _('perspectiveGeneral');
  String get perspectiveOrthodox => _('perspectiveOrthodox');
  String get perspectiveProtestant => _('perspectiveProtestant');
  String get perspectiveCatholic => _('perspectiveCatholic');
  String get perspectiveAcademic => _('perspectiveAcademic');
  String get aiSend => _('aiSend');
  String get aiExplanationLabel => _('aiExplanationLabel');
  String get aiQuoteLabel => _('aiQuoteLabel');
  String get aiInterpretationLabel => _('aiInterpretationLabel');
  String get aiUnverified => _('aiUnverified');
  String get aiUncertain => _('aiUncertain');
  String get aiFollowUp => _('aiFollowUp');
  String get aiCited => _('aiCited');
  String get aiDeclined => _('aiDeclined');
  String get aiBusy => _('aiBusy');

  String get audio => _('audio');
  String get studyPacks => _('studyPacks');
  String get studyPacksNote => _('studyPacksNote');
  String get packsUnavailable => _('packsUnavailable');
  String get packInstalled => _('packInstalled');
  String get packUpdateAvailable => _('packUpdateAvailable');
  String get packInstalling => _('packInstalling');
  String get packErrorOffline => _('packErrorOffline');
  String get packErrorCorrupt => _('packErrorCorrupt');
  String get packErrorServer => _('packErrorServer');
  String get download => _('download');
  String get update => _('update');
  String get removePackConfirm => _('removePackConfirm');
  String get getStudyPacks => _('getStudyPacks');
  String get getStudyPacksHint => _('getStudyPacksHint');
  String packSize(String size) => isAmharic ? '$size ማውረድ' : '$size download';
  String packDownloading(int percent) => isAmharic ? 'በማውረድ ላይ… $percent%' : 'Downloading… $percent%';
  String downloadPackConfirm(String download, String installed) => isAmharic
      ? '$download ይወርዳል፤ በስልክዎ ላይ $installed ቦታ ይይዛል።'
      : 'This downloads $download and uses $installed on your phone.';

  String get allVersions => _('allVersions');
  String get compare => _('compare');
  String get recentlyRead => _('recentlyRead');

  String get reminders => _('reminders');
  String get dailyReminder => _('dailyReminder');
  String get off => _('off');
  String get reminderBody => _('reminderBody');
  String get notificationsBlocked => _('notificationsBlocked');
  String get readingStreak => _('readingStreak');
  String get readingStreakHint => _('readingStreakHint');
  String get streakStart => _('streakStart');
  String get streakKeepGoing => _('streakKeepGoing');
  String get wifiOnly => _('wifiOnly');
  String get wifiOnlyHint => _('wifiOnlyHint');
  String get needWifi => _('needWifi');
  String streakDays(int n) => isAmharic ? '$n ቀን በተከታታይ' : (n == 1 ? '1 day in a row' : '$n days in a row');
  String streakBest(int n) => isAmharic ? 'ረጅሙ፦ ${days(n)}' : 'Longest: ${days(n)}';

  String get readAloud => _('readAloud');
  String get stopReading => _('stopReading');
  String get noVoice => _('noVoice');

  String get tags => _('tags');
  String get tagsHint => _('tagsHint');
  String get exportNotes => _('exportNotes');
  String get notesExportTitle => _('notesExportTitle');
  String get exportedOn => _('exportedOn');
  String get scriptureFrom => _('scriptureFrom');
  String get grammarMatches => _('grammarMatches');
  String get timeline => _('timeline');
  String get studyTools => _('studyTools');
  String get timelineHint => _('timelineHint');
  String get peopleAndPlaces => _('peopleAndPlaces');
  String get peopleHint => _('peopleHint');
  String get wordStudyHint => _('wordStudyHint');
  String get askAiHint => _('askAiHint');
  String get trySearching => _('trySearching');
  String get searchTips => _('searchTips');
  String get tipReference => _('tipReference');
  String get tipWords => _('tipWords');
  String get tipPhrase => _('tipPhrase');
  String get tipStrongs => _('tipStrongs');
  String get tipGrammar => _('tipGrammar');
  String get filter => _('filter');
  String get testament => _('testament');
  String get book => _('book');
  String get allBooks => _('allBooks');
  String get removeFilter => _('removeFilter');
  String get verses => _('verses');
  String get dictionary => _('dictionary');
  String get whichPassage => _('whichPassage');
  String get passageHint => _('passageHint');
  String get notAReference => _('notAReference');
  String get peopleSearchHint => _('peopleSearchHint');
  String get mostMentioned => _('mostMentioned');
  String get people => _('people');
  String get places => _('places');
  String get events => _('events');
  String get wordsSearchHint => _('wordsSearchHint');
  String get greekWords => _('greekWords');
  String get hebrewWords => _('hebrewWords');
  String exportNotesHint(int n) =>
      isAmharic ? '$n ማስታወሻዎች፣ ከጥቅሶቻቸው ጋር' : (n == 1 ? '1 note, with its passage' : '$n notes, with their passages');
  String grammarMatchCount(int shown, int total) =>
      isAmharic ? 'በ$total ጥቅሶች ይገኛል (የመጀመሪያዎቹ $shown)' : 'In $total verses (first $shown shown)';

  String get studyGroups => _('studyGroups');
  String get groupsSignIn => _('groupsSignIn');
  String get noGroups => _('noGroups');
  String get createGroup => _('createGroup');
  String get joinGroup => _('joinGroup');
  String get groupName => _('groupName');
  String get groupNameHint => _('groupNameHint');
  String get inviteCode => _('inviteCode');
  String get inviteCodeHint => _('inviteCodeHint');
  String get newInviteCode => _('newInviteCode');
  String get yourName => _('yourName');
  String get yourNameHint => _('yourNameHint');
  String get fillBothFields => _('fillBothFields');
  String get groupCodeNotFound => _('groupCodeNotFound');
  String get groupFull => _('groupFull');
  String get teacher => _('teacher');
  String get member => _('member');
  String get members => _('members');
  String get discussion => _('discussion');
  String get assignments => _('assignments');
  String get assignment => _('assignment');
  String get readingPlan => _('readingPlan');
  String get writeMessage => _('writeMessage');
  String get send => _('send');
  String get noMessages => _('noMessages');
  String get noAssignments => _('noAssignments');
  String get newAssignment => _('newAssignment');
  String get assignmentText => _('assignmentText');
  String get assignmentHint => _('assignmentHint');
  String get assignmentNeedsText => _('assignmentNeedsText');
  String get passageOptional => _('passageOptional');
  String get passageNotRecognized => _('passageNotRecognized');
  String get dueDate => _('dueDate');
  String get noDueDate => _('noDueDate');
  String get postAssignment => _('postAssignment');
  String get markDone => _('markDone');
  String get doneLabel => _('doneLabel');
  String get noGroupPlan => _('noGroupPlan');
  String get chooseGroupPlan => _('chooseGroupPlan');
  String get choosePlan => _('choosePlan');
  String get changePlan => _('changePlan');
  String get groupProgress => _('groupProgress');
  String get leaveGroup => _('leaveGroup');
  String get leaveGroupConfirm => _('leaveGroupConfirm');
  String get manageMember => _('manageMember');
  String get makeTeacher => _('makeTeacher');
  String get makeMember => _('makeMember');
  String get removeFromGroup => _('removeFromGroup');
  String dueOn(String date) => isAmharic ? 'እስከ $date' : 'Due $date';
  String inDays(int n) => isAmharic ? 'በ$n ቀን ውስጥ' : (n == 1 ? 'Tomorrow' : 'In $n days');
  String doneCount(int done, int total) => isAmharic ? '$done ከ$total ጨርሰዋል' : '$done of $total done';
  String daysRead(int n, int total) => isAmharic ? '$n ከ$total ቀናት ተነበዋል' : '$n of $total days read';
  String inviteMessage(String group, String code) => isAmharic
      ? 'በመጽሐፍ ቅዱስ መተግበሪያው «$group» የጥናት ቡድንን ይቀላቀሉ። ኮድ፦ $code'
      : 'Join the study group "$group" in the Amharic Bible app. Code: $code';

  String get privacy => _('privacy');
  String get sendErrorReports => _('sendErrorReports');
  String get sendErrorReportsHint => _('sendErrorReportsHint');

  /// A grammatical term from lib/domain/morphology.dart ("noun", "aorist", …).
  String grammar(String key) => _m['g.$key'] ?? _en['g.$key'] ?? key;

  /// A textual-variant source ("NA", "ECM", "qere", …).
  String variantSource(String key) => _m['v.$key'] ?? _en['v.$key'] ?? key;

  String occurrenceCount(int n) => isAmharic ? 'በ$n ቦታዎች ይገኛል' : (n == 1 ? 'Occurs once' : 'Occurs $n times');
  String year(int y) =>
      y < 0 ? (isAmharic ? 'ከክርስቶስ ልደት በፊት ${-y}' : '${-y} BC') : (isAmharic ? 'ከክርስቶስ ልደት በኋላ $y' : 'AD $y');

  String minutes(int n) => isAmharic ? '$n ደቂቃ' : '$n min';
  String results(int n) => isAmharic ? (n == 1 ? '1 ውጤት' : '$n ውጤቶች') : (n == 1 ? '1 result' : '$n results');

  /// Search stops at [n] results; say so instead of implying there are no more.
  String firstResults(int n) => isAmharic ? 'የመጀመሪያዎቹ $n ውጤቶች' : 'First $n results';
  String selected(int n) => isAmharic ? '$n ተመርጠዋል' : '$n selected';
  String day(int n) => isAmharic ? 'ቀን $n' : 'Day $n';
  String dayOf(int n, int total) => isAmharic ? 'ቀን $n ከ$total' : 'Day $n of $total';
  String dayDone(int n) => isAmharic ? 'የቀን $n ንባብ ተጠናቋል' : 'Day $n done';

  /// A day in a plan's day strip, for screen readers.
  String dayCell(int n, {required bool done}) =>
      isAmharic ? (done ? 'ቀን $n፣ ተነቧል' : 'ቀን $n') : (done ? 'Day $n, read' : 'Day $n');
  String get markAsUnread => _('markAsUnread');
  String get seeAllPlans => _('seeAllPlans');
  String get dayComplete => _('dayComplete');
  String get myNotes => _('myNotes');
  String get addNote => _('addNote');
  String get noNotesHere => _('noNotesHere');
  String get aiWritten => _('aiWritten');
  String get aiWriting => _('aiWriting');
  String get aiStartWith => _('aiStartWith');
  String get aiOptions => _('aiOptions');
  String get aiLevel => _('aiLevel');
  String get languageAndRegion => _('languageAndRegion');
  String get reading => _('reading');
  String get audioAndDownloads => _('audioAndDownloads');
  String get remindMe => _('remindMe');
  String get turnOff => _('turnOff');
  String get invite => _('invite');
  String memberCount(int n) => isAmharic ? (n == 1 ? '1 አባል' : '$n አባላት') : (n == 1 ? '1 member' : '$n members');
  String get cardStyle => _('cardStyle');
  String get textSmaller => _('textSmaller');
  String get textDefault => _('textDefault');
  String get textLarger => _('textLarger');
  String get showVersion => _('showVersion');
  String get ornamentFrame => _('ornamentFrame');
  String get adjustSchedule => _('adjustSchedule');
  String get catchUpTitle => _('catchUpTitle');
  String missedDays(int n) => isAmharic
      ? 'ያልተነበቡ ${days(n)} አሉ።'
      : (n == 1 ? "There's 1 day you haven't read." : "There are $n days you haven't read.");
  String get pickUp => _('pickUp');
  String pickUpHint(int day) => isAmharic
      ? 'ዛሬ ቀን $day ይሆናል፤ ከዚያ በኋላ ያሉት ቀናትም አብረው ይዛወራሉ።'
      : 'Today becomes day $day; the days after it move along.';
  String markMissed(int n) => isAmharic
      ? 'ያመለጡትን ${days(n)} እንደተነበቡ ምልክት አድርግ'
      : (n == 1 ? 'Mark the missed day read' : 'Mark the $n missed days read');
  String get markMissedHint => _('markMissedHint');
  String get scheduleAdjusted => _('scheduleAdjusted');
  String get planCalendar => _('planCalendar');
  String week(int n) => isAmharic ? 'ሳምንት $n' : 'Week $n';
  String get planComplete => _('planComplete');
  String planCompleteShare(String plan) =>
      isAmharic ? 'የንባብ ዕቅዱን «$plan» ጨረስኩ። — $appName' : 'I finished the reading plan “$plan”. — $appName';
  String get chooseAnotherPlan => _('chooseAnotherPlan');
  String get installApp => _('installApp');
  String get installAppHint => _('installAppHint');
  String get showOnMap => _('showOnMap');
  String get mapOpenFailed => _('mapOpenFailed');

  /// An era of biblical history on the timeline, by `BibleEra.name`.
  String era(String name) => _('era.$name');
  String dayRange(int a, int b) => isAmharic ? 'ቀን $a–$b' : 'Days $a–$b';
  String days(int n) => isAmharic ? (n == 1 ? '1 ቀን' : '$n ቀናት') : (n == 1 ? '1 day' : '$n days');
  String behind(int n) => isAmharic ? '${days(n)} ወደኋላ' : '${days(n)} behind';
  String signedInAs(String email) => isAmharic ? 'በ$email ገብተዋል' : 'Signed in as $email';
  String chapterOf(String book, int c) => isAmharic ? '$book ምዕራፍ $c' : '$book $c';

  /// Screen-reader label for a verse number: "ዮሐንስ ምዕራፍ 3 ቁጥር 16".
  String verseLabel(String book, int chapter, String verse) =>
      isAmharic ? '$book ምዕራፍ $chapter ቁጥር $verse' : '$book chapter $chapter, verse $verse';

  /// A highlight color's name ("yellow" → "ቢጫ").
  String colorName(String key) => _('color.$key');

  /// "Highlight yellow", for the swatch buttons.
  String highlightIn(String colorKey) =>
      isAmharic ? '${colorName(colorKey)} አድምቅ' : '$highlight ${colorName(colorKey).toLowerCase()}';

  /// Keys with no Amharic or no English text (an empty list means every string
  /// is translated; see test/strings_test.dart).
  @visibleForTesting
  static List<String> get untranslatedKeys => [
    for (final k in _en.keys)
      if (!_am.containsKey(k)) 'am: $k',
    for (final k in _am.keys)
      if (!_en.containsKey(k)) 'en: $k',
  ];
}

const _am = {
  'appName': 'መጽሐፍ ቅዱስ',
  'undo': 'ቀልብስ',
  'library': 'ቤተ መጻሕፍት',
  'discardChanges': 'ለውጦቹ ሳይቀመጡ ይውጡ?',
  'discardChangesMessage': 'በዚህ ማስታወሻ ላይ ያደረጉት ለውጥ ገና አልተቀመጠም።',
  'discard': 'ሳታስቀምጥ ውጣ',
  'keepEditing': 'ማረም ቀጥል',
  'deleteNoteConfirm': 'ይህ ማስታወሻ ይሰረዝ?',
  'deleteNoteMessage': 'የተሰረዘ ማስታወሻ መመለስ አይቻልም።',
  'deletePostConfirm': 'ይህ መልእክት ይሰረዝ?',
  'deletePostMessage': 'ለቡድኑ አባላት ሁሉ ይሰረዛል።',
  'removeAudioMessage': 'የወረደው ድምፅ ከዚህ መሣሪያ ይወገዳል። በኋላ እንደገና ማውረድ ይችላሉ።',
  'somethingWentWrong': 'ችግር ተፈጥሯል። ግንኙነትዎን ያረጋግጡና እንደገና ይሞክሩ።',
  'emptyTimeline': 'የዘመን ሰሌዳው ገና የለም። ክስተቶቹ ከጥናት ጥቅሎቹ ጋር ይመጣሉ።',
  'play': 'አጫውት',
  'pause': 'ለአፍታ አቁም',
  'stopAudio': 'ድምፁን አቁም',
  'back10': '10 ሰከንድ ወደኋላ',
  'forward10': '10 ሰከንድ ወደፊት',
  'smallerText': 'ፊደሉን አሳንስ',
  'largerText': 'ፊደሉን አሳድግ',
  'spacingCompact': 'ጠባብ',
  'spacingNormal': 'መካከለኛ',
  'spacingRelaxed': 'ሰፊ',
  'shapeSquare': 'ካሬ',
  'shapeStory': 'ቁመታዊ',
  'pageNotFound': 'ይህ ገጽ አልተገኘም። አድራሻው ተቀይሮ ወይም ተሳስቶ ሊሆን ይችላል።',
  'today': 'ዛሬ',
  'plans': 'ዕቅዶች',
  'groupsIntro': 'ከቤተ ክርስቲያንዎ ወይም ከጓደኞችዎ ጋር አብረው ያንብቡ፣ ይወያዩ።',
  'thisWeek': 'ይህ ሳምንት',
  'startAPlan': 'የንባብ ዕቅድ ይጀምሩ',
  'startPlanHint': 'በቀን ጥቂት ምዕራፎች፤ ዕቅዱ የደረሱበትን ቦታ ያስታውሳል።',
  'skip': 'ዝለል',
  'next': 'ቀጥል',
  'chooseLanguage': 'ቋንቋ ይምረጡ',
  'readingComfort': 'ለንባብ እንዲመችዎ',
  'readingComfortHint': 'የፊደሉን መጠንና ገጽታ ይምረጡ። በኋላም በንባብ ገጹ ላይ ባለው Aa መቀየር ይችላሉ።',
  'whereToBegin': 'ከየት ይጀምሩ?',
  'beginJohn': 'በዮሐንስ ወንጌል ይጀምሩ',
  'beginJohnHint': 'የኢየሱስን ሕይወትና ትምህርት ለማወቅ ጥሩ መነሻ።',
  'beginPlan': 'የንባብ ዕቅድ ይምረጡ',
  'beginPlanHint': 'መጽሐፍ ቅዱስን በዓመት፣ አዲስ ኪዳንን በ90 ቀን፣ ወይም ወንጌላትን በ30 ቀን።',
  'beginToday': 'ወደ ዛሬ ይሂዱ',
  'beginTodayHint': 'የዕለቱ ጥቅስና የንባብዎ ቦታ።',
  'readerTip': 'ለማድመቅ፣ ማስታወሻ ለመጻፍ ወይም ለማጋራት ጥቅሱን ተጭነው ይያዙ። ምናሌዎቹን ለማሳየት ወይም ለመደበቅ አንዴ ይንኩ፤ ለቀጣዩ ምዕራፍ ወደ ጎን ያንሸራቱ።',
  'gotIt': 'ገባኝ',
  'readingLook': 'የንባብ ገጽታ',
  'openInReader': 'በንባብ ገጹ ክፈት',
  'copiedForSharing': 'ተቀድቷል። ለማጋራት በሚፈልጉት ቦታ ይለጥፉት።',
  'studyPanelHint': 'ማጣቀሻዎችን፣ የመጀመሪያ ቋንቋ ቃላትንና ማብራሪያዎችን ለማየት ጥቅስ ይምረጡ።',
  'goToHint': 'ዮሐ 3፥16፣ Jn 3:16 ወይም ቃል',
  'noVoiceBrowser': 'ይህ ብራውዘር ለዚህ ቋንቋ ድምፅ የለውም። ሌላ ብራውዘር ወይም የስልኩን መተግበሪያ ይሞክሩ።',
  'studyPacksAppOnly': 'የዕብራይስጥና የግሪክ ጽሑፎች፣ መዝገበ ቃላትና ሌሎች የጥናት ጥቅሎች በAndroid እና iOS መተግበሪያው ውስጥ ይገኛሉ።',
  'planDayRead': 'የዕለቱ ንባብ ተጠናቋል',
  'moreActions': 'ተጨማሪ',
  'holdToSelectHint': 'ለማድመቅ፣ ለማጋራት ወይም ማስታወሻ ለመጻፍ ጥቅሱን ተጭነው ይያዙ',
  'guest': 'እንግዳ',
  'syncOn': 'ድምቀቶችና ማስታወሻዎች ከዚህ መለያ ጋር ይመሳሰላሉ',
  'signInToSync': 'ድምቀቶችዎና ማስታወሻዎችዎ እንዳይጠፉ ይግቡና ያመሳስሉ',
  'notesOnDevice': 'ድምቀቶችዎና ማስታወሻዎችዎ በዚህ መሣሪያ ላይ ይቀመጣሉ',
  'appSection': 'መተግበሪያ',
  'color.yellow': 'ቢጫ',
  'color.green': 'አረንጓዴ',
  'color.blue': 'ሰማያዊ',
  'color.pink': 'ሮዝ',
  'color.orange': 'ብርቱካናማ',
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
  'askAi': 'AIን ይጠይቁ',
  'aiAssistant': 'የመጽሐፍ ቅዱስ ጥናት ረዳት (AI)',
  'aiDisclaimer': 'መልሶቹ በAI የተዘጋጁ ናቸው፤ ስሕተት ሊኖራቸው ይችላል። መጽሐፍ ቅዱስ የሚታየው ከዚህ መተግበሪያ ጽሑፍ ብቻ ነው። ማብራሪያዎቹን ከቃሉ ጋር ያመሳክሩ።',
  'aiNotConfigured': 'የAI ረዳቱ በዚህ እትም አልተዘጋጀም።',
  'aiExplain': 'አብራራ',
  'aiSummarize': 'አጠቃልል',
  'aiQuestions': 'የጥናት ጥያቄዎች',
  'aiSermon': 'ለስብከት ዝግጅት',
  'aiAskQuestion': 'ጥያቄ',
  'aiQuestionHint': 'ስለዚህ ክፍል ምን ማወቅ ይፈልጋሉ?',
  'aiLevelSimple': 'ቀላል',
  'aiLevelScholar': 'ጥልቅ (ለምሁራን)',
  'aiPerspective': 'አመለካከት',
  'perspectiveGeneral': 'ሁሉንም ወገኖች',
  'perspectiveOrthodox': 'ኦርቶዶክስ ተዋሕዶ',
  'perspectiveProtestant': 'ፕሮቴስታንት',
  'perspectiveCatholic': 'ካቶሊክ',
  'perspectiveAcademic': 'አካዳሚያዊ',
  'aiSend': 'ጠይቅ',
  'aiExplanationLabel': 'የAI ማብራሪያ',
  'aiQuoteLabel': 'ጥቅስ ከምንጭ',
  'aiInterpretationLabel': 'አከራካሪ ትርጓሜ',
  'aiUnverified': 'ከምንጩ ጋር አልተረጋገጠም',
  'aiUncertain': 'እርግጠኛ ያልሆነው',
  'aiFollowUp': 'ተጨማሪ ጥያቄዎች',
  'aiCited': 'ምንጮች',
  'aiDeclined': 'ረዳቱ ይህን ጥያቄ አልመለሰም። በሌላ መንገድ ይጠይቁ።',
  'aiBusy': 'ረዳቱ አሁን ሥራ በዝቶበታል። ትንሽ ቆይተው ይሞክሩ።',
  'audio': 'ድምፅ',
  'studyPacks': 'የጥናት ጥቅሎች',
  'studyPacksNote':
      'የዕብራይስጥና የግሪክ ጽሑፎች፣ መዝገበ ቃላት፣ ተዛማጅ ጥቅሶች፣ ሰዎችና ቦታዎች እንዲሁም ማብራሪያ። አንዴ ካወረዱ ያለ ኢንተርኔት ይሠራሉ። ከተቻለ በWi-Fi ያውርዱ።',
  'packsUnavailable': 'የጥቅሎቹን ዝርዝር ማግኘት አልተቻለም። ኢንተርኔትዎን ያረጋግጡ።',
  'packInstalled': 'ወርዷል',
  'packUpdateAvailable': 'አዲስ እትም አለ',
  'packInstalling': 'በመጫን ላይ…',
  'packErrorOffline': 'ማውረዱ ተቋርጧል። ካቆመበት ለመቀጠል እንደገና ይሞክሩ።',
  'packErrorCorrupt': 'የወረደው ፋይል ተበላሽቷል። እንደገና ይሞክሩ።',
  'packErrorServer': 'ይህን ጥቅል አሁን ማውረድ አልተቻለም። ቆይተው ይሞክሩ።',
  'download': 'አውርድ',
  'update': 'አዘምን',
  'removePackConfirm': 'ይህ ጥቅል ከዚህ ስልክ ይሰረዛል። በኋላ እንደገና ማውረድ ይችላሉ።',
  'getStudyPacks': 'የዕብራይስጥ፣ የግሪክና የጥናት ጥቅሎችን ያውርዱ',
  'getStudyPacksHint': 'ለዚህ ጥቅስ ሙሉ የቃል፣ የተዛማጅ ጥቅስና የማብራሪያ መረጃ ለማግኘት።',
  'allVersions': 'ሁሉም ትርጉሞች',
  'compare': 'አወዳድር',
  'recentlyRead': 'በቅርቡ የተነበቡ',
  'reminders': 'ማስታወሻዎችና ልማድ',
  'dailyReminder': 'የዕለት ንባብ ማስታወሻ',
  'reminderBody': 'የዛሬው የመጽሐፍ ቅዱስ ንባብ ጊዜ ደርሷል።',
  'notificationsBlocked': 'ማሳወቂያዎች ተከልክለዋል። በስልክዎ ቅንብሮች ውስጥ ይፍቀዱ።',
  'readingStreak': 'የንባብ ተከታታይ ቀናት',
  'readingStreakHint': 'በተከታታይ ያነበቡባቸውን ቀናት በመነሻ ገጽ አሳይ',
  'streakStart': 'ዛሬ አንብበው ይጀምሩ።',
  'streakKeepGoing': 'ዛሬ ካነበቡ ይቀጥላል።',
  'wifiOnly': 'በWi-Fi ብቻ አውርድ',
  'wifiOnlyHint': 'የጥናት ጥቅሎችንና ድምፅን በሞባይል ዳታ አያወርድም',
  'needWifi': 'ከWi-Fi ጋር ይገናኙ፣ ወይም በቅንብሮች ውስጥ «በWi-Fi ብቻ አውርድ»ን ያጥፉ።',
  'readAloud': 'በስልኩ ድምፅ አንብብ',
  'stopReading': 'ማንበብ አቁም',
  'noVoice': 'ስልክዎ ለዚህ ቋንቋ ድምፅ የለውም። በስልኩ ቅንብሮች ውስጥ የጽሑፍ-ወደ-ንግግር ድምፅ ይጫኑ።',
  'tags': 'መለያዎች',
  'tagsHint': 'ለምሳሌ፦ ጸሎት፣ ቤተሰብ',
  'exportNotes': 'ማስታወሻዎችን ላክ (Markdown)',
  'notesExportTitle': 'የመጽሐፍ ቅዱስ ማስታወሻዎቼ',
  'exportedOn': 'የተላከበት ቀን',
  'scriptureFrom': 'የመጽሐፍ ቅዱስ ጥቅሶች ከ',
  'grammarMatches': 'በሰዋስው የተገኙ',
  'timeline': 'የመጽሐፍ ቅዱስ የዘመን ሰሌዳ',
  'studyGroups': 'የጥናት ቡድኖች',
  'groupsSignIn': 'የጥናት ቡድኖችን ለመጠቀም ይግቡ።',
  'noGroups': 'እስካሁን በቡድን ውስጥ የሉም። ቡድን ይፍጠሩ ወይም በኮድ ይቀላቀሉ።',
  'createGroup': 'ቡድን ፍጠር',
  'joinGroup': 'በኮድ ተቀላቀል',
  'groupName': 'የቡድኑ ስም',
  'groupNameHint': 'ለምሳሌ፦ የወጣቶች መጽሐፍ ቅዱስ ጥናት',
  'inviteCode': 'የመጋበዣ ኮድ',
  'inviteCodeHint': 'ሌሎች ይህን ኮድ በመጠቀም ቡድኑን ይቀላቀላሉ።',
  'newInviteCode': 'አዲስ ኮድ (አሮጌው መሥራት ያቆማል)',
  'yourName': 'በቡድኑ ውስጥ የሚታየው ስምዎ',
  'yourNameHint': 'ኢሜይልዎ አይታይም።',
  'fillBothFields': 'ሁለቱንም ይሙሉ።',
  'groupCodeNotFound': 'በዚህ ኮድ ቡድን አልተገኘም።',
  'groupFull': 'ይህ ቡድን ሞልቷል።',
  'teacher': 'መምህር',
  'member': 'አባል',
  'members': 'አባላት',
  'discussion': 'ውይይት',
  'assignments': 'የቤት ሥራዎች',
  'assignment': 'የቤት ሥራ',
  'readingPlan': 'የንባብ ዕቅድ',
  'writeMessage': 'መልእክት ይጻፉ…',
  'send': 'ላክ',
  'noMessages': 'እስካሁን መልእክት የለም። ሐሳብዎን ወይም ጥያቄዎን ለቡድኑ ያካፍሉ።',
  'noAssignments': 'እስካሁን የቤት ሥራ የለም።',
  'newAssignment': 'አዲስ የቤት ሥራ',
  'assignmentText': 'የቤት ሥራው',
  'assignmentHint': 'ለምሳሌ፦ ምዕራፉን አንብበው አንድ ጸሎት ይጻፉ',
  'assignmentNeedsText': 'የቤት ሥራውን ይጻፉ።',
  'passageOptional': 'ክፍል (አማራጭ)',
  'passageNotRecognized': 'ይህን ጥቅስ ማወቅ አልተቻለም።',
  'dueDate': 'የሚደርስበት ቀን',
  'noDueDate': 'ቀን የለውም',
  'postAssignment': 'የቤት ሥራውን ላክ',
  'markDone': 'ጨርሻለሁ',
  'doneLabel': 'ተጠናቋል',
  'noGroupPlan': 'መምህሩ እስካሁን የንባብ ዕቅድ አልመረጠም።',
  'chooseGroupPlan': 'ቡድኑ አብሮ የሚያነበው ዕቅድ ይምረጡ።',
  'choosePlan': 'ዕቅድ ምረጥ',
  'changePlan': 'ዕቅዱን ቀይር (ሂደቱ እንደገና ይጀምራል)',
  'groupProgress': 'የቡድኑ ሂደት',
  'leaveGroup': 'ቡድኑን ልቀቅ',
  'leaveGroupConfirm': 'ይህን ቡድን ይለቃሉ? እንደገና ለመቀላቀል ኮዱ ያስፈልግዎታል።',
  'manageMember': 'አባሉን አስተዳድር',
  'makeTeacher': 'መምህር አድርግ',
  'makeMember': 'አባል አድርግ',
  'removeFromGroup': 'ከቡድኑ አስወግድ',
  'privacy': 'ግላዊነት',
  'sendErrorReports': 'የስሕተት ሪፖርቶችን ላክ',
  'sendErrorReportsHint': 'መተግበሪያው ሲበላሽ ምን እንደተፈጠረ ይላካል። የመጽሐፍ ቅዱስ ጽሑፍ፣ ማስታወሻዎች ወይም ኢሜይል አይላኩም።',
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
  // Search & Study
  'studyTools': 'የጥናት መሣሪያዎች',
  'timelineHint': 'የመጽሐፍ ቅዱስ ታሪክ በዘመን ቅደም ተከተል',
  'peopleAndPlaces': 'ሰዎችና ቦታዎች',
  'peopleHint': 'በመጽሐፍ ቅዱስ ውስጥ ያሉ ሰዎች፣ ቦታዎችና ክስተቶች',
  'wordStudyHint': 'የዕብራይስጥና የግሪክ ቃላትና ትርጉማቸው',
  'askAiHint': 'ስለ አንድ የመጽሐፍ ቅዱስ ክፍል ይጠይቁ',
  'trySearching': 'እነዚህን ይሞክሩ',
  'searchTips': 'የፍለጋ ምክሮች',
  'tipReference': 'ክፍሉን በቀጥታ ይከፍታል',
  'tipWords': 'ሁሉንም ቃላት የያዙ ጥቅሶችን ያገኛል፤ የቃሉ መጀመሪያ ብቻ በቂ ነው',
  'tipPhrase': 'ቃላቱን አብረው፣ በዚህ ቅደም ተከተል ያገኛል',
  'tipStrongs': 'የዕብራይስጥ ወይም የግሪክ ቃልን በስትሮንግ ቁጥሩ ያገኛል',
  'tipGrammar': 'ጥቅሶችን በሰዋስው መልክ ያገኛል',
  'filter': 'ማጣሪያ',
  'testament': 'ኪዳን',
  'book': 'መጽሐፍ',
  'allBooks': 'ሁሉም መጻሕፍት',
  'removeFilter': 'ማጣሪያውን አስወግድ',
  'verses': 'ጥቅሶች',
  'dictionary': 'መዝገበ ቃላት',
  'whichPassage': 'ስለ የትኛው ክፍል መጠየቅ ይፈልጋሉ?',
  'passageHint': 'ለምሳሌ ዮሐ 3፥16 ወይም Jn 3:16',
  'notAReference': 'ይህ የመጽሐፍ ቅዱስ ጥቅስ አይመስልም',
  'peopleSearchHint': 'ስም ይፈልጉ (በእንግሊዝኛ)',
  'mostMentioned': 'በብዛት የተጠቀሱ',
  'people': 'ሰዎች',
  'places': 'ቦታዎች',
  'events': 'ክስተቶች',
  'wordsSearchHint': 'ቃል፣ ትርጉም ወይም የስትሮንግ ቁጥር (G26)',
  'greekWords': 'ግሪክ (አዲስ ኪዳን)',
  'hebrewWords': 'ዕብራይስጥ (ብሉይ ኪዳን)',
  // Plans
  'markAsUnread': 'እንዳልተነበበ ምልክት አድርግ',
  'seeAllPlans': 'ሁሉንም ዕቅዶች ይመልከቱ',
  'dayComplete': 'ተነቧል',
  // Study screens
  'myNotes': 'የእኔ ማስታወሻዎች',
  'addNote': 'ማስታወሻ ጻፍ',
  'noNotesHere': 'በዚህ ጥቅስ ላይ ገና ማስታወሻ አልጻፉም።',
  'aiWritten': 'በAI የተጻፈ',
  'aiWriting': 'መልሱ እየተጻፈ ነው…',
  'aiStartWith': 'በዚህ ይጀምሩ',
  'aiOptions': 'የመልስ ምርጫዎች',
  'aiLevel': 'ደረጃ',
  // Settings, groups, share image
  'languageAndRegion': 'ቋንቋና አካባቢ',
  'reading': 'ንባብ',
  'audioAndDownloads': 'ድምፅና ማውረድ',
  'remindMe': 'አስታውሰኝ',
  'turnOff': 'አጥፋ',
  'invite': 'ጋብዝ',
  'cardStyle': 'ቅጥ',
  'textSmaller': 'ትንሽ ፊደል',
  'textDefault': 'መደበኛ ፊደል',
  'textLarger': 'ትልቅ ፊደል',
  'showVersion': 'ትርጉሙን አሳይ',
  'ornamentFrame': 'የጌጥ ክፈፍ',
  // Plans: catching up, calendar, completion
  'adjustSchedule': 'መርሐ ግብሩን አስተካክል',
  'catchUpTitle': 'ወደኋላ ቀርተዋል? መርሐ ግብሩን ያስተካክሉ',
  'pickUp': 'ካቆሙበት ይቀጥሉ',
  'markMissedHint': 'በሌላ ቦታ ካነበቧቸው',
  'scheduleAdjusted': 'መርሐ ግብሩ ተስተካክሏል',
  'planCalendar': 'የዕቅዱ ቀናት',
  'planComplete': 'ዕቅዱ ተጠናቋል',
  'chooseAnotherPlan': 'ሌላ ዕቅድ ይምረጡ',
  'installApp': 'መተግበሪያውን ጫን',
  'installAppHint': 'ከመነሻ ገጽዎ በቀጥታ ይክፈቱት፤ ያለ ኢንተርኔትም ይሰራል።',
  'showOnMap': 'በካርታ ላይ አሳይ',
  'mapOpenFailed': 'ካርታውን መክፈት አልተቻለም',
  'era.beginnings': 'ፍጥረትና የጥንቱ ዓለም',
  'era.patriarchs': 'የአበው ዘመን',
  'era.exodus': 'ዘጸአትና የምድረ በዳው ጉዞ',
  'era.judges': 'የከነዓን ርስትና መሳፍንት',
  'era.kingdom': 'የነገሥታት ዘመን',
  'era.exile': 'ምርኮ',
  'era.returnHome': 'ከምርኮ መመለስ',
  'era.between': 'በብሉይና በአዲስ ኪዳን መካከል',
  'era.jesus': 'የኢየሱስ ክርስቶስ ሕይወት',
  'era.church': 'የመጀመሪያዋ ቤተ ክርስቲያን',
};

const _en = {
  'appName': 'Amharic Bible',
  'undo': 'Undo',
  'library': 'Library',
  'discardChanges': 'Discard changes?',
  'discardChangesMessage': "Your changes to this note haven't been saved.",
  'discard': 'Discard',
  'keepEditing': 'Keep editing',
  'deleteNoteConfirm': 'Delete this note?',
  'deleteNoteMessage': "A deleted note can't be brought back.",
  'deletePostConfirm': 'Delete this message?',
  'deletePostMessage': 'It will be removed for everyone in the group.',
  'removeAudioMessage': 'The downloaded audio will be removed from this device. You can download it again later.',
  'somethingWentWrong': 'Something went wrong. Check your connection and try again.',
  'emptyTimeline': 'No timeline yet. The events come with the study packs.',
  'play': 'Play',
  'pause': 'Pause',
  'stopAudio': 'Stop audio',
  'back10': 'Back 10 seconds',
  'forward10': 'Forward 10 seconds',
  'smallerText': 'Smaller text',
  'largerText': 'Larger text',
  'spacingCompact': 'Compact',
  'spacingNormal': 'Normal',
  'spacingRelaxed': 'Relaxed',
  'shapeSquare': 'Square',
  'shapeStory': 'Story',
  'pageNotFound': "This page wasn't found. The address may have changed or have a typo.",
  'today': 'Today',
  'plans': 'Plans',
  'groupsIntro': 'Read and talk it over together with your church or friends.',
  'thisWeek': 'This week',
  'startAPlan': 'Start a reading plan',
  'startPlanHint': 'A few chapters a day; the plan remembers where you are.',
  'skip': 'Skip',
  'next': 'Next',
  'chooseLanguage': 'Choose your language',
  'readingComfort': 'Make reading comfortable',
  'readingComfortHint': 'Pick a text size and look. You can change them later with Aa in the reader.',
  'whereToBegin': 'Where would you like to begin?',
  'beginJohn': 'Start with the Gospel of John',
  'beginJohnHint': 'A good first book: the life and teaching of Jesus.',
  'beginPlan': 'Choose a reading plan',
  'beginPlanHint': 'The Bible in a year, the New Testament in 90 days, or the Gospels in 30 days.',
  'beginToday': 'Go to Today',
  'beginTodayHint': 'The verse of the day and where you left off.',
  'readerTip': 'Press and hold a verse to highlight, note or share it. Tap to show or hide the bars; swipe sideways for the next chapter.',
  'gotIt': 'Got it',
  'readingLook': 'Reading appearance',
  'openInReader': 'Open in reader',
  'copiedForSharing': 'Copied. Paste it wherever you want to share it.',
  'studyPanelHint': 'Select a verse to see its cross-references, original words and commentary.',
  'goToHint': 'ዮሐ 3፥16, Jn 3:16 or a word',
  'noVoiceBrowser': 'This browser has no voice for this language. Try another browser or the phone app.',
  'studyPacksAppOnly':
      'Hebrew and Greek texts, the lexicon and the other study packs are available in the Android and iOS app.',
  'planDayRead': "This day's reading is done",
  'moreActions': 'More',
  'holdToSelectHint': 'Press and hold a verse to highlight, share or add a note',
  'guest': 'Guest',
  'syncOn': 'Highlights and notes sync with this account',
  'signInToSync': 'Sign in to back up your highlights and notes',
  'notesOnDevice': 'Your highlights and notes are kept on this device',
  'appSection': 'App',
  'color.yellow': 'Yellow',
  'color.green': 'Green',
  'color.blue': 'Blue',
  'color.pink': 'Pink',
  'color.orange': 'Orange',
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
  'askAi': 'Ask AI',
  'aiAssistant': 'Bible study assistant (AI)',
  'aiDisclaimer': 'Answers are written by AI and can be wrong. Scripture is shown only from this app\'s own text. Check every explanation against the Bible.',
  'aiNotConfigured': 'The AI assistant is not set up in this build.',
  'aiExplain': 'Explain',
  'aiSummarize': 'Summarize',
  'aiQuestions': 'Study questions',
  'aiSermon': 'Sermon help',
  'aiAskQuestion': 'Question',
  'aiQuestionHint': 'What would you like to know about this passage?',
  'aiLevelSimple': 'Simple',
  'aiLevelScholar': 'Scholar',
  'aiPerspective': 'Perspective',
  'perspectiveGeneral': 'All traditions',
  'perspectiveOrthodox': 'Orthodox',
  'perspectiveProtestant': 'Protestant',
  'perspectiveCatholic': 'Catholic',
  'perspectiveAcademic': 'Academic',
  'aiSend': 'Ask',
  'aiExplanationLabel': 'AI explanation',
  'aiQuoteLabel': 'Quoted from a source',
  'aiInterpretationLabel': 'Debated interpretation',
  'aiUnverified': 'Not found in its source',
  'aiUncertain': 'What is uncertain',
  'aiFollowUp': 'Follow-up questions',
  'aiCited': 'Sources',
  'aiDeclined': 'The assistant declined this request. Try asking another way.',
  'aiBusy': 'The assistant is busy. Try again in a moment.',
  'audio': 'Audio',
  'studyPacks': 'Study packs',
  'studyPacksNote': 'Hebrew and Greek texts, lexicon, cross-references, people and places, and commentary. Once downloaded they work offline. Use Wi-Fi if you can.',
  'packsUnavailable': 'Could not get the list of packs. Check your internet connection.',
  'packInstalled': 'Downloaded',
  'packUpdateAvailable': 'Update available',
  'packInstalling': 'Installing…',
  'packErrorOffline': 'Download stopped. Try again to continue where it left off.',
  'packErrorCorrupt': 'The downloaded file was damaged. Try again.',
  'packErrorServer': 'This pack could not be downloaded right now. Try again later.',
  'download': 'Download',
  'update': 'Update',
  'removePackConfirm': 'This pack will be deleted from this phone. You can download it again later.',
  'getStudyPacks': 'Download Hebrew, Greek and study packs',
  'getStudyPacksHint': 'For the full word, cross-reference and commentary material for this verse.',
  'allVersions': 'All versions',
  'compare': 'Compare',
  'recentlyRead': 'Recently read',
  'reminders': 'Reminders and habits',
  'dailyReminder': 'Daily reading reminder',
  'off': 'Off',
  'reminderBody': 'Time for today\'s Bible reading.',
  'notificationsBlocked': 'Notifications are blocked. Allow them in your phone\'s settings.',
  'readingStreak': 'Reading streak',
  'readingStreakHint': 'Show how many days in a row you have read, on Home',
  'streakStart': 'Read today to start a streak.',
  'streakKeepGoing': 'Read today to keep it going.',
  'wifiOnly': 'Download on Wi-Fi only',
  'wifiOnlyHint': 'Study packs and audio won\'t download on mobile data',
  'needWifi': 'Connect to Wi-Fi, or turn off "Download on Wi-Fi only" in Settings.',
  'readAloud': 'Read aloud',
  'stopReading': 'Stop reading',
  'noVoice': 'Your phone has no voice for this language. Install a text-to-speech voice in your phone\'s settings.',
  'tags': 'Tags',
  'tagsHint': 'For example: prayer, family',
  'exportNotes': 'Export notes (Markdown)',
  'notesExportTitle': 'My Bible notes',
  'exportedOn': 'Exported',
  'scriptureFrom': 'Scripture quotations from',
  'grammarMatches': 'Grammar matches',
  'timeline': 'Bible timeline',
  'studyGroups': 'Study groups',
  'groupsSignIn': 'Sign in to use study groups.',
  'noGroups': 'You are not in a group yet. Create one, or join with a code.',
  'createGroup': 'Create group',
  'joinGroup': 'Join with a code',
  'groupName': 'Group name',
  'groupNameHint': 'For example: Youth Bible study',
  'inviteCode': 'Invite code',
  'inviteCodeHint': 'Others join the group with this code.',
  'newInviteCode': 'New code (the old one stops working)',
  'yourName': 'Your name in this group',
  'yourNameHint': 'Your email is never shown.',
  'fillBothFields': 'Fill in both fields.',
  'groupCodeNotFound': 'No group has this code.',
  'groupFull': 'This group is full.',
  'teacher': 'Teacher',
  'member': 'Member',
  'members': 'Members',
  'discussion': 'Discussion',
  'assignments': 'Assignments',
  'assignment': 'Assignment',
  'readingPlan': 'Reading plan',
  'writeMessage': 'Write a message…',
  'send': 'Send',
  'noMessages': 'No messages yet. Share a thought or a question with the group.',
  'noAssignments': 'No assignments yet.',
  'newAssignment': 'New assignment',
  'assignmentText': 'The assignment',
  'assignmentHint': 'For example: read the chapter and write one prayer',
  'assignmentNeedsText': 'Write the assignment.',
  'passageOptional': 'Passage (optional)',
  'passageNotRecognized': 'This passage was not recognized.',
  'dueDate': 'Due date',
  'noDueDate': 'No due date',
  'postAssignment': 'Post assignment',
  'markDone': 'Mark done',
  'doneLabel': 'Done',
  'noGroupPlan': 'The teacher has not chosen a reading plan yet.',
  'chooseGroupPlan': 'Choose a plan for the group to read together.',
  'choosePlan': 'Choose a plan',
  'changePlan': 'Change plan (progress starts over)',
  'groupProgress': 'Group progress',
  'leaveGroup': 'Leave group',
  'leaveGroupConfirm': 'Leave this group? You will need the code to join again.',
  'manageMember': 'Manage member',
  'makeTeacher': 'Make teacher',
  'makeMember': 'Make member',
  'removeFromGroup': 'Remove from group',
  'privacy': 'Privacy',
  'sendErrorReports': 'Send error reports',
  'sendErrorReportsHint': 'When the app breaks, what went wrong is sent. No Bible text, notes or email are included.',
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
  // Search & Study
  'studyTools': 'Study tools',
  'timelineHint': 'Bible history, era by era',
  'peopleAndPlaces': 'People & places',
  'peopleHint': 'Who, where and what happened',
  'wordStudyHint': 'Hebrew and Greek words and what they mean',
  'askAiHint': 'Ask about a passage',
  'trySearching': 'Try searching',
  'searchTips': 'Search tips',
  'tipReference': 'Opens the passage',
  'tipWords': 'Finds verses with every word; the start of a word is enough',
  'tipPhrase': 'Finds the words together, in this order',
  'tipStrongs': "Finds a Hebrew or Greek word by its Strong's number",
  'tipGrammar': 'Finds verses by grammatical form',
  'filter': 'Filter',
  'testament': 'Testament',
  'book': 'Book',
  'allBooks': 'All books',
  'removeFilter': 'Remove filter',
  'verses': 'Verses',
  'dictionary': 'Dictionary',
  'whichPassage': 'Which passage?',
  'passageHint': 'For example ዮሐ 3፥16 or Jn 3:16',
  'notAReference': "That doesn't look like a Bible reference",
  'peopleSearchHint': 'Search a name',
  'mostMentioned': 'Most mentioned',
  'people': 'People',
  'places': 'Places',
  'events': 'Events',
  'wordsSearchHint': "A word, a meaning or a Strong's number (G26)",
  'greekWords': 'Greek (New Testament)',
  'hebrewWords': 'Hebrew (Old Testament)',
  // Plans
  'markAsUnread': 'Mark as unread',
  'seeAllPlans': 'See all plans',
  'dayComplete': 'Done',
  // Study screens
  'myNotes': 'My notes',
  'addNote': 'Write a note',
  'noNotesHere': "You haven't written a note on this verse yet.",
  'aiWritten': 'AI-written',
  'aiWriting': 'Writing an answer…',
  'aiStartWith': 'Start with',
  'aiOptions': 'Answer options',
  'aiLevel': 'Level',
  // Settings, groups, share image
  'languageAndRegion': 'Language and region',
  'reading': 'Reading',
  'audioAndDownloads': 'Audio and downloads',
  'remindMe': 'Remind me',
  'turnOff': 'Turn off',
  'invite': 'Invite',
  'cardStyle': 'Style',
  'textSmaller': 'Smaller text',
  'textDefault': 'Default text size',
  'textLarger': 'Larger text',
  'showVersion': 'Show the version',
  'ornamentFrame': 'Ornament frame',
  // Plans: catching up, calendar, completion
  'adjustSchedule': 'Adjust the schedule',
  'catchUpTitle': 'Behind? Adjust the schedule',
  'pickUp': 'Pick up where you left off',
  'markMissedHint': 'If you read them elsewhere',
  'scheduleAdjusted': 'Schedule adjusted',
  'planCalendar': 'All days',
  'planComplete': 'Plan complete',
  'chooseAnotherPlan': 'Choose another plan',
  'installApp': 'Install the app',
  'installAppHint': 'Open it from your home screen or desktop; it works offline too.',
  'showOnMap': 'Show on a map',
  'mapOpenFailed': "Couldn't open the map",
  'era.beginnings': 'Beginnings',
  'era.patriarchs': 'The patriarchs',
  'era.exodus': 'Exodus and wilderness',
  'era.judges': 'Conquest and judges',
  'era.kingdom': 'The kingdom',
  'era.exile': 'Exile',
  'era.returnHome': 'Return from exile',
  'era.between': 'Between the Testaments',
  'era.jesus': 'The life of Jesus',
  'era.church': 'The early church',
};
