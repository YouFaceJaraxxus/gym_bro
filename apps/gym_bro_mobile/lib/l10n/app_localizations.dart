import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sr'),
    Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Gym Bro'**
  String get appTitle;

  /// No description provided for @archiveDayLabel.
  ///
  /// In en, this message translates to:
  /// **'{day}, {count, plural, =0{nothing} =1{1 item} other{{count} items}}'**
  String archiveDayLabel(String day, int count);

  /// No description provided for @archiveLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your archive'**
  String get archiveLoadFailed;

  /// No description provided for @archiveNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get archiveNextMonth;

  /// No description provided for @archiveNoPosts.
  ///
  /// In en, this message translates to:
  /// **'No archived posts from {month}'**
  String archiveNoPosts(String month);

  /// No description provided for @archiveNoStories.
  ///
  /// In en, this message translates to:
  /// **'No stories in {month}'**
  String archiveNoStories(String month);

  /// No description provided for @archiveNothingOnDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing on {day}'**
  String archiveNothingOnDay(String day);

  /// No description provided for @archiveOnlyYou.
  ///
  /// In en, this message translates to:
  /// **'Only you can see your archive.'**
  String get archiveOnlyYou;

  /// No description provided for @archivePostAction.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archivePostAction;

  /// No description provided for @archivePostArchived.
  ///
  /// In en, this message translates to:
  /// **'Post archived. Only you can see it now.'**
  String get archivePostArchived;

  /// No description provided for @archivePostBanner.
  ///
  /// In en, this message translates to:
  /// **'Archived — only you can see this post'**
  String get archivePostBanner;

  /// No description provided for @archivePostRestored.
  ///
  /// In en, this message translates to:
  /// **'Your post is back on your profile'**
  String get archivePostRestored;

  /// No description provided for @archivePostUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Show on profile'**
  String get archivePostUnarchive;

  /// No description provided for @archivePostsHint.
  ///
  /// In en, this message translates to:
  /// **'Archived posts are hidden from your profile and feed until you show them again.'**
  String get archivePostsHint;

  /// No description provided for @archivePrevMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get archivePrevMonth;

  /// No description provided for @archiveStoriesHint.
  ///
  /// In en, this message translates to:
  /// **'Stories stay here after their 24 hours.'**
  String get archiveStoriesHint;

  /// No description provided for @archiveStoryLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get archiveStoryLive;

  /// No description provided for @archiveStoryShared.
  ///
  /// In en, this message translates to:
  /// **'Shared in a story'**
  String get archiveStoryShared;

  /// No description provided for @archiveStoryText.
  ///
  /// In en, this message translates to:
  /// **'Text story'**
  String get archiveStoryText;

  /// No description provided for @archiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your stories and archived posts'**
  String get archiveSubtitle;

  /// No description provided for @archiveTabPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get archiveTabPosts;

  /// No description provided for @archiveTabStories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get archiveTabStories;

  /// No description provided for @archiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveTitle;

  /// No description provided for @archiveViewCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get archiveViewCalendar;

  /// No description provided for @archiveViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get archiveViewList;

  /// No description provided for @archiveWholeMonth.
  ///
  /// In en, this message translates to:
  /// **'All of {month}'**
  String archiveWholeMonth(String month);

  /// No description provided for @businessCheckInAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get businessCheckInAllTime;

  /// No description provided for @businessCheckInAttendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get businessCheckInAttendanceTitle;

  /// No description provided for @businessCheckInBusiestHours.
  ///
  /// In en, this message translates to:
  /// **'Busiest hours'**
  String get businessCheckInBusiestHours;

  /// No description provided for @businessCheckInByStaff.
  ///
  /// In en, this message translates to:
  /// **'by staff'**
  String get businessCheckInByStaff;

  /// No description provided for @businessCheckInCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get businessCheckInCameraDenied;

  /// No description provided for @businessCheckInCameraDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access for Gym Bro in your device settings to scan member codes. You can still check members in by name.'**
  String get businessCheckInCameraDeniedMessage;

  /// No description provided for @businessCheckInCameraStartFailed.
  ///
  /// In en, this message translates to:
  /// **'The camera couldn\'t start ({code}).'**
  String businessCheckInCameraStartFailed(String code);

  /// No description provided for @businessCheckInCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get businessCheckInCameraUnavailable;

  /// No description provided for @businessCheckInCameraUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'This device can\'t scan codes. Check members in by name instead.'**
  String get businessCheckInCameraUnsupportedMessage;

  /// No description provided for @businessCheckInCheckInAction.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get businessCheckInCheckInAction;

  /// No description provided for @businessCheckInCheckIns.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get businessCheckInCheckIns;

  /// No description provided for @businessCheckInCheckedInAt.
  ///
  /// In en, this message translates to:
  /// **'Checked in at {time}'**
  String businessCheckInCheckedInAt(String time);

  /// No description provided for @businessCheckInCheckingIn.
  ///
  /// In en, this message translates to:
  /// **'Checking in…'**
  String get businessCheckInCheckingIn;

  /// No description provided for @businessCheckInClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get businessCheckInClearSearch;

  /// No description provided for @businessCheckInCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 check-in} other{{count} check-ins}}'**
  String businessCheckInCount(int count);

  /// No description provided for @businessCheckInDailyChartSemantics.
  ///
  /// In en, this message translates to:
  /// **'Check-ins per day chart, last {days} days: {total} in total, {average} per day on average.'**
  String businessCheckInDailyChartSemantics(
    int days,
    int total,
    String average,
  );

  /// No description provided for @businessCheckInDismissHint.
  ///
  /// In en, this message translates to:
  /// **'dismiss'**
  String get businessCheckInDismissHint;

  /// No description provided for @businessCheckInGymFallback.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get businessCheckInGymFallback;

  /// No description provided for @businessCheckInHourlyChartSemantics.
  ///
  /// In en, this message translates to:
  /// **'Check-ins by hour chart. Busiest: {hours}.'**
  String businessCheckInHourlyChartSemantics(String hours);

  /// No description provided for @businessCheckInLastDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Last day} other{Last {days} days}}'**
  String businessCheckInLastDays(int days);

  /// No description provided for @businessCheckInLastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit {when}'**
  String businessCheckInLastVisit(String when);

  /// No description provided for @businessCheckInManual.
  ///
  /// In en, this message translates to:
  /// **'Manual check-in'**
  String get businessCheckInManual;

  /// No description provided for @businessCheckInManualShort.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get businessCheckInManualShort;

  /// No description provided for @businessCheckInMemberFallback.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get businessCheckInMemberFallback;

  /// No description provided for @businessCheckInMembersInDays.
  ///
  /// In en, this message translates to:
  /// **'Members ({days}d)'**
  String businessCheckInMembersInDays(int days);

  /// No description provided for @businessCheckInMembershipEnded.
  ///
  /// In en, this message translates to:
  /// **'{type} · ended {date}'**
  String businessCheckInMembershipEnded(String type, String date);

  /// No description provided for @businessCheckInMembershipValidUntil.
  ///
  /// In en, this message translates to:
  /// **'{type} · valid until {date}'**
  String businessCheckInMembershipValidUntil(String type, String date);

  /// No description provided for @businessCheckInNewCodeIn.
  ///
  /// In en, this message translates to:
  /// **'New code in {time}'**
  String businessCheckInNewCodeIn(String time);

  /// No description provided for @businessCheckInNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get businessCheckInNextDay;

  /// No description provided for @businessCheckInNoCheckInsInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No check-ins in this period yet.'**
  String get businessCheckInNoCheckInsInPeriod;

  /// No description provided for @businessCheckInNoGymMessage.
  ///
  /// In en, this message translates to:
  /// **'Once a gym adds you as a member, your check-in code shows up here.'**
  String get businessCheckInNoGymMessage;

  /// No description provided for @businessCheckInNoGymTitle.
  ///
  /// In en, this message translates to:
  /// **'No gym to check in to'**
  String get businessCheckInNoGymTitle;

  /// No description provided for @businessCheckInNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching members'**
  String get businessCheckInNoMatches;

  /// No description provided for @businessCheckInNoMatchesMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different name or email.'**
  String get businessCheckInNoMatchesMessage;

  /// No description provided for @businessCheckInNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No members yet'**
  String get businessCheckInNoMembers;

  /// No description provided for @businessCheckInNoMembersMessage.
  ///
  /// In en, this message translates to:
  /// **'Members added to this gym show up here.'**
  String get businessCheckInNoMembersMessage;

  /// No description provided for @businessCheckInNoMembershipOnFile.
  ///
  /// In en, this message translates to:
  /// **'No membership on file'**
  String get businessCheckInNoMembershipOnFile;

  /// No description provided for @businessCheckInNoVisitsInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No visits in this period.'**
  String get businessCheckInNoVisitsInPeriod;

  /// No description provided for @businessCheckInNoVisitsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your check-ins will be listed here.'**
  String get businessCheckInNoVisitsMessage;

  /// No description provided for @businessCheckInNoVisitsTitle.
  ///
  /// In en, this message translates to:
  /// **'No visits yet'**
  String get businessCheckInNoVisitsTitle;

  /// No description provided for @businessCheckInNoneOnDay.
  ///
  /// In en, this message translates to:
  /// **'No check-ins on this day'**
  String get businessCheckInNoneOnDay;

  /// No description provided for @businessCheckInNoneToday.
  ///
  /// In en, this message translates to:
  /// **'No check-ins yet today'**
  String get businessCheckInNoneToday;

  /// No description provided for @businessCheckInNotEnoughData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet.'**
  String get businessCheckInNotEnoughData;

  /// No description provided for @businessCheckInOpenScanner.
  ///
  /// In en, this message translates to:
  /// **'Open scanner'**
  String get businessCheckInOpenScanner;

  /// No description provided for @businessCheckInPeak.
  ///
  /// In en, this message translates to:
  /// **'Peak: {hours}'**
  String businessCheckInPeak(String hours);

  /// No description provided for @businessCheckInPickDayHelp.
  ///
  /// In en, this message translates to:
  /// **'Show check-ins for'**
  String get businessCheckInPickDayHelp;

  /// No description provided for @businessCheckInPointCamera.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a member\'s code'**
  String get businessCheckInPointCamera;

  /// No description provided for @businessCheckInPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get businessCheckInPreviousDay;

  /// No description provided for @businessCheckInQrNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'QR check-in isn\'t set up on this server yet. Ask the front desk to check you in by name.'**
  String get businessCheckInQrNotConfigured;

  /// No description provided for @businessCheckInQrScan.
  ///
  /// In en, this message translates to:
  /// **'QR scan'**
  String get businessCheckInQrScan;

  /// No description provided for @businessCheckInQrSemantics.
  ///
  /// In en, this message translates to:
  /// **'Check-in QR code for {gym}'**
  String businessCheckInQrSemantics(String gym);

  /// No description provided for @businessCheckInRecentVisits.
  ///
  /// In en, this message translates to:
  /// **'Recent visits'**
  String get businessCheckInRecentVisits;

  /// No description provided for @businessCheckInRefreshCode.
  ///
  /// In en, this message translates to:
  /// **'Refresh code'**
  String get businessCheckInRefreshCode;

  /// No description provided for @businessCheckInRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh: {error}'**
  String businessCheckInRefreshFailed(String error);

  /// No description provided for @businessCheckInRefreshingCode.
  ///
  /// In en, this message translates to:
  /// **'Refreshing code…'**
  String get businessCheckInRefreshingCode;

  /// No description provided for @businessCheckInResultCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get businessCheckInResultCheckedIn;

  /// No description provided for @businessCheckInResultDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Already checked in'**
  String get businessCheckInResultDuplicate;

  /// No description provided for @businessCheckInResultFailed.
  ///
  /// In en, this message translates to:
  /// **'Check-in failed'**
  String get businessCheckInResultFailed;

  /// No description provided for @businessCheckInResultNoMembership.
  ///
  /// In en, this message translates to:
  /// **'No active membership'**
  String get businessCheckInResultNoMembership;

  /// No description provided for @businessCheckInScanHint.
  ///
  /// In en, this message translates to:
  /// **'Scan a member\'s code to check them in.'**
  String get businessCheckInScanHint;

  /// No description provided for @businessCheckInScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan check-in'**
  String get businessCheckInScanTitle;

  /// No description provided for @businessCheckInScanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan check-ins'**
  String get businessCheckInScanTooltip;

  /// No description provided for @businessCheckInSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search members by name or email'**
  String get businessCheckInSearchHint;

  /// No description provided for @businessCheckInSessionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 checked in this session} other{{count} checked in this session}}'**
  String businessCheckInSessionCount(int count);

  /// No description provided for @businessCheckInShowAtDesk.
  ///
  /// In en, this message translates to:
  /// **'Show this code at the front desk'**
  String get businessCheckInShowAtDesk;

  /// No description provided for @businessCheckInShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get businessCheckInShowMore;

  /// No description provided for @businessCheckInStaffNotice.
  ///
  /// In en, this message translates to:
  /// **'You are staff here, not a member. This code is for testing the scanner.'**
  String get businessCheckInStaffNotice;

  /// No description provided for @businessCheckInThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get businessCheckInThisWeek;

  /// No description provided for @businessCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get businessCheckInTitle;

  /// No description provided for @businessCheckInTopMembers.
  ///
  /// In en, this message translates to:
  /// **'Top members'**
  String get businessCheckInTopMembers;

  /// No description provided for @businessCheckInTorchOff.
  ///
  /// In en, this message translates to:
  /// **'Turn flashlight off'**
  String get businessCheckInTorchOff;

  /// No description provided for @businessCheckInTorchOn.
  ///
  /// In en, this message translates to:
  /// **'Turn flashlight on'**
  String get businessCheckInTorchOn;

  /// No description provided for @businessCheckInTotalPerDay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 check-in} other{{count} check-ins}} · {average} per day'**
  String businessCheckInTotalPerDay(int count, String average);

  /// No description provided for @businessCheckInVisitsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Visits this month'**
  String get businessCheckInVisitsThisMonth;

  /// No description provided for @businessCheckInVisitsUnit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{visit} other{visits}}'**
  String businessCheckInVisitsUnit(int count);

  /// No description provided for @businessCheckInYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get businessCheckInYesterday;

  /// No description provided for @businessGymAddEmployee.
  ///
  /// In en, this message translates to:
  /// **'Add employee'**
  String get businessGymAddEmployee;

  /// No description provided for @businessGymAddExistingUser.
  ///
  /// In en, this message translates to:
  /// **'Add existing user'**
  String get businessGymAddExistingUser;

  /// No description provided for @businessGymAddExistingUserHint.
  ///
  /// In en, this message translates to:
  /// **'Search users already in the system'**
  String get businessGymAddExistingUserHint;

  /// No description provided for @businessGymAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get businessGymAddMember;

  /// No description provided for @businessGymAllGyms.
  ///
  /// In en, this message translates to:
  /// **'All gyms'**
  String get businessGymAllGyms;

  /// No description provided for @businessGymAllMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'All members'**
  String get businessGymAllMembersTitle;

  /// No description provided for @businessGymAllStaffTitle.
  ///
  /// In en, this message translates to:
  /// **'All staff'**
  String get businessGymAllStaffTitle;

  /// No description provided for @businessGymAlreadyEmployee.
  ///
  /// In en, this message translates to:
  /// **'Already an employee at this gym'**
  String get businessGymAlreadyEmployee;

  /// No description provided for @businessGymAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'Already a member'**
  String get businessGymAlreadyMember;

  /// No description provided for @businessGymAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get businessGymAssign;

  /// No description provided for @businessGymAssignMembership.
  ///
  /// In en, this message translates to:
  /// **'Assign membership'**
  String get businessGymAssignMembership;

  /// No description provided for @businessGymCancelMembership.
  ///
  /// In en, this message translates to:
  /// **'Cancel membership'**
  String get businessGymCancelMembership;

  /// No description provided for @businessGymCancelMembershipMessage.
  ///
  /// In en, this message translates to:
  /// **'{member}\'s {type} membership will be marked inactive. Billing history is kept.'**
  String businessGymCancelMembershipMessage(String member, String type);

  /// No description provided for @businessGymCancelMembershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel membership?'**
  String get businessGymCancelMembershipTitle;

  /// No description provided for @businessGymChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get businessGymChange;

  /// No description provided for @businessGymChangeRoleMessage.
  ///
  /// In en, this message translates to:
  /// **'Change {name}\'s role to {role} at {gym}?'**
  String businessGymChangeRoleMessage(String name, String role, String gym);

  /// No description provided for @businessGymChangeRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Change role?'**
  String get businessGymChangeRoleTitle;

  /// No description provided for @businessGymClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get businessGymClearSearch;

  /// No description provided for @businessGymDeleteMembershipMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the {type} membership and its invoices. Use Cancel instead to keep the history.'**
  String businessGymDeleteMembershipMessage(String type);

  /// No description provided for @businessGymDeleteMembershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete membership?'**
  String get businessGymDeleteMembershipTitle;

  /// No description provided for @businessGymDetailAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get businessGymDetailAttendance;

  /// No description provided for @businessGymDetailInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get businessGymDetailInvoices;

  /// No description provided for @businessGymDetailManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get businessGymDetailManage;

  /// No description provided for @businessGymDetailManageMembers.
  ///
  /// In en, this message translates to:
  /// **'Manage members'**
  String get businessGymDetailManageMembers;

  /// No description provided for @businessGymDetailManageMembershipTypes.
  ///
  /// In en, this message translates to:
  /// **'Manage membership types'**
  String get businessGymDetailManageMembershipTypes;

  /// No description provided for @businessGymDetailManageStaff.
  ///
  /// In en, this message translates to:
  /// **'Manage staff'**
  String get businessGymDetailManageStaff;

  /// No description provided for @businessGymDetailMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get businessGymDetailMembers;

  /// No description provided for @businessGymDetailMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String businessGymDetailMembersCount(int count);

  /// No description provided for @businessGymDetailMembershipTypes.
  ///
  /// In en, this message translates to:
  /// **'Membership types'**
  String get businessGymDetailMembershipTypes;

  /// No description provided for @businessGymDetailMembershipTypesHint.
  ///
  /// In en, this message translates to:
  /// **'Set up pricing plans members can be enrolled in.'**
  String get businessGymDetailMembershipTypesHint;

  /// No description provided for @businessGymDetailMore.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more'**
  String businessGymDetailMore(int count);

  /// No description provided for @businessGymDetailPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get businessGymDetailPosts;

  /// No description provided for @businessGymDetailScanCheckIns.
  ///
  /// In en, this message translates to:
  /// **'Scan check-ins'**
  String get businessGymDetailScanCheckIns;

  /// No description provided for @businessGymDetailSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get businessGymDetailSchedule;

  /// No description provided for @businessGymDetailStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get businessGymDetailStaff;

  /// No description provided for @businessGymDetailStaffCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 staff member} other{{count} staff members}}'**
  String businessGymDetailStaffCount(int count);

  /// No description provided for @businessGymDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get businessGymDuration;

  /// No description provided for @businessGymEditEmployee.
  ///
  /// In en, this message translates to:
  /// **'Edit employee'**
  String get businessGymEditEmployee;

  /// No description provided for @businessGymEditMember.
  ///
  /// In en, this message translates to:
  /// **'Edit member'**
  String get businessGymEditMember;

  /// No description provided for @businessGymEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get businessGymEmail;

  /// No description provided for @businessGymEmailAlreadyEmployed.
  ///
  /// In en, this message translates to:
  /// **'This email is already employed at this gym'**
  String get businessGymEmailAlreadyEmployed;

  /// No description provided for @businessGymEmployeeActions.
  ///
  /// In en, this message translates to:
  /// **'Employee actions'**
  String get businessGymEmployeeActions;

  /// No description provided for @businessGymExtend.
  ///
  /// In en, this message translates to:
  /// **'Extend'**
  String get businessGymExtend;

  /// No description provided for @businessGymExtendMembership.
  ///
  /// In en, this message translates to:
  /// **'Extend membership'**
  String get businessGymExtendMembership;

  /// No description provided for @businessGymExtendedUntil.
  ///
  /// In en, this message translates to:
  /// **'Extended until {date}'**
  String businessGymExtendedUntil(String date);

  /// No description provided for @businessGymFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get businessGymFilterAll;

  /// No description provided for @businessGymFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get businessGymFirstName;

  /// No description provided for @businessGymFormAddLogo.
  ///
  /// In en, this message translates to:
  /// **'Add logo'**
  String get businessGymFormAddLogo;

  /// No description provided for @businessGymFormCreate.
  ///
  /// In en, this message translates to:
  /// **'Create business'**
  String get businessGymFormCreate;

  /// No description provided for @businessGymFormDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete business'**
  String get businessGymFormDelete;

  /// No description provided for @businessGymFormDeleteGymAction.
  ///
  /// In en, this message translates to:
  /// **'Delete gym'**
  String get businessGymFormDeleteGymAction;

  /// No description provided for @businessGymFormDeleteGymMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the gym with all its members, staff, membership types, memberships, invoices and posts.'**
  String get businessGymFormDeleteGymMessage;

  /// No description provided for @businessGymFormDeleteShopAction.
  ///
  /// In en, this message translates to:
  /// **'Delete shop'**
  String get businessGymFormDeleteShopAction;

  /// No description provided for @businessGymFormDeleteShopMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the shop with all its items, vendors and posts.'**
  String get businessGymFormDeleteShopMessage;

  /// No description provided for @businessGymFormDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String businessGymFormDeleteTitle(String name);

  /// No description provided for @businessGymFormDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String businessGymFormDeleted(String name);

  /// No description provided for @businessGymFormFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get businessGymFormFrom;

  /// No description provided for @businessGymFormLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get businessGymFormLocation;

  /// No description provided for @businessGymFormName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get businessGymFormName;

  /// No description provided for @businessGymFormSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get businessGymFormSaveChanges;

  /// No description provided for @businessGymFormSelectWorkingDay.
  ///
  /// In en, this message translates to:
  /// **'Select at least one working day'**
  String get businessGymFormSelectWorkingDay;

  /// No description provided for @businessGymFormTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit business'**
  String get businessGymFormTitleEdit;

  /// No description provided for @businessGymFormTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New business'**
  String get businessGymFormTitleNew;

  /// No description provided for @businessGymFormTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get businessGymFormTo;

  /// No description provided for @businessGymFormType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get businessGymFormType;

  /// No description provided for @businessGymFormTypeGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get businessGymFormTypeGym;

  /// No description provided for @businessGymFormTypeShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get businessGymFormTypeShop;

  /// No description provided for @businessGymFormWorkingDays.
  ///
  /// In en, this message translates to:
  /// **'Working days'**
  String get businessGymFormWorkingDays;

  /// No description provided for @businessGymFormWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get businessGymFormWorkingHours;

  /// No description provided for @businessGymGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get businessGymGym;

  /// No description provided for @businessGymInviteAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Invite & add'**
  String get businessGymInviteAndAdd;

  /// No description provided for @businessGymInviteMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite member'**
  String get businessGymInviteMemberTitle;

  /// No description provided for @businessGymInviteNewMember.
  ///
  /// In en, this message translates to:
  /// **'Invite new member'**
  String get businessGymInviteNewMember;

  /// No description provided for @businessGymInviteNewMemberHint.
  ///
  /// In en, this message translates to:
  /// **'Send an invite link by email'**
  String get businessGymInviteNewMemberHint;

  /// No description provided for @businessGymInviteNewUserPrompt.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find them? Invite a new user'**
  String get businessGymInviteNewUserPrompt;

  /// No description provided for @businessGymInviteResent.
  ///
  /// In en, this message translates to:
  /// **'Invite resent'**
  String get businessGymInviteResent;

  /// No description provided for @businessGymInviteResentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Invite resent successfully'**
  String get businessGymInviteResentSuccess;

  /// No description provided for @businessGymKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get businessGymKeep;

  /// No description provided for @businessGymLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get businessGymLastName;

  /// No description provided for @businessGymMemberActions.
  ///
  /// In en, this message translates to:
  /// **'Member actions'**
  String get businessGymMemberActions;

  /// No description provided for @businessGymMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'{gym} — Members'**
  String businessGymMembersTitle(String gym);

  /// No description provided for @businessGymMembershipActions.
  ///
  /// In en, this message translates to:
  /// **'Membership actions'**
  String get businessGymMembershipActions;

  /// No description provided for @businessGymMembershipAssigned.
  ///
  /// In en, this message translates to:
  /// **'Membership assigned'**
  String get businessGymMembershipAssigned;

  /// No description provided for @businessGymMembershipFallback.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get businessGymMembershipFallback;

  /// No description provided for @businessGymMembershipType.
  ///
  /// In en, this message translates to:
  /// **'Membership type'**
  String get businessGymMembershipType;

  /// No description provided for @businessGymMembershipTypeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Membership type not found for this gym'**
  String get businessGymMembershipTypeNotFound;

  /// No description provided for @businessGymMemberships.
  ///
  /// In en, this message translates to:
  /// **'Memberships'**
  String get businessGymMemberships;

  /// No description provided for @businessGymMonths.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{1 month} other{{months} months}}'**
  String businessGymMonths(int months);

  /// No description provided for @businessGymNoMembersFound.
  ///
  /// In en, this message translates to:
  /// **'No members found'**
  String get businessGymNoMembersFound;

  /// No description provided for @businessGymNoMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No members yet'**
  String get businessGymNoMembersYet;

  /// No description provided for @businessGymNoMembershipAt.
  ///
  /// In en, this message translates to:
  /// **'No membership at {gym}'**
  String businessGymNoMembershipAt(String gym);

  /// No description provided for @businessGymNoMembershipTypes.
  ///
  /// In en, this message translates to:
  /// **'This gym has no membership types yet — add one first.'**
  String get businessGymNoMembershipTypes;

  /// No description provided for @businessGymNoStaffFound.
  ///
  /// In en, this message translates to:
  /// **'No staff found'**
  String get businessGymNoStaffFound;

  /// No description provided for @businessGymNoStaffYet.
  ///
  /// In en, this message translates to:
  /// **'No staff yet'**
  String get businessGymNoStaffYet;

  /// No description provided for @businessGymPlusMonths.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{+1 month} other{+{months} months}}'**
  String businessGymPlusMonths(int months);

  /// No description provided for @businessGymRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get businessGymRemove;

  /// No description provided for @businessGymRemoveFromGym.
  ///
  /// In en, this message translates to:
  /// **'Remove from gym'**
  String get businessGymRemoveFromGym;

  /// No description provided for @businessGymRemoveFromGymMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove {name} from {gym}.'**
  String businessGymRemoveFromGymMessage(String name, String gym);

  /// No description provided for @businessGymRemoveMemberMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove the member from this gym.'**
  String get businessGymRemoveMemberMessage;

  /// No description provided for @businessGymRemoveMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove member?'**
  String get businessGymRemoveMemberTitle;

  /// No description provided for @businessGymRemoveStaffMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove them from this gym.'**
  String get businessGymRemoveStaffMessage;

  /// No description provided for @businessGymRemoveStaffTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove staff member?'**
  String get businessGymRemoveStaffTitle;

  /// No description provided for @businessGymResendInvite.
  ///
  /// In en, this message translates to:
  /// **'Resend invite'**
  String get businessGymResendInvite;

  /// No description provided for @businessGymRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get businessGymRole;

  /// No description provided for @businessGymRoleChangedTo.
  ///
  /// In en, this message translates to:
  /// **'Role changed to {role}'**
  String businessGymRoleChangedTo(String role);

  /// No description provided for @businessGymRoleEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get businessGymRoleEmployee;

  /// No description provided for @businessGymRoleEmployeeTrainer.
  ///
  /// In en, this message translates to:
  /// **'Employee trainer'**
  String get businessGymRoleEmployeeTrainer;

  /// No description provided for @businessGymRoleEmployeeTrainerShort.
  ///
  /// In en, this message translates to:
  /// **'Emp. trainer'**
  String get businessGymRoleEmployeeTrainerShort;

  /// No description provided for @businessGymRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get businessGymRoleMember;

  /// No description provided for @businessGymRoleVendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get businessGymRoleVendor;

  /// No description provided for @businessGymSearchMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Search members…'**
  String get businessGymSearchMembersHint;

  /// No description provided for @businessGymSearchStaffHint.
  ///
  /// In en, this message translates to:
  /// **'Search staff…'**
  String get businessGymSearchStaffHint;

  /// No description provided for @businessGymSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get businessGymSendInvite;

  /// No description provided for @businessGymStaffTitle.
  ///
  /// In en, this message translates to:
  /// **'{gym} — Staff'**
  String businessGymStaffTitle(String gym);

  /// No description provided for @businessGymStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get businessGymStatusActive;

  /// No description provided for @businessGymStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get businessGymStatusCancelled;

  /// No description provided for @businessGymStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get businessGymStatusExpired;

  /// No description provided for @businessGymTypePerMonth.
  ///
  /// In en, this message translates to:
  /// **'{name} ({price}/mo)'**
  String businessGymTypePerMonth(String name, String price);

  /// No description provided for @businessGymUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get businessGymUsername;

  /// No description provided for @businessGymViewProgress.
  ///
  /// In en, this message translates to:
  /// **'View progress'**
  String get businessGymViewProgress;

  /// No description provided for @businessInvoiceStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get businessInvoiceStatusPaid;

  /// No description provided for @businessInvoiceStatusUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get businessInvoiceStatusUnpaid;

  /// No description provided for @businessInvoiceStatusVoid.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get businessInvoiceStatusVoid;

  /// No description provided for @businessItemTypeEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get businessItemTypeEquipment;

  /// No description provided for @businessItemTypeGiftCard.
  ///
  /// In en, this message translates to:
  /// **'Gift card'**
  String get businessItemTypeGiftCard;

  /// No description provided for @businessItemTypeSupplement.
  ///
  /// In en, this message translates to:
  /// **'Supplement'**
  String get businessItemTypeSupplement;

  /// No description provided for @businessMgmtActiveMembership.
  ///
  /// In en, this message translates to:
  /// **'Active membership'**
  String get businessMgmtActiveMembership;

  /// No description provided for @businessMgmtActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'Active until'**
  String get businessMgmtActiveUntil;

  /// No description provided for @businessMgmtAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get businessMgmtAddItem;

  /// No description provided for @businessMgmtAddProductPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add product photo'**
  String get businessMgmtAddProductPhoto;

  /// No description provided for @businessMgmtAddType.
  ///
  /// In en, this message translates to:
  /// **'Add type'**
  String get businessMgmtAddType;

  /// No description provided for @businessMgmtAddVendor.
  ///
  /// In en, this message translates to:
  /// **'Add vendor'**
  String get businessMgmtAddVendor;

  /// No description provided for @businessMgmtAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get businessMgmtAll;

  /// No description provided for @businessMgmtAllGyms.
  ///
  /// In en, this message translates to:
  /// **'All gyms'**
  String get businessMgmtAllGyms;

  /// No description provided for @businessMgmtAlreadyVendor.
  ///
  /// In en, this message translates to:
  /// **'Already a vendor for this shop'**
  String get businessMgmtAlreadyVendor;

  /// No description provided for @businessMgmtAutoRenewOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew on'**
  String get businessMgmtAutoRenewOn;

  /// No description provided for @businessMgmtAutoRenewTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew turned off'**
  String get businessMgmtAutoRenewTurnedOff;

  /// No description provided for @businessMgmtBillingHistory.
  ///
  /// In en, this message translates to:
  /// **'Billing history'**
  String get businessMgmtBillingHistory;

  /// No description provided for @businessMgmtBuyMembership.
  ///
  /// In en, this message translates to:
  /// **'Buy a membership'**
  String get businessMgmtBuyMembership;

  /// No description provided for @businessMgmtClearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get businessMgmtClearDate;

  /// No description provided for @businessMgmtDeleteItemMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove “{name}” from this shop?'**
  String businessMgmtDeleteItemMessage(String name);

  /// No description provided for @businessMgmtDeleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete item?'**
  String get businessMgmtDeleteItemTitle;

  /// No description provided for @businessMgmtDeleteMembershipTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete “{name}”. Existing memberships referencing it will be kept.'**
  String businessMgmtDeleteMembershipTypeMessage(String name);

  /// No description provided for @businessMgmtDeleteMembershipTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete membership type?'**
  String get businessMgmtDeleteMembershipTypeTitle;

  /// No description provided for @businessMgmtDeleteNamed.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String businessMgmtDeleteNamed(String name);

  /// No description provided for @businessMgmtDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get businessMgmtDescriptionOptional;

  /// No description provided for @businessMgmtEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get businessMgmtEditItem;

  /// No description provided for @businessMgmtEditMembershipType.
  ///
  /// In en, this message translates to:
  /// **'Edit membership type'**
  String get businessMgmtEditMembershipType;

  /// No description provided for @businessMgmtEditNamed.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String businessMgmtEditNamed(String name);

  /// No description provided for @businessMgmtEditVendor.
  ///
  /// In en, this message translates to:
  /// **'Edit vendor'**
  String get businessMgmtEditVendor;

  /// No description provided for @businessMgmtEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get businessMgmtEmail;

  /// No description provided for @businessMgmtEmailAlreadyVendor.
  ///
  /// In en, this message translates to:
  /// **'This email is already a vendor for this shop'**
  String get businessMgmtEmailAlreadyVendor;

  /// No description provided for @businessMgmtExtendOrBuy.
  ///
  /// In en, this message translates to:
  /// **'Extend or buy a membership'**
  String get businessMgmtExtendOrBuy;

  /// No description provided for @businessMgmtFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get businessMgmtFirstName;

  /// No description provided for @businessMgmtGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get businessMgmtGym;

  /// No description provided for @businessMgmtGymInvoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'{gymName} — Invoices'**
  String businessMgmtGymInvoicesTitle(String gymName);

  /// No description provided for @businessMgmtInStock.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get businessMgmtInStock;

  /// No description provided for @businessMgmtInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get businessMgmtInvalidNumber;

  /// No description provided for @businessMgmtInviteAndAddVendor.
  ///
  /// In en, this message translates to:
  /// **'Invite & add vendor'**
  String get businessMgmtInviteAndAddVendor;

  /// No description provided for @businessMgmtInviteNewUser.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find them? Invite a new user'**
  String get businessMgmtInviteNewUser;

  /// No description provided for @businessMgmtInviteResent.
  ///
  /// In en, this message translates to:
  /// **'Invite resent'**
  String get businessMgmtInviteResent;

  /// No description provided for @businessMgmtInviteResentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Invite resent successfully'**
  String get businessMgmtInviteResentSuccess;

  /// No description provided for @businessMgmtInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get businessMgmtInvoice;

  /// No description provided for @businessMgmtInvoiceMarkedPaid.
  ///
  /// In en, this message translates to:
  /// **'Invoice marked paid'**
  String get businessMgmtInvoiceMarkedPaid;

  /// No description provided for @businessMgmtInvoiceMarkedUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Invoice marked unpaid'**
  String get businessMgmtInvoiceMarkedUnpaid;

  /// No description provided for @businessMgmtInvoiceMarkedVoid.
  ///
  /// In en, this message translates to:
  /// **'Invoice marked void'**
  String get businessMgmtInvoiceMarkedVoid;

  /// No description provided for @businessMgmtInvoicePaidThanks.
  ///
  /// In en, this message translates to:
  /// **'Invoice paid. Thank you!'**
  String get businessMgmtInvoicePaidThanks;

  /// No description provided for @businessMgmtInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get businessMgmtInvoices;

  /// No description provided for @businessMgmtIssuedOn.
  ///
  /// In en, this message translates to:
  /// **'Issued {date}'**
  String businessMgmtIssuedOn(String date);

  /// No description provided for @businessMgmtItemActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get businessMgmtItemActive;

  /// No description provided for @businessMgmtItemInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get businessMgmtItemInactive;

  /// No description provided for @businessMgmtItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get businessMgmtItems;

  /// No description provided for @businessMgmtLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get businessMgmtLastName;

  /// No description provided for @businessMgmtManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get businessMgmtManage;

  /// No description provided for @businessMgmtMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark paid'**
  String get businessMgmtMarkPaid;

  /// No description provided for @businessMgmtMarkUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Mark unpaid'**
  String get businessMgmtMarkUnpaid;

  /// No description provided for @businessMgmtMarkVoid.
  ///
  /// In en, this message translates to:
  /// **'Mark void'**
  String get businessMgmtMarkVoid;

  /// No description provided for @businessMgmtMembership.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get businessMgmtMembership;

  /// No description provided for @businessMgmtMembershipExpired.
  ///
  /// In en, this message translates to:
  /// **'Membership expired'**
  String get businessMgmtMembershipExpired;

  /// No description provided for @businessMgmtMembershipHistory.
  ///
  /// In en, this message translates to:
  /// **'Membership history'**
  String get businessMgmtMembershipHistory;

  /// No description provided for @businessMgmtMembershipTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'{gymName} · Membership types'**
  String businessMgmtMembershipTypesTitle(String gymName);

  /// No description provided for @businessMgmtMonthlyCost.
  ///
  /// In en, this message translates to:
  /// **'Monthly cost'**
  String get businessMgmtMonthlyCost;

  /// No description provided for @businessMgmtMoreCount.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more'**
  String businessMgmtMoreCount(int count);

  /// No description provided for @businessMgmtName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get businessMgmtName;

  /// No description provided for @businessMgmtNewItem.
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get businessMgmtNewItem;

  /// No description provided for @businessMgmtNewMembershipType.
  ///
  /// In en, this message translates to:
  /// **'New membership type'**
  String get businessMgmtNewMembershipType;

  /// No description provided for @businessMgmtNoActiveMembership.
  ///
  /// In en, this message translates to:
  /// **'No active membership'**
  String get businessMgmtNoActiveMembership;

  /// No description provided for @businessMgmtNoExpiry.
  ///
  /// In en, this message translates to:
  /// **'No expiry'**
  String get businessMgmtNoExpiry;

  /// No description provided for @businessMgmtNoInvoicesYet.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet'**
  String get businessMgmtNoInvoicesYet;

  /// No description provided for @businessMgmtNoItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get businessMgmtNoItemsYet;

  /// No description provided for @businessMgmtNoMembershipBuyHint.
  ///
  /// In en, this message translates to:
  /// **'Buy a membership in the app, or ask your gym to set one up.'**
  String get businessMgmtNoMembershipBuyHint;

  /// No description provided for @businessMgmtNoMembershipDeskHint.
  ///
  /// In en, this message translates to:
  /// **'Ask your gym to set up your membership plan. Payment happens at the front desk.'**
  String get businessMgmtNoMembershipDeskHint;

  /// No description provided for @businessMgmtNoMembershipTypesYet.
  ///
  /// In en, this message translates to:
  /// **'No membership types yet'**
  String get businessMgmtNoMembershipTypesYet;

  /// No description provided for @businessMgmtNoPaidInvoices.
  ///
  /// In en, this message translates to:
  /// **'No paid invoices'**
  String get businessMgmtNoPaidInvoices;

  /// No description provided for @businessMgmtNoUnpaidInvoices.
  ///
  /// In en, this message translates to:
  /// **'No unpaid invoices'**
  String get businessMgmtNoUnpaidInvoices;

  /// No description provided for @businessMgmtNoVendorsYet.
  ///
  /// In en, this message translates to:
  /// **'No vendors yet'**
  String get businessMgmtNoVendorsYet;

  /// No description provided for @businessMgmtNoVoidInvoices.
  ///
  /// In en, this message translates to:
  /// **'No void invoices'**
  String get businessMgmtNoVoidInvoices;

  /// No description provided for @businessMgmtOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get businessMgmtOrders;

  /// No description provided for @businessMgmtOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customer orders, payments and pickups'**
  String get businessMgmtOrdersSubtitle;

  /// No description provided for @businessMgmtOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get businessMgmtOutOfStock;

  /// No description provided for @businessMgmtPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now · {amount}'**
  String businessMgmtPayNow(String amount);

  /// No description provided for @businessMgmtPaymentsAtDesk.
  ///
  /// In en, this message translates to:
  /// **'Payments for memberships and invoices happen at your gym\'s front desk.'**
  String get businessMgmtPaymentsAtDesk;

  /// No description provided for @businessMgmtPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price}/month'**
  String businessMgmtPerMonth(String price);

  /// No description provided for @businessMgmtPerMonthShort.
  ///
  /// In en, this message translates to:
  /// **'{price}/mo'**
  String businessMgmtPerMonthShort(String price);

  /// No description provided for @businessMgmtPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get businessMgmtPickDate;

  /// No description provided for @businessMgmtPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get businessMgmtPosts;

  /// No description provided for @businessMgmtPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get businessMgmtPrice;

  /// No description provided for @businessMgmtQuantity.
  ///
  /// In en, this message translates to:
  /// **'Qty: {quantity}'**
  String businessMgmtQuantity(int quantity);

  /// No description provided for @businessMgmtRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get businessMgmtRemove;

  /// No description provided for @businessMgmtRemoveFromShop.
  ///
  /// In en, this message translates to:
  /// **'Remove from shop'**
  String get businessMgmtRemoveFromShop;

  /// No description provided for @businessMgmtRemoveVendorFromShopMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove {name} from {shopName}.'**
  String businessMgmtRemoveVendorFromShopMessage(String name, String shopName);

  /// No description provided for @businessMgmtRemoveVendorMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove them from this shop.'**
  String get businessMgmtRemoveVendorMessage;

  /// No description provided for @businessMgmtRemoveVendorTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove vendor?'**
  String get businessMgmtRemoveVendorTitle;

  /// No description provided for @businessMgmtRenewMembership.
  ///
  /// In en, this message translates to:
  /// **'Renew membership'**
  String get businessMgmtRenewMembership;

  /// No description provided for @businessMgmtRenewsMonthly.
  ///
  /// In en, this message translates to:
  /// **'Renews automatically every month'**
  String get businessMgmtRenewsMonthly;

  /// No description provided for @businessMgmtResendInvite.
  ///
  /// In en, this message translates to:
  /// **'Resend invite'**
  String get businessMgmtResendInvite;

  /// No description provided for @businessMgmtSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get businessMgmtSaveChanges;

  /// No description provided for @businessMgmtShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get businessMgmtShop;

  /// No description provided for @businessMgmtShopVendorsTitle.
  ///
  /// In en, this message translates to:
  /// **'{shopName} — Vendors'**
  String businessMgmtShopVendorsTitle(String shopName);

  /// No description provided for @businessMgmtStaffVendors.
  ///
  /// In en, this message translates to:
  /// **'Staff / Vendors'**
  String get businessMgmtStaffVendors;

  /// No description provided for @businessMgmtTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get businessMgmtTurnOff;

  /// No description provided for @businessMgmtTurnOffAutoRenew.
  ///
  /// In en, this message translates to:
  /// **'Turn off auto-renew'**
  String get businessMgmtTurnOffAutoRenew;

  /// No description provided for @businessMgmtTurnOffAutoRenewMessage.
  ///
  /// In en, this message translates to:
  /// **'Your membership stays active until {date} and won\'t be charged again.'**
  String businessMgmtTurnOffAutoRenewMessage(String date);

  /// No description provided for @businessMgmtTurnOffAutoRenewTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off auto-renew?'**
  String get businessMgmtTurnOffAutoRenewTitle;

  /// No description provided for @businessMgmtType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get businessMgmtType;

  /// No description provided for @businessMgmtTypeActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get businessMgmtTypeActive;

  /// No description provided for @businessMgmtTypeInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get businessMgmtTypeInactive;

  /// No description provided for @businessMgmtUnknownMember.
  ///
  /// In en, this message translates to:
  /// **'Unknown member'**
  String get businessMgmtUnknownMember;

  /// No description provided for @businessMgmtUnpaidSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unpaid invoice} other{{count} unpaid invoices}} · {amount} due'**
  String businessMgmtUnpaidSummary(int count, String amount);

  /// No description provided for @businessMgmtUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get businessMgmtUsername;

  /// No description provided for @businessMgmtVendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get businessMgmtVendor;

  /// No description provided for @businessMgmtVendorActions.
  ///
  /// In en, this message translates to:
  /// **'Vendor actions'**
  String get businessMgmtVendorActions;

  /// No description provided for @businessOrderStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get businessOrderStatusCancelled;

  /// No description provided for @businessOrderStatusFulfilled.
  ///
  /// In en, this message translates to:
  /// **'Fulfilled'**
  String get businessOrderStatusFulfilled;

  /// No description provided for @businessOrderStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get businessOrderStatusPaid;

  /// No description provided for @businessOrderStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get businessOrderStatusPending;

  /// No description provided for @businessPaymentMethodCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get businessPaymentMethodCard;

  /// No description provided for @businessPaymentMethodPayAtPickup.
  ///
  /// In en, this message translates to:
  /// **'Pay at pickup'**
  String get businessPaymentMethodPayAtPickup;

  /// No description provided for @businessPaymentStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get businessPaymentStatusCancelled;

  /// No description provided for @businessPaymentStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get businessPaymentStatusFailed;

  /// No description provided for @businessPaymentStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get businessPaymentStatusPaid;

  /// No description provided for @businessPaymentStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get businessPaymentStatusPending;

  /// No description provided for @businessPaymentStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get businessPaymentStatusRefunded;

  /// No description provided for @businessQuantityDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get businessQuantityDecrease;

  /// No description provided for @businessQuantityIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get businessQuantityIncrease;

  /// No description provided for @businessQuantityValue.
  ///
  /// In en, this message translates to:
  /// **'Quantity {value}'**
  String businessQuantityValue(int value);

  /// No description provided for @businessShopAddWithPrice.
  ///
  /// In en, this message translates to:
  /// **'Add · {price}'**
  String businessShopAddWithPrice(String price);

  /// No description provided for @businessShopAddedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added {quantity} × {name} to cart'**
  String businessShopAddedToCart(int quantity, String name);

  /// No description provided for @businessShopAllStockInCart.
  ///
  /// In en, this message translates to:
  /// **'All available stock is in your cart'**
  String get businessShopAllStockInCart;

  /// No description provided for @businessShopAutoRenewExplanation.
  ///
  /// In en, this message translates to:
  /// **'You\'re charged {price} now and every month after. Turn off auto-renew any time from your membership page.'**
  String businessShopAutoRenewExplanation(String price);

  /// No description provided for @businessShopAvailableUntil.
  ///
  /// In en, this message translates to:
  /// **'Available until {date}'**
  String businessShopAvailableUntil(String date);

  /// No description provided for @businessShopAwaitingCardPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting card payment'**
  String get businessShopAwaitingCardPayment;

  /// No description provided for @businessShopAwaitingYourCardPayment.
  ///
  /// In en, this message translates to:
  /// **'This order is waiting for your card payment.'**
  String get businessShopAwaitingYourCardPayment;

  /// No description provided for @businessShopBrowseShops.
  ///
  /// In en, this message translates to:
  /// **'Browse shops'**
  String get businessShopBrowseShops;

  /// No description provided for @businessShopBuyAtFrontDesk.
  ///
  /// In en, this message translates to:
  /// **'Buy or renew your membership at your gym\'s front desk.'**
  String get businessShopBuyAtFrontDesk;

  /// No description provided for @businessShopBuyMembershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Buy a membership'**
  String get businessShopBuyMembershipTitle;

  /// No description provided for @businessShopBuyerPickedUp.
  ///
  /// In en, this message translates to:
  /// **'{name} picked up the order.'**
  String businessShopBuyerPickedUp(String name);

  /// No description provided for @businessShopCancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get businessShopCancelOrder;

  /// No description provided for @businessShopCancelOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get businessShopCancelOrderTitle;

  /// No description provided for @businessShopCardOfAmountWillBeRefunded.
  ///
  /// In en, this message translates to:
  /// **'The card payment of {total} will be refunded.'**
  String businessShopCardOfAmountWillBeRefunded(String total);

  /// No description provided for @businessShopCardPaymentHint.
  ///
  /// In en, this message translates to:
  /// **'You\'ll pay securely with Stripe, then pick up your order.'**
  String get businessShopCardPaymentHint;

  /// No description provided for @businessShopCardUnavailableNow.
  ///
  /// In en, this message translates to:
  /// **'Card payments are unavailable right now. You can pay at pickup.'**
  String get businessShopCardUnavailableNow;

  /// No description provided for @businessShopCardUnavailablePayAtPickup.
  ///
  /// In en, this message translates to:
  /// **'Card payments aren\'t available yet. Pay when you pick up your order.'**
  String get businessShopCardUnavailablePayAtPickup;

  /// No description provided for @businessShopCardWillBeRefunded.
  ///
  /// In en, this message translates to:
  /// **'The card payment will be refunded.'**
  String get businessShopCardWillBeRefunded;

  /// No description provided for @businessShopCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get businessShopCart;

  /// No description provided for @businessShopCartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get businessShopCartEmpty;

  /// No description provided for @businessShopCartEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a product to add it.'**
  String get businessShopCartEmptyHint;

  /// No description provided for @businessShopCartTotal.
  ///
  /// In en, this message translates to:
  /// **'Cart · {price}'**
  String businessShopCartTotal(String price);

  /// No description provided for @businessShopChooseDifferentGym.
  ///
  /// In en, this message translates to:
  /// **'Choose a different gym'**
  String get businessShopChooseDifferentGym;

  /// No description provided for @businessShopClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get businessShopClearSearch;

  /// No description provided for @businessShopConfirmBuyerPaid.
  ///
  /// In en, this message translates to:
  /// **'Confirm {name} paid {total}.'**
  String businessShopConfirmBuyerPaid(String name, String total);

  /// No description provided for @businessShopConfirmCustomerPaid.
  ///
  /// In en, this message translates to:
  /// **'Confirm the customer paid {total}.'**
  String businessShopConfirmCustomerPaid(String total);

  /// No description provided for @businessShopConfirmPaidAtCounter.
  ///
  /// In en, this message translates to:
  /// **'Confirm the customer paid {total} at the counter.'**
  String businessShopConfirmPaidAtCounter(String total);

  /// No description provided for @businessShopConfirmingPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirming your payment…'**
  String get businessShopConfirmingPayment;

  /// No description provided for @businessShopCouldNotOpenPaymentPage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the payment page'**
  String get businessShopCouldNotOpenPaymentPage;

  /// No description provided for @businessShopCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get businessShopCustomer;

  /// No description provided for @businessShopCustomerPickedUp.
  ///
  /// In en, this message translates to:
  /// **'The customer has picked up their order.'**
  String get businessShopCustomerPickedUp;

  /// No description provided for @businessShopCustomerPickedUpOrder.
  ///
  /// In en, this message translates to:
  /// **'The customer picked up the order.'**
  String get businessShopCustomerPickedUpOrder;

  /// No description provided for @businessShopDecreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get businessShopDecreaseQuantity;

  /// No description provided for @businessShopEmptyCart.
  ///
  /// In en, this message translates to:
  /// **'Empty cart'**
  String get businessShopEmptyCart;

  /// No description provided for @businessShopFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get businessShopFilterAll;

  /// No description provided for @businessShopFromPricePerMonth.
  ///
  /// In en, this message translates to:
  /// **'From {price}/month'**
  String businessShopFromPricePerMonth(String price);

  /// No description provided for @businessShopInCartCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item in cart} other{{count} items in cart}}'**
  String businessShopInCartCount(int count);

  /// No description provided for @businessShopInStock.
  ///
  /// In en, this message translates to:
  /// **'{count} in stock'**
  String businessShopInStock(int count);

  /// No description provided for @businessShopInYourCart.
  ///
  /// In en, this message translates to:
  /// **'{count} in your cart'**
  String businessShopInYourCart(int count);

  /// No description provided for @businessShopIncreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get businessShopIncreaseQuantity;

  /// No description provided for @businessShopItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String businessShopItemCount(int count);

  /// No description provided for @businessShopItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get businessShopItems;

  /// No description provided for @businessShopItemsBackInStock.
  ///
  /// In en, this message translates to:
  /// **'The items go back into stock.'**
  String get businessShopItemsBackInStock;

  /// No description provided for @businessShopLeftCount.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String businessShopLeftCount(int count);

  /// No description provided for @businessShopLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get businessShopLength;

  /// No description provided for @businessShopMarkAsFulfilledTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as fulfilled?'**
  String get businessShopMarkAsFulfilledTitle;

  /// No description provided for @businessShopMarkAsPaidTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid?'**
  String get businessShopMarkAsPaidTitle;

  /// No description provided for @businessShopMarkFulfilled.
  ///
  /// In en, this message translates to:
  /// **'Mark fulfilled'**
  String get businessShopMarkFulfilled;

  /// No description provided for @businessShopMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark paid'**
  String get businessShopMarkPaid;

  /// No description provided for @businessShopMembershipPaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment successful. Your membership is active!'**
  String get businessShopMembershipPaymentSuccess;

  /// No description provided for @businessShopMembershipType.
  ///
  /// In en, this message translates to:
  /// **'Membership type'**
  String get businessShopMembershipType;

  /// No description provided for @businessShopMyOrders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get businessShopMyOrders;

  /// No description provided for @businessShopNewOrdersHint.
  ///
  /// In en, this message translates to:
  /// **'New orders from customers will show up here.'**
  String get businessShopNewOrdersHint;

  /// No description provided for @businessShopNoGymSellsMemberships.
  ///
  /// In en, this message translates to:
  /// **'No gym sells memberships in the app yet.'**
  String get businessShopNoGymSellsMemberships;

  /// No description provided for @businessShopNoGymsMatch.
  ///
  /// In en, this message translates to:
  /// **'No gyms match your search'**
  String get businessShopNoGymsMatch;

  /// No description provided for @businessShopNoMembershipsForSale.
  ///
  /// In en, this message translates to:
  /// **'No memberships for sale'**
  String get businessShopNoMembershipsForSale;

  /// No description provided for @businessShopNoOrdersWithStatus.
  ///
  /// In en, this message translates to:
  /// **'{status, select, pending{No pending orders} paid{No paid orders} fulfilled{No fulfilled orders} cancelled{No cancelled orders} other{No orders}}'**
  String businessShopNoOrdersWithStatus(String status);

  /// No description provided for @businessShopNoOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get businessShopNoOrdersYet;

  /// No description provided for @businessShopNoOrdersYetMessage.
  ///
  /// In en, this message translates to:
  /// **'Products you order from a shop show up here.'**
  String get businessShopNoOrdersYetMessage;

  /// No description provided for @businessShopNoProductsMatch.
  ///
  /// In en, this message translates to:
  /// **'No products match your search'**
  String get businessShopNoProductsMatch;

  /// No description provided for @businessShopNoProductsYet.
  ///
  /// In en, this message translates to:
  /// **'This shop has no products yet'**
  String get businessShopNoProductsYet;

  /// No description provided for @businessShopNoShopsYet.
  ///
  /// In en, this message translates to:
  /// **'No shops yet'**
  String get businessShopNoShopsYet;

  /// No description provided for @businessShopNoShopsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'Shops will appear here once they open.'**
  String get businessShopNoShopsYetMessage;

  /// No description provided for @businessShopNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get businessShopNotYet;

  /// No description provided for @businessShopNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get businessShopNote;

  /// No description provided for @businessShopNoteForShop.
  ///
  /// In en, this message translates to:
  /// **'Note for the shop (optional)'**
  String get businessShopNoteForShop;

  /// No description provided for @businessShopOneTimeExplanation.
  ///
  /// In en, this message translates to:
  /// **'One payment of {price}. If you already have a membership at {gym}, it\'s extended.'**
  String businessShopOneTimeExplanation(String price, String gym);

  /// No description provided for @businessShopOnlinePaymentsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Online payments are not available'**
  String get businessShopOnlinePaymentsUnavailable;

  /// No description provided for @businessShopOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get businessShopOrder;

  /// No description provided for @businessShopOrderIdStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'{status, select, paid{Order {id} marked as paid.} fulfilled{Order {id} marked as fulfilled.} cancelled{Order {id} cancelled.} other{Order {id} updated.}}'**
  String businessShopOrderIdStatusChanged(String status, String id);

  /// No description provided for @businessShopOrderPaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment successful. Your order is paid!'**
  String get businessShopOrderPaymentSuccess;

  /// No description provided for @businessShopOrderStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'{status, select, paid{Order marked as paid.} fulfilled{Order marked as fulfilled.} cancelled{Order cancelled.} other{Order updated.}}'**
  String businessShopOrderStatusChanged(String status);

  /// No description provided for @businessShopOrderWithId.
  ///
  /// In en, this message translates to:
  /// **'Order {id}'**
  String businessShopOrderWithId(String id);

  /// No description provided for @businessShopOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get businessShopOrders;

  /// No description provided for @businessShopOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get businessShopOutOfStock;

  /// No description provided for @businessShopPayAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {price}'**
  String businessShopPayAmount(String price);

  /// No description provided for @businessShopPayByCard.
  ///
  /// In en, this message translates to:
  /// **'Pay by card'**
  String get businessShopPayByCard;

  /// No description provided for @businessShopPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now · {price}'**
  String businessShopPayNow(String price);

  /// No description provided for @businessShopPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get businessShopPayment;

  /// No description provided for @businessShopPaymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get businessShopPaymentCancelled;

  /// No description provided for @businessShopPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. You have not been charged.'**
  String get businessShopPaymentFailed;

  /// No description provided for @businessShopPaymentNotConfirmedYet.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the payment yet. We\'ll notify you once it\'s done.'**
  String get businessShopPaymentNotConfirmedYet;

  /// No description provided for @businessShopPaymentRefunded.
  ///
  /// In en, this message translates to:
  /// **'Payment refunded'**
  String get businessShopPaymentRefunded;

  /// No description provided for @businessShopPaymentStillProcessing.
  ///
  /// In en, this message translates to:
  /// **'Your payment is still processing. We\'ll notify you once it\'s confirmed.'**
  String get businessShopPaymentStillProcessing;

  /// No description provided for @businessShopPaymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment successful'**
  String get businessShopPaymentSuccessful;

  /// No description provided for @businessShopPickupPaymentHint.
  ///
  /// In en, this message translates to:
  /// **'Pay at the shop when you pick up your order.'**
  String get businessShopPickupPaymentHint;

  /// No description provided for @businessShopPlaceOrderAndPay.
  ///
  /// In en, this message translates to:
  /// **'Place order & pay {price}'**
  String businessShopPlaceOrderAndPay(String price);

  /// No description provided for @businessShopPlaceOrderTotal.
  ///
  /// In en, this message translates to:
  /// **'Place order · {price}'**
  String businessShopPlaceOrderTotal(String price);

  /// No description provided for @businessShopPlanMonthlyAutoRenew.
  ///
  /// In en, this message translates to:
  /// **'Monthly, auto-renew'**
  String get businessShopPlanMonthlyAutoRenew;

  /// No description provided for @businessShopPlanMonths.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{1 month} other{{months} months}}'**
  String businessShopPlanMonths(int months);

  /// No description provided for @businessShopPriceEachLineTotal.
  ///
  /// In en, this message translates to:
  /// **'{price} each · {total}'**
  String businessShopPriceEachLineTotal(String price, String total);

  /// No description provided for @businessShopPricePerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String businessShopPricePerMonth(String price);

  /// No description provided for @businessShopProductCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 product} other{{count} products}}'**
  String businessShopProductCount(int count);

  /// No description provided for @businessShopQuantityValue.
  ///
  /// In en, this message translates to:
  /// **'Quantity: {count}'**
  String businessShopQuantityValue(int count);

  /// No description provided for @businessShopRefundDone.
  ///
  /// In en, this message translates to:
  /// **'The card payment was refunded.'**
  String get businessShopRefundDone;

  /// No description provided for @businessShopRefundFailed.
  ///
  /// In en, this message translates to:
  /// **'The refund failed. Please refund it from Stripe.'**
  String get businessShopRefundFailed;

  /// No description provided for @businessShopRefundManual.
  ///
  /// In en, this message translates to:
  /// **'Refund the card payment manually.'**
  String get businessShopRefundManual;

  /// No description provided for @businessShopRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get businessShopRemove;

  /// No description provided for @businessShopRemovedFromCart.
  ///
  /// In en, this message translates to:
  /// **'Removed from your cart (no longer available): {items}'**
  String businessShopRemovedFromCart(String items);

  /// No description provided for @businessShopSearchGyms.
  ///
  /// In en, this message translates to:
  /// **'Search gyms'**
  String get businessShopSearchGyms;

  /// No description provided for @businessShopSearchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get businessShopSearchProducts;

  /// No description provided for @businessShopShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get businessShopShop;

  /// No description provided for @businessShopSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get businessShopSoldOut;

  /// No description provided for @businessShopStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get businessShopStatus;

  /// No description provided for @businessShopSubscribePerMonth.
  ///
  /// In en, this message translates to:
  /// **'Subscribe · {price}/month'**
  String businessShopSubscribePerMonth(String price);

  /// No description provided for @businessShopTimelinePlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get businessShopTimelinePlaced;

  /// No description provided for @businessShopTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get businessShopTotal;

  /// No description provided for @businessShopYourCart.
  ///
  /// In en, this message translates to:
  /// **'Your cart'**
  String get businessShopYourCart;

  /// No description provided for @calendarCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get calendarCancelled;

  /// No description provided for @calendarDayLabel.
  ///
  /// In en, this message translates to:
  /// **'{day}, {count, plural, =0{nothing scheduled} =1{1 item} other{{count} items}}'**
  String calendarDayLabel(String day, int count);

  /// No description provided for @calendarDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get calendarDone;

  /// No description provided for @calendarGoToToday.
  ///
  /// In en, this message translates to:
  /// **'Go to today'**
  String get calendarGoToToday;

  /// No description provided for @calendarNextDay.
  ///
  /// In en, this message translates to:
  /// **'{range} (+1 day)'**
  String calendarNextDay(String range);

  /// No description provided for @calendarNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get calendarNextWeek;

  /// No description provided for @calendarNothingOnDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this day'**
  String get calendarNothingOnDay;

  /// No description provided for @calendarNow.
  ///
  /// In en, this message translates to:
  /// **'Now, {time}'**
  String calendarNow(String time);

  /// No description provided for @calendarPreviousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get calendarPreviousWeek;

  /// No description provided for @chatAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get chatAccept;

  /// No description provided for @chatAddCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 person} other{Add {count} people}}'**
  String chatAddCount(int count);

  /// No description provided for @chatAddPeople.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get chatAddPeople;

  /// No description provided for @chatAddPeopleTitle.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get chatAddPeopleTitle;

  /// No description provided for @chatAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'Already in the group'**
  String get chatAlreadyMember;

  /// No description provided for @chatArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get chatArchive;

  /// No description provided for @chatArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get chatArchived;

  /// No description provided for @chatArchivedSnack.
  ///
  /// In en, this message translates to:
  /// **'Chat archived'**
  String get chatArchivedSnack;

  /// No description provided for @chatArchivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Archived chats'**
  String get chatArchivedTitle;

  /// No description provided for @chatAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get chatAttach;

  /// No description provided for @chatBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get chatBlock;

  /// No description provided for @chatBlockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to message you or find your profile. They won\'t be told you blocked them.'**
  String get chatBlockConfirmBody;

  /// No description provided for @chatBlockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String chatBlockConfirmTitle(String name);

  /// No description provided for @chatBlockedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} is blocked'**
  String chatBlockedSnack(String name);

  /// No description provided for @chatCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatCancel;

  /// No description provided for @chatClearChat.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get chatClearChat;

  /// No description provided for @chatClearChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear this chat\'s history for you? Others in the chat still see it.'**
  String get chatClearChatConfirm;

  /// No description provided for @chatCleared.
  ///
  /// In en, this message translates to:
  /// **'Chat cleared'**
  String get chatCleared;

  /// No description provided for @chatCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get chatCopied;

  /// No description provided for @chatCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopy;

  /// No description provided for @chatCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get chatCreateGroup;

  /// No description provided for @chatDeleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get chatDeleteChat;

  /// No description provided for @chatDeleteChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this chat? It\'s removed for you only — the other person still sees it.'**
  String get chatDeleteChatConfirm;

  /// No description provided for @chatDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get chatDeleteGroup;

  /// No description provided for @chatDeleteGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\" for everyone? This can\'t be undone.'**
  String chatDeleteGroupConfirm(String title);

  /// No description provided for @chatEditGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get chatEditGroup;

  /// No description provided for @chatEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get chatEdited;

  /// No description provided for @chatEditingMessage.
  ///
  /// In en, this message translates to:
  /// **'Editing message'**
  String get chatEditingMessage;

  /// No description provided for @chatEmptyArchived.
  ///
  /// In en, this message translates to:
  /// **'No archived chats'**
  String get chatEmptyArchived;

  /// No description provided for @chatEmptyInbox.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get chatEmptyInbox;

  /// No description provided for @chatEmptyInboxHint.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation with your gym buddies.'**
  String get chatEmptyInboxHint;

  /// No description provided for @chatEmptyRequests.
  ///
  /// In en, this message translates to:
  /// **'No message requests'**
  String get chatEmptyRequests;

  /// No description provided for @chatEmptyRequestsHint.
  ///
  /// In en, this message translates to:
  /// **'Messages from people who can\'t message you directly show up here.'**
  String get chatEmptyRequestsHint;

  /// No description provided for @chatFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent · Tap to retry'**
  String get chatFailed;

  /// No description provided for @chatFollowingSection.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get chatFollowingSection;

  /// No description provided for @chatGroupDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get chatGroupDescription;

  /// No description provided for @chatGroupFallback.
  ///
  /// In en, this message translates to:
  /// **'Group chat'**
  String get chatGroupFallback;

  /// No description provided for @chatGroupInfo.
  ///
  /// In en, this message translates to:
  /// **'Group info'**
  String get chatGroupInfo;

  /// No description provided for @chatGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get chatGroupName;

  /// No description provided for @chatGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name your group (optional)'**
  String get chatGroupNameHint;

  /// No description provided for @chatGroupRequestBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been added to this group'**
  String get chatGroupRequestBanner;

  /// No description provided for @chatGroupRequestHint.
  ///
  /// In en, this message translates to:
  /// **'Accept to join the conversation.'**
  String get chatGroupRequestHint;

  /// No description provided for @chatInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatInboxTitle;

  /// No description provided for @chatInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get chatInvited;

  /// No description provided for @chatJumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get chatJumpToLatest;

  /// No description provided for @chatLeaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get chatLeaveGroup;

  /// No description provided for @chatLeaveGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave \"{title}\"? You won\'t get new messages from this group.'**
  String chatLeaveGroupConfirm(String title);

  /// No description provided for @chatMakeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get chatMakeAdmin;

  /// No description provided for @chatMakeOwner.
  ///
  /// In en, this message translates to:
  /// **'Make group owner'**
  String get chatMakeOwner;

  /// No description provided for @chatMakeOwnerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Make {name} the group owner? You\'ll stay on as an admin.'**
  String chatMakeOwnerConfirm(String name);

  /// No description provided for @chatMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get chatMarkRead;

  /// No description provided for @chatMediaAudio.
  ///
  /// In en, this message translates to:
  /// **'🎤 Audio'**
  String get chatMediaAudio;

  /// No description provided for @chatMediaFile.
  ///
  /// In en, this message translates to:
  /// **'📎 File'**
  String get chatMediaFile;

  /// No description provided for @chatMediaPhoto.
  ///
  /// In en, this message translates to:
  /// **'📷 Photo'**
  String get chatMediaPhoto;

  /// No description provided for @chatMediaVideo.
  ///
  /// In en, this message translates to:
  /// **'🎥 Video'**
  String get chatMediaVideo;

  /// No description provided for @chatMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String chatMembersCount(int count);

  /// No description provided for @chatMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get chatMembersTitle;

  /// No description provided for @chatMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get chatMessageHint;

  /// No description provided for @chatMessageMember.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatMessageMember;

  /// No description provided for @chatMessageUnsent.
  ///
  /// In en, this message translates to:
  /// **'Message unsent'**
  String get chatMessageUnsent;

  /// No description provided for @chatMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get chatMoreOptions;

  /// No description provided for @chatMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get chatMute;

  /// No description provided for @chatMutedSnack.
  ///
  /// In en, this message translates to:
  /// **'Notifications muted'**
  String get chatMutedSnack;

  /// No description provided for @chatNewMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get chatNewMessage;

  /// No description provided for @chatNoAudio.
  ///
  /// In en, this message translates to:
  /// **'No audio yet'**
  String get chatNoAudio;

  /// No description provided for @chatNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get chatNoFiles;

  /// No description provided for @chatNoMedia.
  ///
  /// In en, this message translates to:
  /// **'No photos or videos yet'**
  String get chatNoMedia;

  /// No description provided for @chatNoPeopleFound.
  ///
  /// In en, this message translates to:
  /// **'No people found'**
  String get chatNoPeopleFound;

  /// No description provided for @chatNoResults.
  ///
  /// In en, this message translates to:
  /// **'No chats match \"{query}\"'**
  String chatNoResults(String query);

  /// No description provided for @chatOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get chatOpenFile;

  /// No description provided for @chatOriginalNotFound.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find the original message'**
  String get chatOriginalNotFound;

  /// No description provided for @chatPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get chatPause;

  /// No description provided for @chatPeopleAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person added} other{{count} people added}}'**
  String chatPeopleAdded(int count);

  /// No description provided for @chatPhotoMessage.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatPhotoMessage;

  /// No description provided for @chatPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get chatPlay;

  /// No description provided for @chatPreviewSender.
  ///
  /// In en, this message translates to:
  /// **'{name}: {text}'**
  String chatPreviewSender(String name, String text);

  /// No description provided for @chatPreviewYou.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String chatPreviewYou(String text);

  /// No description provided for @chatReactions.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get chatReactions;

  /// No description provided for @chatRemoveAdmin.
  ///
  /// In en, this message translates to:
  /// **'Remove as admin'**
  String get chatRemoveAdmin;

  /// No description provided for @chatRemoveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get chatRemoveAttachment;

  /// No description provided for @chatRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get chatRemoveMember;

  /// No description provided for @chatRemoveMemberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the group?'**
  String chatRemoveMemberConfirm(String name);

  /// No description provided for @chatRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove for everyone'**
  String get chatRemoveMessage;

  /// No description provided for @chatReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatReply;

  /// No description provided for @chatReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String chatReplyingTo(String name);

  /// No description provided for @chatReplyingToYourself.
  ///
  /// In en, this message translates to:
  /// **'Replying to yourself'**
  String get chatReplyingToYourself;

  /// No description provided for @chatReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get chatReport;

  /// No description provided for @chatReportHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get chatReportHarassment;

  /// No description provided for @chatReportImpersonation.
  ///
  /// In en, this message translates to:
  /// **'Pretending to be someone else'**
  String get chatReportImpersonation;

  /// No description provided for @chatReportInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get chatReportInappropriate;

  /// No description provided for @chatReportOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get chatReportOther;

  /// No description provided for @chatReportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks — we\'ll review it.'**
  String get chatReportSent;

  /// No description provided for @chatReportSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get chatReportSpam;

  /// No description provided for @chatReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this?'**
  String get chatReportTitle;

  /// No description provided for @chatRequestBanner.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to message you'**
  String chatRequestBanner(String name);

  /// No description provided for @chatRequestBannerHint.
  ///
  /// In en, this message translates to:
  /// **'They won\'t know you\'ve seen this until you accept.'**
  String get chatRequestBannerHint;

  /// No description provided for @chatRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get chatRoleAdmin;

  /// No description provided for @chatRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get chatRoleOwner;

  /// No description provided for @chatSaveEdit.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get chatSaveEdit;

  /// No description provided for @chatSayHi.
  ///
  /// In en, this message translates to:
  /// **'Say hi to {name} 👋'**
  String chatSayHi(String name);

  /// No description provided for @chatSayHiGroup.
  ///
  /// In en, this message translates to:
  /// **'Say hi to the group 👋'**
  String get chatSayHiGroup;

  /// No description provided for @chatSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get chatSearchHint;

  /// No description provided for @chatSearchPeople.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get chatSearchPeople;

  /// No description provided for @chatSeen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get chatSeen;

  /// No description provided for @chatSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get chatSelected;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get chatSending;

  /// No description provided for @chatSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get chatSent;

  /// No description provided for @chatSharedMedia.
  ///
  /// In en, this message translates to:
  /// **'Media, files and audio'**
  String get chatSharedMedia;

  /// No description provided for @chatSomeone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get chatSomeone;

  /// No description provided for @chatStartChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatStartChat;

  /// No description provided for @chatSuggestedSection.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get chatSuggestedSection;

  /// No description provided for @chatSysAdded.
  ///
  /// In en, this message translates to:
  /// **'{who, select, me{You added {targets}} other{{name} added {targets}}}'**
  String chatSysAdded(String who, String name, String targets);

  /// No description provided for @chatSysCreated.
  ///
  /// In en, this message translates to:
  /// **'{who, select, me{You created the group} other{{name} created the group}}'**
  String chatSysCreated(String who, String name);

  /// No description provided for @chatSysLeft.
  ///
  /// In en, this message translates to:
  /// **'{who, select, me{You left the group} other{{name} left the group}}'**
  String chatSysLeft(String who, String name);

  /// No description provided for @chatSysMadeAdmin.
  ///
  /// In en, this message translates to:
  /// **'{who, select, me{You made {target} an admin} other{{name} made {target} an admin}}'**
  String chatSysMadeAdmin(String who, String name, String target);

  /// No description provided for @chatSysMadeOwner.
  ///
  /// In en, this message translates to:
  /// **'{who, select, me{You made {target} the group owner} other{{name} made {target} the group owner}}'**
  String chatSysMadeOwner(String who, String name, String target);

  /// No description provided for @chatSysNameCleared.
  ///
  /// In en, this message translates to:
  /// **'{who, select, me{You removed the group name} other{{name} removed the group name}}'**
  String chatSysNameCleared(String who, String name);

  /// No description provided for @chatSysPhoto.
  ///
  /// In en, this message translates to:
  /// **'{who, select, me{You changed the group photo} other{{name} changed the group photo}}'**
  String chatSysPhoto(String who, String name);

  /// No description provided for @chatSysRemoved.
  ///
  /// In en, this message translates to:
  /// **'{who, select, me{You removed {target}} other{{name} removed {target}}}'**
  String chatSysRemoved(String who, String name, String target);

  /// No description provided for @chatSysRemovedAdmin.
  ///
  /// In en, this message translates to:
  /// **'{who, select, me{You removed {target} as admin} other{{name} removed {target} as admin}}'**
  String chatSysRemovedAdmin(String who, String name, String target);

  /// No description provided for @chatSysRenamed.
  ///
  /// In en, this message translates to:
  /// **'{who, select, me{You named the group \"{title}\"} other{{name} named the group \"{title}\"}}'**
  String chatSysRenamed(String who, String name, String title);

  /// No description provided for @chatSysUpdated.
  ///
  /// In en, this message translates to:
  /// **'{who, select, me{You updated the group} other{{name} updated the group}}'**
  String chatSysUpdated(String who, String name);

  /// No description provided for @chatTabAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get chatTabAudio;

  /// No description provided for @chatTabChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatTabChats;

  /// No description provided for @chatTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get chatTabFiles;

  /// No description provided for @chatTabMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get chatTabMedia;

  /// No description provided for @chatTabRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get chatTabRequests;

  /// No description provided for @chatTapToRemove.
  ///
  /// In en, this message translates to:
  /// **'Tap to remove'**
  String get chatTapToRemove;

  /// No description provided for @chatTo.
  ///
  /// In en, this message translates to:
  /// **'To:'**
  String get chatTo;

  /// No description provided for @chatUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get chatUnarchive;

  /// No description provided for @chatUnarchivedSnack.
  ///
  /// In en, this message translates to:
  /// **'Chat moved to your inbox'**
  String get chatUnarchivedSnack;

  /// No description provided for @chatUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get chatUndo;

  /// No description provided for @chatUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get chatUnmute;

  /// No description provided for @chatUnmutedSnack.
  ///
  /// In en, this message translates to:
  /// **'Notifications unmuted'**
  String get chatUnmutedSnack;

  /// No description provided for @chatUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread message} other{{count} unread messages}}'**
  String chatUnreadCount(int count);

  /// No description provided for @chatUnsend.
  ///
  /// In en, this message translates to:
  /// **'Unsend'**
  String get chatUnsend;

  /// No description provided for @chatUnsendConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed for everyone in this chat.'**
  String get chatUnsendConfirmBody;

  /// No description provided for @chatUnsendConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsend message?'**
  String get chatUnsendConfirmTitle;

  /// No description provided for @chatVideoMessage.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatVideoMessage;

  /// No description provided for @chatViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get chatViewProfile;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

  /// No description provided for @chatYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatYou;

  /// No description provided for @chatYouObject.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get chatYouObject;

  /// No description provided for @classCalendarAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get classCalendarAccept;

  /// No description provided for @classCalendarBookedOf.
  ///
  /// In en, this message translates to:
  /// **'{booked} of {capacity} booked'**
  String classCalendarBookedOf(int booked, int capacity);

  /// No description provided for @classCalendarDayLabel.
  ///
  /// In en, this message translates to:
  /// **'{day}, {count, plural, =0{no classes} =1{1 class} other{{count} classes}}'**
  String classCalendarDayLabel(String day, int count);

  /// No description provided for @classCalendarDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get classCalendarDecline;

  /// No description provided for @classCalendarInviteDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invite declined'**
  String get classCalendarInviteDeclined;

  /// No description provided for @classCalendarInvites.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 invite} other{{count} invites}}'**
  String classCalendarInvites(int count);

  /// No description provided for @classCalendarJoined.
  ///
  /// In en, this message translates to:
  /// **'You\'re in: {title}. Its sessions are in your schedule.'**
  String classCalendarJoined(String title);

  /// No description provided for @classCalendarNothingOnDay.
  ///
  /// In en, this message translates to:
  /// **'No classes on this day'**
  String get classCalendarNothingOnDay;

  /// No description provided for @classCalendarOnlyMine.
  ///
  /// In en, this message translates to:
  /// **'Only mine'**
  String get classCalendarOnlyMine;

  /// No description provided for @classCalendarTrainerAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name} is now your trainer'**
  String classCalendarTrainerAccepted(String name);

  /// No description provided for @classCalendarTrainerInvite.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to train you'**
  String classCalendarTrainerInvite(String name);

  /// No description provided for @classCalendarTrainerInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Accept to let them plan your classes and workouts.'**
  String get classCalendarTrainerInviteHint;

  /// No description provided for @classCalendarWaitlistShort.
  ///
  /// In en, this message translates to:
  /// **'+{count} waiting'**
  String classCalendarWaitlistShort(int count);

  /// No description provided for @classSeriesActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get classSeriesActive;

  /// No description provided for @classSeriesActiveHint.
  ///
  /// In en, this message translates to:
  /// **'New sessions keep coming.'**
  String get classSeriesActiveHint;

  /// No description provided for @classSeriesAddTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get classSeriesAddTime;

  /// No description provided for @classSeriesCancelInvite.
  ///
  /// In en, this message translates to:
  /// **'Cancel invite'**
  String get classSeriesCancelInvite;

  /// No description provided for @classSeriesCancelInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to accept it anymore.'**
  String get classSeriesCancelInviteMessage;

  /// No description provided for @classSeriesCancelInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel the invite to {name}?'**
  String classSeriesCancelInviteTitle(String name);

  /// No description provided for @classSeriesCapacity.
  ///
  /// In en, this message translates to:
  /// **'Spots per session'**
  String get classSeriesCapacity;

  /// No description provided for @classSeriesCapacityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Between 1 and 1000'**
  String get classSeriesCapacityInvalid;

  /// No description provided for @classSeriesClearEndDate.
  ///
  /// In en, this message translates to:
  /// **'Remove the end date'**
  String get classSeriesClearEndDate;

  /// No description provided for @classSeriesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create class'**
  String get classSeriesCreate;

  /// No description provided for @classSeriesCreateOne.
  ///
  /// In en, this message translates to:
  /// **'Create a class'**
  String get classSeriesCreateOne;

  /// No description provided for @classSeriesCreated.
  ///
  /// In en, this message translates to:
  /// **'Class created'**
  String get classSeriesCreated;

  /// No description provided for @classSeriesDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get classSeriesDate;

  /// No description provided for @classSeriesDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get classSeriesDescription;

  /// No description provided for @classSeriesDoneCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 done} other{{count} done}}'**
  String classSeriesDoneCount(int count);

  /// No description provided for @classSeriesDuration.
  ///
  /// In en, this message translates to:
  /// **'Length (minutes)'**
  String get classSeriesDuration;

  /// No description provided for @classSeriesDurationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Between 5 and 1440 minutes'**
  String get classSeriesDurationInvalid;

  /// No description provided for @classSeriesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit class'**
  String get classSeriesEdit;

  /// No description provided for @classSeriesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a class with its timetable. Its sessions show up in your calendar 90 days ahead.'**
  String get classSeriesEmptyMessage;

  /// No description provided for @classSeriesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No classes yet'**
  String get classSeriesEmptyTitle;

  /// No description provided for @classSeriesEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end date can\'t be before the start'**
  String get classSeriesEndBeforeStart;

  /// No description provided for @classSeriesEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get classSeriesEnds;

  /// No description provided for @classSeriesEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get classSeriesEveryDay;

  /// No description provided for @classSeriesGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get classSeriesGym;

  /// No description provided for @classSeriesInClass.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 in the class} other{{count} in the class}}'**
  String classSeriesInClass(int count);

  /// No description provided for @classSeriesInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get classSeriesInvite;

  /// No description provided for @classSeriesInviteAgain.
  ///
  /// In en, this message translates to:
  /// **'Invite again'**
  String get classSeriesInviteAgain;

  /// No description provided for @classSeriesInviteHint.
  ///
  /// In en, this message translates to:
  /// **'They accept the invite, then every session lands in their schedule.'**
  String get classSeriesInviteHint;

  /// No description provided for @classSeriesInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invite sent to {name}'**
  String classSeriesInviteSent(String name);

  /// No description provided for @classSeriesInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite to {title}'**
  String classSeriesInviteTitle(String title);

  /// No description provided for @classSeriesInvitedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 invited} other{{count} invited}}'**
  String classSeriesInvitedCount(int count);

  /// No description provided for @classSeriesLocation.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get classSeriesLocation;

  /// No description provided for @classSeriesLocationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Studio A'**
  String get classSeriesLocationHint;

  /// No description provided for @classSeriesMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get classSeriesMore;

  /// No description provided for @classSeriesNameYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String classSeriesNameYou(String name);

  /// No description provided for @classSeriesNew.
  ///
  /// In en, this message translates to:
  /// **'New class'**
  String get classSeriesNew;

  /// No description provided for @classSeriesNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {when}'**
  String classSeriesNext(String when);

  /// No description provided for @classSeriesNoEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get classSeriesNoEndDate;

  /// No description provided for @classSeriesNoEndDateHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps going. Sessions appear 90 days ahead.'**
  String get classSeriesNoEndDateHint;

  /// No description provided for @classSeriesNoGyms.
  ///
  /// In en, this message translates to:
  /// **'No gyms to teach at'**
  String get classSeriesNoGyms;

  /// No description provided for @classSeriesNoGymsMessage.
  ///
  /// In en, this message translates to:
  /// **'Once a gym adds you as a trainer, you can create classes there.'**
  String get classSeriesNoGymsMessage;

  /// No description provided for @classSeriesNoPeople.
  ///
  /// In en, this message translates to:
  /// **'No one yet. Invite your customers, followers or members of the gym.'**
  String get classSeriesNoPeople;

  /// No description provided for @classSeriesNoSessionsSoon.
  ///
  /// In en, this message translates to:
  /// **'No sessions in the next two weeks.'**
  String get classSeriesNoSessionsSoon;

  /// No description provided for @classSeriesNoTrainer.
  ///
  /// In en, this message translates to:
  /// **'No trainer'**
  String get classSeriesNoTrainer;

  /// No description provided for @classSeriesNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming sessions'**
  String get classSeriesNoUpcoming;

  /// No description provided for @classSeriesOnceOn.
  ///
  /// In en, this message translates to:
  /// **'Once on {date}'**
  String classSeriesOnceOn(String date);

  /// No description provided for @classSeriesOpenTimetable.
  ///
  /// In en, this message translates to:
  /// **'Class timetable'**
  String get classSeriesOpenTimetable;

  /// No description provided for @classSeriesOpenTimetableHint.
  ///
  /// In en, this message translates to:
  /// **'Every session, the people in it and invites'**
  String get classSeriesOpenTimetableHint;

  /// No description provided for @classSeriesPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get classSeriesPause;

  /// No description provided for @classSeriesPauseMessage.
  ///
  /// In en, this message translates to:
  /// **'Upcoming sessions are cancelled and the people booked into them are told. Resuming brings them back.'**
  String get classSeriesPauseMessage;

  /// No description provided for @classSeriesPauseTitle.
  ///
  /// In en, this message translates to:
  /// **'Pause this class?'**
  String get classSeriesPauseTitle;

  /// No description provided for @classSeriesPausedDone.
  ///
  /// In en, this message translates to:
  /// **'Class paused'**
  String get classSeriesPausedDone;

  /// No description provided for @classSeriesPausedHint.
  ///
  /// In en, this message translates to:
  /// **'No sessions while paused.'**
  String get classSeriesPausedHint;

  /// No description provided for @classSeriesPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get classSeriesPeople;

  /// No description provided for @classSeriesPickWeekday.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one day'**
  String get classSeriesPickWeekday;

  /// No description provided for @classSeriesRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from class'**
  String get classSeriesRemove;

  /// No description provided for @classSeriesRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'Their upcoming sessions of this class are cancelled.'**
  String get classSeriesRemoveMessage;

  /// No description provided for @classSeriesRemoveTime.
  ///
  /// In en, this message translates to:
  /// **'Remove {time}'**
  String classSeriesRemoveTime(String time);

  /// No description provided for @classSeriesRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String classSeriesRemoveTitle(String name);

  /// No description provided for @classSeriesRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String classSeriesRemoved(String name);

  /// No description provided for @classSeriesRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get classSeriesRepeat;

  /// No description provided for @classSeriesRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get classSeriesRepeatDaily;

  /// No description provided for @classSeriesRepeatOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get classSeriesRepeatOnce;

  /// No description provided for @classSeriesRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get classSeriesRepeatWeekly;

  /// No description provided for @classSeriesResumedDone.
  ///
  /// In en, this message translates to:
  /// **'Class resumed'**
  String get classSeriesResumedDone;

  /// No description provided for @classSeriesSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get classSeriesSave;

  /// No description provided for @classSeriesSaved.
  ///
  /// In en, this message translates to:
  /// **'Class updated'**
  String get classSeriesSaved;

  /// No description provided for @classSeriesSetEndDate.
  ///
  /// In en, this message translates to:
  /// **'Set an end date'**
  String get classSeriesSetEndDate;

  /// No description provided for @classSeriesSpots.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 spot per session} other{{count} spots per session}}'**
  String classSeriesSpots(int count);

  /// No description provided for @classSeriesStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get classSeriesStarts;

  /// No description provided for @classSeriesStateActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get classSeriesStateActive;

  /// No description provided for @classSeriesStateEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get classSeriesStateEnded;

  /// No description provided for @classSeriesStatePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get classSeriesStatePaused;

  /// No description provided for @classSeriesStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'In the class'**
  String get classSeriesStatusAccepted;

  /// No description provided for @classSeriesStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get classSeriesStatusDeclined;

  /// No description provided for @classSeriesStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get classSeriesStatusPending;

  /// No description provided for @classSeriesTimes.
  ///
  /// In en, this message translates to:
  /// **'Start times'**
  String get classSeriesTimes;

  /// No description provided for @classSeriesTimesHint.
  ///
  /// In en, this message translates to:
  /// **'Add every time it runs in a day.'**
  String get classSeriesTimesHint;

  /// No description provided for @classSeriesTimesMax.
  ///
  /// In en, this message translates to:
  /// **'Up to 12 start times a day'**
  String get classSeriesTimesMax;

  /// No description provided for @classSeriesTimesRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one start time'**
  String get classSeriesTimesRequired;

  /// No description provided for @classSeriesTimetable.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get classSeriesTimetable;

  /// No description provided for @classSeriesTimetableChangeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Change it'**
  String get classSeriesTimetableChangeConfirm;

  /// No description provided for @classSeriesTimetableChangeMessage.
  ///
  /// In en, this message translates to:
  /// **'Upcoming sessions that no longer fit are cancelled, and the people booked into them are told. New sessions are added for everyone in the class.'**
  String get classSeriesTimetableChangeMessage;

  /// No description provided for @classSeriesTimetableChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change the timetable?'**
  String get classSeriesTimetableChangeTitle;

  /// No description provided for @classSeriesTimezone.
  ///
  /// In en, this message translates to:
  /// **'Times are in {zone}'**
  String classSeriesTimezone(String zone);

  /// No description provided for @classSeriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get classSeriesTitle;

  /// No description provided for @classSeriesTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Morning HIIT'**
  String get classSeriesTitleHint;

  /// No description provided for @classSeriesTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the class a title'**
  String get classSeriesTitleRequired;

  /// No description provided for @classSeriesTrainer.
  ///
  /// In en, this message translates to:
  /// **'Trainer'**
  String get classSeriesTrainer;

  /// No description provided for @classSeriesUpcomingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 upcoming} other{{count} upcoming}}'**
  String classSeriesUpcomingCount(int count);

  /// No description provided for @classSeriesUpcomingSessions.
  ///
  /// In en, this message translates to:
  /// **'Upcoming sessions'**
  String get classSeriesUpcomingSessions;

  /// No description provided for @classSeriesWeekdays.
  ///
  /// In en, this message translates to:
  /// **'On these days'**
  String get classSeriesWeekdays;

  /// No description provided for @classSeriesYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get classSeriesYou;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonSomethingWentWrong;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @customersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get customersAdd;

  /// No description provided for @customersAddPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Your followers, members of gyms where you coach, and people you\'ve invited before.'**
  String get customersAddPickerHint;

  /// No description provided for @customersAddPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a customer'**
  String get customersAddPickerTitle;

  /// No description provided for @customersAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} was invited to be your customer'**
  String customersAdded(String name);

  /// No description provided for @customersCancelInvite.
  ///
  /// In en, this message translates to:
  /// **'Cancel invite'**
  String get customersCancelInvite;

  /// No description provided for @customersChooseClassesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. They accept each class invite themselves, and you can change this later.'**
  String get customersChooseClassesHint;

  /// No description provided for @customersChooseClassesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite {name} to classes?'**
  String customersChooseClassesTitle(String name);

  /// No description provided for @customersClassDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get customersClassDeclined;

  /// No description provided for @customersClassIn.
  ///
  /// In en, this message translates to:
  /// **'In the class'**
  String get customersClassIn;

  /// No description provided for @customersClassInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get customersClassInvited;

  /// No description provided for @customersClassPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get customersClassPaused;

  /// No description provided for @customersEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your followers or members of gyms where you coach. Anyone you invite to a class shows up here too.'**
  String get customersEmptyMessage;

  /// No description provided for @customersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get customersEmptyTitle;

  /// No description provided for @customersInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get customersInvite;

  /// No description provided for @customersInviteCancelled.
  ///
  /// In en, this message translates to:
  /// **'Invite cancelled'**
  String get customersInviteCancelled;

  /// No description provided for @customersInviteToClasses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Invite to 1 class} other{Invite to {count} classes}}'**
  String customersInviteToClasses(int count);

  /// No description provided for @customersInvited.
  ///
  /// In en, this message translates to:
  /// **'Invite sent'**
  String get customersInvited;

  /// No description provided for @customersJustAdd.
  ///
  /// In en, this message translates to:
  /// **'Just add'**
  String get customersJustAdd;

  /// No description provided for @customersNoActiveClasses.
  ///
  /// In en, this message translates to:
  /// **'You have no active classes to invite them to yet.'**
  String get customersNoActiveClasses;

  /// No description provided for @customersNoClasses.
  ///
  /// In en, this message translates to:
  /// **'You don\'t run any classes yet. Create one in the Classes tab.'**
  String get customersNoClasses;

  /// No description provided for @customersNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No customers match your search'**
  String get customersNoMatches;

  /// No description provided for @customersNotFound.
  ///
  /// In en, this message translates to:
  /// **'This person is no longer your customer.'**
  String get customersNotFound;

  /// No description provided for @customersNotInClass.
  ///
  /// In en, this message translates to:
  /// **'Not in this class'**
  String get customersNotInClass;

  /// No description provided for @customersProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get customersProgress;

  /// No description provided for @customersProgressLocked.
  ///
  /// In en, this message translates to:
  /// **'Available once they accept your invite'**
  String get customersProgressLocked;

  /// No description provided for @customersProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts, lifts and body measurements'**
  String get customersProgressSubtitle;

  /// No description provided for @customersRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get customersRemove;

  /// No description provided for @customersRemoveCustomer.
  ///
  /// In en, this message translates to:
  /// **'Remove customer'**
  String get customersRemoveCustomer;

  /// No description provided for @customersRemoveCustomerMessage.
  ///
  /// In en, this message translates to:
  /// **'They\'re also taken off your classes and their upcoming sessions are cancelled. You won\'t be able to see their progress anymore.'**
  String get customersRemoveCustomerMessage;

  /// No description provided for @customersRemoveCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String customersRemoveCustomerTitle(String name);

  /// No description provided for @customersRemoveFromClass.
  ///
  /// In en, this message translates to:
  /// **'Remove from class'**
  String get customersRemoveFromClass;

  /// No description provided for @customersRemoveFromClassMessage.
  ///
  /// In en, this message translates to:
  /// **'Their upcoming sessions of this class are cancelled and they\'re told about it.'**
  String get customersRemoveFromClassMessage;

  /// No description provided for @customersRemoveFromClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from {title}?'**
  String customersRemoveFromClassTitle(String title);

  /// No description provided for @customersRemoved.
  ///
  /// In en, this message translates to:
  /// **'Customer removed'**
  String get customersRemoved;

  /// No description provided for @customersRemovedFromClass.
  ///
  /// In en, this message translates to:
  /// **'Removed from the class'**
  String get customersRemovedFromClass;

  /// No description provided for @customersSearch.
  ///
  /// In en, this message translates to:
  /// **'Search customers'**
  String get customersSearch;

  /// No description provided for @customersStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customersStatusAccepted;

  /// No description provided for @customersStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Invite pending'**
  String get customersStatusPending;

  /// No description provided for @customersViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get customersViewProfile;

  /// No description provided for @customersYourClasses.
  ///
  /// In en, this message translates to:
  /// **'Your classes'**
  String get customersYourClasses;

  /// No description provided for @draftBadge.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draftBadge;

  /// No description provided for @draftChooseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Continue a draft or start from scratch.'**
  String get draftChooseSubtitle;

  /// No description provided for @draftChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Your drafts'**
  String get draftChooseTitle;

  /// No description provided for @draftDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get draftDelete;

  /// No description provided for @draftDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this draft?'**
  String get draftDeleteTitle;

  /// No description provided for @draftDeleted.
  ///
  /// In en, this message translates to:
  /// **'Draft deleted'**
  String get draftDeleted;

  /// No description provided for @draftDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get draftDiscard;

  /// No description provided for @draftDiscardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get draftDiscardChanges;

  /// No description provided for @draftEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited {when}'**
  String draftEdited(String when);

  /// No description provided for @draftEditingBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'re editing a draft. Publishing it removes the draft.'**
  String get draftEditingBanner;

  /// No description provided for @draftKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get draftKeepEditing;

  /// No description provided for @draftMediaCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo or video} other{{count} photos and videos}}'**
  String draftMediaCount(int count);

  /// No description provided for @draftOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the draft: {error}'**
  String draftOpenFailed(String error);

  /// No description provided for @draftOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening draft…'**
  String get draftOpening;

  /// No description provided for @draftSave.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get draftSave;

  /// No description provided for @draftSaveBody.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off later. Drafts are private — only you can see them.'**
  String get draftSaveBody;

  /// No description provided for @draftSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get draftSaveChanges;

  /// No description provided for @draftSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the draft: {error}'**
  String draftSaveFailed(String error);

  /// No description provided for @draftSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save as a draft?'**
  String get draftSaveTitle;

  /// No description provided for @draftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get draftSaved;

  /// No description provided for @draftSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving draft…'**
  String get draftSaving;

  /// No description provided for @draftStartNew.
  ///
  /// In en, this message translates to:
  /// **'Start new'**
  String get draftStartNew;

  /// No description provided for @draftUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled draft'**
  String get draftUntitled;

  /// No description provided for @draftUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Save changes to this draft?'**
  String get draftUpdateTitle;

  /// No description provided for @feedAddMedia.
  ///
  /// In en, this message translates to:
  /// **'Add photos or videos'**
  String get feedAddMedia;

  /// No description provided for @feedAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get feedAddMore;

  /// No description provided for @feedAllComments.
  ///
  /// In en, this message translates to:
  /// **'Back to all comments'**
  String get feedAllComments;

  /// No description provided for @feedCancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get feedCancelReply;

  /// No description provided for @feedCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Write a caption…'**
  String get feedCaptionHint;

  /// No description provided for @feedCollapseThread.
  ///
  /// In en, this message translates to:
  /// **'Collapse thread'**
  String get feedCollapseThread;

  /// No description provided for @feedCommentsHeader.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get feedCommentsHeader;

  /// No description provided for @feedComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Share a photo or update…'**
  String get feedComposerHint;

  /// No description provided for @feedContinueThread.
  ///
  /// In en, this message translates to:
  /// **'Continue this thread →'**
  String get feedContinueThread;

  /// No description provided for @feedCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get feedCopied;

  /// No description provided for @feedCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get feedCopyText;

  /// No description provided for @feedDeletedComment.
  ///
  /// In en, this message translates to:
  /// **'[deleted]'**
  String get feedDeletedComment;

  /// No description provided for @feedDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get feedDiscard;

  /// No description provided for @feedDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this post?'**
  String get feedDiscardTitle;

  /// No description provided for @feedDoubleTapToLove.
  ///
  /// In en, this message translates to:
  /// **'Double-tap to love'**
  String get feedDoubleTapToLove;

  /// No description provided for @feedEmptyExploreBody.
  ///
  /// In en, this message translates to:
  /// **'Popular public posts will show up here.'**
  String get feedEmptyExploreBody;

  /// No description provided for @feedEmptyExploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to explore yet'**
  String get feedEmptyExploreTitle;

  /// No description provided for @feedEmptyHomeBody.
  ///
  /// In en, this message translates to:
  /// **'Follow people or join a gym to see their posts here.'**
  String get feedEmptyHomeBody;

  /// No description provided for @feedEmptyHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your feed is empty'**
  String get feedEmptyHomeTitle;

  /// No description provided for @feedEndOfFeed.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get feedEndOfFeed;

  /// No description provided for @feedExpandThread.
  ///
  /// In en, this message translates to:
  /// **'Expand thread'**
  String get feedExpandThread;

  /// No description provided for @feedExploreAction.
  ///
  /// In en, this message translates to:
  /// **'Explore popular posts'**
  String get feedExploreAction;

  /// No description provided for @feedHiddenComment.
  ///
  /// In en, this message translates to:
  /// **'[hidden]'**
  String get feedHiddenComment;

  /// No description provided for @feedLoadMoreComments.
  ///
  /// In en, this message translates to:
  /// **'Load more comments'**
  String get feedLoadMoreComments;

  /// No description provided for @feedMediaIndex.
  ///
  /// In en, this message translates to:
  /// **'{index}/{count}'**
  String feedMediaIndex(int index, int count);

  /// No description provided for @feedMediaLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} photos or videos per post'**
  String feedMediaLimit(int count);

  /// No description provided for @feedMore.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get feedMore;

  /// No description provided for @feedMoveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get feedMoveLeft;

  /// No description provided for @feedMoveRight.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get feedMoveRight;

  /// No description provided for @feedMultipleMedia.
  ///
  /// In en, this message translates to:
  /// **'Multiple photos or videos'**
  String get feedMultipleMedia;

  /// No description provided for @feedNewPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get feedNewPost;

  /// No description provided for @feedNoReactions.
  ///
  /// In en, this message translates to:
  /// **'No reactions yet'**
  String get feedNoReactions;

  /// No description provided for @feedOp.
  ///
  /// In en, this message translates to:
  /// **'OP'**
  String get feedOp;

  /// No description provided for @feedOpenProfile.
  ///
  /// In en, this message translates to:
  /// **'Open {name}\'s profile'**
  String feedOpenProfile(String name);

  /// No description provided for @feedOriginalPoster.
  ///
  /// In en, this message translates to:
  /// **'Original poster'**
  String get feedOriginalPoster;

  /// No description provided for @feedPostEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a photo, video or caption first'**
  String get feedPostEmpty;

  /// No description provided for @feedPostNotFound.
  ///
  /// In en, this message translates to:
  /// **'This post isn\'t available anymore.'**
  String get feedPostNotFound;

  /// No description provided for @feedPostOptions.
  ///
  /// In en, this message translates to:
  /// **'Post options'**
  String get feedPostOptions;

  /// No description provided for @feedPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get feedPostTitle;

  /// No description provided for @feedPostUpdated.
  ///
  /// In en, this message translates to:
  /// **'Post updated'**
  String get feedPostUpdated;

  /// No description provided for @feedPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get feedPosted;

  /// No description provided for @feedPostedBy.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String feedPostedBy(String name);

  /// No description provided for @feedPrivateAccountNote.
  ///
  /// In en, this message translates to:
  /// **'Your account is private, so only your followers will see this post.'**
  String get feedPrivateAccountNote;

  /// No description provided for @feedPublishing.
  ///
  /// In en, this message translates to:
  /// **'Publishing…'**
  String get feedPublishing;

  /// No description provided for @feedReactionsAll.
  ///
  /// In en, this message translates to:
  /// **'All {count}'**
  String feedReactionsAll(int count);

  /// No description provided for @feedReactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get feedReactionsTitle;

  /// No description provided for @feedRemoveMedia.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get feedRemoveMedia;

  /// No description provided for @feedReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Hold and drag to reorder'**
  String get feedReorderHint;

  /// No description provided for @feedReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get feedReply;

  /// No description provided for @feedReplyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reply} other{{count} replies}}'**
  String feedReplyCount(int count);

  /// No description provided for @feedReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String feedReplyingTo(String name);

  /// No description provided for @feedSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get feedSending;

  /// No description provided for @feedShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get feedShowLess;

  /// No description provided for @feedShowMoreReplies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 more reply} other{Show {count} more replies}}'**
  String feedShowMoreReplies(int count);

  /// No description provided for @feedShowParent.
  ///
  /// In en, this message translates to:
  /// **'Show parent comment'**
  String get feedShowParent;

  /// No description provided for @feedSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort comments'**
  String get feedSortLabel;

  /// No description provided for @feedSortNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get feedSortNew;

  /// No description provided for @feedSortOld.
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get feedSortOld;

  /// No description provided for @feedSortTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get feedSortTop;

  /// No description provided for @feedTabExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get feedTabExplore;

  /// No description provided for @feedTabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get feedTabHome;

  /// No description provided for @feedThreadTitle.
  ///
  /// In en, this message translates to:
  /// **'Thread'**
  String get feedThreadTitle;

  /// No description provided for @feedUploadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading {index} of {count}…'**
  String feedUploadingProgress(int index, int count);

  /// No description provided for @feedVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get feedVideo;

  /// No description provided for @feedVisibilityFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get feedVisibilityFollowers;

  /// No description provided for @feedVisibilityFollowersHint.
  ///
  /// In en, this message translates to:
  /// **'Only your followers can see this post'**
  String get feedVisibilityFollowersHint;

  /// No description provided for @feedVisibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Who can see this'**
  String get feedVisibilityLabel;

  /// No description provided for @feedVisibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get feedVisibilityPublic;

  /// No description provided for @feedVisibilityPublicHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone can see this post'**
  String get feedVisibilityPublicHint;

  /// No description provided for @feedWriteReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Write a reply…'**
  String get feedWriteReplyHint;

  /// No description provided for @mediaAdjustBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get mediaAdjustBrightness;

  /// No description provided for @mediaAdjustContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get mediaAdjustContrast;

  /// No description provided for @mediaAdjustFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get mediaAdjustFade;

  /// No description provided for @mediaAdjustSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get mediaAdjustSaturation;

  /// No description provided for @mediaAdjustTint.
  ///
  /// In en, this message translates to:
  /// **'Tint'**
  String get mediaAdjustTint;

  /// No description provided for @mediaAdjustVignette.
  ///
  /// In en, this message translates to:
  /// **'Vignette'**
  String get mediaAdjustVignette;

  /// No description provided for @mediaAdjustWarmth.
  ///
  /// In en, this message translates to:
  /// **'Warmth'**
  String get mediaAdjustWarmth;

  /// No description provided for @mediaBackToTools.
  ///
  /// In en, this message translates to:
  /// **'Back to tools'**
  String get mediaBackToTools;

  /// No description provided for @mediaBatchNote.
  ///
  /// In en, this message translates to:
  /// **'Filters and adjustments here apply to all {count} items and replace their own. Videos are trimmed one by one.'**
  String mediaBatchNote(int count);

  /// No description provided for @mediaCantEdit.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be edited.'**
  String get mediaCantEdit;

  /// No description provided for @mediaDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get mediaDone;

  /// No description provided for @mediaEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get mediaEdit;

  /// No description provided for @mediaEditAll.
  ///
  /// In en, this message translates to:
  /// **'Edit all'**
  String get mediaEditAll;

  /// No description provided for @mediaEditAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit all ({count})'**
  String mediaEditAllTitle(int count);

  /// No description provided for @mediaEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply the edits. Try again, or reset them.'**
  String get mediaEditFailed;

  /// No description provided for @mediaEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item {index}'**
  String mediaEditItem(int index);

  /// No description provided for @mediaEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get mediaEditTitle;

  /// No description provided for @mediaEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get mediaEdited;

  /// No description provided for @mediaFilterArctic.
  ///
  /// In en, this message translates to:
  /// **'Arctic'**
  String get mediaFilterArctic;

  /// No description provided for @mediaFilterDramatic.
  ///
  /// In en, this message translates to:
  /// **'Dramatic'**
  String get mediaFilterDramatic;

  /// No description provided for @mediaFilterGolden.
  ///
  /// In en, this message translates to:
  /// **'Golden'**
  String get mediaFilterGolden;

  /// No description provided for @mediaFilterMatte.
  ///
  /// In en, this message translates to:
  /// **'Matte'**
  String get mediaFilterMatte;

  /// No description provided for @mediaFilterMono.
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get mediaFilterMono;

  /// No description provided for @mediaFilterNoir.
  ///
  /// In en, this message translates to:
  /// **'Noir'**
  String get mediaFilterNoir;

  /// No description provided for @mediaFilterNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get mediaFilterNormal;

  /// No description provided for @mediaFilterPunch.
  ///
  /// In en, this message translates to:
  /// **'Punch'**
  String get mediaFilterPunch;

  /// No description provided for @mediaFilterRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get mediaFilterRose;

  /// No description provided for @mediaFilterSepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get mediaFilterSepia;

  /// No description provided for @mediaFilterStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get mediaFilterStrength;

  /// No description provided for @mediaFilterVintage.
  ///
  /// In en, this message translates to:
  /// **'Vintage'**
  String get mediaFilterVintage;

  /// No description provided for @mediaFilterVivid.
  ///
  /// In en, this message translates to:
  /// **'Vivid'**
  String get mediaFilterVivid;

  /// No description provided for @mediaHoldToCompare.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to see the original'**
  String get mediaHoldToCompare;

  /// No description provided for @mediaOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get mediaOriginal;

  /// No description provided for @mediaProcessing.
  ///
  /// In en, this message translates to:
  /// **'Applying edits {index} of {count}…'**
  String mediaProcessing(int index, int count);

  /// No description provided for @mediaReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get mediaReset;

  /// No description provided for @mediaResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all edits'**
  String get mediaResetAll;

  /// No description provided for @mediaTabAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get mediaTabAdjust;

  /// No description provided for @mediaTabFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get mediaTabFilter;

  /// No description provided for @mediaTabTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get mediaTabTrim;

  /// No description provided for @mediaTrimEnd.
  ///
  /// In en, this message translates to:
  /// **'Trim end'**
  String get mediaTrimEnd;

  /// No description provided for @mediaTrimPickVideo.
  ///
  /// In en, this message translates to:
  /// **'Pick a video to trim'**
  String get mediaTrimPickVideo;

  /// No description provided for @mediaTrimStart.
  ///
  /// In en, this message translates to:
  /// **'Trim start'**
  String get mediaTrimStart;

  /// No description provided for @mediaTrimSummary.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end} · {length}'**
  String mediaTrimSummary(String start, String end, String length);

  /// No description provided for @mediaTrimWindow.
  ///
  /// In en, this message translates to:
  /// **'Trimmed clip, drag to move'**
  String get mediaTrimWindow;

  /// No description provided for @mediaUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get mediaUndo;

  /// No description provided for @mediaVideoNumber.
  ///
  /// In en, this message translates to:
  /// **'Video {index}'**
  String mediaVideoNumber(int index);

  /// No description provided for @nutritionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get nutritionAdd;

  /// No description provided for @nutritionAddFoodItem.
  ///
  /// In en, this message translates to:
  /// **'Add food item'**
  String get nutritionAddFoodItem;

  /// No description provided for @nutritionAddFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Add food'**
  String get nutritionAddFoodTitle;

  /// No description provided for @nutritionAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get nutritionAddImage;

  /// No description provided for @nutritionAddIngredient.
  ///
  /// In en, this message translates to:
  /// **'Add ingredient'**
  String get nutritionAddIngredient;

  /// No description provided for @nutritionAddMineral.
  ///
  /// In en, this message translates to:
  /// **'Add mineral'**
  String get nutritionAddMineral;

  /// No description provided for @nutritionAddNamed.
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String nutritionAddNamed(String name);

  /// No description provided for @nutritionAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get nutritionAddPhoto;

  /// No description provided for @nutritionAddRecipe.
  ///
  /// In en, this message translates to:
  /// **'Add recipe'**
  String get nutritionAddRecipe;

  /// No description provided for @nutritionAddSlot.
  ///
  /// In en, this message translates to:
  /// **'Add Slot'**
  String get nutritionAddSlot;

  /// No description provided for @nutritionAddStep.
  ///
  /// In en, this message translates to:
  /// **'Add step'**
  String get nutritionAddStep;

  /// No description provided for @nutritionAddToSlot.
  ///
  /// In en, this message translates to:
  /// **'Add to {slot}'**
  String nutritionAddToSlot(String slot);

  /// No description provided for @nutritionAddVideo.
  ///
  /// In en, this message translates to:
  /// **'Add video'**
  String get nutritionAddVideo;

  /// No description provided for @nutritionAddVitamin.
  ///
  /// In en, this message translates to:
  /// **'Add vitamin'**
  String get nutritionAddVitamin;

  /// No description provided for @nutritionAllMineralsAdded.
  ///
  /// In en, this message translates to:
  /// **'All minerals are already added'**
  String get nutritionAllMineralsAdded;

  /// No description provided for @nutritionAllSlotsAdded.
  ///
  /// In en, this message translates to:
  /// **'All meal slots have been added'**
  String get nutritionAllSlotsAdded;

  /// No description provided for @nutritionAllVitaminsAdded.
  ///
  /// In en, this message translates to:
  /// **'All vitamins are already added'**
  String get nutritionAllVitaminsAdded;

  /// No description provided for @nutritionAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get nutritionAmount;

  /// No description provided for @nutritionAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get nutritionAssign;

  /// No description provided for @nutritionAssignMealPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign meal plan'**
  String get nutritionAssignMealPlanTitle;

  /// No description provided for @nutritionAssignPlanToQuestion.
  ///
  /// In en, this message translates to:
  /// **'Assign \"{plan}\" to {name}?'**
  String nutritionAssignPlanToQuestion(String plan, String name);

  /// No description provided for @nutritionAssignPlanToSelfQuestion.
  ///
  /// In en, this message translates to:
  /// **'Assign \"{plan}\" to you?'**
  String nutritionAssignPlanToSelfQuestion(String plan);

  /// No description provided for @nutritionAssignTo.
  ///
  /// In en, this message translates to:
  /// **'Assign to'**
  String get nutritionAssignTo;

  /// No description provided for @nutritionAssignedBy.
  ///
  /// In en, this message translates to:
  /// **'Assigned by {name}'**
  String nutritionAssignedBy(String name);

  /// No description provided for @nutritionAssignedByMe.
  ///
  /// In en, this message translates to:
  /// **'Assigned by me'**
  String get nutritionAssignedByMe;

  /// No description provided for @nutritionAssignedOn.
  ///
  /// In en, this message translates to:
  /// **'Assigned {date}'**
  String nutritionAssignedOn(String date);

  /// No description provided for @nutritionAssignedToMe.
  ///
  /// In en, this message translates to:
  /// **'Assigned to me'**
  String get nutritionAssignedToMe;

  /// No description provided for @nutritionAssignmentFor.
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String nutritionAssignmentFor(String name);

  /// No description provided for @nutritionBarcodeExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. {example}'**
  String nutritionBarcodeExample(String example);

  /// No description provided for @nutritionBarcodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'No product found for barcode {code}'**
  String nutritionBarcodeNotFound(String code);

  /// No description provided for @nutritionBarcodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Barcode (optional)'**
  String get nutritionBarcodeOptional;

  /// No description provided for @nutritionBarcodeValue.
  ///
  /// In en, this message translates to:
  /// **'Barcode {code}'**
  String nutritionBarcodeValue(String code);

  /// No description provided for @nutritionBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get nutritionBasicInfo;

  /// No description provided for @nutritionBrandOptional.
  ///
  /// In en, this message translates to:
  /// **'Brand (optional)'**
  String get nutritionBrandOptional;

  /// No description provided for @nutritionCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get nutritionCalories;

  /// No description provided for @nutritionCameraAccessOff.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get nutritionCameraAccessOff;

  /// No description provided for @nutritionCameraAccessOffHint.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access for Gym Bro in your device settings to scan barcodes, or type the code instead.'**
  String get nutritionCameraAccessOffHint;

  /// No description provided for @nutritionCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get nutritionCameraUnavailable;

  /// No description provided for @nutritionCameraUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'The camera could not be started. You can type the barcode number instead.'**
  String get nutritionCameraUnavailableHint;

  /// No description provided for @nutritionCancelEditing.
  ///
  /// In en, this message translates to:
  /// **'Cancel editing'**
  String get nutritionCancelEditing;

  /// No description provided for @nutritionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get nutritionCannotBeUndone;

  /// No description provided for @nutritionCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get nutritionCarbs;

  /// No description provided for @nutritionCarbsLetter.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get nutritionCarbsLetter;

  /// No description provided for @nutritionCarbsShort.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get nutritionCarbsShort;

  /// No description provided for @nutritionChooseDailyPlanFor.
  ///
  /// In en, this message translates to:
  /// **'Choose daily plan for {week}, {day}'**
  String nutritionChooseDailyPlanFor(String week, String day);

  /// No description provided for @nutritionClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get nutritionClearSearch;

  /// No description provided for @nutritionClearStartDate.
  ///
  /// In en, this message translates to:
  /// **'Clear start date'**
  String get nutritionClearStartDate;

  /// No description provided for @nutritionClearUnassign.
  ///
  /// In en, this message translates to:
  /// **'Clear / Unassign'**
  String get nutritionClearUnassign;

  /// No description provided for @nutritionComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get nutritionComment;

  /// No description provided for @nutritionCommentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 comment} other{{count} comments}}'**
  String nutritionCommentCount(int count);

  /// No description provided for @nutritionCommentOptions.
  ///
  /// In en, this message translates to:
  /// **'Comment options'**
  String get nutritionCommentOptions;

  /// No description provided for @nutritionComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get nutritionComments;

  /// No description provided for @nutritionCommentsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Comments ({count})'**
  String nutritionCommentsWithCount(int count);

  /// No description provided for @nutritionCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'{business} · Community'**
  String nutritionCommunityTitle(String business);

  /// No description provided for @nutritionComputedPerServing.
  ///
  /// In en, this message translates to:
  /// **'Computed per serving'**
  String get nutritionComputedPerServing;

  /// No description provided for @nutritionCookMinLabel.
  ///
  /// In en, this message translates to:
  /// **'Cook (min)'**
  String get nutritionCookMinLabel;

  /// No description provided for @nutritionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get nutritionCreate;

  /// No description provided for @nutritionCreateItem.
  ///
  /// In en, this message translates to:
  /// **'Create item'**
  String get nutritionCreateItem;

  /// No description provided for @nutritionDailyAveragePlannedDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Daily average · 1 planned day} other{Daily average · {count} planned days}}'**
  String nutritionDailyAveragePlannedDays(int count);

  /// No description provided for @nutritionDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String nutritionDaysAgo(int count);

  /// No description provided for @nutritionDaysPlannedOfSeven.
  ///
  /// In en, this message translates to:
  /// **'{count} of 7 days planned'**
  String nutritionDaysPlannedOfSeven(int count);

  /// No description provided for @nutritionDeleteCommentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete comment?'**
  String get nutritionDeleteCommentTitle;

  /// No description provided for @nutritionDeleteFoodItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete food item?'**
  String get nutritionDeleteFoodItemTitle;

  /// No description provided for @nutritionDeleteMealPlanMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" permanently? Any assignments of this plan are removed too.'**
  String nutritionDeleteMealPlanMessage(String name);

  /// No description provided for @nutritionDeleteMealPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete meal plan?'**
  String get nutritionDeleteMealPlanTitle;

  /// No description provided for @nutritionDeletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get nutritionDeletePost;

  /// No description provided for @nutritionDeletePostTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete post?'**
  String get nutritionDeletePostTitle;

  /// No description provided for @nutritionDeleteRecipeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recipe?'**
  String get nutritionDeleteRecipeTitle;

  /// No description provided for @nutritionDeletedUser.
  ///
  /// In en, this message translates to:
  /// **'Deleted user'**
  String get nutritionDeletedUser;

  /// No description provided for @nutritionDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get nutritionDescription;

  /// No description provided for @nutritionDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get nutritionDragToReorder;

  /// No description provided for @nutritionDrinkBeer.
  ///
  /// In en, this message translates to:
  /// **'Beer'**
  String get nutritionDrinkBeer;

  /// No description provided for @nutritionDrinkBlackTea.
  ///
  /// In en, this message translates to:
  /// **'Black Tea'**
  String get nutritionDrinkBlackTea;

  /// No description provided for @nutritionDrinkCider.
  ///
  /// In en, this message translates to:
  /// **'Cider'**
  String get nutritionDrinkCider;

  /// No description provided for @nutritionDrinkCocktail.
  ///
  /// In en, this message translates to:
  /// **'Cocktail'**
  String get nutritionDrinkCocktail;

  /// No description provided for @nutritionDrinkCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get nutritionDrinkCoffee;

  /// No description provided for @nutritionDrinkDairyMilk.
  ///
  /// In en, this message translates to:
  /// **'Dairy Milk'**
  String get nutritionDrinkDairyMilk;

  /// No description provided for @nutritionDrinkEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy Drink'**
  String get nutritionDrinkEnergy;

  /// No description provided for @nutritionDrinkEspresso.
  ///
  /// In en, this message translates to:
  /// **'Espresso'**
  String get nutritionDrinkEspresso;

  /// No description provided for @nutritionDrinkFlavouredWater.
  ///
  /// In en, this message translates to:
  /// **'Flavoured Water'**
  String get nutritionDrinkFlavouredWater;

  /// No description provided for @nutritionDrinkFruitJuice.
  ///
  /// In en, this message translates to:
  /// **'Fruit Juice'**
  String get nutritionDrinkFruitJuice;

  /// No description provided for @nutritionDrinkGreenTea.
  ///
  /// In en, this message translates to:
  /// **'Green Tea'**
  String get nutritionDrinkGreenTea;

  /// No description provided for @nutritionDrinkHerbalTea.
  ///
  /// In en, this message translates to:
  /// **'Herbal Tea'**
  String get nutritionDrinkHerbalTea;

  /// No description provided for @nutritionDrinkIsotonic.
  ///
  /// In en, this message translates to:
  /// **'Isotonic'**
  String get nutritionDrinkIsotonic;

  /// No description provided for @nutritionDrinkKefir.
  ///
  /// In en, this message translates to:
  /// **'Kefir Drink'**
  String get nutritionDrinkKefir;

  /// No description provided for @nutritionDrinkKombucha.
  ///
  /// In en, this message translates to:
  /// **'Kombucha'**
  String get nutritionDrinkKombucha;

  /// No description provided for @nutritionDrinkMealReplacement.
  ///
  /// In en, this message translates to:
  /// **'Meal Replacement'**
  String get nutritionDrinkMealReplacement;

  /// No description provided for @nutritionDrinkPlantMilk.
  ///
  /// In en, this message translates to:
  /// **'Plant Milk'**
  String get nutritionDrinkPlantMilk;

  /// No description provided for @nutritionDrinkProteinShake.
  ///
  /// In en, this message translates to:
  /// **'Protein Shake'**
  String get nutritionDrinkProteinShake;

  /// No description provided for @nutritionDrinkShake.
  ///
  /// In en, this message translates to:
  /// **'Shake'**
  String get nutritionDrinkShake;

  /// No description provided for @nutritionDrinkSmoothie.
  ///
  /// In en, this message translates to:
  /// **'Smoothie'**
  String get nutritionDrinkSmoothie;

  /// No description provided for @nutritionDrinkSoda.
  ///
  /// In en, this message translates to:
  /// **'Soda'**
  String get nutritionDrinkSoda;

  /// No description provided for @nutritionDrinkSparklingWater.
  ///
  /// In en, this message translates to:
  /// **'Sparkling Water'**
  String get nutritionDrinkSparklingWater;

  /// No description provided for @nutritionDrinkSpirit.
  ///
  /// In en, this message translates to:
  /// **'Spirit'**
  String get nutritionDrinkSpirit;

  /// No description provided for @nutritionDrinkSports.
  ///
  /// In en, this message translates to:
  /// **'Sports Drink'**
  String get nutritionDrinkSports;

  /// No description provided for @nutritionDrinkStillWater.
  ///
  /// In en, this message translates to:
  /// **'Still Water'**
  String get nutritionDrinkStillWater;

  /// No description provided for @nutritionDrinkVegetableJuice.
  ///
  /// In en, this message translates to:
  /// **'Vegetable Juice'**
  String get nutritionDrinkVegetableJuice;

  /// No description provided for @nutritionDrinkWine.
  ///
  /// In en, this message translates to:
  /// **'Wine'**
  String get nutritionDrinkWine;

  /// No description provided for @nutritionDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get nutritionDuration;

  /// No description provided for @nutritionEditAmountOrMeal.
  ///
  /// In en, this message translates to:
  /// **'Edit amount or meal'**
  String get nutritionEditAmountOrMeal;

  /// No description provided for @nutritionEditDailyPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Meal Plan'**
  String get nutritionEditDailyPlanTitle;

  /// No description provided for @nutritionEditFoodItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Food Item'**
  String get nutritionEditFoodItemTitle;

  /// No description provided for @nutritionEditMealPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Meal Plan'**
  String get nutritionEditMealPlanTitle;

  /// No description provided for @nutritionEditMicronutrients.
  ///
  /// In en, this message translates to:
  /// **'Edit micronutrients'**
  String get nutritionEditMicronutrients;

  /// No description provided for @nutritionEditPost.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get nutritionEditPost;

  /// No description provided for @nutritionEditPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Post'**
  String get nutritionEditPostTitle;

  /// No description provided for @nutritionEditRecipeTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Recipe'**
  String get nutritionEditRecipeTitle;

  /// No description provided for @nutritionEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get nutritionEdited;

  /// No description provided for @nutritionEditedLower.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get nutritionEditedLower;

  /// No description provided for @nutritionEditingComment.
  ///
  /// In en, this message translates to:
  /// **'Editing comment'**
  String get nutritionEditingComment;

  /// No description provided for @nutritionEndsOn.
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String nutritionEndsOn(String date);

  /// No description provided for @nutritionEnterBarcode.
  ///
  /// In en, this message translates to:
  /// **'Enter barcode'**
  String get nutritionEnterBarcode;

  /// No description provided for @nutritionEnterCodeManually.
  ///
  /// In en, this message translates to:
  /// **'Enter code manually'**
  String get nutritionEnterCodeManually;

  /// No description provided for @nutritionEnterPositiveNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number'**
  String get nutritionEnterPositiveNumber;

  /// No description provided for @nutritionEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get nutritionEnterValidNumber;

  /// No description provided for @nutritionFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get nutritionFat;

  /// No description provided for @nutritionFatLetter.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get nutritionFatLetter;

  /// No description provided for @nutritionFiber.
  ///
  /// In en, this message translates to:
  /// **'Fiber'**
  String get nutritionFiber;

  /// No description provided for @nutritionFiberNoTargets.
  ///
  /// In en, this message translates to:
  /// **'Fiber {fiber} g · No meal plan targets for this day'**
  String nutritionFiberNoTargets(int fiber);

  /// No description provided for @nutritionFiberWithTargets.
  ///
  /// In en, this message translates to:
  /// **'Fiber {fiber} / {target} g · Targets from your meal plan'**
  String nutritionFiberWithTargets(int fiber, int target);

  /// No description provided for @nutritionFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get nutritionFilterAll;

  /// No description provided for @nutritionFoodBabyFood.
  ///
  /// In en, this message translates to:
  /// **'Baby Food'**
  String get nutritionFoodBabyFood;

  /// No description provided for @nutritionFoodBaking.
  ///
  /// In en, this message translates to:
  /// **'Baking'**
  String get nutritionFoodBaking;

  /// No description provided for @nutritionFoodBeans.
  ///
  /// In en, this message translates to:
  /// **'Beans'**
  String get nutritionFoodBeans;

  /// No description provided for @nutritionFoodBeef.
  ///
  /// In en, this message translates to:
  /// **'Beef'**
  String get nutritionFoodBeef;

  /// No description provided for @nutritionFoodBiscuitCookie.
  ///
  /// In en, this message translates to:
  /// **'Biscuit / Cookie'**
  String get nutritionFoodBiscuitCookie;

  /// No description provided for @nutritionFoodBreadBakery.
  ///
  /// In en, this message translates to:
  /// **'Bread / Bakery'**
  String get nutritionFoodBreadBakery;

  /// No description provided for @nutritionFoodButter.
  ///
  /// In en, this message translates to:
  /// **'Butter'**
  String get nutritionFoodButter;

  /// No description provided for @nutritionFoodCanned.
  ///
  /// In en, this message translates to:
  /// **'Canned Food'**
  String get nutritionFoodCanned;

  /// No description provided for @nutritionFoodCerealBar.
  ///
  /// In en, this message translates to:
  /// **'Cereal Bar'**
  String get nutritionFoodCerealBar;

  /// No description provided for @nutritionFoodCheese.
  ///
  /// In en, this message translates to:
  /// **'Cheese'**
  String get nutritionFoodCheese;

  /// No description provided for @nutritionFoodChips.
  ///
  /// In en, this message translates to:
  /// **'Chips / Crisps'**
  String get nutritionFoodChips;

  /// No description provided for @nutritionFoodChocolateCandy.
  ///
  /// In en, this message translates to:
  /// **'Chocolate / Candy'**
  String get nutritionFoodChocolateCandy;

  /// No description provided for @nutritionFoodCorn.
  ///
  /// In en, this message translates to:
  /// **'Corn / Maize'**
  String get nutritionFoodCorn;

  /// No description provided for @nutritionFoodCream.
  ///
  /// In en, this message translates to:
  /// **'Cream'**
  String get nutritionFoodCream;

  /// No description provided for @nutritionFoodDiary.
  ///
  /// In en, this message translates to:
  /// **'Food diary'**
  String get nutritionFoodDiary;

  /// No description provided for @nutritionFoodDressing.
  ///
  /// In en, this message translates to:
  /// **'Dressing'**
  String get nutritionFoodDressing;

  /// No description provided for @nutritionFoodEgg.
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get nutritionFoodEgg;

  /// No description provided for @nutritionFoodFish.
  ///
  /// In en, this message translates to:
  /// **'Fish'**
  String get nutritionFoodFish;

  /// No description provided for @nutritionFoodFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen Food'**
  String get nutritionFoodFrozen;

  /// No description provided for @nutritionFoodFruit.
  ///
  /// In en, this message translates to:
  /// **'Fruit'**
  String get nutritionFoodFruit;

  /// No description provided for @nutritionFoodGameMeat.
  ///
  /// In en, this message translates to:
  /// **'Game Meat'**
  String get nutritionFoodGameMeat;

  /// No description provided for @nutritionFoodGrainCereal.
  ///
  /// In en, this message translates to:
  /// **'Grain / Cereal'**
  String get nutritionFoodGrainCereal;

  /// No description provided for @nutritionFoodHerbFresh.
  ///
  /// In en, this message translates to:
  /// **'Fresh Herb'**
  String get nutritionFoodHerbFresh;

  /// No description provided for @nutritionFoodJamSpread.
  ///
  /// In en, this message translates to:
  /// **'Jam / Spread'**
  String get nutritionFoodJamSpread;

  /// No description provided for @nutritionFoodLamb.
  ///
  /// In en, this message translates to:
  /// **'Lamb'**
  String get nutritionFoodLamb;

  /// No description provided for @nutritionFoodLentils.
  ///
  /// In en, this message translates to:
  /// **'Lentils'**
  String get nutritionFoodLentils;

  /// No description provided for @nutritionFoodMilk.
  ///
  /// In en, this message translates to:
  /// **'Milk'**
  String get nutritionFoodMilk;

  /// No description provided for @nutritionFoodMushroom.
  ///
  /// In en, this message translates to:
  /// **'Mushroom'**
  String get nutritionFoodMushroom;

  /// No description provided for @nutritionFoodNuts.
  ///
  /// In en, this message translates to:
  /// **'Nuts'**
  String get nutritionFoodNuts;

  /// No description provided for @nutritionFoodOilFat.
  ///
  /// In en, this message translates to:
  /// **'Oil / Fat'**
  String get nutritionFoodOilFat;

  /// No description provided for @nutritionFoodPastaNoodle.
  ///
  /// In en, this message translates to:
  /// **'Pasta / Noodle'**
  String get nutritionFoodPastaNoodle;

  /// No description provided for @nutritionFoodPlantMilk.
  ///
  /// In en, this message translates to:
  /// **'Plant Milk'**
  String get nutritionFoodPlantMilk;

  /// No description provided for @nutritionFoodPork.
  ///
  /// In en, this message translates to:
  /// **'Pork'**
  String get nutritionFoodPork;

  /// No description provided for @nutritionFoodPotatoTuber.
  ///
  /// In en, this message translates to:
  /// **'Potato / Tuber'**
  String get nutritionFoodPotatoTuber;

  /// No description provided for @nutritionFoodPoultry.
  ///
  /// In en, this message translates to:
  /// **'Poultry'**
  String get nutritionFoodPoultry;

  /// No description provided for @nutritionFoodProcessedMeat.
  ///
  /// In en, this message translates to:
  /// **'Processed Meat'**
  String get nutritionFoodProcessedMeat;

  /// No description provided for @nutritionFoodReadyMeal.
  ///
  /// In en, this message translates to:
  /// **'Ready Meal'**
  String get nutritionFoodReadyMeal;

  /// No description provided for @nutritionFoodRice.
  ///
  /// In en, this message translates to:
  /// **'Rice'**
  String get nutritionFoodRice;

  /// No description provided for @nutritionFoodSauceCondiment.
  ///
  /// In en, this message translates to:
  /// **'Sauce / Condiment'**
  String get nutritionFoodSauceCondiment;

  /// No description provided for @nutritionFoodSeafood.
  ///
  /// In en, this message translates to:
  /// **'Seafood'**
  String get nutritionFoodSeafood;

  /// No description provided for @nutritionFoodSeeds.
  ///
  /// In en, this message translates to:
  /// **'Seeds'**
  String get nutritionFoodSeeds;

  /// No description provided for @nutritionFoodSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Snack Bar'**
  String get nutritionFoodSnackBar;

  /// No description provided for @nutritionFoodSupplementPowder.
  ///
  /// In en, this message translates to:
  /// **'Supplement Powder'**
  String get nutritionFoodSupplementPowder;

  /// No description provided for @nutritionFoodSweetener.
  ///
  /// In en, this message translates to:
  /// **'Sweetener'**
  String get nutritionFoodSweetener;

  /// No description provided for @nutritionFoodVegetable.
  ///
  /// In en, this message translates to:
  /// **'Vegetable'**
  String get nutritionFoodVegetable;

  /// No description provided for @nutritionFoodYogurt.
  ///
  /// In en, this message translates to:
  /// **'Yogurt'**
  String get nutritionFoodYogurt;

  /// No description provided for @nutritionFoods.
  ///
  /// In en, this message translates to:
  /// **'Foods'**
  String get nutritionFoods;

  /// No description provided for @nutritionHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String nutritionHoursAgo(int count);

  /// No description provided for @nutritionImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get nutritionImageUrl;

  /// No description provided for @nutritionImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get nutritionImages;

  /// No description provided for @nutritionImportedFromOff.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{name}\" from Open Food Facts. Check the values before relying on them.'**
  String nutritionImportedFromOff(String name);

  /// No description provided for @nutritionIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get nutritionIngredients;

  /// No description provided for @nutritionInstructionHint.
  ///
  /// In en, this message translates to:
  /// **'Instruction…'**
  String get nutritionInstructionHint;

  /// No description provided for @nutritionItemFallback.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get nutritionItemFallback;

  /// No description provided for @nutritionJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get nutritionJustNow;

  /// No description provided for @nutritionKcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get nutritionKcal;

  /// No description provided for @nutritionKcalEatenSemantics.
  ///
  /// In en, this message translates to:
  /// **'Calories eaten: {eaten} kcal'**
  String nutritionKcalEatenSemantics(int eaten);

  /// No description provided for @nutritionKcalLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String nutritionKcalLeft(int count);

  /// No description provided for @nutritionKcalOver.
  ///
  /// In en, this message translates to:
  /// **'{count} over'**
  String nutritionKcalOver(int count);

  /// No description provided for @nutritionKcalPer100.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal {per100}'**
  String nutritionKcalPer100(int kcal, String per100);

  /// No description provided for @nutritionKcalPerServing.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal per serving'**
  String nutritionKcalPerServing(int kcal);

  /// No description provided for @nutritionKcalPerServingLabel.
  ///
  /// In en, this message translates to:
  /// **'kcal per serving'**
  String get nutritionKcalPerServingLabel;

  /// No description provided for @nutritionKcalRingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Calories: {eaten} of {target} kcal'**
  String nutritionKcalRingSemantics(int eaten, int target);

  /// No description provided for @nutritionKcalValue.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal'**
  String nutritionKcalValue(int kcal);

  /// No description provided for @nutritionLabelWithUnit.
  ///
  /// In en, this message translates to:
  /// **'{label} ({unit})'**
  String nutritionLabelWithUnit(String label, String unit);

  /// No description provided for @nutritionLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get nutritionLike;

  /// No description provided for @nutritionLikeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No likes} =1{1 like} other{{count} likes}}'**
  String nutritionLikeCount(int count);

  /// No description provided for @nutritionLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get nutritionLoadMore;

  /// No description provided for @nutritionLogAction.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get nutritionLogAction;

  /// No description provided for @nutritionLogAnyway.
  ///
  /// In en, this message translates to:
  /// **'Log anyway'**
  String get nutritionLogAnyway;

  /// No description provided for @nutritionLogPlannedAllDuplicateWarning.
  ///
  /// In en, this message translates to:
  /// **'Some meals already have entries today. The planned items will be added on top of them.'**
  String get nutritionLogPlannedAllDuplicateWarning;

  /// No description provided for @nutritionLogPlannedMeals.
  ///
  /// In en, this message translates to:
  /// **'Log planned meals'**
  String get nutritionLogPlannedMeals;

  /// No description provided for @nutritionLogPlannedMealsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Log planned meals?'**
  String get nutritionLogPlannedMealsQuestion;

  /// No description provided for @nutritionLogPlannedSlotDuplicateWarning.
  ///
  /// In en, this message translates to:
  /// **'{slot} already has entries. The planned items will be added on top of them.'**
  String nutritionLogPlannedSlotDuplicateWarning(String slot);

  /// No description provided for @nutritionLogToDiary.
  ///
  /// In en, this message translates to:
  /// **'Log to diary'**
  String get nutritionLogToDiary;

  /// No description provided for @nutritionLogToToday.
  ///
  /// In en, this message translates to:
  /// **'Log to today'**
  String get nutritionLogToToday;

  /// No description provided for @nutritionLoggedItemToSlot.
  ///
  /// In en, this message translates to:
  /// **'Logged {name} to {slot}'**
  String nutritionLoggedItemToSlot(String name, String slot);

  /// No description provided for @nutritionLoggedPlannedItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Logged 1 planned item} other{Logged {count} planned items}}'**
  String nutritionLoggedPlannedItems(int count);

  /// No description provided for @nutritionLoggedToSlot.
  ///
  /// In en, this message translates to:
  /// **'Logged to {slot}'**
  String nutritionLoggedToSlot(String slot);

  /// No description provided for @nutritionLookUp.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get nutritionLookUp;

  /// No description provided for @nutritionLookingUpProduct.
  ///
  /// In en, this message translates to:
  /// **'Looking up product…'**
  String get nutritionLookingUpProduct;

  /// No description provided for @nutritionMacronutrients.
  ///
  /// In en, this message translates to:
  /// **'Macronutrients'**
  String get nutritionMacronutrients;

  /// No description provided for @nutritionMeal.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get nutritionMeal;

  /// No description provided for @nutritionMealCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 meal} other{{count} meals}}'**
  String nutritionMealCount(int count);

  /// No description provided for @nutritionMealPlanFallback.
  ///
  /// In en, this message translates to:
  /// **'Meal plan'**
  String get nutritionMealPlanFallback;

  /// No description provided for @nutritionMealPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Meal Plans'**
  String get nutritionMealPlansTitle;

  /// No description provided for @nutritionMealSlots.
  ///
  /// In en, this message translates to:
  /// **'Meal Slots'**
  String get nutritionMealSlots;

  /// No description provided for @nutritionMemberFallback.
  ///
  /// In en, this message translates to:
  /// **'member'**
  String get nutritionMemberFallback;

  /// No description provided for @nutritionMicronutrients.
  ///
  /// In en, this message translates to:
  /// **'Micronutrients'**
  String get nutritionMicronutrients;

  /// No description provided for @nutritionMicronutrientsOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. Amounts {per100}.'**
  String nutritionMicronutrientsOptionalHint(String per100);

  /// No description provided for @nutritionMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get nutritionMine;

  /// No description provided for @nutritionMineral.
  ///
  /// In en, this message translates to:
  /// **'Mineral'**
  String get nutritionMineral;

  /// No description provided for @nutritionMinerals.
  ///
  /// In en, this message translates to:
  /// **'Minerals'**
  String get nutritionMinerals;

  /// No description provided for @nutritionMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String nutritionMinutesAgo(int count);

  /// No description provided for @nutritionMoveToMeal.
  ///
  /// In en, this message translates to:
  /// **'Move to meal'**
  String get nutritionMoveToMeal;

  /// No description provided for @nutritionMyself.
  ///
  /// In en, this message translates to:
  /// **'Myself'**
  String get nutritionMyself;

  /// No description provided for @nutritionNameRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get nutritionNameRequiredLabel;

  /// No description provided for @nutritionNewDailyPlanMenu.
  ///
  /// In en, this message translates to:
  /// **'New Daily Plan'**
  String get nutritionNewDailyPlanMenu;

  /// No description provided for @nutritionNewDailyPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'New Meal Plan'**
  String get nutritionNewDailyPlanTitle;

  /// No description provided for @nutritionNewFoodItemTitle.
  ///
  /// In en, this message translates to:
  /// **'New Food Item'**
  String get nutritionNewFoodItemTitle;

  /// No description provided for @nutritionNewMealPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'New Meal Plan'**
  String get nutritionNewMealPlanTitle;

  /// No description provided for @nutritionNewPost.
  ///
  /// In en, this message translates to:
  /// **'New Post'**
  String get nutritionNewPost;

  /// No description provided for @nutritionNewRecipeTitle.
  ///
  /// In en, this message translates to:
  /// **'New Recipe'**
  String get nutritionNewRecipeTitle;

  /// No description provided for @nutritionNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nutritionNextDay;

  /// No description provided for @nutritionNoAssignmentsByMe.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t assigned meal plans to anyone'**
  String get nutritionNoAssignmentsByMe;

  /// No description provided for @nutritionNoAssignmentsToMe.
  ///
  /// In en, this message translates to:
  /// **'No meal plans assigned to you yet'**
  String get nutritionNoAssignmentsToMe;

  /// No description provided for @nutritionNoCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get nutritionNoCommentsYet;

  /// No description provided for @nutritionNoDailyPlansFound.
  ///
  /// In en, this message translates to:
  /// **'No daily plans found'**
  String get nutritionNoDailyPlansFound;

  /// No description provided for @nutritionNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries'**
  String get nutritionNoEntries;

  /// No description provided for @nutritionNoEntriesYet.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get nutritionNoEntriesYet;

  /// No description provided for @nutritionNoFoodItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No food items found'**
  String get nutritionNoFoodItemsFound;

  /// No description provided for @nutritionNoFoodsFound.
  ///
  /// In en, this message translates to:
  /// **'No foods found'**
  String get nutritionNoFoodsFound;

  /// No description provided for @nutritionNoFoodsFoundHint.
  ///
  /// In en, this message translates to:
  /// **'Try another search, or scan the product barcode.'**
  String get nutritionNoFoodsFoundHint;

  /// No description provided for @nutritionNoIngredientsYet.
  ///
  /// In en, this message translates to:
  /// **'No ingredients added yet'**
  String get nutritionNoIngredientsYet;

  /// No description provided for @nutritionNoMealPlansFound.
  ///
  /// In en, this message translates to:
  /// **'No meal plans found'**
  String get nutritionNoMealPlansFound;

  /// No description provided for @nutritionNoMealsYet.
  ///
  /// In en, this message translates to:
  /// **'No meals added yet'**
  String get nutritionNoMealsYet;

  /// No description provided for @nutritionNoMembersMatch.
  ///
  /// In en, this message translates to:
  /// **'No members match your search'**
  String get nutritionNoMembersMatch;

  /// No description provided for @nutritionNoMembersToCoach.
  ///
  /// In en, this message translates to:
  /// **'No members to coach. Members of gyms where you work or train appear here.'**
  String get nutritionNoMembersToCoach;

  /// No description provided for @nutritionNoMicronutrients.
  ///
  /// In en, this message translates to:
  /// **'No vitamins or minerals recorded for this item.'**
  String get nutritionNoMicronutrients;

  /// No description provided for @nutritionNoMicronutrientsAdded.
  ///
  /// In en, this message translates to:
  /// **'No vitamins or minerals added'**
  String get nutritionNoMicronutrientsAdded;

  /// No description provided for @nutritionNoOwnMealPlans.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t created any meal plans yet'**
  String get nutritionNoOwnMealPlans;

  /// No description provided for @nutritionNoPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get nutritionNoPostsYet;

  /// No description provided for @nutritionNoRecipesFound.
  ///
  /// In en, this message translates to:
  /// **'No recipes found'**
  String get nutritionNoRecipesFound;

  /// No description provided for @nutritionNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get nutritionNoResults;

  /// No description provided for @nutritionNoStepsYet.
  ///
  /// In en, this message translates to:
  /// **'No steps added yet'**
  String get nutritionNoStepsYet;

  /// No description provided for @nutritionNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get nutritionNoteOptional;

  /// No description provided for @nutritionNothingLogged.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged'**
  String get nutritionNothingLogged;

  /// No description provided for @nutritionNothingLoggedThisDay.
  ///
  /// In en, this message translates to:
  /// **'No food was logged on this day.'**
  String get nutritionNothingLoggedThisDay;

  /// No description provided for @nutritionNothingPlanned.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned'**
  String get nutritionNothingPlanned;

  /// No description provided for @nutritionNutrient.
  ///
  /// In en, this message translates to:
  /// **'Nutrient'**
  String get nutritionNutrient;

  /// No description provided for @nutritionNutrientListLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the nutrient list: {error}'**
  String nutritionNutrientListLoadFailed(String error);

  /// No description provided for @nutritionOfTargetKcal.
  ///
  /// In en, this message translates to:
  /// **'of {target} kcal'**
  String nutritionOfTargetKcal(int target);

  /// No description provided for @nutritionPcfGrams.
  ///
  /// In en, this message translates to:
  /// **'P {protein}g · C {carbs}g · F {fat}g'**
  String nutritionPcfGrams(int protein, int carbs, int fat);

  /// No description provided for @nutritionPcfShort.
  ///
  /// In en, this message translates to:
  /// **'P {protein} · C {carbs} · F {fat}'**
  String nutritionPcfShort(int protein, int carbs, int fat);

  /// No description provided for @nutritionPer100Unit.
  ///
  /// In en, this message translates to:
  /// **'per 100{unit}'**
  String nutritionPer100Unit(String unit);

  /// No description provided for @nutritionPerServing.
  ///
  /// In en, this message translates to:
  /// **'per serving'**
  String get nutritionPerServing;

  /// No description provided for @nutritionPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String nutritionPhotoCount(int count);

  /// No description provided for @nutritionPhotoOf.
  ///
  /// In en, this message translates to:
  /// **'Photo of {name}'**
  String nutritionPhotoOf(String name);

  /// No description provided for @nutritionPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get nutritionPickDate;

  /// No description provided for @nutritionPlanAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'\"{plan}\" assigned to {name}'**
  String nutritionPlanAssignedTo(String plan, String name);

  /// No description provided for @nutritionPlanAssignedToSelf.
  ///
  /// In en, this message translates to:
  /// **'\"{plan}\" assigned to you'**
  String nutritionPlanAssignedToSelf(String plan);

  /// No description provided for @nutritionPlanNameRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan name *'**
  String get nutritionPlanNameRequiredLabel;

  /// No description provided for @nutritionPlannedSummary.
  ///
  /// In en, this message translates to:
  /// **'Planned: {items} · {kcal} kcal'**
  String nutritionPlannedSummary(String items, int kcal);

  /// No description provided for @nutritionPointCameraAtBarcode.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the product barcode'**
  String get nutritionPointCameraAtBarcode;

  /// No description provided for @nutritionPostAction.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get nutritionPostAction;

  /// No description provided for @nutritionPostPhoto.
  ///
  /// In en, this message translates to:
  /// **'Post photo'**
  String get nutritionPostPhoto;

  /// No description provided for @nutritionPostPhotoOf.
  ///
  /// In en, this message translates to:
  /// **'Photo {index} of {count}'**
  String nutritionPostPhotoOf(int index, int count);

  /// No description provided for @nutritionPrepMinLabel.
  ///
  /// In en, this message translates to:
  /// **'Prep (min)'**
  String get nutritionPrepMinLabel;

  /// No description provided for @nutritionPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get nutritionPreviousDay;

  /// No description provided for @nutritionPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get nutritionPrivate;

  /// No description provided for @nutritionProductNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get nutritionProductNotFound;

  /// No description provided for @nutritionProductNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing is known for barcode {code}. Create the food item yourself?'**
  String nutritionProductNotFoundMessage(String code);

  /// No description provided for @nutritionProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get nutritionProtein;

  /// No description provided for @nutritionProteinLetter.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get nutritionProteinLetter;

  /// No description provided for @nutritionPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get nutritionPublic;

  /// No description provided for @nutritionQtyShort.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get nutritionQtyShort;

  /// No description provided for @nutritionQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get nutritionQuantity;

  /// No description provided for @nutritionRecipeCookTime.
  ///
  /// In en, this message translates to:
  /// **'Cook {minutes} min'**
  String nutritionRecipeCookTime(int minutes);

  /// No description provided for @nutritionRecipeFallback.
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get nutritionRecipeFallback;

  /// No description provided for @nutritionRecipeNameRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipe name *'**
  String get nutritionRecipeNameRequiredLabel;

  /// No description provided for @nutritionRecipePrepTime.
  ///
  /// In en, this message translates to:
  /// **'Prep {minutes} min'**
  String nutritionRecipePrepTime(int minutes);

  /// No description provided for @nutritionRecipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get nutritionRecipes;

  /// No description provided for @nutritionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get nutritionRemove;

  /// No description provided for @nutritionRemoveAssignmentMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will no longer be assigned.'**
  String nutritionRemoveAssignmentMessage(String name);

  /// No description provided for @nutritionRemoveAssignmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove assignment?'**
  String get nutritionRemoveAssignmentTitle;

  /// No description provided for @nutritionRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get nutritionRemoveImage;

  /// No description provided for @nutritionRemoveIngredient.
  ///
  /// In en, this message translates to:
  /// **'Remove ingredient'**
  String get nutritionRemoveIngredient;

  /// No description provided for @nutritionRemoveNamed.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String nutritionRemoveNamed(String name);

  /// No description provided for @nutritionRemovePermanently.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" permanently?'**
  String nutritionRemovePermanently(String name);

  /// No description provided for @nutritionRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get nutritionRemovePhoto;

  /// No description provided for @nutritionRemoveSlot.
  ///
  /// In en, this message translates to:
  /// **'Remove slot'**
  String get nutritionRemoveSlot;

  /// No description provided for @nutritionRemoveStep.
  ///
  /// In en, this message translates to:
  /// **'Remove step'**
  String get nutritionRemoveStep;

  /// No description provided for @nutritionRemoveVideo.
  ///
  /// In en, this message translates to:
  /// **'Remove video'**
  String get nutritionRemoveVideo;

  /// No description provided for @nutritionRemovedItem.
  ///
  /// In en, this message translates to:
  /// **'Removed {name}'**
  String nutritionRemovedItem(String name);

  /// No description provided for @nutritionRestFree.
  ///
  /// In en, this message translates to:
  /// **'Rest / Free'**
  String get nutritionRestFree;

  /// No description provided for @nutritionSaveComment.
  ///
  /// In en, this message translates to:
  /// **'Save comment'**
  String get nutritionSaveComment;

  /// No description provided for @nutritionScanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get nutritionScanBarcode;

  /// No description provided for @nutritionSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get nutritionSchedule;

  /// No description provided for @nutritionSearchDailyPlansHint.
  ///
  /// In en, this message translates to:
  /// **'Search daily plans…'**
  String get nutritionSearchDailyPlansHint;

  /// No description provided for @nutritionSearchFoodItemsHint.
  ///
  /// In en, this message translates to:
  /// **'Search food items…'**
  String get nutritionSearchFoodItemsHint;

  /// No description provided for @nutritionSearchFoodsAndRecipes.
  ///
  /// In en, this message translates to:
  /// **'Search foods and recipes'**
  String get nutritionSearchFoodsAndRecipes;

  /// No description provided for @nutritionSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get nutritionSearchHint;

  /// No description provided for @nutritionSearchMealPlansHint.
  ///
  /// In en, this message translates to:
  /// **'Search meal plans…'**
  String get nutritionSearchMealPlansHint;

  /// No description provided for @nutritionSearchMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Search members…'**
  String get nutritionSearchMembersHint;

  /// No description provided for @nutritionSearchRecipesHint.
  ///
  /// In en, this message translates to:
  /// **'Search recipes…'**
  String get nutritionSearchRecipesHint;

  /// No description provided for @nutritionSelectMealSlot.
  ///
  /// In en, this message translates to:
  /// **'Select Meal Slot'**
  String get nutritionSelectMealSlot;

  /// No description provided for @nutritionSelfAssigned.
  ///
  /// In en, this message translates to:
  /// **'Self-assigned'**
  String get nutritionSelfAssigned;

  /// No description provided for @nutritionSendComment.
  ///
  /// In en, this message translates to:
  /// **'Send comment'**
  String get nutritionSendComment;

  /// No description provided for @nutritionServingUnit.
  ///
  /// In en, this message translates to:
  /// **'Serving unit'**
  String get nutritionServingUnit;

  /// No description provided for @nutritionServings.
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get nutritionServings;

  /// No description provided for @nutritionServingsAmount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{amount} serving} other{{amount} servings}}'**
  String nutritionServingsAmount(num count, String amount);

  /// No description provided for @nutritionServingsRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Servings *'**
  String get nutritionServingsRequiredLabel;

  /// No description provided for @nutritionSetAsThumbnail.
  ///
  /// In en, this message translates to:
  /// **'Set as thumbnail'**
  String get nutritionSetAsThumbnail;

  /// No description provided for @nutritionShareHint.
  ///
  /// In en, this message translates to:
  /// **'What do you want to share?'**
  String get nutritionShareHint;

  /// No description provided for @nutritionSlotAfternoonSnack.
  ///
  /// In en, this message translates to:
  /// **'Afternoon Snack'**
  String get nutritionSlotAfternoonSnack;

  /// No description provided for @nutritionSlotBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get nutritionSlotBreakfast;

  /// No description provided for @nutritionSlotDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get nutritionSlotDinner;

  /// No description provided for @nutritionSlotEveningSnack.
  ///
  /// In en, this message translates to:
  /// **'Evening Snack'**
  String get nutritionSlotEveningSnack;

  /// No description provided for @nutritionSlotLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get nutritionSlotLunch;

  /// No description provided for @nutritionSlotMorningSnack.
  ///
  /// In en, this message translates to:
  /// **'Morning Snack'**
  String get nutritionSlotMorningSnack;

  /// No description provided for @nutritionSlotPostWorkout.
  ///
  /// In en, this message translates to:
  /// **'Post-Workout'**
  String get nutritionSlotPostWorkout;

  /// No description provided for @nutritionSlotPreWorkout.
  ///
  /// In en, this message translates to:
  /// **'Pre-Workout'**
  String get nutritionSlotPreWorkout;

  /// No description provided for @nutritionSpiceBlend.
  ///
  /// In en, this message translates to:
  /// **'Seasoning Blend'**
  String get nutritionSpiceBlend;

  /// No description provided for @nutritionSpiceDriedHerb.
  ///
  /// In en, this message translates to:
  /// **'Dried Herb'**
  String get nutritionSpiceDriedHerb;

  /// No description provided for @nutritionSpiceDryMarinade.
  ///
  /// In en, this message translates to:
  /// **'Dry Marinade'**
  String get nutritionSpiceDryMarinade;

  /// No description provided for @nutritionSpiceExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract / Essence'**
  String get nutritionSpiceExtract;

  /// No description provided for @nutritionSpiceGround.
  ///
  /// In en, this message translates to:
  /// **'Ground Spice'**
  String get nutritionSpiceGround;

  /// No description provided for @nutritionSpicePepper.
  ///
  /// In en, this message translates to:
  /// **'Pepper'**
  String get nutritionSpicePepper;

  /// No description provided for @nutritionSpiceRub.
  ///
  /// In en, this message translates to:
  /// **'Rub'**
  String get nutritionSpiceRub;

  /// No description provided for @nutritionSpiceSalt.
  ///
  /// In en, this message translates to:
  /// **'Salt'**
  String get nutritionSpiceSalt;

  /// No description provided for @nutritionSpiceSeed.
  ///
  /// In en, this message translates to:
  /// **'Spice Seed'**
  String get nutritionSpiceSeed;

  /// No description provided for @nutritionSpiceWhole.
  ///
  /// In en, this message translates to:
  /// **'Whole Spice'**
  String get nutritionSpiceWhole;

  /// No description provided for @nutritionStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation below.'**
  String get nutritionStartConversation;

  /// No description provided for @nutritionStartDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Start date (optional)'**
  String get nutritionStartDateOptional;

  /// No description provided for @nutritionStartsOn.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String nutritionStartsOn(String date);

  /// No description provided for @nutritionStepImageUrlOptional.
  ///
  /// In en, this message translates to:
  /// **'Step image URL (optional)'**
  String get nutritionStepImageUrlOptional;

  /// No description provided for @nutritionStepNumber.
  ///
  /// In en, this message translates to:
  /// **'Step {number}'**
  String nutritionStepNumber(int number);

  /// No description provided for @nutritionStepPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo for step {number}'**
  String nutritionStepPhoto(int number);

  /// No description provided for @nutritionSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get nutritionSteps;

  /// No description provided for @nutritionSubtypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get nutritionSubtypeOther;

  /// No description provided for @nutritionSubtypeRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtype *'**
  String get nutritionSubtypeRequiredLabel;

  /// No description provided for @nutritionSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get nutritionSystem;

  /// No description provided for @nutritionTabAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get nutritionTabAssigned;

  /// No description provided for @nutritionTabDailyPlans.
  ///
  /// In en, this message translates to:
  /// **'Daily Plans'**
  String get nutritionTabDailyPlans;

  /// No description provided for @nutritionTabFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get nutritionTabFood;

  /// No description provided for @nutritionTabMyDailyPlans.
  ///
  /// In en, this message translates to:
  /// **'My Daily Plans'**
  String get nutritionTabMyDailyPlans;

  /// No description provided for @nutritionTabMyFood.
  ///
  /// In en, this message translates to:
  /// **'My Food'**
  String get nutritionTabMyFood;

  /// No description provided for @nutritionTabMyLibrary.
  ///
  /// In en, this message translates to:
  /// **'My Library'**
  String get nutritionTabMyLibrary;

  /// No description provided for @nutritionTabMyMealPlans.
  ///
  /// In en, this message translates to:
  /// **'My Meal Plans'**
  String get nutritionTabMyMealPlans;

  /// No description provided for @nutritionTabMyRecipes.
  ///
  /// In en, this message translates to:
  /// **'My Recipes'**
  String get nutritionTabMyRecipes;

  /// No description provided for @nutritionTabPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get nutritionTabPlans;

  /// No description provided for @nutritionThumbnail.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail'**
  String get nutritionThumbnail;

  /// No description provided for @nutritionTitleOptional.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get nutritionTitleOptional;

  /// No description provided for @nutritionTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get nutritionTomorrow;

  /// No description provided for @nutritionTorchOff.
  ///
  /// In en, this message translates to:
  /// **'Turn torch off'**
  String get nutritionTorchOff;

  /// No description provided for @nutritionTorchOn.
  ///
  /// In en, this message translates to:
  /// **'Turn torch on'**
  String get nutritionTorchOn;

  /// No description provided for @nutritionTotals.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get nutritionTotals;

  /// No description provided for @nutritionTryAnotherSearch.
  ///
  /// In en, this message translates to:
  /// **'Try another search term.'**
  String get nutritionTryAnotherSearch;

  /// No description provided for @nutritionType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get nutritionType;

  /// No description provided for @nutritionTypeDrink.
  ///
  /// In en, this message translates to:
  /// **'Drink'**
  String get nutritionTypeDrink;

  /// No description provided for @nutritionTypeFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get nutritionTypeFood;

  /// No description provided for @nutritionTypeSpice.
  ///
  /// In en, this message translates to:
  /// **'Spice'**
  String get nutritionTypeSpice;

  /// No description provided for @nutritionUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get nutritionUnassigned;

  /// No description provided for @nutritionUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get nutritionUnit;

  /// No description provided for @nutritionUnitServings.
  ///
  /// In en, this message translates to:
  /// **'servings'**
  String get nutritionUnitServings;

  /// No description provided for @nutritionUnlike.
  ///
  /// In en, this message translates to:
  /// **'Unlike'**
  String get nutritionUnlike;

  /// No description provided for @nutritionUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload photo'**
  String get nutritionUploadPhoto;

  /// No description provided for @nutritionUsersDiary.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s diary'**
  String nutritionUsersDiary(String name);

  /// No description provided for @nutritionValuesPer.
  ///
  /// In en, this message translates to:
  /// **'Values {per100}'**
  String nutritionValuesPer(String per100);

  /// No description provided for @nutritionVideoNumber.
  ///
  /// In en, this message translates to:
  /// **'Video {number}'**
  String nutritionVideoNumber(int number);

  /// No description provided for @nutritionVideoUrl.
  ///
  /// In en, this message translates to:
  /// **'Video URL'**
  String get nutritionVideoUrl;

  /// No description provided for @nutritionVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get nutritionVideos;

  /// No description provided for @nutritionVisibleToAllUsers.
  ///
  /// In en, this message translates to:
  /// **'Visible to all users'**
  String get nutritionVisibleToAllUsers;

  /// No description provided for @nutritionVitamin.
  ///
  /// In en, this message translates to:
  /// **'Vitamin'**
  String get nutritionVitamin;

  /// No description provided for @nutritionVitamins.
  ///
  /// In en, this message translates to:
  /// **'Vitamins'**
  String get nutritionVitamins;

  /// No description provided for @nutritionWeekDay.
  ///
  /// In en, this message translates to:
  /// **'Week {week} · Day {day}'**
  String nutritionWeekDay(int week, int day);

  /// No description provided for @nutritionWeekNumber.
  ///
  /// In en, this message translates to:
  /// **'Week {number}'**
  String nutritionWeekNumber(int number);

  /// No description provided for @nutritionWeeksCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String nutritionWeeksCount(int count);

  /// No description provided for @nutritionWeeksShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 wk} other{{count} wks}}'**
  String nutritionWeeksShort(int count);

  /// No description provided for @nutritionWriteCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get nutritionWriteCommentHint;

  /// No description provided for @nutritionWriteSomethingFirst.
  ///
  /// In en, this message translates to:
  /// **'Write something first'**
  String get nutritionWriteSomethingFirst;

  /// No description provided for @nutritionYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get nutritionYesterday;

  /// No description provided for @nutritionYourCoachFallback.
  ///
  /// In en, this message translates to:
  /// **'your coach'**
  String get nutritionYourCoachFallback;

  /// No description provided for @nutritionYours.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get nutritionYours;

  /// No description provided for @peopleAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get peopleAccept;

  /// No description provided for @peopleAddFriend.
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get peopleAddFriend;

  /// No description provided for @peopleBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get peopleBio;

  /// No description provided for @peopleBioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell people about your training'**
  String get peopleBioHint;

  /// No description provided for @peopleBioLess.
  ///
  /// In en, this message translates to:
  /// **'less'**
  String get peopleBioLess;

  /// No description provided for @peopleBioMore.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get peopleBioMore;

  /// No description provided for @peopleBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get peopleBlock;

  /// No description provided for @peopleBlockBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to find your profile, see your posts or message you, and you won\'t see theirs. Follows and friendship between you are removed. They won\'t be notified.'**
  String get peopleBlockBody;

  /// No description provided for @peopleBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block @{username}?'**
  String peopleBlockTitle(String username);

  /// No description provided for @peopleBlockedSnack.
  ///
  /// In en, this message translates to:
  /// **'@{username} blocked'**
  String peopleBlockedSnack(String username);

  /// No description provided for @peopleBlockedStateBody.
  ///
  /// In en, this message translates to:
  /// **'Unblock to see their profile and interact again.'**
  String get peopleBlockedStateBody;

  /// No description provided for @peopleBlockedStateTitle.
  ///
  /// In en, this message translates to:
  /// **'You blocked this account'**
  String get peopleBlockedStateTitle;

  /// No description provided for @peopleBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get peopleBlockedUsers;

  /// No description provided for @peopleBlockedUsersEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone.'**
  String get peopleBlockedUsersEmpty;

  /// No description provided for @peopleBlockedUsersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'People you\'ve blocked'**
  String get peopleBlockedUsersSubtitle;

  /// No description provided for @peopleCancelFollowRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel your follow request to @{username}?'**
  String peopleCancelFollowRequestTitle(String username);

  /// No description provided for @peopleCancelFriendRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel your friend request to {name}?'**
  String peopleCancelFriendRequestTitle(String name);

  /// No description provided for @peopleCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get peopleCancelRequest;

  /// No description provided for @peopleCopyUsername.
  ///
  /// In en, this message translates to:
  /// **'Copy username'**
  String get peopleCopyUsername;

  /// No description provided for @peopleDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get peopleDecline;

  /// No description provided for @peopleDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get peopleDiscard;

  /// No description provided for @peopleDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get peopleDiscardTitle;

  /// No description provided for @peopleDiscoverable.
  ///
  /// In en, this message translates to:
  /// **'Appear in suggestions & nearby'**
  String get peopleDiscoverable;

  /// No description provided for @peopleDiscoverableHint.
  ///
  /// In en, this message translates to:
  /// **'People can still find you by searching your name.'**
  String get peopleDiscoverableHint;

  /// No description provided for @peopleDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get peopleDismiss;

  /// No description provided for @peopleDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'~{km} km'**
  String peopleDistanceKm(int km);

  /// No description provided for @peopleDistanceUnder1.
  ///
  /// In en, this message translates to:
  /// **'< 1 km'**
  String get peopleDistanceUnder1;

  /// No description provided for @peopleEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get peopleEditProfile;

  /// No description provided for @peopleEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get peopleEditTitle;

  /// No description provided for @peopleFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get peopleFollow;

  /// No description provided for @peopleFollowBack.
  ///
  /// In en, this message translates to:
  /// **'Follow back'**
  String get peopleFollowBack;

  /// No description provided for @peopleFollowRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 follow request} other{{count} follow requests}}'**
  String peopleFollowRequestsCount(int count);

  /// No description provided for @peopleFollowRequestsTab.
  ///
  /// In en, this message translates to:
  /// **'Follow requests'**
  String get peopleFollowRequestsTab;

  /// No description provided for @peopleFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get peopleFollowers;

  /// No description provided for @peopleFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get peopleFollowing;

  /// No description provided for @peopleFriendRequestFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} sent you a friend request'**
  String peopleFriendRequestFrom(String name);

  /// No description provided for @peopleFriendRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get peopleFriendRequestSent;

  /// No description provided for @peopleFriendRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 friend request} other{{count} friend requests}}'**
  String peopleFriendRequestsCount(int count);

  /// No description provided for @peopleFriendRequestsTab.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get peopleFriendRequestsTab;

  /// No description provided for @peopleFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get peopleFriends;

  /// No description provided for @peopleGoPublicBody.
  ///
  /// In en, this message translates to:
  /// **'Anyone will be able to see your posts and follower lists, and all pending follow requests will be accepted.'**
  String get peopleGoPublicBody;

  /// No description provided for @peopleGoPublicConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch to public'**
  String get peopleGoPublicConfirm;

  /// No description provided for @peopleGoPublicTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to a public account?'**
  String get peopleGoPublicTitle;

  /// No description provided for @peopleInterestBodybuilding.
  ///
  /// In en, this message translates to:
  /// **'Bodybuilding'**
  String get peopleInterestBodybuilding;

  /// No description provided for @peopleInterestBoxing.
  ///
  /// In en, this message translates to:
  /// **'Boxing'**
  String get peopleInterestBoxing;

  /// No description provided for @peopleInterestCalisthenics.
  ///
  /// In en, this message translates to:
  /// **'Calisthenics'**
  String get peopleInterestCalisthenics;

  /// No description provided for @peopleInterestClimbing.
  ///
  /// In en, this message translates to:
  /// **'Climbing'**
  String get peopleInterestClimbing;

  /// No description provided for @peopleInterestCrossfit.
  ///
  /// In en, this message translates to:
  /// **'CrossFit'**
  String get peopleInterestCrossfit;

  /// No description provided for @peopleInterestCycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get peopleInterestCycling;

  /// No description provided for @peopleInterestHiit.
  ///
  /// In en, this message translates to:
  /// **'HIIT'**
  String get peopleInterestHiit;

  /// No description provided for @peopleInterestHiking.
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get peopleInterestHiking;

  /// No description provided for @peopleInterestMealPrep.
  ///
  /// In en, this message translates to:
  /// **'Meal prep'**
  String get peopleInterestMealPrep;

  /// No description provided for @peopleInterestMobility.
  ///
  /// In en, this message translates to:
  /// **'Mobility'**
  String get peopleInterestMobility;

  /// No description provided for @peopleInterestNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get peopleInterestNutrition;

  /// No description provided for @peopleInterestOlympicLifting.
  ///
  /// In en, this message translates to:
  /// **'Olympic lifting'**
  String get peopleInterestOlympicLifting;

  /// No description provided for @peopleInterestPilates.
  ///
  /// In en, this message translates to:
  /// **'Pilates'**
  String get peopleInterestPilates;

  /// No description provided for @peopleInterestPowerlifting.
  ///
  /// In en, this message translates to:
  /// **'Powerlifting'**
  String get peopleInterestPowerlifting;

  /// No description provided for @peopleInterestRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove {interest}'**
  String peopleInterestRemove(String interest);

  /// No description provided for @peopleInterestRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get peopleInterestRunning;

  /// No description provided for @peopleInterestStrongman.
  ///
  /// In en, this message translates to:
  /// **'Strongman'**
  String get peopleInterestStrongman;

  /// No description provided for @peopleInterestSwimming.
  ///
  /// In en, this message translates to:
  /// **'Swimming'**
  String get peopleInterestSwimming;

  /// No description provided for @peopleInterestYoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get peopleInterestYoga;

  /// No description provided for @peopleInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get peopleInterests;

  /// No description provided for @peopleInterestsHint.
  ///
  /// In en, this message translates to:
  /// **'Add an interest'**
  String get peopleInterestsHint;

  /// No description provided for @peopleInterestsMax.
  ///
  /// In en, this message translates to:
  /// **'Up to {max} interests'**
  String peopleInterestsMax(int max);

  /// No description provided for @peopleKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get peopleKeep;

  /// No description provided for @peopleListEmptyFollowers.
  ///
  /// In en, this message translates to:
  /// **'No followers yet'**
  String get peopleListEmptyFollowers;

  /// No description provided for @peopleListEmptyFollowing.
  ///
  /// In en, this message translates to:
  /// **'Not following anyone yet'**
  String get peopleListEmptyFollowing;

  /// No description provided for @peopleListEmptyFriends.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get peopleListEmptyFriends;

  /// No description provided for @peopleListEmptyMutual.
  ///
  /// In en, this message translates to:
  /// **'No mutual friends'**
  String get peopleListEmptyMutual;

  /// No description provided for @peopleLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is off. You can turn it on in your phone\'s settings.'**
  String get peopleLocationDenied;

  /// No description provided for @peopleLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location. Try again.'**
  String get peopleLocationFailed;

  /// No description provided for @peopleLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Not sharing your location'**
  String get peopleLocationOff;

  /// No description provided for @peopleLocationOn.
  ///
  /// In en, this message translates to:
  /// **'Sharing your approximate location (about 1 km)'**
  String get peopleLocationOn;

  /// No description provided for @peopleLocationOnUpdated.
  ///
  /// In en, this message translates to:
  /// **'Sharing your approximate location · updated {when}'**
  String peopleLocationOnUpdated(String when);

  /// No description provided for @peopleLocationSection.
  ///
  /// In en, this message translates to:
  /// **'Location sharing'**
  String get peopleLocationSection;

  /// No description provided for @peopleLocationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to find people nearby.'**
  String get peopleLocationServiceOff;

  /// No description provided for @peopleLocationStop.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get peopleLocationStop;

  /// No description provided for @peopleLocationStopped.
  ///
  /// In en, this message translates to:
  /// **'Location sharing stopped'**
  String get peopleLocationStopped;

  /// No description provided for @peopleLocationUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get peopleLocationUpdate;

  /// No description provided for @peopleLocationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Location updated'**
  String get peopleLocationUpdated;

  /// No description provided for @peopleLocked.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get peopleLocked;

  /// No description provided for @peopleMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get peopleMessage;

  /// No description provided for @peopleMessageRequestHint.
  ///
  /// In en, this message translates to:
  /// **'Your message will arrive as a request'**
  String get peopleMessageRequestHint;

  /// No description provided for @peopleMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get peopleMoreOptions;

  /// No description provided for @peopleMoreSuggestions.
  ///
  /// In en, this message translates to:
  /// **'More suggestions'**
  String get peopleMoreSuggestions;

  /// No description provided for @peopleMutual.
  ///
  /// In en, this message translates to:
  /// **'Mutual'**
  String get peopleMutual;

  /// No description provided for @peopleMutualFriendsMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Friends with {a}, {b} and 1 other} other{Friends with {a}, {b} and {count} others}}'**
  String peopleMutualFriendsMore(int count, String a, String b);

  /// No description provided for @peopleMutualFriendsOne.
  ///
  /// In en, this message translates to:
  /// **'Friends with {a}'**
  String peopleMutualFriendsOne(String a);

  /// No description provided for @peopleMutualFriendsTwo.
  ///
  /// In en, this message translates to:
  /// **'Friends with {a} and {b}'**
  String peopleMutualFriendsTwo(String a, String b);

  /// No description provided for @peopleNearbyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one within {km} km yet.'**
  String peopleNearbyEmpty(int km);

  /// No description provided for @peopleNearbyPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'We store your location rounded to about 1 km and only use it to show distances. Your exact location is never shared with anyone.'**
  String get peopleNearbyPrivacyBody;

  /// No description provided for @peopleNearbyPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'See people training near you'**
  String get peopleNearbyPrivacyTitle;

  /// No description provided for @peopleNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get peopleNearbyTitle;

  /// No description provided for @peopleNoFollowRequests.
  ///
  /// In en, this message translates to:
  /// **'No follow requests'**
  String get peopleNoFollowRequests;

  /// No description provided for @peopleNoFollowRequestsHint.
  ///
  /// In en, this message translates to:
  /// **'When your account is private, people who want to follow you show up here.'**
  String get peopleNoFollowRequestsHint;

  /// No description provided for @peopleNoFriendRequests.
  ///
  /// In en, this message translates to:
  /// **'No friend requests'**
  String get peopleNoFriendRequests;

  /// No description provided for @peopleNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No one matches “{query}”'**
  String peopleNoMatches(String query);

  /// No description provided for @peopleNoPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get peopleNoPosts;

  /// No description provided for @peopleNoSentRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests you\'ve sent'**
  String get peopleNoSentRequests;

  /// No description provided for @peopleNoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No suggestions right now. Check in at your gym or add interests to your profile to get better ones.'**
  String get peopleNoSuggestions;

  /// No description provided for @peopleNonFollowerMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages from non-followers'**
  String get peopleNonFollowerMessages;

  /// No description provided for @peopleNonFollowerMessagesOff.
  ///
  /// In en, this message translates to:
  /// **'Only your approved followers can message you.'**
  String get peopleNonFollowerMessagesOff;

  /// No description provided for @peopleNonFollowerMessagesPrivate.
  ///
  /// In en, this message translates to:
  /// **'People you haven\'t approved as followers can send you message requests.'**
  String get peopleNonFollowerMessagesPrivate;

  /// No description provided for @peopleNonFollowerMessagesPublic.
  ///
  /// In en, this message translates to:
  /// **'People who don\'t follow you can message you directly.'**
  String get peopleNonFollowerMessagesPublic;

  /// No description provided for @peoplePosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get peoplePosts;

  /// No description provided for @peoplePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get peoplePrivacy;

  /// No description provided for @peoplePrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Private account, messages, activity status'**
  String get peoplePrivacySubtitle;

  /// No description provided for @peoplePrivateAccount.
  ///
  /// In en, this message translates to:
  /// **'Private account'**
  String get peoplePrivateAccount;

  /// No description provided for @peoplePrivateAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Only people you approve see your photos, videos and follower lists. Anyone can still find you and see your comments and reactions.'**
  String get peoplePrivateAccountHint;

  /// No description provided for @peoplePrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Follow to see their photos and videos.'**
  String get peoplePrivateBody;

  /// No description provided for @peoplePrivateRequestedBody.
  ///
  /// In en, this message translates to:
  /// **'Your follow request is pending. You\'ll see their photos and videos once they accept.'**
  String get peoplePrivateRequestedBody;

  /// No description provided for @peoplePrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'This account is private'**
  String get peoplePrivateTitle;

  /// No description provided for @peopleProfileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This profile isn\'t available.'**
  String get peopleProfileUnavailable;

  /// No description provided for @peopleRadiusKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String peopleRadiusKm(int km);

  /// No description provided for @peopleReasonFollowsYou.
  ///
  /// In en, this message translates to:
  /// **'Follows you'**
  String get peopleReasonFollowsYou;

  /// No description provided for @peopleReasonInterests.
  ///
  /// In en, this message translates to:
  /// **'Also into {interests}'**
  String peopleReasonInterests(String interests);

  /// No description provided for @peopleReasonMutual.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 mutual friend} other{{count} mutual friends}}'**
  String peopleReasonMutual(int count);

  /// No description provided for @peopleReasonNearby.
  ///
  /// In en, this message translates to:
  /// **'~{km} km away'**
  String peopleReasonNearby(int km);

  /// No description provided for @peopleReasonNearbyUnder1.
  ///
  /// In en, this message translates to:
  /// **'Less than 1 km away'**
  String get peopleReasonNearbyUnder1;

  /// No description provided for @peopleReasonSameClass.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Took the same class} other{Took {count} of the same classes}}'**
  String peopleReasonSameClass(int count);

  /// No description provided for @peopleReasonSameGym.
  ///
  /// In en, this message translates to:
  /// **'Goes to {gym}'**
  String peopleReasonSameGym(String gym);

  /// No description provided for @peopleReasonSameTime.
  ///
  /// In en, this message translates to:
  /// **'Trains at the same times'**
  String get peopleReasonSameTime;

  /// No description provided for @peopleRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get peopleRemove;

  /// No description provided for @peopleRemoveFollower.
  ///
  /// In en, this message translates to:
  /// **'Remove follower'**
  String get peopleRemoveFollower;

  /// No description provided for @peopleRemoveFollowerBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be notified that you removed them.'**
  String get peopleRemoveFollowerBody;

  /// No description provided for @peopleRemoveFollowerTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove @{username} from your followers?'**
  String peopleRemoveFollowerTitle(String username);

  /// No description provided for @peopleRemoveFriend.
  ///
  /// In en, this message translates to:
  /// **'Remove friend'**
  String get peopleRemoveFriend;

  /// No description provided for @peopleRemoveFriendBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll stay followers of each other unless you also unfollow.'**
  String get peopleRemoveFriendBody;

  /// No description provided for @peopleRemoveFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from your friends?'**
  String peopleRemoveFriendTitle(String name);

  /// No description provided for @peopleReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get peopleReport;

  /// No description provided for @peopleReportDetails.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get peopleReportDetails;

  /// No description provided for @peopleReportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get peopleReportReasonHarassment;

  /// No description provided for @peopleReportReasonImpersonation.
  ///
  /// In en, this message translates to:
  /// **'Pretending to be someone else'**
  String get peopleReportReasonImpersonation;

  /// No description provided for @peopleReportReasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get peopleReportReasonInappropriate;

  /// No description provided for @peopleReportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get peopleReportReasonOther;

  /// No description provided for @peopleReportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get peopleReportReasonSpam;

  /// No description provided for @peopleReportSend.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get peopleReportSend;

  /// No description provided for @peopleReportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks. Our team will review your report.'**
  String get peopleReportSent;

  /// No description provided for @peopleReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report @{username}'**
  String peopleReportTitle(String username);

  /// No description provided for @peopleReportWhy.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this account?'**
  String get peopleReportWhy;

  /// No description provided for @peopleRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get peopleRequested;

  /// No description provided for @peopleRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow and friend requests'**
  String get peopleRequestsSubtitle;

  /// No description provided for @peopleRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get peopleRequestsTitle;

  /// No description provided for @peopleRespond.
  ///
  /// In en, this message translates to:
  /// **'Respond'**
  String get peopleRespond;

  /// No description provided for @peopleSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get peopleSaved;

  /// No description provided for @peopleSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or username'**
  String get peopleSearchHint;

  /// No description provided for @peopleSearchInList.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get peopleSearchInList;

  /// No description provided for @peopleSentTab.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get peopleSentTab;

  /// No description provided for @peopleSettingSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get peopleSettingSaved;

  /// No description provided for @peopleShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get peopleShare;

  /// No description provided for @peopleShareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share my location'**
  String get peopleShareLocation;

  /// No description provided for @peopleShowActivity.
  ///
  /// In en, this message translates to:
  /// **'Show activity status'**
  String get peopleShowActivity;

  /// No description provided for @peopleShowActivityHint.
  ///
  /// In en, this message translates to:
  /// **'People you\'re connected with can see when you were last active.'**
  String get peopleShowActivityHint;

  /// No description provided for @peopleSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'People you may know'**
  String get peopleSuggestionsTitle;

  /// No description provided for @peopleTrainsAt.
  ///
  /// In en, this message translates to:
  /// **'Trains at {gyms}'**
  String peopleTrainsAt(String gyms);

  /// No description provided for @peopleUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get peopleUnblock;

  /// No description provided for @peopleUnblockedSnack.
  ///
  /// In en, this message translates to:
  /// **'@{username} unblocked'**
  String peopleUnblockedSnack(String username);

  /// No description provided for @peopleUnfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get peopleUnfollow;

  /// No description provided for @peopleUnfollowPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'This account is private. You\'ll have to request again to see their photos and videos.'**
  String get peopleUnfollowPrivateBody;

  /// No description provided for @peopleUnfollowTitle.
  ///
  /// In en, this message translates to:
  /// **'Unfollow @{username}?'**
  String peopleUnfollowTitle(String username);

  /// No description provided for @peopleUsernameCopied.
  ///
  /// In en, this message translates to:
  /// **'Username copied'**
  String get peopleUsernameCopied;

  /// No description provided for @peopleUsernameInvalid.
  ///
  /// In en, this message translates to:
  /// **'3–30 letters, numbers, dots or underscores'**
  String get peopleUsernameInvalid;

  /// No description provided for @peopleUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is taken'**
  String get peopleUsernameTaken;

  /// No description provided for @peopleViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get peopleViewProfile;

  /// No description provided for @planAddFood.
  ///
  /// In en, this message translates to:
  /// **'Add food'**
  String get planAddFood;

  /// No description provided for @planCalendarDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get planCalendarDone;

  /// No description provided for @planCalendarMealSemantics.
  ///
  /// In en, this message translates to:
  /// **'Meal: {title}'**
  String planCalendarMealSemantics(String title);

  /// No description provided for @planCalendarPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get planCalendarPlanned;

  /// No description provided for @planCalendarSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get planCalendarSkipped;

  /// No description provided for @planCalendarWorkoutSemantics.
  ///
  /// In en, this message translates to:
  /// **'Workout: {title}'**
  String planCalendarWorkoutSemantics(String title);

  /// No description provided for @planConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm as planned'**
  String get planConfirm;

  /// No description provided for @planConfirmedMeal.
  ///
  /// In en, this message translates to:
  /// **'Meal logged as planned'**
  String get planConfirmedMeal;

  /// No description provided for @planConfirmedWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout logged as planned'**
  String get planConfirmedWorkout;

  /// No description provided for @planEditDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get planEditDate;

  /// No description provided for @planEditDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get planEditDuration;

  /// No description provided for @planEditMealTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit planned meal'**
  String get planEditMealTitle;

  /// No description provided for @planEditNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get planEditNote;

  /// No description provided for @planEditTime.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get planEditTime;

  /// No description provided for @planEditTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get planEditTraining;

  /// No description provided for @planEditWorkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit planned workout'**
  String get planEditWorkoutTitle;

  /// No description provided for @planEditedBadge.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get planEditedBadge;

  /// No description provided for @planEnrolAssignMember.
  ///
  /// In en, this message translates to:
  /// **'Assign to a member'**
  String get planEnrolAssignMember;

  /// No description provided for @planEnrolAssignedBy.
  ///
  /// In en, this message translates to:
  /// **'Assigned by {name}'**
  String planEnrolAssignedBy(String name);

  /// No description provided for @planEnrolClearEnd.
  ///
  /// In en, this message translates to:
  /// **'Remove end date'**
  String get planEnrolClearEnd;

  /// No description provided for @planEnrolDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Start {name}'**
  String planEnrolDialogTitle(String name);

  /// No description provided for @planEnrolEndDate.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get planEnrolEndDate;

  /// No description provided for @planEnrolLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get planEnrolLeave;

  /// No description provided for @planEnrolLeavePlanBody.
  ///
  /// In en, this message translates to:
  /// **'Its planned meals are removed from your Schedule. Food you\'ve logged stays.'**
  String get planEnrolLeavePlanBody;

  /// No description provided for @planEnrolLeaveRoutineBody.
  ///
  /// In en, this message translates to:
  /// **'Its planned workouts are removed from your Schedule. Workouts you\'ve logged stay.'**
  String get planEnrolLeaveRoutineBody;

  /// No description provided for @planEnrolLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}?'**
  String planEnrolLeaveTitle(String name);

  /// No description provided for @planEnrolLeft.
  ///
  /// In en, this message translates to:
  /// **'You left {name}'**
  String planEnrolLeft(String name);

  /// No description provided for @planEnrolManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get planEnrolManage;

  /// No description provided for @planEnrolManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage {name}'**
  String planEnrolManageTitle(String name);

  /// No description provided for @planEnrolMealHint.
  ///
  /// In en, this message translates to:
  /// **'Each day\'s meals go on your Schedule at their usual times.'**
  String get planEnrolMealHint;

  /// No description provided for @planEnrolNoCalendar.
  ///
  /// In en, this message translates to:
  /// **'No fixed days, so not on your Schedule'**
  String get planEnrolNoCalendar;

  /// No description provided for @planEnrolNoEnd.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get planEnrolNoEnd;

  /// No description provided for @planEnrolNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get planEnrolNote;

  /// No description provided for @planEnrolOpenSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get planEnrolOpenSchedule;

  /// No description provided for @planEnrolRoutineHint.
  ///
  /// In en, this message translates to:
  /// **'Its workouts go on your Schedule on their days, at the time you choose.'**
  String get planEnrolRoutineHint;

  /// No description provided for @planEnrolSince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String planEnrolSince(String date);

  /// No description provided for @planEnrolStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get planEnrolStart;

  /// No description provided for @planEnrolStartDate.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get planEnrolStartDate;

  /// No description provided for @planEnrolStartPlan.
  ///
  /// In en, this message translates to:
  /// **'Start this meal plan'**
  String get planEnrolStartPlan;

  /// No description provided for @planEnrolStartRoutine.
  ///
  /// In en, this message translates to:
  /// **'Start this routine'**
  String get planEnrolStartRoutine;

  /// No description provided for @planEnrolStarted.
  ///
  /// In en, this message translates to:
  /// **'You started {name}'**
  String planEnrolStarted(String name);

  /// No description provided for @planEnrolUntil.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String planEnrolUntil(String date);

  /// No description provided for @planEnrolUpdated.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get planEnrolUpdated;

  /// No description provided for @planEnrolWildcardHint.
  ///
  /// In en, this message translates to:
  /// **'This routine has no fixed days, so nothing is added to your Schedule — pick one of its trainings whenever you work out.'**
  String get planEnrolWildcardHint;

  /// No description provided for @planEnrolWorkoutTime.
  ///
  /// In en, this message translates to:
  /// **'Workout time'**
  String get planEnrolWorkoutTime;

  /// No description provided for @planEnrolWorkoutsAt.
  ///
  /// In en, this message translates to:
  /// **'Workouts at {time}'**
  String planEnrolWorkoutsAt(String time);

  /// No description provided for @planEnrolledPlan.
  ///
  /// In en, this message translates to:
  /// **'You\'re following this meal plan'**
  String get planEnrolledPlan;

  /// No description provided for @planEnrolledRoutine.
  ///
  /// In en, this message translates to:
  /// **'You\'re following this routine'**
  String get planEnrolledRoutine;

  /// No description provided for @planExercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get planExercises;

  /// No description provided for @planFromSource.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String planFromSource(String name);

  /// No description provided for @planLogDifferently.
  ///
  /// In en, this message translates to:
  /// **'Log differently'**
  String get planLogDifferently;

  /// No description provided for @planLogMeal.
  ///
  /// In en, this message translates to:
  /// **'Log meal'**
  String get planLogMeal;

  /// No description provided for @planLogMealHint.
  ///
  /// In en, this message translates to:
  /// **'{slot} · add food or a recipe'**
  String planLogMealHint(String slot);

  /// No description provided for @planLogWorkout.
  ///
  /// In en, this message translates to:
  /// **'Log workout'**
  String get planLogWorkout;

  /// No description provided for @planLogWorkoutHint.
  ///
  /// In en, this message translates to:
  /// **'Exercises, sets and weights'**
  String get planLogWorkoutHint;

  /// No description provided for @planLoggedItems.
  ///
  /// In en, this message translates to:
  /// **'Logged'**
  String get planLoggedItems;

  /// No description provided for @planMealFallback.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get planMealFallback;

  /// No description provided for @planMealItemsKcal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}} · {kcal} kcal'**
  String planMealItemsKcal(int count, int kcal);

  /// No description provided for @planNoExercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises in this training.'**
  String get planNoExercises;

  /// No description provided for @planNoItems.
  ///
  /// In en, this message translates to:
  /// **'Nothing is planned for this meal.'**
  String get planNoItems;

  /// No description provided for @planOpenDiary.
  ///
  /// In en, this message translates to:
  /// **'Open food diary'**
  String get planOpenDiary;

  /// No description provided for @planOpenWorkout.
  ///
  /// In en, this message translates to:
  /// **'Open workout'**
  String get planOpenWorkout;

  /// No description provided for @planPlannedItems.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get planPlannedItems;

  /// No description provided for @planRestoredSnack.
  ///
  /// In en, this message translates to:
  /// **'Back on your plan'**
  String get planRestoredSnack;

  /// No description provided for @planScheduleEmptyDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this day. Tap an hour to log a workout or a meal.'**
  String get planScheduleEmptyDay;

  /// No description provided for @planScheduleHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your classes, workouts and meals'**
  String get planScheduleHubSubtitle;

  /// No description provided for @planSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get planSkip;

  /// No description provided for @planSkippedSnack.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get planSkippedSnack;

  /// No description provided for @planSlotLabel.
  ///
  /// In en, this message translates to:
  /// **'{time}, log a workout or a meal'**
  String planSlotLabel(String time);

  /// No description provided for @planTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get planTotal;

  /// No description provided for @planUnskip.
  ///
  /// In en, this message translates to:
  /// **'Put back on the plan'**
  String get planUnskip;

  /// No description provided for @planWorkoutFallback.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get planWorkoutFallback;

  /// No description provided for @postShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share as post'**
  String get postShareAction;

  /// No description provided for @postShareBestReps.
  ///
  /// In en, this message translates to:
  /// **'best {reps} reps'**
  String postShareBestReps(int reps);

  /// No description provided for @postShareBestSet.
  ///
  /// In en, this message translates to:
  /// **'best {weight} × {reps}'**
  String postShareBestSet(String weight, int reps);

  /// No description provided for @postShareCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Say something about it…'**
  String get postShareCaptionHint;

  /// No description provided for @postShareDaysPlanned.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day planned} other{{count} days planned}}'**
  String postShareDaysPlanned(int count);

  /// No description provided for @postShareExercises.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise} other{{count} exercises}}'**
  String postShareExercises(int count);

  /// No description provided for @postShareFutureBlocked.
  ///
  /// In en, this message translates to:
  /// **'You can share this once it has happened'**
  String get postShareFutureBlocked;

  /// No description provided for @postShareMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String postShareMinutes(int count);

  /// No description provided for @postShareMoreItems.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String postShareMoreItems(int count);

  /// No description provided for @postSharePer100.
  ///
  /// In en, this message translates to:
  /// **'per 100 {unit}'**
  String postSharePer100(String unit);

  /// No description provided for @postSharePerDay.
  ///
  /// In en, this message translates to:
  /// **'per day'**
  String get postSharePerDay;

  /// No description provided for @postSharePerServing.
  ///
  /// In en, this message translates to:
  /// **'per serving'**
  String get postSharePerServing;

  /// No description provided for @postSharePosted.
  ///
  /// In en, this message translates to:
  /// **'Shared to your feed'**
  String get postSharePosted;

  /// No description provided for @postShareRemove.
  ///
  /// In en, this message translates to:
  /// **'Don\'t share this'**
  String get postShareRemove;

  /// No description provided for @postShareServings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 serving} other{{count} servings}}'**
  String postShareServings(int count);

  /// No description provided for @postShareSets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String postShareSets(int count);

  /// No description provided for @postShareShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get postShareShareAction;

  /// No description provided for @postShareSharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get postShareSharing;

  /// No description provided for @postShareSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available anymore'**
  String get postShareSourceUnavailable;

  /// No description provided for @postShareTypeDailyMealPlan.
  ///
  /// In en, this message translates to:
  /// **'Day plan'**
  String get postShareTypeDailyMealPlan;

  /// No description provided for @postShareTypeExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get postShareTypeExercise;

  /// No description provided for @postShareTypeFoodItem.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get postShareTypeFoodItem;

  /// No description provided for @postShareTypeGeneric.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postShareTypeGeneric;

  /// No description provided for @postShareTypeMeal.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get postShareTypeMeal;

  /// No description provided for @postShareTypeMealPlan.
  ///
  /// In en, this message translates to:
  /// **'Meal program'**
  String get postShareTypeMealPlan;

  /// No description provided for @postShareTypeRecipe.
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get postShareTypeRecipe;

  /// No description provided for @postShareTypeRoutine.
  ///
  /// In en, this message translates to:
  /// **'Workout program'**
  String get postShareTypeRoutine;

  /// No description provided for @postShareTypeTraining.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get postShareTypeTraining;

  /// No description provided for @postShareTypeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get postShareTypeWorkout;

  /// No description provided for @postShareWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String postShareWeeks(int count);

  /// No description provided for @postShareWorkoutFinished.
  ///
  /// In en, this message translates to:
  /// **'Workout finished'**
  String get postShareWorkoutFinished;

  /// No description provided for @postShareWorkoutLogged.
  ///
  /// In en, this message translates to:
  /// **'Workout logged'**
  String get postShareWorkoutLogged;

  /// No description provided for @postShareWorkouts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 workout} other{{count} workouts}}'**
  String postShareWorkouts(int count);

  /// No description provided for @reactionAngry.
  ///
  /// In en, this message translates to:
  /// **'Angry'**
  String get reactionAngry;

  /// No description provided for @reactionCelebrate.
  ///
  /// In en, this message translates to:
  /// **'Celebrate'**
  String get reactionCelebrate;

  /// No description provided for @reactionClap.
  ///
  /// In en, this message translates to:
  /// **'Clap'**
  String get reactionClap;

  /// No description provided for @reactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reaction} other{{count} reactions}}'**
  String reactionCount(int count);

  /// No description provided for @reactionFire.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get reactionFire;

  /// No description provided for @reactionHaha.
  ///
  /// In en, this message translates to:
  /// **'Haha'**
  String get reactionHaha;

  /// No description provided for @reactionLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get reactionLike;

  /// No description provided for @reactionLove.
  ///
  /// In en, this message translates to:
  /// **'Love'**
  String get reactionLove;

  /// No description provided for @reactionPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Hold to pick a reaction'**
  String get reactionPickerHint;

  /// No description provided for @reactionSad.
  ///
  /// In en, this message translates to:
  /// **'Sad'**
  String get reactionSad;

  /// No description provided for @reactionStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get reactionStrong;

  /// No description provided for @reactionWow.
  ///
  /// In en, this message translates to:
  /// **'Wow'**
  String get reactionWow;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageSerbian.
  ///
  /// In en, this message translates to:
  /// **'Srpski'**
  String get settingsLanguageSerbian;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @shareBusinessAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareBusinessAction;

  /// No description provided for @shareProductAction.
  ///
  /// In en, this message translates to:
  /// **'Share product'**
  String get shareProductAction;

  /// No description provided for @shareProfileAction.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get shareProfileAction;

  /// No description provided for @shareSendAction.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get shareSendAction;

  /// No description provided for @shareSheetAddToStory.
  ///
  /// In en, this message translates to:
  /// **'Add to story'**
  String get shareSheetAddToStory;

  /// No description provided for @shareSheetFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send: {error}'**
  String shareSheetFailed(String error);

  /// No description provided for @shareSheetGroupMembers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String shareSheetGroupMembers(int count);

  /// No description provided for @shareSheetLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your chats'**
  String get shareSheetLoadFailed;

  /// No description provided for @shareSheetMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get shareSheetMessageHint;

  /// No description provided for @shareSheetNoChats.
  ///
  /// In en, this message translates to:
  /// **'No chats yet — search for someone to send this to.'**
  String get shareSheetNoChats;

  /// No description provided for @shareSheetNoResults.
  ///
  /// In en, this message translates to:
  /// **'No one found'**
  String get shareSheetNoResults;

  /// No description provided for @shareSheetPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get shareSheetPeople;

  /// No description provided for @shareSheetRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent chats'**
  String get shareSheetRecent;

  /// No description provided for @shareSheetSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get shareSheetSearchHint;

  /// No description provided for @shareSheetSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get shareSheetSend;

  /// No description provided for @shareSheetSendTo.
  ///
  /// In en, this message translates to:
  /// **'Send to {count}'**
  String shareSheetSendTo(int count);

  /// No description provided for @shareSheetSent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Sent} other{Sent to {count} chats}}'**
  String shareSheetSent(int count);

  /// No description provided for @shareSheetShareAsPost.
  ///
  /// In en, this message translates to:
  /// **'Share as post'**
  String get shareSheetShareAsPost;

  /// No description provided for @shareSheetSomeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send to {names}'**
  String shareSheetSomeFailed(String names);

  /// No description provided for @shareSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareSheetTitle;

  /// No description provided for @sharedExpiredStoryBody.
  ///
  /// In en, this message translates to:
  /// **'Stories are only visible for 24 hours.'**
  String get sharedExpiredStoryBody;

  /// No description provided for @sharedExpiredStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Story expired'**
  String get sharedExpiredStoryTitle;

  /// No description provided for @sharedKindGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get sharedKindGym;

  /// No description provided for @sharedKindPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get sharedKindPost;

  /// No description provided for @sharedKindProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get sharedKindProduct;

  /// No description provided for @sharedKindProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get sharedKindProfile;

  /// No description provided for @sharedKindShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get sharedKindShop;

  /// No description provided for @sharedKindStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get sharedKindStory;

  /// No description provided for @sharedLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get sharedLoading;

  /// No description provided for @sharedPostOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s post'**
  String sharedPostOf(String name);

  /// No description provided for @sharedPreviewBusiness.
  ///
  /// In en, this message translates to:
  /// **'Shared a page'**
  String get sharedPreviewBusiness;

  /// No description provided for @sharedPreviewDayPlan.
  ///
  /// In en, this message translates to:
  /// **'Shared a day plan'**
  String get sharedPreviewDayPlan;

  /// No description provided for @sharedPreviewExercise.
  ///
  /// In en, this message translates to:
  /// **'Shared an exercise'**
  String get sharedPreviewExercise;

  /// No description provided for @sharedPreviewFood.
  ///
  /// In en, this message translates to:
  /// **'Shared a food'**
  String get sharedPreviewFood;

  /// No description provided for @sharedPreviewMeal.
  ///
  /// In en, this message translates to:
  /// **'Shared a meal'**
  String get sharedPreviewMeal;

  /// No description provided for @sharedPreviewMealPlan.
  ///
  /// In en, this message translates to:
  /// **'Shared a meal program'**
  String get sharedPreviewMealPlan;

  /// No description provided for @sharedPreviewPost.
  ///
  /// In en, this message translates to:
  /// **'Shared a post'**
  String get sharedPreviewPost;

  /// No description provided for @sharedPreviewProduct.
  ///
  /// In en, this message translates to:
  /// **'Shared a product'**
  String get sharedPreviewProduct;

  /// No description provided for @sharedPreviewProfile.
  ///
  /// In en, this message translates to:
  /// **'Shared a profile'**
  String get sharedPreviewProfile;

  /// No description provided for @sharedPreviewRecipe.
  ///
  /// In en, this message translates to:
  /// **'Shared a recipe'**
  String get sharedPreviewRecipe;

  /// No description provided for @sharedPreviewRoutine.
  ///
  /// In en, this message translates to:
  /// **'Shared a workout program'**
  String get sharedPreviewRoutine;

  /// No description provided for @sharedPreviewStory.
  ///
  /// In en, this message translates to:
  /// **'Shared a story'**
  String get sharedPreviewStory;

  /// No description provided for @sharedPreviewWorkout.
  ///
  /// In en, this message translates to:
  /// **'Shared a workout'**
  String get sharedPreviewWorkout;

  /// No description provided for @sharedPrivateChip.
  ///
  /// In en, this message translates to:
  /// **'Private account'**
  String get sharedPrivateChip;

  /// No description provided for @sharedPrivateItemBody.
  ///
  /// In en, this message translates to:
  /// **'Only its author and people it\'s shared with can see it.'**
  String get sharedPrivateItemBody;

  /// No description provided for @sharedPrivateItemTitle.
  ///
  /// In en, this message translates to:
  /// **'{kind} is private'**
  String sharedPrivateItemTitle(String kind);

  /// No description provided for @sharedPrivatePostBody.
  ///
  /// In en, this message translates to:
  /// **'Only approved followers can see this post.'**
  String get sharedPrivatePostBody;

  /// No description provided for @sharedPrivatePostTitle.
  ///
  /// In en, this message translates to:
  /// **'This account is private'**
  String get sharedPrivatePostTitle;

  /// No description provided for @sharedPrivateStoryBody.
  ///
  /// In en, this message translates to:
  /// **'Only approved followers can see this story.'**
  String get sharedPrivateStoryBody;

  /// No description provided for @sharedPrivateStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'This story is private'**
  String get sharedPrivateStoryTitle;

  /// No description provided for @sharedStoryExpiredShort.
  ///
  /// In en, this message translates to:
  /// **'Story expired'**
  String get sharedStoryExpiredShort;

  /// No description provided for @sharedStoryGoneShort.
  ///
  /// In en, this message translates to:
  /// **'Story unavailable'**
  String get sharedStoryGoneShort;

  /// No description provided for @sharedStoryOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s story'**
  String sharedStoryOf(String name);

  /// No description provided for @sharedStoryReactedPreview.
  ///
  /// In en, this message translates to:
  /// **'Reacted {emoji} to a story'**
  String sharedStoryReactedPreview(String emoji);

  /// No description provided for @sharedStoryReactedTheirs.
  ///
  /// In en, this message translates to:
  /// **'You reacted to their story'**
  String get sharedStoryReactedTheirs;

  /// No description provided for @sharedStoryReactedYours.
  ///
  /// In en, this message translates to:
  /// **'Reacted to your story'**
  String get sharedStoryReactedYours;

  /// No description provided for @sharedStoryRepliedPreview.
  ///
  /// In en, this message translates to:
  /// **'Replied to a story: {text}'**
  String sharedStoryRepliedPreview(String text);

  /// No description provided for @sharedStoryRepliedTheirs.
  ///
  /// In en, this message translates to:
  /// **'You replied to their story'**
  String get sharedStoryRepliedTheirs;

  /// No description provided for @sharedStoryRepliedYours.
  ///
  /// In en, this message translates to:
  /// **'Replied to your story'**
  String get sharedStoryRepliedYours;

  /// No description provided for @sharedUnavailableAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account unavailable'**
  String get sharedUnavailableAccountTitle;

  /// No description provided for @sharedUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This content was removed or you can no longer see it.'**
  String get sharedUnavailableBody;

  /// No description provided for @sharedUnavailablePostTitle.
  ///
  /// In en, this message translates to:
  /// **'Post unavailable'**
  String get sharedUnavailablePostTitle;

  /// No description provided for @sharedUnavailableStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Story unavailable'**
  String get sharedUnavailableStoryTitle;

  /// No description provided for @sharedUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get sharedUnavailableTitle;

  /// No description provided for @shellActivateAccount.
  ///
  /// In en, this message translates to:
  /// **'Activate account'**
  String get shellActivateAccount;

  /// No description provided for @shellActivateInviteIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your invite email along with the email address and a password you\'d like to use.'**
  String get shellActivateInviteIntro;

  /// No description provided for @shellActivateInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Activate invite'**
  String get shellActivateInviteTitle;

  /// No description provided for @shellAddBusiness.
  ///
  /// In en, this message translates to:
  /// **'Add business'**
  String get shellAddBusiness;

  /// No description provided for @shellAddUser.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get shellAddUser;

  /// No description provided for @shellAdminBusinessesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage gyms & shops'**
  String get shellAdminBusinessesSubtitle;

  /// No description provided for @shellAdminInvoicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View all membership invoices'**
  String get shellAdminInvoicesSubtitle;

  /// No description provided for @shellAdminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin panel'**
  String get shellAdminPanel;

  /// No description provided for @shellAdminUsersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage all accounts'**
  String get shellAdminUsersSubtitle;

  /// No description provided for @shellAlreadyYourEmail.
  ///
  /// In en, this message translates to:
  /// **'That\'s already your email'**
  String get shellAlreadyYourEmail;

  /// No description provided for @shellAuthEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get shellAuthEmail;

  /// No description provided for @shellAuthFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get shellAuthFirstName;

  /// No description provided for @shellAuthInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get shellAuthInvalidEmail;

  /// No description provided for @shellAuthLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get shellAuthLastName;

  /// No description provided for @shellAuthPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get shellAuthPassword;

  /// No description provided for @shellAuthPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Minimum {count} characters'**
  String shellAuthPasswordMin(int count);

  /// No description provided for @shellAuthUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get shellAuthUsername;

  /// No description provided for @shellAvatarAdd.
  ///
  /// In en, this message translates to:
  /// **'Add profile photo'**
  String get shellAvatarAdd;

  /// No description provided for @shellAvatarChange.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get shellAvatarChange;

  /// No description provided for @shellChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get shellChange;

  /// No description provided for @shellChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get shellChangeEmail;

  /// No description provided for @shellChangeEmailIntro.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a confirmation link to the new address. Your email changes once you open it.'**
  String get shellChangeEmailIntro;

  /// No description provided for @shellChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get shellChangePassword;

  /// No description provided for @shellChats.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get shellChats;

  /// No description provided for @shellChatsUnread.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Messages, 1 unread chat} other{Messages, {count} unread chats}}'**
  String shellChatsUnread(int count);

  /// No description provided for @shellCheckEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent you a confirmation link. Please verify your email before logging in.'**
  String get shellCheckEmailBody;

  /// No description provided for @shellCheckEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get shellCheckEmailTitle;

  /// No description provided for @shellChooseShop.
  ///
  /// In en, this message translates to:
  /// **'Choose a shop'**
  String get shellChooseShop;

  /// No description provided for @shellClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get shellClearSearch;

  /// No description provided for @shellConfirmNewEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your new email'**
  String get shellConfirmNewEmailTitle;

  /// No description provided for @shellConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get shellConfirmNewPassword;

  /// No description provided for @shellConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get shellConfirmPassword;

  /// No description provided for @shellContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get shellContinueWithGoogle;

  /// No description provided for @shellCouldNotOpenUrl.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String shellCouldNotOpenUrl(String url);

  /// No description provided for @shellCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get shellCreateAccount;

  /// No description provided for @shellCreateUser.
  ///
  /// In en, this message translates to:
  /// **'Create user'**
  String get shellCreateUser;

  /// No description provided for @shellCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get shellCurrentPassword;

  /// No description provided for @shellDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get shellDeleteAccount;

  /// No description provided for @shellDeleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete account'**
  String get shellDeleteAccountFailed;

  /// No description provided for @shellDeleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account, memberships and billing history. This cannot be undone.'**
  String get shellDeleteAccountMessage;

  /// No description provided for @shellDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your account'**
  String get shellDeleteAccountSubtitle;

  /// No description provided for @shellDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get shellDeleteAccountTitle;

  /// No description provided for @shellDeleteConfirmWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get shellDeleteConfirmWord;

  /// No description provided for @shellDeleteUserMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes {name}\'s account, memberships and billing history. This cannot be undone.'**
  String shellDeleteUserMessage(String name);

  /// No description provided for @shellDeleteUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String shellDeleteUserTitle(String name);

  /// No description provided for @shellEditBusiness.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String shellEditBusiness(String name);

  /// No description provided for @shellEditUser.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String shellEditUser(String name);

  /// No description provided for @shellEditUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit user'**
  String get shellEditUserTitle;

  /// No description provided for @shellForgotPasswordIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a link to reset your password.'**
  String get shellForgotPasswordIntro;

  /// No description provided for @shellForgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get shellForgotPasswordLink;

  /// No description provided for @shellForgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get shellForgotPasswordTitle;

  /// No description provided for @shellGoToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to login'**
  String get shellGoToLogin;

  /// No description provided for @shellGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed'**
  String get shellGoogleFailed;

  /// No description provided for @shellGoogleNoIdToken.
  ///
  /// In en, this message translates to:
  /// **'Google did not return an ID token'**
  String get shellGoogleNoIdToken;

  /// No description provided for @shellGoogleNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not supported on this device'**
  String get shellGoogleNotSupported;

  /// No description provided for @shellGyms.
  ///
  /// In en, this message translates to:
  /// **'Gyms'**
  String get shellGyms;

  /// No description provided for @shellHaveAccountLogIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get shellHaveAccountLogIn;

  /// No description provided for @shellHaveInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Have an invite code?'**
  String get shellHaveInviteCode;

  /// No description provided for @shellHello.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String shellHello(String name);

  /// No description provided for @shellHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get shellHidePassword;

  /// No description provided for @shellHidePasswords.
  ///
  /// In en, this message translates to:
  /// **'Hide passwords'**
  String get shellHidePasswords;

  /// No description provided for @shellHomeBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get shellHomeBackToLogin;

  /// No description provided for @shellHomeLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get shellHomeLogOut;

  /// No description provided for @shellHomeNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get shellHomeNotifications;

  /// No description provided for @shellHomeNotificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Notifications, 1 unread} other{Notifications, {count} unread}}'**
  String shellHomeNotificationsUnread(int count);

  /// No description provided for @shellHomeProfileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile'**
  String get shellHomeProfileLoadFailed;

  /// No description provided for @shellHomeReturnToAdmin.
  ///
  /// In en, this message translates to:
  /// **'Return to admin'**
  String get shellHomeReturnToAdmin;

  /// No description provided for @shellHomeViewingAs.
  ///
  /// In en, this message translates to:
  /// **'Viewing as {name}'**
  String shellHomeViewingAs(String name);

  /// No description provided for @shellHubCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get shellHubCheckIn;

  /// No description provided for @shellHubCheckInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show your code at the front desk'**
  String get shellHubCheckInSubtitle;

  /// No description provided for @shellHubClassesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse and book group classes'**
  String get shellHubClassesSubtitle;

  /// No description provided for @shellHubCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get shellHubCommunity;

  /// No description provided for @shellHubCommunityOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open community: {error}'**
  String shellHubCommunityOpenFailed(String error);

  /// No description provided for @shellHubCommunitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Posts and announcements from your gym'**
  String get shellHubCommunitySubtitle;

  /// No description provided for @shellHubExercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get shellHubExercises;

  /// No description provided for @shellHubExercisesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse and manage exercises'**
  String get shellHubExercisesSubtitle;

  /// No description provided for @shellHubFoodDiary.
  ///
  /// In en, this message translates to:
  /// **'Food diary'**
  String get shellHubFoodDiary;

  /// No description provided for @shellHubFoodDiarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log meals and track macros'**
  String get shellHubFoodDiarySubtitle;

  /// No description provided for @shellHubMealPlans.
  ///
  /// In en, this message translates to:
  /// **'Meal plans'**
  String get shellHubMealPlans;

  /// No description provided for @shellHubMealPlansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Food, recipes and nutrition'**
  String get shellHubMealPlansSubtitle;

  /// No description provided for @shellHubNotLinked.
  ///
  /// In en, this message translates to:
  /// **'You\'re not linked to a gym or shop yet'**
  String get shellHubNotLinked;

  /// No description provided for @shellHubProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get shellHubProgress;

  /// No description provided for @shellHubSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get shellHubSessions;

  /// No description provided for @shellHubSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log and review your sessions'**
  String get shellHubSessionsSubtitle;

  /// No description provided for @shellHubStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get shellHubStore;

  /// No description provided for @shellHubStoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Supplements, gear and your orders'**
  String get shellHubStoreSubtitle;

  /// No description provided for @shellHubWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get shellHubWorkouts;

  /// No description provided for @shellHubWorkoutsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trainings and routines'**
  String get shellHubWorkoutsSubtitle;

  /// No description provided for @shellImageAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get shellImageAddPhoto;

  /// No description provided for @shellImageChange.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get shellImageChange;

  /// No description provided for @shellImageChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get shellImageChooseFromGallery;

  /// No description provided for @shellImageTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get shellImageTakePhoto;

  /// No description provided for @shellImageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String shellImageUploadFailed(String error);

  /// No description provided for @shellImageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo'**
  String get shellImageUploading;

  /// No description provided for @shellImpersonateBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see the app exactly as {email} does and can act on their behalf. This is recorded in the audit log. Use \"Return to admin\" (or log out) to get back to your account.'**
  String shellImpersonateBody(String email);

  /// No description provided for @shellImpersonateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign in as user'**
  String get shellImpersonateConfirm;

  /// No description provided for @shellImpersonateTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in as {name}?'**
  String shellImpersonateTitle(String name);

  /// No description provided for @shellInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation'**
  String get shellInvitationTitle;

  /// No description provided for @shellInviteAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept — join {entity}'**
  String shellInviteAccept(String entity);

  /// No description provided for @shellInviteAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get shellInviteAccepted;

  /// No description provided for @shellInviteBody.
  ///
  /// In en, this message translates to:
  /// **'You have been invited to work at {entity} as {role}.'**
  String shellInviteBody(String entity, String role);

  /// No description provided for @shellInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get shellInviteCode;

  /// No description provided for @shellInviteCodeHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get shellInviteCodeHint;

  /// No description provided for @shellInviteCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get shellInviteCodeInvalid;

  /// No description provided for @shellInviteDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get shellInviteDecline;

  /// No description provided for @shellInviteDeclined.
  ///
  /// In en, this message translates to:
  /// **'You declined this invitation'**
  String get shellInviteDeclined;

  /// No description provided for @shellInviteDeclinedChip.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get shellInviteDeclinedChip;

  /// No description provided for @shellInviteJoined.
  ///
  /// In en, this message translates to:
  /// **'You joined {entity} as {role}'**
  String shellInviteJoined(String entity, String role);

  /// No description provided for @shellInviteOrganisationFallback.
  ///
  /// In en, this message translates to:
  /// **'the organisation'**
  String get shellInviteOrganisationFallback;

  /// No description provided for @shellInvitePending.
  ///
  /// In en, this message translates to:
  /// **'Pending response'**
  String get shellInvitePending;

  /// No description provided for @shellInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get shellInvoices;

  /// No description provided for @shellLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get shellLoadMore;

  /// No description provided for @shellLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get shellLogIn;

  /// No description provided for @shellLogInInstead.
  ///
  /// In en, this message translates to:
  /// **'Log in instead'**
  String get shellLogInInstead;

  /// No description provided for @shellMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get shellMarkAllRead;

  /// No description provided for @shellMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String shellMemberCount(int count);

  /// No description provided for @shellMembersYouCoach.
  ///
  /// In en, this message translates to:
  /// **'Members you coach'**
  String get shellMembersYouCoach;

  /// No description provided for @shellMuteBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get shellMuteBilling;

  /// No description provided for @shellMuteBillingDescription.
  ///
  /// In en, this message translates to:
  /// **'Invoices, payments and expiring memberships'**
  String get shellMuteBillingDescription;

  /// No description provided for @shellMuteClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get shellMuteClasses;

  /// No description provided for @shellMuteClassesDescription.
  ///
  /// In en, this message translates to:
  /// **'Class reminders, changes and cancellations'**
  String get shellMuteClassesDescription;

  /// No description provided for @shellMuteCoaching.
  ///
  /// In en, this message translates to:
  /// **'Coaching'**
  String get shellMuteCoaching;

  /// No description provided for @shellMuteCoachingDescription.
  ///
  /// In en, this message translates to:
  /// **'Assigned routines and plans, session feedback'**
  String get shellMuteCoachingDescription;

  /// No description provided for @shellMuteCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get shellMuteCommunity;

  /// No description provided for @shellMuteCommunityDescription.
  ///
  /// In en, this message translates to:
  /// **'Gym news, comments, replies and reactions to your posts'**
  String get shellMuteCommunityDescription;

  /// No description provided for @shellMuteFootnote.
  ///
  /// In en, this message translates to:
  /// **'Invites always come through. Muted notifications still appear in the app.'**
  String get shellMuteFootnote;

  /// No description provided for @shellMuteMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get shellMuteMessages;

  /// No description provided for @shellMuteMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'New chat messages and being added to groups'**
  String get shellMuteMessagesDescription;

  /// No description provided for @shellMuteShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shellMuteShop;

  /// No description provided for @shellMuteShopDescription.
  ///
  /// In en, this message translates to:
  /// **'Order updates, new orders and restocks'**
  String get shellMuteShopDescription;

  /// No description provided for @shellMuteSocial.
  ///
  /// In en, this message translates to:
  /// **'Followers & friends'**
  String get shellMuteSocial;

  /// No description provided for @shellMuteSocialDescription.
  ///
  /// In en, this message translates to:
  /// **'New followers, follow and friend requests'**
  String get shellMuteSocialDescription;

  /// No description provided for @shellMuteStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get shellMuteStaff;

  /// No description provided for @shellMuteStaffDescription.
  ///
  /// In en, this message translates to:
  /// **'Shifts and people joining your business'**
  String get shellMuteStaffDescription;

  /// No description provided for @shellMyMembership.
  ///
  /// In en, this message translates to:
  /// **'My membership'**
  String get shellMyMembership;

  /// No description provided for @shellMyMembershipSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plan, billing and invoices'**
  String get shellMyMembershipSubtitle;

  /// No description provided for @shellMyOrders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get shellMyOrders;

  /// No description provided for @shellMyOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shop orders and pickups'**
  String get shellMyOrdersSubtitle;

  /// No description provided for @shellMyProgress.
  ///
  /// In en, this message translates to:
  /// **'My progress'**
  String get shellMyProgress;

  /// No description provided for @shellMyProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lifts, body weight and streaks'**
  String get shellMyProgressSubtitle;

  /// No description provided for @shellNewEmail.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get shellNewEmail;

  /// No description provided for @shellNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get shellNewPassword;

  /// No description provided for @shellNewUserTitle.
  ///
  /// In en, this message translates to:
  /// **'New user'**
  String get shellNewUserTitle;

  /// No description provided for @shellNoAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get shellNoAccountSignUp;

  /// No description provided for @shellNoBusinesses.
  ///
  /// In en, this message translates to:
  /// **'No businesses yet'**
  String get shellNoBusinesses;

  /// No description provided for @shellNoCoachedMembers.
  ///
  /// In en, this message translates to:
  /// **'No members at the gyms you coach at yet'**
  String get shellNoCoachedMembers;

  /// No description provided for @shellNoLongerMember.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer a member'**
  String shellNoLongerMember(String name);

  /// No description provided for @shellNoMembersMatch.
  ///
  /// In en, this message translates to:
  /// **'No members match \"{query}\"'**
  String shellNoMembersMatch(String query);

  /// No description provided for @shellNoNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get shellNoNotifications;

  /// No description provided for @shellNoSessionsToday.
  ///
  /// In en, this message translates to:
  /// **'No sessions with you today'**
  String get shellNoSessionsToday;

  /// No description provided for @shellNoUsers.
  ///
  /// In en, this message translates to:
  /// **'No users yet'**
  String get shellNoUsers;

  /// No description provided for @shellNoUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get shellNoUsersFound;

  /// No description provided for @shellNotAVendor.
  ///
  /// In en, this message translates to:
  /// **'You\'re not a vendor at any shop yet'**
  String get shellNotAVendor;

  /// No description provided for @shellNotAssignedToGym.
  ///
  /// In en, this message translates to:
  /// **'Not assigned to any gym yet'**
  String get shellNotAssignedToGym;

  /// No description provided for @shellNotificationUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get shellNotificationUnread;

  /// No description provided for @shellOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — showing saved data'**
  String get shellOffline;

  /// No description provided for @shellOfflinePending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You\'re offline — showing saved data · 1 change waiting to sync} other{You\'re offline — showing saved data · {count} changes waiting to sync}}'**
  String shellOfflinePending(int count);

  /// No description provided for @shellOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get shellOr;

  /// No description provided for @shellOrdersForShop.
  ///
  /// In en, this message translates to:
  /// **'Orders · {shop}'**
  String shellOrdersForShop(String shop);

  /// No description provided for @shellOwnerAllInvoices.
  ///
  /// In en, this message translates to:
  /// **'All invoices'**
  String get shellOwnerAllInvoices;

  /// No description provided for @shellPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get shellPasswordChanged;

  /// No description provided for @shellPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get shellPasswordsDontMatch;

  /// No description provided for @shellPlatformOverview.
  ///
  /// In en, this message translates to:
  /// **'Platform overview'**
  String get shellPlatformOverview;

  /// No description provided for @shellProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get shellProfileUpdated;

  /// No description provided for @shellPushChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Class reminders, orders, memberships and messages'**
  String get shellPushChannelDescription;

  /// No description provided for @shellPushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get shellPushNotifications;

  /// No description provided for @shellPushNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts on this phone'**
  String get shellPushNotificationsSubtitle;

  /// No description provided for @shellPushUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Push notifications aren\'t available in this build. You\'ll still find everything under the bell icon; these choices apply on devices that support push.'**
  String get shellPushUnavailable;

  /// No description provided for @shellResetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a password reset link to {email}.'**
  String shellResetLinkSent(String email);

  /// No description provided for @shellResetPasswordIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password for your account.'**
  String get shellResetPasswordIntro;

  /// No description provided for @shellResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get shellResetPasswordTitle;

  /// No description provided for @shellRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get shellRole;

  /// No description provided for @shellRoleEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get shellRoleEmployee;

  /// No description provided for @shellRoleEmployeeTrainer.
  ///
  /// In en, this message translates to:
  /// **'Employee / Trainer'**
  String get shellRoleEmployeeTrainer;

  /// No description provided for @shellRoleEmployeeTrainerShort.
  ///
  /// In en, this message translates to:
  /// **'Emp. trainer'**
  String get shellRoleEmployeeTrainerShort;

  /// No description provided for @shellRoleGymOwner.
  ///
  /// In en, this message translates to:
  /// **'Gym owner'**
  String get shellRoleGymOwner;

  /// No description provided for @shellRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get shellRoleMember;

  /// No description provided for @shellRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get shellRoleOwner;

  /// No description provided for @shellRoleShopOwner.
  ///
  /// In en, this message translates to:
  /// **'Shop owner'**
  String get shellRoleShopOwner;

  /// No description provided for @shellRoleShopVendor.
  ///
  /// In en, this message translates to:
  /// **'Shop vendor'**
  String get shellRoleShopVendor;

  /// No description provided for @shellRoleSuperUser.
  ///
  /// In en, this message translates to:
  /// **'Super user'**
  String get shellRoleSuperUser;

  /// No description provided for @shellRoleTrainer.
  ///
  /// In en, this message translates to:
  /// **'Trainer'**
  String get shellRoleTrainer;

  /// No description provided for @shellRoleVendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get shellRoleVendor;

  /// No description provided for @shellSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get shellSaveChanges;

  /// No description provided for @shellScanCheckIns.
  ///
  /// In en, this message translates to:
  /// **'Scan check-ins'**
  String get shellScanCheckIns;

  /// No description provided for @shellSearchMembers.
  ///
  /// In en, this message translates to:
  /// **'Search members'**
  String get shellSearchMembers;

  /// No description provided for @shellSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get shellSendLink;

  /// No description provided for @shellSendMePushesAbout.
  ///
  /// In en, this message translates to:
  /// **'Send me pushes about'**
  String get shellSendMePushesAbout;

  /// No description provided for @shellSendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get shellSendResetLink;

  /// No description provided for @shellSessionStartedInProgress.
  ///
  /// In en, this message translates to:
  /// **'Started {time} · in progress'**
  String shellSessionStartedInProgress(String time);

  /// No description provided for @shellSetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get shellSetNewPassword;

  /// No description provided for @shellSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellSettings;

  /// No description provided for @shellSettingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get shellSettingsAccount;

  /// No description provided for @shellSettingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get shellSettingsAppearance;

  /// No description provided for @shellSettingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {error}'**
  String shellSettingsSaveFailed(String error);

  /// No description provided for @shellSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, units, notifications, account'**
  String get shellSettingsSubtitle;

  /// No description provided for @shellSettingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get shellSettingsTheme;

  /// No description provided for @shellSettingsUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get shellSettingsUnits;

  /// No description provided for @shellSettingsWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get shellSettingsWeight;

  /// No description provided for @shellShops.
  ///
  /// In en, this message translates to:
  /// **'Shops'**
  String get shellShops;

  /// No description provided for @shellShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get shellShowMore;

  /// No description provided for @shellShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get shellShowPassword;

  /// No description provided for @shellShowPasswords.
  ///
  /// In en, this message translates to:
  /// **'Show passwords'**
  String get shellShowPasswords;

  /// No description provided for @shellSignInAsThisUser.
  ///
  /// In en, this message translates to:
  /// **'Sign in as this user'**
  String get shellSignInAsThisUser;

  /// No description provided for @shellSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get shellSignUp;

  /// No description provided for @shellSignupEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get shellSignupEmailTaken;

  /// No description provided for @shellSignupEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get shellSignupEnterCode;

  /// No description provided for @shellSignupPendingInviteBody.
  ///
  /// In en, this message translates to:
  /// **'An account for {email} was already created by an invite. We\'ve re-sent the invite email — enter the 6-digit code from it to activate your account.'**
  String shellSignupPendingInviteBody(String email);

  /// No description provided for @shellSignupPendingInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'You have a pending invite'**
  String get shellSignupPendingInviteTitle;

  /// No description provided for @shellStatsActiveMemberships.
  ///
  /// In en, this message translates to:
  /// **'Active memberships'**
  String get shellStatsActiveMemberships;

  /// No description provided for @shellStatsEndsInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{in 1 day ({date})} other{in {days} days ({date})}}'**
  String shellStatsEndsInDays(int days, String date);

  /// No description provided for @shellStatsEndsOn.
  ///
  /// In en, this message translates to:
  /// **'{gym} · ends {when}'**
  String shellStatsEndsOn(String gym, String when);

  /// No description provided for @shellStatsEndsToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get shellStatsEndsToday;

  /// No description provided for @shellStatsEndsTomorrow.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get shellStatsEndsTomorrow;

  /// No description provided for @shellStatsExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get shellStatsExpiringSoon;

  /// No description provided for @shellStatsGymCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 gym} other{{count} gyms}}'**
  String shellStatsGymCount(int count);

  /// No description provided for @shellStatsInvoicesThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Invoices this month'**
  String get shellStatsInvoicesThisMonth;

  /// No description provided for @shellStatsMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get shellStatsMembers;

  /// No description provided for @shellStatsNext14Days.
  ///
  /// In en, this message translates to:
  /// **'next 14 days'**
  String get shellStatsNext14Days;

  /// No description provided for @shellStatsNoneExpiring.
  ///
  /// In en, this message translates to:
  /// **'No memberships expiring in the next two weeks'**
  String get shellStatsNoneExpiring;

  /// No description provided for @shellStatsStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get shellStatsStaff;

  /// No description provided for @shellStatsUnpaidInvoices.
  ///
  /// In en, this message translates to:
  /// **'Unpaid invoices'**
  String get shellStatsUnpaidInvoices;

  /// No description provided for @shellTabBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Businesses'**
  String get shellTabBusinesses;

  /// No description provided for @shellTabClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get shellTabClasses;

  /// No description provided for @shellTabDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get shellTabDiscover;

  /// No description provided for @shellTabFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get shellTabFeed;

  /// No description provided for @shellTabGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get shellTabGym;

  /// No description provided for @shellTabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellTabHome;

  /// No description provided for @shellTabMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get shellTabMembers;

  /// No description provided for @shellTabMembership.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get shellTabMembership;

  /// No description provided for @shellTabMyShop.
  ///
  /// In en, this message translates to:
  /// **'My Shop'**
  String get shellTabMyShop;

  /// No description provided for @shellTabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get shellTabProfile;

  /// No description provided for @shellTabSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get shellTabSchedule;

  /// No description provided for @shellTabUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get shellTabUsers;

  /// No description provided for @shellThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get shellThemeDark;

  /// No description provided for @shellThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get shellThemeLight;

  /// No description provided for @shellThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get shellThemeSystem;

  /// No description provided for @shellTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String shellTimeDaysAgo(int count);

  /// No description provided for @shellTimeDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String shellTimeDaysShort(int count);

  /// No description provided for @shellTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String shellTimeHoursAgo(int count);

  /// No description provided for @shellTimeHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String shellTimeHoursShort(int count);

  /// No description provided for @shellTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String shellTimeMinutesAgo(int count);

  /// No description provided for @shellTimeMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String shellTimeMinutesShort(int count);

  /// No description provided for @shellTimeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get shellTimeNow;

  /// No description provided for @shellTodaysSessions.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sessions'**
  String get shellTodaysSessions;

  /// No description provided for @shellTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {text} to confirm.'**
  String shellTypeToConfirm(String text);

  /// No description provided for @shellUnitKilograms.
  ///
  /// In en, this message translates to:
  /// **'Kilograms'**
  String get shellUnitKilograms;

  /// No description provided for @shellUnitPounds.
  ///
  /// In en, this message translates to:
  /// **'Pounds'**
  String get shellUnitPounds;

  /// No description provided for @shellUserSearchAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get shellUserSearchAdd;

  /// No description provided for @shellUserSearchAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String shellUserSearchAddLabel(String name);

  /// No description provided for @shellUserSearchAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding'**
  String get shellUserSearchAdding;

  /// No description provided for @shellUserSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or username'**
  String get shellUserSearchHint;

  /// No description provided for @shellWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String shellWelcome(String name);

  /// No description provided for @shellYourGym.
  ///
  /// In en, this message translates to:
  /// **'Your gym'**
  String get shellYourGym;

  /// No description provided for @shellYourGyms.
  ///
  /// In en, this message translates to:
  /// **'Your gyms'**
  String get shellYourGyms;

  /// No description provided for @socialActiveAgo.
  ///
  /// In en, this message translates to:
  /// **'Active {when}'**
  String socialActiveAgo(String when);

  /// No description provided for @socialActiveNow.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get socialActiveNow;

  /// No description provided for @socialCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get socialCamera;

  /// No description provided for @socialFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get socialFile;

  /// No description provided for @socialFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Files are limited to 50 MB.'**
  String get socialFileTooLarge;

  /// No description provided for @socialGallery.
  ///
  /// In en, this message translates to:
  /// **'Photos & videos'**
  String get socialGallery;

  /// No description provided for @socialRecordVideo.
  ///
  /// In en, this message translates to:
  /// **'Record video'**
  String get socialRecordVideo;

  /// No description provided for @socialRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get socialRetry;

  /// No description provided for @socialTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get socialTakePhoto;

  /// No description provided for @socialTyping.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing…'**
  String socialTyping(String name);

  /// No description provided for @socialTypingSeveral.
  ///
  /// In en, this message translates to:
  /// **'Several people are typing…'**
  String get socialTypingSeveral;

  /// No description provided for @socialUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Try again.'**
  String get socialUploadFailed;

  /// No description provided for @storyActivityCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Activity} =1{1 view} other{{count} views}}'**
  String storyActivityCount(int count);

  /// No description provided for @storyAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to your story'**
  String get storyAddTooltip;

  /// No description provided for @storyArchivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get storyArchivedLabel;

  /// No description provided for @storyClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get storyClose;

  /// No description provided for @storyComposerBackground.
  ///
  /// In en, this message translates to:
  /// **'Background colour'**
  String get storyComposerBackground;

  /// No description provided for @storyComposerCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a caption…'**
  String get storyComposerCaptionHint;

  /// No description provided for @storyComposerDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get storyComposerDiscard;

  /// No description provided for @storyComposerDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this story?'**
  String get storyComposerDiscardTitle;

  /// No description provided for @storyComposerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get storyComposerEdit;

  /// No description provided for @storyComposerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a photo, a video or some text'**
  String get storyComposerEmpty;

  /// No description provided for @storyComposerPickMedia.
  ///
  /// In en, this message translates to:
  /// **'Photo or video'**
  String get storyComposerPickMedia;

  /// No description provided for @storyComposerPosting.
  ///
  /// In en, this message translates to:
  /// **'Sharing…'**
  String get storyComposerPosting;

  /// No description provided for @storyComposerRemoveMedia.
  ///
  /// In en, this message translates to:
  /// **'Remove photo or video'**
  String get storyComposerRemoveMedia;

  /// No description provided for @storyComposerShare.
  ///
  /// In en, this message translates to:
  /// **'Share to story'**
  String get storyComposerShare;

  /// No description provided for @storyComposerTextHint.
  ///
  /// In en, this message translates to:
  /// **'Type something…'**
  String get storyComposerTextHint;

  /// No description provided for @storyComposerTitle.
  ///
  /// In en, this message translates to:
  /// **'New story'**
  String get storyComposerTitle;

  /// No description provided for @storyDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete story'**
  String get storyDelete;

  /// No description provided for @storyDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from your story and your archive.'**
  String get storyDeleteConfirmBody;

  /// No description provided for @storyDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this story?'**
  String get storyDeleteConfirmTitle;

  /// No description provided for @storyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Story deleted'**
  String get storyDeleted;

  /// No description provided for @storyLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get storyLike;

  /// No description provided for @storyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load stories'**
  String get storyLoadFailed;

  /// No description provided for @storyMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get storyMore;

  /// No description provided for @storyNew.
  ///
  /// In en, this message translates to:
  /// **'New story'**
  String get storyNew;

  /// No description provided for @storyNoViewers.
  ///
  /// In en, this message translates to:
  /// **'No one has seen this story yet'**
  String get storyNoViewers;

  /// No description provided for @storyPosted.
  ///
  /// In en, this message translates to:
  /// **'Added to your story'**
  String get storyPosted;

  /// No description provided for @storyQuickReactions.
  ///
  /// In en, this message translates to:
  /// **'Quick reactions'**
  String get storyQuickReactions;

  /// No description provided for @storyReactionSent.
  ///
  /// In en, this message translates to:
  /// **'Reaction sent'**
  String get storyReactionSent;

  /// No description provided for @storyReplySent.
  ///
  /// In en, this message translates to:
  /// **'Reply sent'**
  String get storyReplySent;

  /// No description provided for @storySend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get storySend;

  /// No description provided for @storySendMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get storySendMessageHint;

  /// No description provided for @storySendTo.
  ///
  /// In en, this message translates to:
  /// **'Send to…'**
  String get storySendTo;

  /// No description provided for @storyTraySeen.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s story'**
  String storyTraySeen(String name);

  /// No description provided for @storyTrayUnseen.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s story, not seen yet'**
  String storyTrayUnseen(String name);

  /// No description provided for @storyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This story is no longer available'**
  String get storyUnavailable;

  /// No description provided for @storyUnlike.
  ///
  /// In en, this message translates to:
  /// **'Unlike'**
  String get storyUnlike;

  /// No description provided for @storyViewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No views yet} =1{1 view} other{{count} views}}'**
  String storyViewsCount(int count);

  /// No description provided for @storyYourStory.
  ///
  /// In en, this message translates to:
  /// **'Your story'**
  String get storyYourStory;

  /// No description provided for @tagsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tagsDone;

  /// No description provided for @tagsDragHint.
  ///
  /// In en, this message translates to:
  /// **'Drag a name to move it, tap the photo to tag someone else'**
  String get tagsDragHint;

  /// No description provided for @tagsKindGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get tagsKindGym;

  /// No description provided for @tagsKindProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get tagsKindProduct;

  /// No description provided for @tagsKindShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get tagsKindShop;

  /// No description provided for @tagsLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} people per photo'**
  String tagsLimit(int count);

  /// No description provided for @tagsNoPeople.
  ///
  /// In en, this message translates to:
  /// **'No people found'**
  String get tagsNoPeople;

  /// No description provided for @tagsNoTagged.
  ///
  /// In en, this message translates to:
  /// **'No posts tagged yet'**
  String get tagsNoTagged;

  /// No description provided for @tagsNoTaggedMe.
  ///
  /// In en, this message translates to:
  /// **'When people tag you in photos or mention you, the posts show up here.'**
  String get tagsNoTaggedMe;

  /// No description provided for @tagsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {name}'**
  String tagsOpenFailed(String name);

  /// No description provided for @tagsRemoveMe.
  ///
  /// In en, this message translates to:
  /// **'Remove me from this post'**
  String get tagsRemoveMe;

  /// No description provided for @tagsRemoveMeBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll no longer be tagged on this post\'s photos, and it won\'t show on your profile\'s Tagged tab.'**
  String get tagsRemoveMeBody;

  /// No description provided for @tagsRemoveMeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove yourself?'**
  String get tagsRemoveMeTitle;

  /// No description provided for @tagsRemovePerson.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String tagsRemovePerson(String name);

  /// No description provided for @tagsRemovedMe.
  ///
  /// In en, this message translates to:
  /// **'You were removed from this post'**
  String get tagsRemovedMe;

  /// No description provided for @tagsSaved.
  ///
  /// In en, this message translates to:
  /// **'Tags updated'**
  String get tagsSaved;

  /// No description provided for @tagsSearchPeople.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get tagsSearchPeople;

  /// No description provided for @tagsTabTagged.
  ///
  /// In en, this message translates to:
  /// **'Tagged'**
  String get tagsTabTagged;

  /// No description provided for @tagsTaggedPeople.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person tagged} other{{count} people tagged}}'**
  String tagsTaggedPeople(int count);

  /// No description provided for @tagsTapToTag.
  ///
  /// In en, this message translates to:
  /// **'Tap the photo to tag people'**
  String get tagsTapToTag;

  /// No description provided for @tagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tag people'**
  String get tagsTitle;

  /// No description provided for @tagsTitleOf.
  ///
  /// In en, this message translates to:
  /// **'Tag people · {index}/{count}'**
  String tagsTitleOf(int index, int count);

  /// No description provided for @trainerClassesPickerCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get trainerClassesPickerCustomer;

  /// No description provided for @trainerClassesPickerCustomerPending.
  ///
  /// In en, this message translates to:
  /// **'Invite pending'**
  String get trainerClassesPickerCustomerPending;

  /// No description provided for @trainerClassesPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one found. You can add your followers, members of gyms where you coach, and your customers.'**
  String get trainerClassesPickerEmpty;

  /// No description provided for @trainerClassesPickerFollower.
  ///
  /// In en, this message translates to:
  /// **'Follows you'**
  String get trainerClassesPickerFollower;

  /// No description provided for @trainerClassesPickerMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get trainerClassesPickerMember;

  /// No description provided for @trainerClassesPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by name or username'**
  String get trainerClassesPickerSearch;

  /// No description provided for @trainerClassesTabCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get trainerClassesTabCalendar;

  /// No description provided for @trainerClassesTabClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get trainerClassesTabClasses;

  /// No description provided for @trainerClassesTabCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get trainerClassesTabCustomers;

  /// No description provided for @trainingAssignAction.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get trainingAssignAction;

  /// No description provided for @trainingAssignAssignedOn.
  ///
  /// In en, this message translates to:
  /// **'Assigned {date}'**
  String trainingAssignAssignedOn(String date);

  /// No description provided for @trainingAssignClearDates.
  ///
  /// In en, this message translates to:
  /// **'Clear dates'**
  String get trainingAssignClearDates;

  /// No description provided for @trainingAssignConfirm.
  ///
  /// In en, this message translates to:
  /// **'Assign \"{routine}\" to {name}?'**
  String trainingAssignConfirm(String routine, String name);

  /// No description provided for @trainingAssignConfirmSelf.
  ///
  /// In en, this message translates to:
  /// **'Assign \"{routine}\" to yourself?'**
  String trainingAssignConfirmSelf(String routine);

  /// No description provided for @trainingAssignDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign routine'**
  String get trainingAssignDialogTitle;

  /// No description provided for @trainingAssignDone.
  ///
  /// In en, this message translates to:
  /// **'\"{routine}\" assigned to {name}'**
  String trainingAssignDone(String routine, String name);

  /// No description provided for @trainingAssignDoneSelf.
  ///
  /// In en, this message translates to:
  /// **'\"{routine}\" assigned to you'**
  String trainingAssignDoneSelf(String routine);

  /// No description provided for @trainingAssignEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get trainingAssignEnd;

  /// No description provided for @trainingAssignEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String trainingAssignEnds(String date);

  /// No description provided for @trainingAssignNoRoutines.
  ///
  /// In en, this message translates to:
  /// **'No routines found'**
  String get trainingAssignNoRoutines;

  /// No description provided for @trainingAssignNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Focus on form, 3 sessions a week'**
  String get trainingAssignNoteHint;

  /// No description provided for @trainingAssignNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get trainingAssignNoteLabel;

  /// No description provided for @trainingAssignPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign \"{routine}\" to…'**
  String trainingAssignPickerTitle(String routine);

  /// No description provided for @trainingAssignRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get trainingAssignRemoveAction;

  /// No description provided for @trainingAssignRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'\"{routine}\" will no longer be assigned.'**
  String trainingAssignRemoveBody(String routine);

  /// No description provided for @trainingAssignRemoveBodyUser.
  ///
  /// In en, this message translates to:
  /// **'\"{routine}\" will no longer be assigned to {name}.'**
  String trainingAssignRemoveBodyUser(String routine, String name);

  /// No description provided for @trainingAssignRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove assignment?'**
  String get trainingAssignRemoveTitle;

  /// No description provided for @trainingAssignRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove assignment'**
  String get trainingAssignRemoveTooltip;

  /// No description provided for @trainingAssignSearchRoutinesHint.
  ///
  /// In en, this message translates to:
  /// **'Search routines…'**
  String get trainingAssignSearchRoutinesHint;

  /// No description provided for @trainingAssignStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get trainingAssignStart;

  /// No description provided for @trainingAssignStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String trainingAssignStarts(String date);

  /// No description provided for @trainingBookingAttended.
  ///
  /// In en, this message translates to:
  /// **'Attended'**
  String get trainingBookingAttended;

  /// No description provided for @trainingBookingBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get trainingBookingBooked;

  /// No description provided for @trainingBookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get trainingBookingCancelled;

  /// No description provided for @trainingBookingNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get trainingBookingNoShow;

  /// No description provided for @trainingBookingWaitlisted.
  ///
  /// In en, this message translates to:
  /// **'Waitlisted'**
  String get trainingBookingWaitlisted;

  /// No description provided for @trainingChartDefaultSeries.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get trainingChartDefaultSeries;

  /// No description provided for @trainingChartNoData.
  ///
  /// In en, this message translates to:
  /// **'No data in this range'**
  String get trainingChartNoData;

  /// No description provided for @trainingChartSummary.
  ///
  /// In en, this message translates to:
  /// **'{series} chart, {count, plural, =1{1 data point} other{{count} data points}}, last value {value}'**
  String trainingChartSummary(String series, String value, int count);

  /// No description provided for @trainingClassAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get trainingClassAbout;

  /// No description provided for @trainingClassAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get trainingClassAdd;

  /// No description provided for @trainingClassAddPeople.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get trainingClassAddPeople;

  /// No description provided for @trainingClassAddPeopleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one found. People need to be members of this gym or follow you.'**
  String get trainingClassAddPeopleEmpty;

  /// No description provided for @trainingClassAddPeopleHint.
  ///
  /// In en, this message translates to:
  /// **'Members of this gym and people who follow you.'**
  String get trainingClassAddPeopleHint;

  /// No description provided for @trainingClassAddPeopleSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by name or username'**
  String get trainingClassAddPeopleSearch;

  /// No description provided for @trainingClassAddedPerson.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String trainingClassAddedPerson(String name);

  /// No description provided for @trainingClassAddedToWaitlist.
  ///
  /// In en, this message translates to:
  /// **'{name} added to the waitlist'**
  String trainingClassAddedToWaitlist(String name);

  /// No description provided for @trainingClassApplyToSeries.
  ///
  /// In en, this message translates to:
  /// **'Apply to this and future classes'**
  String get trainingClassApplyToSeries;

  /// No description provided for @trainingClassApplyToSeriesOff.
  ///
  /// In en, this message translates to:
  /// **'Only this class changes'**
  String get trainingClassApplyToSeriesOff;

  /// No description provided for @trainingClassApplyToSeriesOn.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to every later class in this weekly series'**
  String get trainingClassApplyToSeriesOn;

  /// No description provided for @trainingClassAttendedOf.
  ///
  /// In en, this message translates to:
  /// **'{attended}/{total} attended'**
  String trainingClassAttendedOf(int attended, int total);

  /// No description provided for @trainingClassAttendedUndo.
  ///
  /// In en, this message translates to:
  /// **'Attended (tap to undo)'**
  String get trainingClassAttendedUndo;

  /// No description provided for @trainingClassBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get trainingClassBook;

  /// No description provided for @trainingClassBookedAt.
  ///
  /// In en, this message translates to:
  /// **'Booked {when}'**
  String trainingClassBookedAt(String when);

  /// No description provided for @trainingClassBookedFor.
  ///
  /// In en, this message translates to:
  /// **'You\'re booked for {title}'**
  String trainingClassBookedFor(String title);

  /// No description provided for @trainingClassBookedOf.
  ///
  /// In en, this message translates to:
  /// **'{booked}/{capacity} booked'**
  String trainingClassBookedOf(int booked, int capacity);

  /// No description provided for @trainingClassBookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled'**
  String get trainingClassBookingCancelled;

  /// No description provided for @trainingClassCancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get trainingClassCancelBooking;

  /// No description provided for @trainingClassCancelBookingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your spot in {title} will be given to the next person on the waitlist.'**
  String trainingClassCancelBookingMessage(String title);

  /// No description provided for @trainingClassCancelBookingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking?'**
  String get trainingClassCancelBookingQuestion;

  /// No description provided for @trainingClassCancelClass.
  ///
  /// In en, this message translates to:
  /// **'Cancel class'**
  String get trainingClassCancelClass;

  /// No description provided for @trainingClassCancelNotifyPeople.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person booked or waitlisted will be notified.} other{{count} people booked or waitlisted will be notified.}}'**
  String trainingClassCancelNotifyPeople(int count);

  /// No description provided for @trainingClassCancelQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cancel class?'**
  String get trainingClassCancelQuestion;

  /// No description provided for @trainingClassCancelThisAndFuture.
  ///
  /// In en, this message translates to:
  /// **'Cancel this and future classes'**
  String get trainingClassCancelThisAndFuture;

  /// No description provided for @trainingClassCancelThisOnly.
  ///
  /// In en, this message translates to:
  /// **'Cancel this class only'**
  String get trainingClassCancelThisOnly;

  /// No description provided for @trainingClassCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get trainingClassCancelled;

  /// No description provided for @trainingClassCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get trainingClassCapacity;

  /// No description provided for @trainingClassCapacityBelowBooked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person is already booked} other{{count} people are already booked}}'**
  String trainingClassCapacityBelowBooked(int count);

  /// No description provided for @trainingClassCapacityHelper.
  ///
  /// In en, this message translates to:
  /// **'Extra people join a waitlist'**
  String get trainingClassCapacityHelper;

  /// No description provided for @trainingClassCapacityMax.
  ///
  /// In en, this message translates to:
  /// **'That\'s a lot of people — 500 max'**
  String get trainingClassCapacityMax;

  /// No description provided for @trainingClassCapacityMin.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 1'**
  String get trainingClassCapacityMin;

  /// No description provided for @trainingClassClassCancelled.
  ///
  /// In en, this message translates to:
  /// **'Class cancelled'**
  String get trainingClassClassCancelled;

  /// No description provided for @trainingClassClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get trainingClassClasses;

  /// No description provided for @trainingClassClassesCancelled.
  ///
  /// In en, this message translates to:
  /// **'Classes cancelled'**
  String get trainingClassClassesCancelled;

  /// No description provided for @trainingClassCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 class} other{{count} classes}}'**
  String trainingClassCount(int count);

  /// No description provided for @trainingClassCreate.
  ///
  /// In en, this message translates to:
  /// **'Create class'**
  String get trainingClassCreate;

  /// No description provided for @trainingClassCreateOne.
  ///
  /// In en, this message translates to:
  /// **'Create a class'**
  String get trainingClassCreateOne;

  /// No description provided for @trainingClassCreated.
  ///
  /// In en, this message translates to:
  /// **'Class created'**
  String get trainingClassCreated;

  /// No description provided for @trainingClassCurrentTrainer.
  ///
  /// In en, this message translates to:
  /// **'Current trainer'**
  String get trainingClassCurrentTrainer;

  /// No description provided for @trainingClassDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get trainingClassDescriptionOptional;

  /// No description provided for @trainingClassDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get trainingClassDuration;

  /// No description provided for @trainingClassEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit class'**
  String get trainingClassEdit;

  /// No description provided for @trainingClassEnded.
  ///
  /// In en, this message translates to:
  /// **'This class has ended.'**
  String get trainingClassEnded;

  /// No description provided for @trainingClassEndsAt.
  ///
  /// In en, this message translates to:
  /// **'Ends at {time}'**
  String trainingClassEndsAt(String time);

  /// No description provided for @trainingClassFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get trainingClassFull;

  /// No description provided for @trainingClassFullWaiting.
  ///
  /// In en, this message translates to:
  /// **'Full · {count} waiting'**
  String trainingClassFullWaiting(int count);

  /// No description provided for @trainingClassGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get trainingClassGym;

  /// No description provided for @trainingClassInProgress.
  ///
  /// In en, this message translates to:
  /// **'This class is in progress.'**
  String get trainingClassInProgress;

  /// No description provided for @trainingClassJoinWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join waitlist'**
  String get trainingClassJoinWaitlist;

  /// No description provided for @trainingClassKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get trainingClassKeep;

  /// No description provided for @trainingClassKeepClass.
  ///
  /// In en, this message translates to:
  /// **'Keep class'**
  String get trainingClassKeepClass;

  /// No description provided for @trainingClassLeaveWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Leave waitlist'**
  String get trainingClassLeaveWaitlist;

  /// No description provided for @trainingClassLeaveWaitlistMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ll lose your place in line for {title}.'**
  String trainingClassLeaveWaitlistMessage(String title);

  /// No description provided for @trainingClassLeaveWaitlistQuestion.
  ///
  /// In en, this message translates to:
  /// **'Leave waitlist?'**
  String get trainingClassLeaveWaitlistQuestion;

  /// No description provided for @trainingClassLocationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Studio A'**
  String get trainingClassLocationHint;

  /// No description provided for @trainingClassLocationOptional.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get trainingClassLocationOptional;

  /// No description provided for @trainingClassMarkAttended.
  ///
  /// In en, this message translates to:
  /// **'Mark attended'**
  String get trainingClassMarkAttended;

  /// No description provided for @trainingClassMarkNoShow.
  ///
  /// In en, this message translates to:
  /// **'Mark no-show'**
  String get trainingClassMarkNoShow;

  /// No description provided for @trainingClassMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get trainingClassMember;

  /// No description provided for @trainingClassMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get trainingClassMore;

  /// No description provided for @trainingClassMyClasses.
  ///
  /// In en, this message translates to:
  /// **'My classes'**
  String get trainingClassMyClasses;

  /// No description provided for @trainingClassNameYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String trainingClassNameYou(String name);

  /// No description provided for @trainingClassNew.
  ///
  /// In en, this message translates to:
  /// **'New class'**
  String get trainingClassNew;

  /// No description provided for @trainingClassNoBookingsYet.
  ///
  /// In en, this message translates to:
  /// **'No one has booked yet'**
  String get trainingClassNoBookingsYet;

  /// No description provided for @trainingClassNoGyms.
  ///
  /// In en, this message translates to:
  /// **'No gyms to schedule at'**
  String get trainingClassNoGyms;

  /// No description provided for @trainingClassNoGymsMessage.
  ///
  /// In en, this message translates to:
  /// **'You can create classes at gyms where you are a trainer, staff member or owner.'**
  String get trainingClassNoGymsMessage;

  /// No description provided for @trainingClassNoPast.
  ///
  /// In en, this message translates to:
  /// **'No past classes'**
  String get trainingClassNoPast;

  /// No description provided for @trainingClassNoPastMessage.
  ///
  /// In en, this message translates to:
  /// **'Classes you taught in the last {days} days show up here.'**
  String trainingClassNoPastMessage(int days);

  /// No description provided for @trainingClassNoShowUndo.
  ///
  /// In en, this message translates to:
  /// **'No-show (tap to undo)'**
  String get trainingClassNoShowUndo;

  /// No description provided for @trainingClassNoTrainer.
  ///
  /// In en, this message translates to:
  /// **'No trainer'**
  String get trainingClassNoTrainer;

  /// No description provided for @trainingClassNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming classes'**
  String get trainingClassNoUpcoming;

  /// No description provided for @trainingClassNoUpcomingMessage.
  ///
  /// In en, this message translates to:
  /// **'Schedule a one-off class or a weekly series and members can book it.'**
  String get trainingClassNoUpcomingMessage;

  /// No description provided for @trainingClassNobodyBooked.
  ///
  /// In en, this message translates to:
  /// **'Nobody has booked yet.'**
  String get trainingClassNobodyBooked;

  /// No description provided for @trainingClassNoneThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No classes this week'**
  String get trainingClassNoneThisWeek;

  /// No description provided for @trainingClassNoneThisWeekCreate.
  ///
  /// In en, this message translates to:
  /// **'Create a class or a weekly series for members to book.'**
  String get trainingClassNoneThisWeekCreate;

  /// No description provided for @trainingClassNoneThisWeekMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been scheduled for this week yet.'**
  String get trainingClassNoneThisWeekMessage;

  /// No description provided for @trainingClassNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get trainingClassNotSignedIn;

  /// No description provided for @trainingClassNotifyOnChange.
  ///
  /// In en, this message translates to:
  /// **'People who booked are notified if the time or location changes.'**
  String get trainingClassNotifyOnChange;

  /// No description provided for @trainingClassOneOff.
  ///
  /// In en, this message translates to:
  /// **'One-off class'**
  String get trainingClassOneOff;

  /// No description provided for @trainingClassPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get trainingClassPast;

  /// No description provided for @trainingClassPersonFollower.
  ///
  /// In en, this message translates to:
  /// **'Follows you'**
  String get trainingClassPersonFollower;

  /// No description provided for @trainingClassPersonMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get trainingClassPersonMember;

  /// No description provided for @trainingClassRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get trainingClassRemove;

  /// No description provided for @trainingClassRemoveBookedMessage.
  ///
  /// In en, this message translates to:
  /// **'Their spot will go to the next person on the waitlist.'**
  String get trainingClassRemoveBookedMessage;

  /// No description provided for @trainingClassRemoveFromClass.
  ///
  /// In en, this message translates to:
  /// **'Remove from class'**
  String get trainingClassRemoveFromClass;

  /// No description provided for @trainingClassRemoveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String trainingClassRemoveQuestion(String name);

  /// No description provided for @trainingClassRemoveWaitlistMessage.
  ///
  /// In en, this message translates to:
  /// **'They\'ll be taken off the waitlist.'**
  String get trainingClassRemoveWaitlistMessage;

  /// No description provided for @trainingClassRepeatSummary.
  ///
  /// In en, this message translates to:
  /// **'Every {weekday} for {weeks} weeks'**
  String trainingClassRepeatSummary(String weekday, int weeks);

  /// No description provided for @trainingClassRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Repeat weekly'**
  String get trainingClassRepeatWeekly;

  /// No description provided for @trainingClassRoster.
  ///
  /// In en, this message translates to:
  /// **'Roster'**
  String get trainingClassRoster;

  /// No description provided for @trainingClassSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get trainingClassSaveChanges;

  /// No description provided for @trainingClassSpots.
  ///
  /// In en, this message translates to:
  /// **'Spots'**
  String get trainingClassSpots;

  /// No description provided for @trainingClassSpotsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 spot left} other{{count} spots left}}'**
  String trainingClassSpotsLeft(int count);

  /// No description provided for @trainingClassStartInFuture.
  ///
  /// In en, this message translates to:
  /// **'Pick a start time in the future'**
  String get trainingClassStartInFuture;

  /// No description provided for @trainingClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get trainingClassTitle;

  /// No description provided for @trainingClassTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Morning HIIT'**
  String get trainingClassTitleHint;

  /// No description provided for @trainingClassTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get trainingClassTitleLabel;

  /// No description provided for @trainingClassTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the class a title'**
  String get trainingClassTitleRequired;

  /// No description provided for @trainingClassUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get trainingClassUpcoming;

  /// No description provided for @trainingClassUpcomingCount.
  ///
  /// In en, this message translates to:
  /// **'Upcoming ({count})'**
  String trainingClassUpcomingCount(int count);

  /// No description provided for @trainingClassUpdated.
  ///
  /// In en, this message translates to:
  /// **'Class updated'**
  String get trainingClassUpdated;

  /// No description provided for @trainingClassWaitlistCount.
  ///
  /// In en, this message translates to:
  /// **'Waitlist ({count})'**
  String trainingClassWaitlistCount(int count);

  /// No description provided for @trainingClassWaitlistJoined.
  ///
  /// In en, this message translates to:
  /// **'Class is full. You\'re #{position} on the waitlist.'**
  String trainingClassWaitlistJoined(int position);

  /// No description provided for @trainingClassWaitlistJoinedNoPosition.
  ///
  /// In en, this message translates to:
  /// **'Class is full. You\'re on the waitlist.'**
  String get trainingClassWaitlistJoinedNoPosition;

  /// No description provided for @trainingClassWaitlistPosition.
  ///
  /// In en, this message translates to:
  /// **'#{position} on the waitlist'**
  String trainingClassWaitlistPosition(int position);

  /// No description provided for @trainingClassWaitlistedPosition.
  ///
  /// In en, this message translates to:
  /// **'Waitlisted #{position}'**
  String trainingClassWaitlistedPosition(int position);

  /// No description provided for @trainingClassWasCancelled.
  ///
  /// In en, this message translates to:
  /// **'This class was cancelled'**
  String get trainingClassWasCancelled;

  /// No description provided for @trainingClassWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly class'**
  String get trainingClassWeekly;

  /// No description provided for @trainingClassWeeklyCreated.
  ///
  /// In en, this message translates to:
  /// **'{count} weekly classes created'**
  String trainingClassWeeklyCreated(int count);

  /// No description provided for @trainingClassWeeklySeries.
  ///
  /// In en, this message translates to:
  /// **'Part of a weekly series'**
  String get trainingClassWeeklySeries;

  /// No description provided for @trainingClassWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get trainingClassWeeks;

  /// No description provided for @trainingClassWeeksValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String trainingClassWeeksValue(int count);

  /// No description provided for @trainingClassWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get trainingClassWhen;

  /// No description provided for @trainingClassYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get trainingClassYou;

  /// No description provided for @trainingCoachChooseMember.
  ///
  /// In en, this message translates to:
  /// **'Choose a member'**
  String get trainingCoachChooseMember;

  /// No description provided for @trainingCoachMyself.
  ///
  /// In en, this message translates to:
  /// **'Myself'**
  String get trainingCoachMyself;

  /// No description provided for @trainingCoachNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No members match your search'**
  String get trainingCoachNoMatches;

  /// No description provided for @trainingCoachNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No members to coach yet. Members of gyms where you work or train show up here.'**
  String get trainingCoachNoMembers;

  /// No description provided for @trainingCoachNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get trainingCoachNotSignedIn;

  /// No description provided for @trainingCoachSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search members…'**
  String get trainingCoachSearchHint;

  /// No description provided for @trainingCoachYou.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get trainingCoachYou;

  /// No description provided for @trainingDropCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 drop} other{{count} drops}}'**
  String trainingDropCount(int count);

  /// No description provided for @trainingExerciseAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add exercise photo'**
  String get trainingExerciseAddPhoto;

  /// No description provided for @trainingExerciseAllMuscles.
  ///
  /// In en, this message translates to:
  /// **'All muscles'**
  String get trainingExerciseAllMuscles;

  /// No description provided for @trainingExerciseAlternating.
  ///
  /// In en, this message translates to:
  /// **'{name} (alternating)'**
  String trainingExerciseAlternating(String name);

  /// No description provided for @trainingExerciseClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get trainingExerciseClearFilter;

  /// No description provided for @trainingExerciseDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete exercise?'**
  String get trainingExerciseDeleteTitle;

  /// No description provided for @trainingExerciseDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get trainingExerciseDone;

  /// No description provided for @trainingExerciseEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Exercise'**
  String get trainingExerciseEditTitle;

  /// No description provided for @trainingExerciseFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get trainingExerciseFallbackName;

  /// No description provided for @trainingExerciseFilterActiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter by muscle (current: {muscle})'**
  String trainingExerciseFilterActiveTooltip(String muscle);

  /// No description provided for @trainingExerciseFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter by Muscle'**
  String get trainingExerciseFilterTitle;

  /// No description provided for @trainingExerciseFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter by muscle'**
  String get trainingExerciseFilterTooltip;

  /// No description provided for @trainingExerciseMyPrivate.
  ///
  /// In en, this message translates to:
  /// **'My private'**
  String get trainingExerciseMyPrivate;

  /// No description provided for @trainingExerciseNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Exercise name *'**
  String get trainingExerciseNameLabel;

  /// No description provided for @trainingExerciseNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Exercise'**
  String get trainingExerciseNewTitle;

  /// No description provided for @trainingExerciseNoPrivate.
  ///
  /// In en, this message translates to:
  /// **'You have no private exercises'**
  String get trainingExerciseNoPrivate;

  /// No description provided for @trainingExerciseNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No exercises found'**
  String get trainingExerciseNoneFound;

  /// No description provided for @trainingExercisePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo of {name}'**
  String trainingExercisePhoto(String name);

  /// No description provided for @trainingExercisePrimaryMuscles.
  ///
  /// In en, this message translates to:
  /// **'Primary Muscles'**
  String get trainingExercisePrimaryMuscles;

  /// No description provided for @trainingExerciseSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search exercises…'**
  String get trainingExerciseSearchHint;

  /// No description provided for @trainingExerciseSecondaryMuscles.
  ///
  /// In en, this message translates to:
  /// **'Secondary Muscles'**
  String get trainingExerciseSecondaryMuscles;

  /// No description provided for @trainingExerciseTapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select'**
  String get trainingExerciseTapToSelect;

  /// No description provided for @trainingExerciseTargetMuscles.
  ///
  /// In en, this message translates to:
  /// **'Target Muscles'**
  String get trainingExerciseTargetMuscles;

  /// No description provided for @trainingExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get trainingExerciseTitle;

  /// No description provided for @trainingExerciseVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get trainingExerciseVideo;

  /// No description provided for @trainingExerciseVideoUrl.
  ///
  /// In en, this message translates to:
  /// **'Video URL'**
  String get trainingExerciseVideoUrl;

  /// No description provided for @trainingLogBodyweightHint.
  ///
  /// In en, this message translates to:
  /// **'Blank = bodyweight'**
  String get trainingLogBodyweightHint;

  /// No description provided for @trainingLogChooseExercise.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose an exercise'**
  String get trainingLogChooseExercise;

  /// No description provided for @trainingLogCouldNotLogSet.
  ///
  /// In en, this message translates to:
  /// **'Could not log set: {error}'**
  String trainingLogCouldNotLogSet(String error);

  /// No description provided for @trainingLogCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Could not start'**
  String get trainingLogCouldNotStart;

  /// No description provided for @trainingLogElapsed.
  ///
  /// In en, this message translates to:
  /// **'Elapsed time {time}'**
  String trainingLogElapsed(String time);

  /// No description provided for @trainingLogEnterReps.
  ///
  /// In en, this message translates to:
  /// **'Enter the number of reps'**
  String get trainingLogEnterReps;

  /// No description provided for @trainingLogEstimated1rm.
  ///
  /// In en, this message translates to:
  /// **'Estimated 1RM ≈ {weight}'**
  String trainingLogEstimated1rm(String weight);

  /// No description provided for @trainingLogExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get trainingLogExercise;

  /// No description provided for @trainingLogFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get trainingLogFinish;

  /// No description provided for @trainingLogFinishMessage.
  ///
  /// In en, this message translates to:
  /// **'This will record the end time of your workout.'**
  String get trainingLogFinishMessage;

  /// No description provided for @trainingLogFinishMessageOffline.
  ///
  /// In en, this message translates to:
  /// **'This will record the end time of your workout. Sets saved offline will sync when you\'re back online.'**
  String get trainingLogFinishMessageOffline;

  /// No description provided for @trainingLogFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish session?'**
  String get trainingLogFinishTitle;

  /// No description provided for @trainingLogFirstSetHint.
  ///
  /// In en, this message translates to:
  /// **'Tap below to log your first set'**
  String get trainingLogFirstSetHint;

  /// No description provided for @trainingLogKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get trainingLogKeepGoing;

  /// No description provided for @trainingLogLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get trainingLogLog;

  /// No description provided for @trainingLogLogASet.
  ///
  /// In en, this message translates to:
  /// **'Log a Set'**
  String get trainingLogLogASet;

  /// No description provided for @trainingLogLogSet.
  ///
  /// In en, this message translates to:
  /// **'Log Set'**
  String get trainingLogLogSet;

  /// No description provided for @trainingLogLogged.
  ///
  /// In en, this message translates to:
  /// **'Logged'**
  String get trainingLogLogged;

  /// No description provided for @trainingLogNewPr.
  ///
  /// In en, this message translates to:
  /// **'New PR! {exercise}'**
  String trainingLogNewPr(String exercise);

  /// No description provided for @trainingLogNewPrShort.
  ///
  /// In en, this message translates to:
  /// **'New PR'**
  String get trainingLogNewPrShort;

  /// No description provided for @trainingLogNewPrWithE1rm.
  ///
  /// In en, this message translates to:
  /// **'New PR! {exercise} — e1RM {weight}'**
  String trainingLogNewPrWithE1rm(String exercise, String weight);

  /// No description provided for @trainingLogOfflineSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved offline — will sync when you\'re back online'**
  String get trainingLogOfflineSaved;

  /// No description provided for @trainingLogPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get trainingLogPending;

  /// No description provided for @trainingLogPendingSync.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get trainingLogPendingSync;

  /// No description provided for @trainingLogPickExercise.
  ///
  /// In en, this message translates to:
  /// **'Pick an exercise first'**
  String get trainingLogPickExercise;

  /// No description provided for @trainingLogPlateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Plate calculator & warm-up'**
  String get trainingLogPlateTooltip;

  /// No description provided for @trainingLogRepType.
  ///
  /// In en, this message translates to:
  /// **'Rep type'**
  String get trainingLogRepType;

  /// No description provided for @trainingLogSavedOfflineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Saved offline — will sync'**
  String get trainingLogSavedOfflineTooltip;

  /// No description provided for @trainingLogSetHeader.
  ///
  /// In en, this message translates to:
  /// **'Set {number} · {type}'**
  String trainingLogSetHeader(int number, String type);

  /// No description provided for @trainingLogSetHeaderWithRest.
  ///
  /// In en, this message translates to:
  /// **'Set {number} · {type} · rest {rest}'**
  String trainingLogSetHeaderWithRest(int number, String type, String rest);

  /// No description provided for @trainingLogStartRest.
  ///
  /// In en, this message translates to:
  /// **'Start rest timer'**
  String get trainingLogStartRest;

  /// No description provided for @trainingLogStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting session…'**
  String get trainingLogStarting;

  /// No description provided for @trainingLogWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get trainingLogWeight;

  /// No description provided for @trainingMeasureAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get trainingMeasureAdd;

  /// No description provided for @trainingMeasureBodyFatOptional.
  ///
  /// In en, this message translates to:
  /// **'Body fat (optional)'**
  String get trainingMeasureBodyFatOptional;

  /// No description provided for @trainingMeasureBodyFatValue.
  ///
  /// In en, this message translates to:
  /// **'{value} % fat'**
  String trainingMeasureBodyFatValue(String value);

  /// No description provided for @trainingMeasureBodyWeight.
  ///
  /// In en, this message translates to:
  /// **'Body weight'**
  String get trainingMeasureBodyWeight;

  /// No description provided for @trainingMeasureChangeSince.
  ///
  /// In en, this message translates to:
  /// **'{change} since {date}'**
  String trainingMeasureChangeSince(String change, String date);

  /// No description provided for @trainingMeasureDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String trainingMeasureDateLabel(String date);

  /// No description provided for @trainingMeasureDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'The entry from {date} will be removed.'**
  String trainingMeasureDeleteMessage(String date);

  /// No description provided for @trainingMeasureDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete measurement?'**
  String get trainingMeasureDeleteTitle;

  /// No description provided for @trainingMeasureDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete measurement'**
  String get trainingMeasureDeleteTooltip;

  /// No description provided for @trainingMeasureEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit measurement'**
  String get trainingMeasureEditTitle;

  /// No description provided for @trainingMeasureEmptyMessageOther.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet.'**
  String get trainingMeasureEmptyMessageOther;

  /// No description provided for @trainingMeasureEmptyMessageOwn.
  ///
  /// In en, this message translates to:
  /// **'Log your body weight regularly to see your trend here.'**
  String get trainingMeasureEmptyMessageOwn;

  /// No description provided for @trainingMeasureEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No measurements yet'**
  String get trainingMeasureEmptyTitle;

  /// No description provided for @trainingMeasureInvalidNumbers.
  ///
  /// In en, this message translates to:
  /// **'Enter valid numbers'**
  String get trainingMeasureInvalidNumbers;

  /// No description provided for @trainingMeasureLogAction.
  ///
  /// In en, this message translates to:
  /// **'Log measurement'**
  String get trainingMeasureLogAction;

  /// No description provided for @trainingMeasureLogHeading.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get trainingMeasureLogHeading;

  /// No description provided for @trainingMeasureNeedValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a weight or a body-fat value'**
  String get trainingMeasureNeedValue;

  /// No description provided for @trainingMeasureNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get trainingMeasureNoteOptional;

  /// No description provided for @trainingMemberAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get trainingMemberAssign;

  /// No description provided for @trainingMemberAssignMealPlan.
  ///
  /// In en, this message translates to:
  /// **'Assign meal plan'**
  String get trainingMemberAssignMealPlan;

  /// No description provided for @trainingMemberAssignRoutine.
  ///
  /// In en, this message translates to:
  /// **'Assign routine'**
  String get trainingMemberAssignRoutine;

  /// No description provided for @trainingMemberAssignedBy.
  ///
  /// In en, this message translates to:
  /// **'Assigned by {name}'**
  String trainingMemberAssignedBy(String name);

  /// No description provided for @trainingMemberAssignedByAnotherCoach.
  ///
  /// In en, this message translates to:
  /// **'Assigned by another coach'**
  String get trainingMemberAssignedByAnotherCoach;

  /// No description provided for @trainingMemberAssignedByYou.
  ///
  /// In en, this message translates to:
  /// **'Assigned by you'**
  String get trainingMemberAssignedByYou;

  /// No description provided for @trainingMemberFoodDiary.
  ///
  /// In en, this message translates to:
  /// **'Food diary'**
  String get trainingMemberFoodDiary;

  /// No description provided for @trainingMemberFoodDiarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Meals & macros'**
  String get trainingMemberFoodDiarySubtitle;

  /// No description provided for @trainingMemberMealPlans.
  ///
  /// In en, this message translates to:
  /// **'Meal plans'**
  String get trainingMemberMealPlans;

  /// No description provided for @trainingMemberNoMealPlans.
  ///
  /// In en, this message translates to:
  /// **'No meal plans assigned'**
  String get trainingMemberNoMealPlans;

  /// No description provided for @trainingMemberNoRoutines.
  ///
  /// In en, this message translates to:
  /// **'No routines assigned'**
  String get trainingMemberNoRoutines;

  /// No description provided for @trainingMemberNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No training sessions logged yet'**
  String get trainingMemberNoSessions;

  /// No description provided for @trainingMemberProgramWorkout.
  ///
  /// In en, this message translates to:
  /// **'Program workout'**
  String get trainingMemberProgramWorkout;

  /// No description provided for @trainingMemberProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PRs, volume, body weight'**
  String get trainingMemberProgressSubtitle;

  /// No description provided for @trainingMemberRecentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent sessions'**
  String get trainingMemberRecentSessions;

  /// No description provided for @trainingMemberRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get trainingMemberRemove;

  /// No description provided for @trainingMemberRemoveAssignmentMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{plan}\" will no longer be assigned to {member}.'**
  String trainingMemberRemoveAssignmentMessage(String plan, String member);

  /// No description provided for @trainingMemberRemoveAssignmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove assignment?'**
  String get trainingMemberRemoveAssignmentTitle;

  /// No description provided for @trainingMemberRoutines.
  ///
  /// In en, this message translates to:
  /// **'Routines'**
  String get trainingMemberRoutines;

  /// No description provided for @trainingMemberSelfAssigned.
  ///
  /// In en, this message translates to:
  /// **'Self-assigned'**
  String get trainingMemberSelfAssigned;

  /// No description provided for @trainingMuscleAbsLower.
  ///
  /// In en, this message translates to:
  /// **'Lower Abs'**
  String get trainingMuscleAbsLower;

  /// No description provided for @trainingMuscleAbsObliques.
  ///
  /// In en, this message translates to:
  /// **'Obliques'**
  String get trainingMuscleAbsObliques;

  /// No description provided for @trainingMuscleAbsUpper.
  ///
  /// In en, this message translates to:
  /// **'Upper Abs'**
  String get trainingMuscleAbsUpper;

  /// No description provided for @trainingMuscleBackAll.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get trainingMuscleBackAll;

  /// No description provided for @trainingMuscleBackLats.
  ///
  /// In en, this message translates to:
  /// **'Lats'**
  String get trainingMuscleBackLats;

  /// No description provided for @trainingMuscleBackLower.
  ///
  /// In en, this message translates to:
  /// **'Lower Back'**
  String get trainingMuscleBackLower;

  /// No description provided for @trainingMuscleBackMid.
  ///
  /// In en, this message translates to:
  /// **'Mid Back'**
  String get trainingMuscleBackMid;

  /// No description provided for @trainingMuscleBackRhomboids.
  ///
  /// In en, this message translates to:
  /// **'Rhomboids'**
  String get trainingMuscleBackRhomboids;

  /// No description provided for @trainingMuscleBackTraps.
  ///
  /// In en, this message translates to:
  /// **'Traps'**
  String get trainingMuscleBackTraps;

  /// No description provided for @trainingMuscleBackUpper.
  ///
  /// In en, this message translates to:
  /// **'Upper Back'**
  String get trainingMuscleBackUpper;

  /// No description provided for @trainingMuscleBiceps.
  ///
  /// In en, this message translates to:
  /// **'Biceps'**
  String get trainingMuscleBiceps;

  /// No description provided for @trainingMuscleCalves.
  ///
  /// In en, this message translates to:
  /// **'Calves'**
  String get trainingMuscleCalves;

  /// No description provided for @trainingMuscleChestAll.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get trainingMuscleChestAll;

  /// No description provided for @trainingMuscleChestLower.
  ///
  /// In en, this message translates to:
  /// **'Lower Chest'**
  String get trainingMuscleChestLower;

  /// No description provided for @trainingMuscleChestUpper.
  ///
  /// In en, this message translates to:
  /// **'Upper Chest'**
  String get trainingMuscleChestUpper;

  /// No description provided for @trainingMuscleDeltsAll.
  ///
  /// In en, this message translates to:
  /// **'Deltoids'**
  String get trainingMuscleDeltsAll;

  /// No description provided for @trainingMuscleDeltsFront.
  ///
  /// In en, this message translates to:
  /// **'Front Delt'**
  String get trainingMuscleDeltsFront;

  /// No description provided for @trainingMuscleDeltsMedial.
  ///
  /// In en, this message translates to:
  /// **'Side Delt'**
  String get trainingMuscleDeltsMedial;

  /// No description provided for @trainingMuscleDeltsRear.
  ///
  /// In en, this message translates to:
  /// **'Rear Delt'**
  String get trainingMuscleDeltsRear;

  /// No description provided for @trainingMuscleForearmsAll.
  ///
  /// In en, this message translates to:
  /// **'Forearms'**
  String get trainingMuscleForearmsAll;

  /// No description provided for @trainingMuscleForearmsBottom.
  ///
  /// In en, this message translates to:
  /// **'Forearms (Bottom)'**
  String get trainingMuscleForearmsBottom;

  /// No description provided for @trainingMuscleForearmsTop.
  ///
  /// In en, this message translates to:
  /// **'Forearms (Top)'**
  String get trainingMuscleForearmsTop;

  /// No description provided for @trainingMuscleGlutesAll.
  ///
  /// In en, this message translates to:
  /// **'Glutes'**
  String get trainingMuscleGlutesAll;

  /// No description provided for @trainingMuscleGlutesMaximus.
  ///
  /// In en, this message translates to:
  /// **'Glute Maximus'**
  String get trainingMuscleGlutesMaximus;

  /// No description provided for @trainingMuscleGlutesMedius.
  ///
  /// In en, this message translates to:
  /// **'Glute Medius'**
  String get trainingMuscleGlutesMedius;

  /// No description provided for @trainingMuscleGlutesMinimus.
  ///
  /// In en, this message translates to:
  /// **'Glute Minimus'**
  String get trainingMuscleGlutesMinimus;

  /// No description provided for @trainingMuscleHamstrings.
  ///
  /// In en, this message translates to:
  /// **'Hamstrings'**
  String get trainingMuscleHamstrings;

  /// No description provided for @trainingMuscleMapLabel.
  ///
  /// In en, this message translates to:
  /// **'Muscle diagram'**
  String get trainingMuscleMapLabel;

  /// No description provided for @trainingMuscleMapLegendSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get trainingMuscleMapLegendSecondary;

  /// No description provided for @trainingMuscleMapLegendTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get trainingMuscleMapLegendTarget;

  /// No description provided for @trainingMuscleMapNone.
  ///
  /// In en, this message translates to:
  /// **'No muscles highlighted'**
  String get trainingMuscleMapNone;

  /// No description provided for @trainingMuscleMapPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary: {muscles}'**
  String trainingMuscleMapPrimary(String muscles);

  /// No description provided for @trainingMuscleMapSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary: {muscles}'**
  String trainingMuscleMapSecondary(String muscles);

  /// No description provided for @trainingMuscleNeck.
  ///
  /// In en, this message translates to:
  /// **'Neck'**
  String get trainingMuscleNeck;

  /// No description provided for @trainingMuscleQuadsAll.
  ///
  /// In en, this message translates to:
  /// **'Quads'**
  String get trainingMuscleQuadsAll;

  /// No description provided for @trainingMuscleQuadsLateral.
  ///
  /// In en, this message translates to:
  /// **'Lateral Quad'**
  String get trainingMuscleQuadsLateral;

  /// No description provided for @trainingMuscleQuadsMedial.
  ///
  /// In en, this message translates to:
  /// **'Medial Quad'**
  String get trainingMuscleQuadsMedial;

  /// No description provided for @trainingMuscleTricepsAll.
  ///
  /// In en, this message translates to:
  /// **'Triceps'**
  String get trainingMuscleTricepsAll;

  /// No description provided for @trainingMuscleTricepsLateral.
  ///
  /// In en, this message translates to:
  /// **'Triceps Lateral'**
  String get trainingMuscleTricepsLateral;

  /// No description provided for @trainingMuscleTricepsLong.
  ///
  /// In en, this message translates to:
  /// **'Triceps Long Head'**
  String get trainingMuscleTricepsLong;

  /// No description provided for @trainingMuscleTricepsMedial.
  ///
  /// In en, this message translates to:
  /// **'Triceps Medial'**
  String get trainingMuscleTricepsMedial;

  /// No description provided for @trainingPlanAddCoverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add cover photo'**
  String get trainingPlanAddCoverPhoto;

  /// No description provided for @trainingPlanAddDrop.
  ///
  /// In en, this message translates to:
  /// **'Add Drop'**
  String get trainingPlanAddDrop;

  /// No description provided for @trainingPlanAddExerciseToSuperset.
  ///
  /// In en, this message translates to:
  /// **'Add Exercise to Superset'**
  String get trainingPlanAddExerciseToSuperset;

  /// No description provided for @trainingPlanAddSet.
  ///
  /// In en, this message translates to:
  /// **'Add Set'**
  String get trainingPlanAddSet;

  /// No description provided for @trainingPlanAlternating.
  ///
  /// In en, this message translates to:
  /// **'Alternating'**
  String get trainingPlanAlternating;

  /// No description provided for @trainingPlanAlternatingShort.
  ///
  /// In en, this message translates to:
  /// **'Alt.'**
  String get trainingPlanAlternatingShort;

  /// No description provided for @trainingPlanCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get trainingPlanCollapse;

  /// No description provided for @trainingPlanDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" permanently?'**
  String trainingPlanDeleteBody(String name);

  /// No description provided for @trainingPlanDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete training?'**
  String get trainingPlanDeleteTitle;

  /// No description provided for @trainingPlanDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get trainingPlanDescriptionLabel;

  /// No description provided for @trainingPlanDropLine.
  ///
  /// In en, this message translates to:
  /// **'Drop {number}: {details}'**
  String trainingPlanDropLine(int number, String details);

  /// No description provided for @trainingPlanDropNumber.
  ///
  /// In en, this message translates to:
  /// **'Drop {number}'**
  String trainingPlanDropNumber(int number);

  /// No description provided for @trainingPlanEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Training'**
  String get trainingPlanEditTitle;

  /// No description provided for @trainingPlanExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get trainingPlanExpand;

  /// No description provided for @trainingPlanMakeDropset.
  ///
  /// In en, this message translates to:
  /// **'Make Dropset'**
  String get trainingPlanMakeDropset;

  /// No description provided for @trainingPlanMusclesTrained.
  ///
  /// In en, this message translates to:
  /// **'Muscles Trained'**
  String get trainingPlanMusclesTrained;

  /// No description provided for @trainingPlanNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Training name *'**
  String get trainingPlanNameLabel;

  /// No description provided for @trainingPlanNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get trainingPlanNotes;

  /// No description provided for @trainingPlanPickExercise.
  ///
  /// In en, this message translates to:
  /// **'Pick exercise'**
  String get trainingPlanPickExercise;

  /// No description provided for @trainingPlanProgramme.
  ///
  /// In en, this message translates to:
  /// **'Programme'**
  String get trainingPlanProgramme;

  /// No description provided for @trainingPlanPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get trainingPlanPublic;

  /// No description provided for @trainingPlanPublicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visible to all users'**
  String get trainingPlanPublicSubtitle;

  /// No description provided for @trainingPlanRemoveDrop.
  ///
  /// In en, this message translates to:
  /// **'Remove drop'**
  String get trainingPlanRemoveDrop;

  /// No description provided for @trainingPlanRemoveExercise.
  ///
  /// In en, this message translates to:
  /// **'Remove exercise'**
  String get trainingPlanRemoveExercise;

  /// No description provided for @trainingPlanRemoveSet.
  ///
  /// In en, this message translates to:
  /// **'Remove set'**
  String get trainingPlanRemoveSet;

  /// No description provided for @trainingPlanReorderSet.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get trainingPlanReorderSet;

  /// No description provided for @trainingPlanRestSeconds.
  ///
  /// In en, this message translates to:
  /// **'Rest {seconds}s'**
  String trainingPlanRestSeconds(int seconds);

  /// No description provided for @trainingPlanSelectExercise.
  ///
  /// In en, this message translates to:
  /// **'Select exercise…'**
  String get trainingPlanSelectExercise;

  /// No description provided for @trainingPlanSets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get trainingPlanSets;

  /// No description provided for @trainingPlanStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get trainingPlanStartSession;

  /// No description provided for @trainingPlateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Plates: {plates}'**
  String trainingPlateAvailable(String plates);

  /// No description provided for @trainingPlateBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get trainingPlateBar;

  /// No description provided for @trainingPlateEachSide.
  ///
  /// In en, this message translates to:
  /// **'Each side'**
  String get trainingPlateEachSide;

  /// No description provided for @trainingPlateEmptyBar.
  ///
  /// In en, this message translates to:
  /// **'Empty bar'**
  String get trainingPlateEmptyBar;

  /// No description provided for @trainingPlateEnterTarget.
  ///
  /// In en, this message translates to:
  /// **'Enter a target weight to see the plates for each side.'**
  String get trainingPlateEnterTarget;

  /// No description provided for @trainingPlateNoWarmup.
  ///
  /// In en, this message translates to:
  /// **'Target is at or below the bar — no warm-up plates needed.'**
  String get trainingPlateNoWarmup;

  /// No description provided for @trainingPlateNotExact.
  ///
  /// In en, this message translates to:
  /// **'{target} can\'t be loaded exactly. Closest: {closest} ({difference}).'**
  String trainingPlateNotExact(
    String target,
    String closest,
    String difference,
  );

  /// No description provided for @trainingPlatePerSide.
  ///
  /// In en, this message translates to:
  /// **'Per side: {plates}'**
  String trainingPlatePerSide(String plates);

  /// No description provided for @trainingPlateSuggestedRamp.
  ///
  /// In en, this message translates to:
  /// **'Suggested ramp to {weight}'**
  String trainingPlateSuggestedRamp(String weight);

  /// No description provided for @trainingPlateTargetWeight.
  ///
  /// In en, this message translates to:
  /// **'Target weight'**
  String get trainingPlateTargetWeight;

  /// No description provided for @trainingPlateTitle.
  ///
  /// In en, this message translates to:
  /// **'Plate calculator'**
  String get trainingPlateTitle;

  /// No description provided for @trainingPlateTotal.
  ///
  /// In en, this message translates to:
  /// **'Total {weight}'**
  String trainingPlateTotal(String weight);

  /// No description provided for @trainingPlateWarmup.
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get trainingPlateWarmup;

  /// No description provided for @trainingProgressBestE1rm.
  ///
  /// In en, this message translates to:
  /// **'Best e1RM'**
  String get trainingProgressBestE1rm;

  /// No description provided for @trainingProgressBestVolume.
  ///
  /// In en, this message translates to:
  /// **'Best volume'**
  String get trainingProgressBestVolume;

  /// No description provided for @trainingProgressChartE1rm.
  ///
  /// In en, this message translates to:
  /// **'Estimated 1-rep max ({unit})'**
  String trainingProgressChartE1rm(String unit);

  /// No description provided for @trainingProgressChartVolume.
  ///
  /// In en, this message translates to:
  /// **'Session volume ({unit} × reps)'**
  String trainingProgressChartVolume(String unit);

  /// No description provided for @trainingProgressChartWeight.
  ///
  /// In en, this message translates to:
  /// **'Heaviest set ({unit})'**
  String trainingProgressChartWeight(String unit);

  /// No description provided for @trainingProgressE1rm.
  ///
  /// In en, this message translates to:
  /// **'e1RM {weight}'**
  String trainingProgressE1rm(String weight);

  /// No description provided for @trainingProgressEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Log a session and your volume, streak and personal records will show up here.'**
  String get trainingProgressEmptyMessage;

  /// No description provided for @trainingProgressEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No training logged yet'**
  String get trainingProgressEmptyTitle;

  /// No description provided for @trainingProgressExercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get trainingProgressExercises;

  /// No description provided for @trainingProgressFilterExercises.
  ///
  /// In en, this message translates to:
  /// **'Filter exercises…'**
  String get trainingProgressFilterExercises;

  /// No description provided for @trainingProgressHeaviest.
  ///
  /// In en, this message translates to:
  /// **'Heaviest'**
  String get trainingProgressHeaviest;

  /// No description provided for @trainingProgressLast30Days.
  ///
  /// In en, this message translates to:
  /// **'last 30 days'**
  String get trainingProgressLast30Days;

  /// No description provided for @trainingProgressLastSession.
  ///
  /// In en, this message translates to:
  /// **'Last session: {when}'**
  String trainingProgressLastSession(String when);

  /// No description provided for @trainingProgressMetricE1rm.
  ///
  /// In en, this message translates to:
  /// **'e1RM'**
  String get trainingProgressMetricE1rm;

  /// No description provided for @trainingProgressMetricVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get trainingProgressMetricVolume;

  /// No description provided for @trainingProgressMetricWeight.
  ///
  /// In en, this message translates to:
  /// **'Best weight'**
  String get trainingProgressMetricWeight;

  /// No description provided for @trainingProgressNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get trainingProgressNoData;

  /// No description provided for @trainingProgressNoExercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises logged yet'**
  String get trainingProgressNoExercises;

  /// No description provided for @trainingProgressNoExercisesMatch.
  ///
  /// In en, this message translates to:
  /// **'No exercises match'**
  String get trainingProgressNoExercisesMatch;

  /// No description provided for @trainingProgressNoRecentPrs.
  ///
  /// In en, this message translates to:
  /// **'No new personal records in the last 30 days. Beat your best estimated 1RM on any lift to set one.'**
  String get trainingProgressNoRecentPrs;

  /// No description provided for @trainingProgressNoSessionsInRange.
  ///
  /// In en, this message translates to:
  /// **'No sessions in this range'**
  String get trainingProgressNoSessionsInRange;

  /// No description provided for @trainingProgressPersonalRecords.
  ///
  /// In en, this message translates to:
  /// **'Personal records'**
  String get trainingProgressPersonalRecords;

  /// No description provided for @trainingProgressRange1m.
  ///
  /// In en, this message translates to:
  /// **'1M'**
  String get trainingProgressRange1m;

  /// No description provided for @trainingProgressRange3m.
  ///
  /// In en, this message translates to:
  /// **'3M'**
  String get trainingProgressRange3m;

  /// No description provided for @trainingProgressRange6m.
  ///
  /// In en, this message translates to:
  /// **'6M'**
  String get trainingProgressRange6m;

  /// No description provided for @trainingProgressRangeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get trainingProgressRangeAll;

  /// No description provided for @trainingProgressRecentPrs.
  ///
  /// In en, this message translates to:
  /// **'Recent PRs'**
  String get trainingProgressRecentPrs;

  /// No description provided for @trainingProgressRepsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rep} other{{count} reps}}'**
  String trainingProgressRepsCount(int count);

  /// No description provided for @trainingProgressSeriesE1rm.
  ///
  /// In en, this message translates to:
  /// **'Estimated 1RM'**
  String get trainingProgressSeriesE1rm;

  /// No description provided for @trainingProgressSeriesVolume.
  ///
  /// In en, this message translates to:
  /// **'Session volume'**
  String get trainingProgressSeriesVolume;

  /// No description provided for @trainingProgressSeriesWeight.
  ///
  /// In en, this message translates to:
  /// **'Heaviest set'**
  String get trainingProgressSeriesWeight;

  /// No description provided for @trainingProgressSessionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}}'**
  String trainingProgressSessionCount(int count);

  /// No description provided for @trainingProgressSessionsHeading.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get trainingProgressSessionsHeading;

  /// No description provided for @trainingProgressSessionsInRange.
  ///
  /// In en, this message translates to:
  /// **'Sessions ({range})'**
  String trainingProgressSessionsInRange(String range);

  /// No description provided for @trainingProgressStatSessions30d.
  ///
  /// In en, this message translates to:
  /// **'Sessions · 30 days'**
  String get trainingProgressStatSessions30d;

  /// No description provided for @trainingProgressStatSessions7d.
  ///
  /// In en, this message translates to:
  /// **'Sessions · 7 days'**
  String get trainingProgressStatSessions7d;

  /// No description provided for @trainingProgressStatStreak.
  ///
  /// In en, this message translates to:
  /// **'Weekly streak'**
  String get trainingProgressStatStreak;

  /// No description provided for @trainingProgressStatVolume30d.
  ///
  /// In en, this message translates to:
  /// **'Volume · 30 days'**
  String get trainingProgressStatVolume30d;

  /// No description provided for @trainingProgressStreakDone.
  ///
  /// In en, this message translates to:
  /// **'Trained this week'**
  String get trainingProgressStreakDone;

  /// No description provided for @trainingProgressStreakKeep.
  ///
  /// In en, this message translates to:
  /// **'Train this week to keep it'**
  String get trainingProgressStreakKeep;

  /// No description provided for @trainingProgressStreakStart.
  ///
  /// In en, this message translates to:
  /// **'Train this week to start one'**
  String get trainingProgressStreakStart;

  /// No description provided for @trainingProgressStreakWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 wk} other{{count} wks}}'**
  String trainingProgressStreakWeeks(int count);

  /// No description provided for @trainingProgressTabBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get trainingProgressTabBody;

  /// No description provided for @trainingProgressTabTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get trainingProgressTabTraining;

  /// No description provided for @trainingProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get trainingProgressTitle;

  /// No description provided for @trainingProgressTopWeight.
  ///
  /// In en, this message translates to:
  /// **'Top {weight}'**
  String trainingProgressTopWeight(String weight);

  /// No description provided for @trainingProgressTrendSemantics.
  ///
  /// In en, this message translates to:
  /// **'Trend, last value {value}'**
  String trainingProgressTrendSemantics(String value);

  /// No description provided for @trainingProgressYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get trainingProgressYesterday;

  /// No description provided for @trainingRepFailureShort.
  ///
  /// In en, this message translates to:
  /// **'Failure'**
  String get trainingRepFailureShort;

  /// No description provided for @trainingRepTypeCount.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get trainingRepTypeCount;

  /// No description provided for @trainingRepTypeFailure.
  ///
  /// In en, this message translates to:
  /// **'To Failure'**
  String get trainingRepTypeFailure;

  /// Planned/logged rep count, e.g. 8x
  ///
  /// In en, this message translates to:
  /// **'{count}x'**
  String trainingRepsTimes(int count);

  /// No description provided for @trainingRestAddSeconds.
  ///
  /// In en, this message translates to:
  /// **'+{seconds} s'**
  String trainingRestAddSeconds(int seconds);

  /// No description provided for @trainingRestAddSecondsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add {seconds} seconds'**
  String trainingRestAddSecondsTooltip(int seconds);

  /// No description provided for @trainingRestPresetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rest for {time}'**
  String trainingRestPresetTooltip(String time);

  /// No description provided for @trainingRestRemaining.
  ///
  /// In en, this message translates to:
  /// **'{time} of rest remaining'**
  String trainingRestRemaining(String time);

  /// No description provided for @trainingRestSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get trainingRestSkip;

  /// No description provided for @trainingRestTitle.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get trainingRestTitle;

  /// No description provided for @trainingRoutineAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get trainingRoutineAdd;

  /// No description provided for @trainingRoutineDayHint.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get trainingRoutineDayHint;

  /// No description provided for @trainingRoutineDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete routine?'**
  String get trainingRoutineDeleteTitle;

  /// No description provided for @trainingRoutineDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete routine'**
  String get trainingRoutineDeleteTooltip;

  /// No description provided for @trainingRoutineEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Routine'**
  String get trainingRoutineEditTitle;

  /// No description provided for @trainingRoutineEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit routine'**
  String get trainingRoutineEditTooltip;

  /// No description provided for @trainingRoutineInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get trainingRoutineInvalidNumber;

  /// No description provided for @trainingRoutineInvalidWeeks.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number of weeks'**
  String get trainingRoutineInvalidWeeks;

  /// No description provided for @trainingRoutineMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get trainingRoutineMine;

  /// No description provided for @trainingRoutineNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Routine name *'**
  String get trainingRoutineNameLabel;

  /// No description provided for @trainingRoutineNoTrainings.
  ///
  /// In en, this message translates to:
  /// **'No trainings assigned yet'**
  String get trainingRoutineNoTrainings;

  /// No description provided for @trainingRoutineNoTrainingsAdded.
  ///
  /// In en, this message translates to:
  /// **'No trainings added yet'**
  String get trainingRoutineNoTrainingsAdded;

  /// No description provided for @trainingRoutineNumWeeksHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 12'**
  String get trainingRoutineNumWeeksHint;

  /// No description provided for @trainingRoutineNumWeeksLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of weeks *'**
  String get trainingRoutineNumWeeksLabel;

  /// No description provided for @trainingRoutinePrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get trainingRoutinePrivate;

  /// No description provided for @trainingRoutineRemoveTraining.
  ///
  /// In en, this message translates to:
  /// **'Remove training'**
  String get trainingRoutineRemoveTraining;

  /// No description provided for @trainingRoutineRestDay.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get trainingRoutineRestDay;

  /// No description provided for @trainingRoutineSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get trainingRoutineSchedule;

  /// No description provided for @trainingRoutineScheduleType.
  ///
  /// In en, this message translates to:
  /// **'Schedule Type'**
  String get trainingRoutineScheduleType;

  /// No description provided for @trainingRoutineSearchTrainingsHint.
  ///
  /// In en, this message translates to:
  /// **'Search trainings…'**
  String get trainingRoutineSearchTrainingsHint;

  /// No description provided for @trainingRoutineTrainingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 training} other{{count} trainings}}'**
  String trainingRoutineTrainingCount(int count);

  /// No description provided for @trainingRoutineTrainingFallback.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get trainingRoutineTrainingFallback;

  /// No description provided for @trainingRoutineWeek.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String trainingRoutineWeek(int week);

  /// No description provided for @trainingRoutineWeekShort.
  ///
  /// In en, this message translates to:
  /// **'Wk {week}'**
  String trainingRoutineWeekShort(int week);

  /// No description provided for @trainingRoutineWeekShortHint.
  ///
  /// In en, this message translates to:
  /// **'Wk'**
  String get trainingRoutineWeekShortHint;

  /// No description provided for @trainingScheduleFixedWeeks.
  ///
  /// In en, this message translates to:
  /// **'Fixed Weeks'**
  String get trainingScheduleFixedWeeks;

  /// No description provided for @trainingScheduleHasClasses.
  ///
  /// In en, this message translates to:
  /// **'has classes'**
  String get trainingScheduleHasClasses;

  /// No description provided for @trainingScheduleHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String trainingScheduleHours(int hours);

  /// No description provided for @trainingScheduleHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String trainingScheduleHoursMinutes(int hours, int minutes);

  /// No description provided for @trainingScheduleMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String trainingScheduleMinutes(int minutes);

  /// Time range that ends the next day
  ///
  /// In en, this message translates to:
  /// **'{range} (+1 day)'**
  String trainingScheduleNextDay(String range);

  /// No description provided for @trainingScheduleNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get trainingScheduleNextWeek;

  /// No description provided for @trainingSchedulePreviousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get trainingSchedulePreviousWeek;

  /// No description provided for @trainingScheduleThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get trainingScheduleThisWeek;

  /// No description provided for @trainingScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get trainingScheduleTitle;

  /// No description provided for @trainingScheduleTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get trainingScheduleTomorrow;

  /// No description provided for @trainingScheduleWildcard.
  ///
  /// In en, this message translates to:
  /// **'Wildcard'**
  String get trainingScheduleWildcard;

  /// No description provided for @trainingScheduleYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get trainingScheduleYesterday;

  /// No description provided for @trainingSessionAddDrop.
  ///
  /// In en, this message translates to:
  /// **'Add drop'**
  String get trainingSessionAddDrop;

  /// No description provided for @trainingSessionCommentAthlete.
  ///
  /// In en, this message translates to:
  /// **'Athlete'**
  String get trainingSessionCommentAthlete;

  /// No description provided for @trainingSessionCommentCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get trainingSessionCommentCoach;

  /// No description provided for @trainingSessionCommentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 comment} other{{count} comments}}'**
  String trainingSessionCommentCount(int count);

  /// No description provided for @trainingSessionCommentDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This comment will be permanently removed.'**
  String get trainingSessionCommentDeleteMessage;

  /// No description provided for @trainingSessionCommentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete comment?'**
  String get trainingSessionCommentDeleteTitle;

  /// No description provided for @trainingSessionCommentEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get trainingSessionCommentEditTitle;

  /// No description provided for @trainingSessionCommentEdited.
  ///
  /// In en, this message translates to:
  /// **'{when} · edited'**
  String trainingSessionCommentEdited(String when);

  /// No description provided for @trainingSessionCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get trainingSessionCommentHint;

  /// No description provided for @trainingSessionCommentOptions.
  ///
  /// In en, this message translates to:
  /// **'Comment options'**
  String get trainingSessionCommentOptions;

  /// No description provided for @trainingSessionCommentYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get trainingSessionCommentYou;

  /// No description provided for @trainingSessionComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get trainingSessionComments;

  /// No description provided for @trainingSessionDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get trainingSessionDate;

  /// No description provided for @trainingSessionDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This log entry will be permanently removed.'**
  String get trainingSessionDeleteMessage;

  /// No description provided for @trainingSessionDeleteSetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete set'**
  String get trainingSessionDeleteSetTooltip;

  /// No description provided for @trainingSessionDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete session?'**
  String get trainingSessionDeleteTitle;

  /// No description provided for @trainingSessionDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get trainingSessionDeleteTooltip;

  /// No description provided for @trainingSessionDeletedUser.
  ///
  /// In en, this message translates to:
  /// **'Deleted user'**
  String get trainingSessionDeletedUser;

  /// No description provided for @trainingSessionDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Detail'**
  String get trainingSessionDetailTitle;

  /// No description provided for @trainingSessionDropNumber.
  ///
  /// In en, this message translates to:
  /// **'Drop {number}'**
  String trainingSessionDropNumber(int number);

  /// No description provided for @trainingSessionDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get trainingSessionDuration;

  /// No description provided for @trainingSessionDurationSemantics.
  ///
  /// In en, this message translates to:
  /// **'Duration {duration}'**
  String trainingSessionDurationSemantics(String duration);

  /// No description provided for @trainingSessionEditSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {title}'**
  String trainingSessionEditSetTitle(String title);

  /// No description provided for @trainingSessionEditSetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit set'**
  String get trainingSessionEditSetTooltip;

  /// No description provided for @trainingSessionFree.
  ///
  /// In en, this message translates to:
  /// **'Free Session'**
  String get trainingSessionFree;

  /// No description provided for @trainingSessionInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get trainingSessionInProgress;

  /// No description provided for @trainingSessionNoComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Coaches and the athlete can leave feedback here.'**
  String get trainingSessionNoComments;

  /// No description provided for @trainingSessionNoReps.
  ///
  /// In en, this message translates to:
  /// **'No reps recorded'**
  String get trainingSessionNoReps;

  /// No description provided for @trainingSessionNoSets.
  ///
  /// In en, this message translates to:
  /// **'No sets logged'**
  String get trainingSessionNoSets;

  /// No description provided for @trainingSessionNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get trainingSessionNote;

  /// No description provided for @trainingSessionNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get trainingSessionNotes;

  /// No description provided for @trainingSessionPlanned.
  ///
  /// In en, this message translates to:
  /// **'Training Session'**
  String get trainingSessionPlanned;

  /// No description provided for @trainingSessionRemoveDrop.
  ///
  /// In en, this message translates to:
  /// **'Remove drop'**
  String get trainingSessionRemoveDrop;

  /// No description provided for @trainingSessionRepType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get trainingSessionRepType;

  /// No description provided for @trainingSessionRepsWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Reps must be a whole number'**
  String get trainingSessionRepsWholeNumber;

  /// No description provided for @trainingSessionSendComment.
  ///
  /// In en, this message translates to:
  /// **'Send comment'**
  String get trainingSessionSendComment;

  /// No description provided for @trainingSessionSetDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This logged set will be permanently removed.'**
  String get trainingSessionSetDeleteMessage;

  /// No description provided for @trainingSessionSetDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete set?'**
  String get trainingSessionSetDeleteTitle;

  /// No description provided for @trainingSessionSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set {number}'**
  String trainingSessionSetTitle(int number);

  /// No description provided for @trainingSessionSetTitleWithExercise.
  ///
  /// In en, this message translates to:
  /// **'Set {number} · {exercise}'**
  String trainingSessionSetTitleWithExercise(int number, String exercise);

  /// No description provided for @trainingSessionSetsLogged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Set Logged} other{{count} Sets Logged}}'**
  String trainingSessionSetsLogged(int count);

  /// No description provided for @trainingSessionTapToEdit.
  ///
  /// In en, this message translates to:
  /// **'Tap a set to edit it.'**
  String get trainingSessionTapToEdit;

  /// No description provided for @trainingSessionTodayAt.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String trainingSessionTodayAt(String time);

  /// No description provided for @trainingSessionTrainer.
  ///
  /// In en, this message translates to:
  /// **'Trainer'**
  String get trainingSessionTrainer;

  /// No description provided for @trainingSessionWeightNumber.
  ///
  /// In en, this message translates to:
  /// **'Weight must be a number'**
  String get trainingSessionWeightNumber;

  /// No description provided for @trainingSessionYesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String trainingSessionYesterdayAt(String time);

  /// No description provided for @trainingSessionsClassesTitle.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get trainingSessionsClassesTitle;

  /// No description provided for @trainingSessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get trainingSessionsEmpty;

  /// No description provided for @trainingSessionsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to start your first workout'**
  String get trainingSessionsEmptyHint;

  /// No description provided for @trainingSessionsMyProgress.
  ///
  /// In en, this message translates to:
  /// **'My progress'**
  String get trainingSessionsMyProgress;

  /// No description provided for @trainingSessionsNew.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get trainingSessionsNew;

  /// No description provided for @trainingSessionsNoClasses.
  ///
  /// In en, this message translates to:
  /// **'No classes yet'**
  String get trainingSessionsNoClasses;

  /// No description provided for @trainingSessionsNoClassesHint.
  ///
  /// In en, this message translates to:
  /// **'Sessions you run for members will show up here'**
  String get trainingSessionsNoClassesHint;

  /// No description provided for @trainingSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get trainingSessionsTitle;

  /// No description provided for @trainingSetTypeCircuit.
  ///
  /// In en, this message translates to:
  /// **'Circuit'**
  String get trainingSetTypeCircuit;

  /// No description provided for @trainingSetTypeDropset.
  ///
  /// In en, this message translates to:
  /// **'Drop Set'**
  String get trainingSetTypeDropset;

  /// No description provided for @trainingSetTypeStandard.
  ///
  /// In en, this message translates to:
  /// **'Straight Set'**
  String get trainingSetTypeStandard;

  /// No description provided for @trainingSetTypeSuperset.
  ///
  /// In en, this message translates to:
  /// **'Superset'**
  String get trainingSetTypeSuperset;

  /// No description provided for @trainingShiftAdd.
  ///
  /// In en, this message translates to:
  /// **'Add shift'**
  String get trainingShiftAdd;

  /// No description provided for @trainingShiftAddOn.
  ///
  /// In en, this message translates to:
  /// **'Add shift on {day}'**
  String trainingShiftAddOn(String day);

  /// No description provided for @trainingShiftAddOne.
  ///
  /// In en, this message translates to:
  /// **'Add a shift'**
  String get trainingShiftAddOne;

  /// No description provided for @trainingShiftAdded.
  ///
  /// In en, this message translates to:
  /// **'Shift added'**
  String get trainingShiftAdded;

  /// No description provided for @trainingShiftCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 shift} other{{count} shifts}}'**
  String trainingShiftCount(int count);

  /// No description provided for @trainingShiftDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete shift'**
  String get trainingShiftDelete;

  /// No description provided for @trainingShiftDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s shift on {day} will be removed.'**
  String trainingShiftDeleteMessage(String name, String day);

  /// No description provided for @trainingShiftDeleteNotifyMessage.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s shift on {day} will be removed and they\'ll be notified.'**
  String trainingShiftDeleteNotifyMessage(String name, String day);

  /// No description provided for @trainingShiftDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete shift?'**
  String get trainingShiftDeleteQuestion;

  /// No description provided for @trainingShiftDeleted.
  ///
  /// In en, this message translates to:
  /// **'Shift deleted'**
  String get trainingShiftDeleted;

  /// No description provided for @trainingShiftEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit shift'**
  String get trainingShiftEdit;

  /// No description provided for @trainingShiftEnd.
  ///
  /// In en, this message translates to:
  /// **'End {time}'**
  String trainingShiftEnd(String time);

  /// No description provided for @trainingShiftEndsNextDay.
  ///
  /// In en, this message translates to:
  /// **'{duration} · ends the next day'**
  String trainingShiftEndsNextDay(String duration);

  /// No description provided for @trainingShiftFree.
  ///
  /// In en, this message translates to:
  /// **'You\'re free. New shifts will show up here.'**
  String get trainingShiftFree;

  /// No description provided for @trainingShiftLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load shifts'**
  String get trainingShiftLoadFailed;

  /// No description provided for @trainingShiftMyShifts.
  ///
  /// In en, this message translates to:
  /// **'My shifts'**
  String get trainingShiftMyShifts;

  /// No description provided for @trainingShiftNew.
  ///
  /// In en, this message translates to:
  /// **'New shift'**
  String get trainingShiftNew;

  /// No description provided for @trainingShiftNextDays.
  ///
  /// In en, this message translates to:
  /// **'Next {days} days'**
  String trainingShiftNextDays(int days);

  /// No description provided for @trainingShiftNextShifts.
  ///
  /// In en, this message translates to:
  /// **'Next shifts'**
  String get trainingShiftNextShifts;

  /// No description provided for @trainingShiftNoStaff.
  ///
  /// In en, this message translates to:
  /// **'No staff to schedule'**
  String get trainingShiftNoStaff;

  /// No description provided for @trainingShiftNoStaffMessage.
  ///
  /// In en, this message translates to:
  /// **'Add employees, employee-trainers or trainers to this gym first.'**
  String get trainingShiftNoStaffMessage;

  /// No description provided for @trainingShiftNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming shifts'**
  String get trainingShiftNoUpcoming;

  /// No description provided for @trainingShiftNoUpcomingMessage.
  ///
  /// In en, this message translates to:
  /// **'When a manager schedules you, your shifts show up here and you get a notification.'**
  String get trainingShiftNoUpcomingMessage;

  /// No description provided for @trainingShiftNone.
  ///
  /// In en, this message translates to:
  /// **'No shifts'**
  String get trainingShiftNone;

  /// No description provided for @trainingShiftNoneThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No shifts this week'**
  String get trainingShiftNoneThisWeek;

  /// No description provided for @trainingShiftNoneThisWeekManage.
  ///
  /// In en, this message translates to:
  /// **'Plan who\'s working when. Staff get notified about their shifts.'**
  String get trainingShiftNoneThisWeekManage;

  /// No description provided for @trainingShiftNoneThisWeekMessage.
  ///
  /// In en, this message translates to:
  /// **'No one has been scheduled for this week yet.'**
  String get trainingShiftNoneThisWeekMessage;

  /// No description provided for @trainingShiftNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Front desk, open up'**
  String get trainingShiftNoteHint;

  /// No description provided for @trainingShiftNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get trainingShiftNoteOptional;

  /// No description provided for @trainingShiftOnNow.
  ///
  /// In en, this message translates to:
  /// **'On now'**
  String get trainingShiftOnNow;

  /// No description provided for @trainingShiftOptions.
  ///
  /// In en, this message translates to:
  /// **'Shift options'**
  String get trainingShiftOptions;

  /// No description provided for @trainingShiftPickStaff.
  ///
  /// In en, this message translates to:
  /// **'Pick who works this shift'**
  String get trainingShiftPickStaff;

  /// No description provided for @trainingShiftSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get trainingShiftSeeAll;

  /// No description provided for @trainingShiftShifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get trainingShiftShifts;

  /// No description provided for @trainingShiftStaffMember.
  ///
  /// In en, this message translates to:
  /// **'Staff member'**
  String get trainingShiftStaffMember;

  /// No description provided for @trainingShiftStart.
  ///
  /// In en, this message translates to:
  /// **'Start {time}'**
  String trainingShiftStart(String time);

  /// No description provided for @trainingShiftUpdated.
  ///
  /// In en, this message translates to:
  /// **'Shift updated'**
  String get trainingShiftUpdated;

  /// No description provided for @trainingSideBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get trainingSideBoth;

  /// No description provided for @trainingSideLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get trainingSideLeft;

  /// No description provided for @trainingSideRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get trainingSideRight;

  /// No description provided for @trainingStaffRoleEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get trainingStaffRoleEmployee;

  /// No description provided for @trainingStaffRoleEmployeeTrainer.
  ///
  /// In en, this message translates to:
  /// **'Employee / Trainer'**
  String get trainingStaffRoleEmployeeTrainer;

  /// No description provided for @trainingStaffRoleTrainer.
  ///
  /// In en, this message translates to:
  /// **'Trainer'**
  String get trainingStaffRoleTrainer;

  /// No description provided for @trainingWeekProgram.
  ///
  /// In en, this message translates to:
  /// **'{weeks}-Week Program'**
  String trainingWeekProgram(int weeks);

  /// No description provided for @trainingWorkoutsAssignedByMe.
  ///
  /// In en, this message translates to:
  /// **'By me ({count})'**
  String trainingWorkoutsAssignedByMe(int count);

  /// No description provided for @trainingWorkoutsAssignedFor.
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String trainingWorkoutsAssignedFor(String name);

  /// No description provided for @trainingWorkoutsAssignedForMember.
  ///
  /// In en, this message translates to:
  /// **'For a member'**
  String get trainingWorkoutsAssignedForMember;

  /// No description provided for @trainingWorkoutsAssignedFrom.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String trainingWorkoutsAssignedFrom(String name);

  /// No description provided for @trainingWorkoutsAssignedFromCoach.
  ///
  /// In en, this message translates to:
  /// **'From your coach'**
  String get trainingWorkoutsAssignedFromCoach;

  /// No description provided for @trainingWorkoutsAssignedToMe.
  ///
  /// In en, this message translates to:
  /// **'Assigned to me ({count})'**
  String trainingWorkoutsAssignedToMe(int count);

  /// No description provided for @trainingWorkoutsByMeEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t assigned routines to anyone yet.\nOpen a routine and tap Assign.'**
  String get trainingWorkoutsByMeEmpty;

  /// No description provided for @trainingWorkoutsClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get trainingWorkoutsClearSearch;

  /// No description provided for @trainingWorkoutsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get trainingWorkoutsCreate;

  /// No description provided for @trainingWorkoutsMyRoutines.
  ///
  /// In en, this message translates to:
  /// **'My Routines'**
  String get trainingWorkoutsMyRoutines;

  /// No description provided for @trainingWorkoutsMyTrainings.
  ///
  /// In en, this message translates to:
  /// **'My Trainings'**
  String get trainingWorkoutsMyTrainings;

  /// No description provided for @trainingWorkoutsNewRoutine.
  ///
  /// In en, this message translates to:
  /// **'New Routine'**
  String get trainingWorkoutsNewRoutine;

  /// No description provided for @trainingWorkoutsNewTraining.
  ///
  /// In en, this message translates to:
  /// **'New Training'**
  String get trainingWorkoutsNewTraining;

  /// No description provided for @trainingWorkoutsNoTrainings.
  ///
  /// In en, this message translates to:
  /// **'No trainings found'**
  String get trainingWorkoutsNoTrainings;

  /// No description provided for @trainingWorkoutsSelfAssigned.
  ///
  /// In en, this message translates to:
  /// **'Self-assigned'**
  String get trainingWorkoutsSelfAssigned;

  /// No description provided for @trainingWorkoutsSetCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String trainingWorkoutsSetCount(int count);

  /// No description provided for @trainingWorkoutsTabAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get trainingWorkoutsTabAssigned;

  /// No description provided for @trainingWorkoutsTabLibrary.
  ///
  /// In en, this message translates to:
  /// **'My Library'**
  String get trainingWorkoutsTabLibrary;

  /// No description provided for @trainingWorkoutsTabRoutines.
  ///
  /// In en, this message translates to:
  /// **'Routines'**
  String get trainingWorkoutsTabRoutines;

  /// No description provided for @trainingWorkoutsTabTrainings.
  ///
  /// In en, this message translates to:
  /// **'Trainings'**
  String get trainingWorkoutsTabTrainings;

  /// No description provided for @trainingWorkoutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get trainingWorkoutsTitle;

  /// No description provided for @trainingWorkoutsToMeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No routines assigned to you yet.\nYour coach\'s assignments show up here.'**
  String get trainingWorkoutsToMeEmpty;

  /// No description provided for @workoutLogAddExercise.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get workoutLogAddExercise;

  /// No description provided for @workoutLogAddToTrainings.
  ///
  /// In en, this message translates to:
  /// **'Add to trainings'**
  String get workoutLogAddToTrainings;

  /// No description provided for @workoutLogAddToTrainingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Save these exercises, sets and weights as a training so you can log or start it again in one tap.'**
  String get workoutLogAddToTrainingsMessage;

  /// No description provided for @workoutLogAddToTrainingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to your trainings?'**
  String get workoutLogAddToTrainingsTitle;

  /// No description provided for @workoutLogCalendarDone.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workoutLogCalendarDone;

  /// No description provided for @workoutLogCalendarSemantics.
  ///
  /// In en, this message translates to:
  /// **'Workout: {title}'**
  String workoutLogCalendarSemantics(String title);

  /// No description provided for @workoutLogChooseTraining.
  ///
  /// In en, this message translates to:
  /// **'Choose a training (optional)'**
  String get workoutLogChooseTraining;

  /// No description provided for @workoutLogClearTraining.
  ///
  /// In en, this message translates to:
  /// **'Don\'t follow a training'**
  String get workoutLogClearTraining;

  /// No description provided for @workoutLogDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get workoutLogDate;

  /// No description provided for @workoutLogDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get workoutLogDuration;

  /// No description provided for @workoutLogExercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get workoutLogExercises;

  /// No description provided for @workoutLogFutureError.
  ///
  /// In en, this message translates to:
  /// **'The start time can\'t be in the future.'**
  String get workoutLogFutureError;

  /// No description provided for @workoutLogFutureSlot.
  ///
  /// In en, this message translates to:
  /// **'You can log a workout once it has started.'**
  String get workoutLogFutureSlot;

  /// No description provided for @workoutLogMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String workoutLogMinutes(int minutes);

  /// No description provided for @workoutLogMissingRepsError.
  ///
  /// In en, this message translates to:
  /// **'Enter the reps for every set, or switch it to failure.'**
  String get workoutLogMissingRepsError;

  /// No description provided for @workoutLogNoExercisesError.
  ///
  /// In en, this message translates to:
  /// **'Add at least one exercise.'**
  String get workoutLogNoExercisesError;

  /// No description provided for @workoutLogNoExercisesHint.
  ///
  /// In en, this message translates to:
  /// **'Add the exercises you did, or pick a training above.'**
  String get workoutLogNoExercisesHint;

  /// No description provided for @workoutLogNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get workoutLogNotNow;

  /// No description provided for @workoutLogPickTraining.
  ///
  /// In en, this message translates to:
  /// **'What did you train?'**
  String get workoutLogPickTraining;

  /// No description provided for @workoutLogRemoveSet.
  ///
  /// In en, this message translates to:
  /// **'Remove this set'**
  String get workoutLogRemoveSet;

  /// No description provided for @workoutLogRepeatSet.
  ///
  /// In en, this message translates to:
  /// **'Repeat this set'**
  String get workoutLogRepeatSet;

  /// No description provided for @workoutLogReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get workoutLogReplace;

  /// No description provided for @workoutLogReplaceMessage.
  ///
  /// In en, this message translates to:
  /// **'The exercises you entered will be replaced with the ones from {name}.'**
  String workoutLogReplaceMessage(String name);

  /// No description provided for @workoutLogReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace exercises?'**
  String get workoutLogReplaceTitle;

  /// No description provided for @workoutLogReps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get workoutLogReps;

  /// No description provided for @workoutLogSaved.
  ///
  /// In en, this message translates to:
  /// **'Workout logged'**
  String get workoutLogSaved;

  /// No description provided for @workoutLogScheduleEmptyDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this day. Tap an hour to log a workout.'**
  String get workoutLogScheduleEmptyDay;

  /// No description provided for @workoutLogSetCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String workoutLogSetCount(int count);

  /// No description provided for @workoutLogSetNumber.
  ///
  /// In en, this message translates to:
  /// **'Set {number}'**
  String workoutLogSetNumber(int number);

  /// No description provided for @workoutLogSlotLabel.
  ///
  /// In en, this message translates to:
  /// **'{time}, log a workout'**
  String workoutLogSlotLabel(String time);

  /// No description provided for @workoutLogStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get workoutLogStart;

  /// No description provided for @workoutLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Log workout'**
  String get workoutLogTitle;

  /// No description provided for @workoutLogTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get workoutLogTraining;

  /// No description provided for @workoutLogTrainingHelper.
  ///
  /// In en, this message translates to:
  /// **'Pick one to fill in its exercises, or add them yourself below.'**
  String get workoutLogTrainingHelper;

  /// No description provided for @workoutPickerAssigned.
  ///
  /// In en, this message translates to:
  /// **'From your coach'**
  String get workoutPickerAssigned;

  /// No description provided for @workoutPickerLastLogged.
  ///
  /// In en, this message translates to:
  /// **'Last logged {date}'**
  String workoutPickerLastLogged(String date);

  /// No description provided for @workoutPickerLibrary.
  ///
  /// In en, this message translates to:
  /// **'All trainings'**
  String get workoutPickerLibrary;

  /// No description provided for @workoutPickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No trainings found'**
  String get workoutPickerNoResults;

  /// No description provided for @workoutPickerRecent.
  ///
  /// In en, this message translates to:
  /// **'Logged before'**
  String get workoutPickerRecent;

  /// No description provided for @workoutPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search trainings'**
  String get workoutPickerSearchHint;

  /// No description provided for @workoutTrainingCopyName.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String workoutTrainingCopyName(String name);

  /// No description provided for @workoutTrainingCopySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved “{name}” to your trainings'**
  String workoutTrainingCopySaved(String name);

  /// No description provided for @workoutTrainingInNoRoutine.
  ///
  /// In en, this message translates to:
  /// **'Not in any of your routines'**
  String get workoutTrainingInNoRoutine;

  /// No description provided for @workoutTrainingLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'This training has logged sessions, and they show its exercises, so the sets can\'t be changed. You can still edit its name, photo, notes, visibility and routines.'**
  String get workoutTrainingLockedMessage;

  /// No description provided for @workoutTrainingNoRoutines.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t created any routines yet'**
  String get workoutTrainingNoRoutines;

  /// No description provided for @workoutTrainingRoutines.
  ///
  /// In en, this message translates to:
  /// **'Routines'**
  String get workoutTrainingRoutines;

  /// No description provided for @workoutTrainingRoutinesDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get workoutTrainingRoutinesDone;

  /// No description provided for @workoutTrainingRoutinesHint.
  ///
  /// In en, this message translates to:
  /// **'Your routines this training is part of. New ones get it at the end; set its week and day in the routine.'**
  String get workoutTrainingRoutinesHint;

  /// No description provided for @workoutTrainingRoutinesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your routines…'**
  String get workoutTrainingRoutinesLoading;

  /// No description provided for @workoutTrainingRoutinesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your routines'**
  String get workoutTrainingRoutinesUnavailable;

  /// No description provided for @workoutTrainingSaveAsCopy.
  ///
  /// In en, this message translates to:
  /// **'Save as a new training'**
  String get workoutTrainingSaveAsCopy;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'sr':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return AppLocalizationsSrLatn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sr':
      return AppLocalizationsSr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
