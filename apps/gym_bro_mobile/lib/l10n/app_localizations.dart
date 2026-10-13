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

  /// No description provided for @shellHey.
  ///
  /// In en, this message translates to:
  /// **'Hey, {name}!'**
  String shellHey(String name);

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

  /// No description provided for @shellMembershipActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get shellMembershipActive;

  /// No description provided for @shellMembershipLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your membership'**
  String get shellMembershipLoadFailed;

  /// No description provided for @shellMembershipValidUntil.
  ///
  /// In en, this message translates to:
  /// **'{type} · valid until {date}'**
  String shellMembershipValidUntil(String type, String date);

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
  /// **'Gym news and comments on your posts'**
  String get shellMuteCommunityDescription;

  /// No description provided for @shellMuteFootnote.
  ///
  /// In en, this message translates to:
  /// **'Invites always come through. Muted notifications still appear in the app.'**
  String get shellMuteFootnote;

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

  /// No description provided for @shellNoActiveMembership.
  ///
  /// In en, this message translates to:
  /// **'No active membership'**
  String get shellNoActiveMembership;

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

  /// No description provided for @shellNoneScheduled.
  ///
  /// In en, this message translates to:
  /// **'None scheduled'**
  String get shellNoneScheduled;

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

  /// No description provided for @shellOwnerNoGyms.
  ///
  /// In en, this message translates to:
  /// **'You don\'t own any gyms yet — add one from the Businesses tab.'**
  String get shellOwnerNoGyms;

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

  /// No description provided for @shellSessionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Session in progress'**
  String get shellSessionInProgress;

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

  /// No description provided for @shellUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get shellUnavailable;

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

  /// No description provided for @shellUpcomingClasses.
  ///
  /// In en, this message translates to:
  /// **'Upcoming classes'**
  String get shellUpcomingClasses;

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

  /// No description provided for @shellWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String shellWelcomeBack(String name);

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

  /// No description provided for @shellYourShop.
  ///
  /// In en, this message translates to:
  /// **'Your shop'**
  String get shellYourShop;

  /// No description provided for @shellYourShops.
  ///
  /// In en, this message translates to:
  /// **'Your shops'**
  String get shellYourShops;

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

  /// No description provided for @trainingClassBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse classes'**
  String get trainingClassBrowse;

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

  /// No description provided for @trainingClassJumpToNext.
  ///
  /// In en, this message translates to:
  /// **'Jump to next class'**
  String get trainingClassJumpToNext;

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

  /// No description provided for @trainingClassMyBookings.
  ///
  /// In en, this message translates to:
  /// **'My bookings'**
  String get trainingClassMyBookings;

  /// No description provided for @trainingClassMyBookingsCount.
  ///
  /// In en, this message translates to:
  /// **'My bookings ({count})'**
  String trainingClassMyBookingsCount(int count);

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

  /// No description provided for @trainingClassNextClass.
  ///
  /// In en, this message translates to:
  /// **'Next class: {title}, {day} at {time}.'**
  String trainingClassNextClass(String title, String day, String time);

  /// No description provided for @trainingClassNoBookings.
  ///
  /// In en, this message translates to:
  /// **'No bookings yet'**
  String get trainingClassNoBookings;

  /// No description provided for @trainingClassNoBookingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Classes you book or join the waitlist for show up here.'**
  String get trainingClassNoBookingsMessage;

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

  /// No description provided for @trainingClassNoneScheduled.
  ///
  /// In en, this message translates to:
  /// **'No classes scheduled'**
  String get trainingClassNoneScheduled;

  /// No description provided for @trainingClassNoneScheduledMessage.
  ///
  /// In en, this message translates to:
  /// **'Your gyms haven\'t scheduled any classes for the next two weeks. Check back soon.'**
  String get trainingClassNoneScheduledMessage;

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

  /// No description provided for @trainingClassNothingOn.
  ///
  /// In en, this message translates to:
  /// **'Nothing on {day}'**
  String trainingClassNothingOn(String day);

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

  /// No description provided for @trainingClassRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get trainingClassRefresh;

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
