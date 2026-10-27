// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Gym Bro';

  @override
  String get businessCheckInAllTime => 'All time';

  @override
  String get businessCheckInAttendanceTitle => 'Attendance';

  @override
  String get businessCheckInBusiestHours => 'Busiest hours';

  @override
  String get businessCheckInByStaff => 'by staff';

  @override
  String get businessCheckInCameraDenied => 'Camera access is off';

  @override
  String get businessCheckInCameraDeniedMessage =>
      'Allow camera access for Gym Bro in your device settings to scan member codes. You can still check members in by name.';

  @override
  String businessCheckInCameraStartFailed(String code) {
    return 'The camera couldn\'t start ($code).';
  }

  @override
  String get businessCheckInCameraUnavailable => 'Camera unavailable';

  @override
  String get businessCheckInCameraUnsupportedMessage =>
      'This device can\'t scan codes. Check members in by name instead.';

  @override
  String get businessCheckInCheckInAction => 'Check in';

  @override
  String get businessCheckInCheckIns => 'Check-ins';

  @override
  String businessCheckInCheckedInAt(String time) {
    return 'Checked in at $time';
  }

  @override
  String get businessCheckInCheckingIn => 'Checking in…';

  @override
  String get businessCheckInClearSearch => 'Clear search';

  @override
  String businessCheckInCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins',
      one: '1 check-in',
    );
    return '$_temp0';
  }

  @override
  String businessCheckInDailyChartSemantics(
    int days,
    int total,
    String average,
  ) {
    return 'Check-ins per day chart, last $days days: $total in total, $average per day on average.';
  }

  @override
  String get businessCheckInDismissHint => 'dismiss';

  @override
  String get businessCheckInGymFallback => 'Gym';

  @override
  String businessCheckInHourlyChartSemantics(String hours) {
    return 'Check-ins by hour chart. Busiest: $hours.';
  }

  @override
  String businessCheckInLastDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Last $days days',
      one: 'Last day',
    );
    return '$_temp0';
  }

  @override
  String businessCheckInLastVisit(String when) {
    return 'Last visit $when';
  }

  @override
  String get businessCheckInManual => 'Manual check-in';

  @override
  String get businessCheckInManualShort => 'Manual';

  @override
  String get businessCheckInMemberFallback => 'Member';

  @override
  String businessCheckInMembersInDays(int days) {
    return 'Members (${days}d)';
  }

  @override
  String businessCheckInMembershipEnded(String type, String date) {
    return '$type · ended $date';
  }

  @override
  String businessCheckInMembershipValidUntil(String type, String date) {
    return '$type · valid until $date';
  }

  @override
  String businessCheckInNewCodeIn(String time) {
    return 'New code in $time';
  }

  @override
  String get businessCheckInNextDay => 'Next day';

  @override
  String get businessCheckInNoCheckInsInPeriod =>
      'No check-ins in this period yet.';

  @override
  String get businessCheckInNoGymMessage =>
      'Once a gym adds you as a member, your check-in code shows up here.';

  @override
  String get businessCheckInNoGymTitle => 'No gym to check in to';

  @override
  String get businessCheckInNoMatches => 'No matching members';

  @override
  String get businessCheckInNoMatchesMessage =>
      'Try a different name or email.';

  @override
  String get businessCheckInNoMembers => 'No members yet';

  @override
  String get businessCheckInNoMembersMessage =>
      'Members added to this gym show up here.';

  @override
  String get businessCheckInNoMembershipOnFile => 'No membership on file';

  @override
  String get businessCheckInNoVisitsInPeriod => 'No visits in this period.';

  @override
  String get businessCheckInNoVisitsMessage =>
      'Your check-ins will be listed here.';

  @override
  String get businessCheckInNoVisitsTitle => 'No visits yet';

  @override
  String get businessCheckInNoneOnDay => 'No check-ins on this day';

  @override
  String get businessCheckInNoneToday => 'No check-ins yet today';

  @override
  String get businessCheckInNotEnoughData => 'Not enough data yet.';

  @override
  String get businessCheckInOpenScanner => 'Open scanner';

  @override
  String businessCheckInPeak(String hours) {
    return 'Peak: $hours';
  }

  @override
  String get businessCheckInPickDayHelp => 'Show check-ins for';

  @override
  String get businessCheckInPointCamera =>
      'Point the camera at a member\'s code';

  @override
  String get businessCheckInPreviousDay => 'Previous day';

  @override
  String get businessCheckInQrNotConfigured =>
      'QR check-in isn\'t set up on this server yet. Ask the front desk to check you in by name.';

  @override
  String get businessCheckInQrScan => 'QR scan';

  @override
  String businessCheckInQrSemantics(String gym) {
    return 'Check-in QR code for $gym';
  }

  @override
  String get businessCheckInRecentVisits => 'Recent visits';

  @override
  String get businessCheckInRefreshCode => 'Refresh code';

  @override
  String businessCheckInRefreshFailed(String error) {
    return 'Couldn\'t refresh: $error';
  }

  @override
  String get businessCheckInRefreshingCode => 'Refreshing code…';

  @override
  String get businessCheckInResultCheckedIn => 'Checked in';

  @override
  String get businessCheckInResultDuplicate => 'Already checked in';

  @override
  String get businessCheckInResultFailed => 'Check-in failed';

  @override
  String get businessCheckInResultNoMembership => 'No active membership';

  @override
  String get businessCheckInScanHint =>
      'Scan a member\'s code to check them in.';

  @override
  String get businessCheckInScanTitle => 'Scan check-in';

  @override
  String get businessCheckInScanTooltip => 'Scan check-ins';

  @override
  String get businessCheckInSearchHint => 'Search members by name or email';

  @override
  String businessCheckInSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count checked in this session',
      one: '1 checked in this session',
    );
    return '$_temp0';
  }

  @override
  String get businessCheckInShowAtDesk => 'Show this code at the front desk';

  @override
  String get businessCheckInShowMore => 'Show more';

  @override
  String get businessCheckInStaffNotice =>
      'You are staff here, not a member. This code is for testing the scanner.';

  @override
  String get businessCheckInThisWeek => 'This week';

  @override
  String get businessCheckInTitle => 'Check in';

  @override
  String get businessCheckInTopMembers => 'Top members';

  @override
  String get businessCheckInTorchOff => 'Turn flashlight off';

  @override
  String get businessCheckInTorchOn => 'Turn flashlight on';

  @override
  String businessCheckInTotalPerDay(int count, String average) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins',
      one: '1 check-in',
    );
    return '$_temp0 · $average per day';
  }

  @override
  String get businessCheckInVisitsThisMonth => 'Visits this month';

  @override
  String businessCheckInVisitsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'visits',
      one: 'visit',
    );
    return '$_temp0';
  }

  @override
  String get businessCheckInYesterday => 'Yesterday';

  @override
  String get businessGymAddEmployee => 'Add employee';

  @override
  String get businessGymAddExistingUser => 'Add existing user';

  @override
  String get businessGymAddExistingUserHint =>
      'Search users already in the system';

  @override
  String get businessGymAddMember => 'Add member';

  @override
  String get businessGymAllGyms => 'All gyms';

  @override
  String get businessGymAllMembersTitle => 'All members';

  @override
  String get businessGymAllStaffTitle => 'All staff';

  @override
  String get businessGymAlreadyEmployee => 'Already an employee at this gym';

  @override
  String get businessGymAlreadyMember => 'Already a member';

  @override
  String get businessGymAssign => 'Assign';

  @override
  String get businessGymAssignMembership => 'Assign membership';

  @override
  String get businessGymCancelMembership => 'Cancel membership';

  @override
  String businessGymCancelMembershipMessage(String member, String type) {
    return '$member\'s $type membership will be marked inactive. Billing history is kept.';
  }

  @override
  String get businessGymCancelMembershipTitle => 'Cancel membership?';

  @override
  String get businessGymChange => 'Change';

  @override
  String businessGymChangeRoleMessage(String name, String role, String gym) {
    return 'Change $name\'s role to $role at $gym?';
  }

  @override
  String get businessGymChangeRoleTitle => 'Change role?';

  @override
  String get businessGymClearSearch => 'Clear search';

  @override
  String businessGymDeleteMembershipMessage(String type) {
    return 'This permanently deletes the $type membership and its invoices. Use Cancel instead to keep the history.';
  }

  @override
  String get businessGymDeleteMembershipTitle => 'Delete membership?';

  @override
  String get businessGymDetailAttendance => 'Attendance';

  @override
  String get businessGymDetailInvoices => 'Invoices';

  @override
  String get businessGymDetailManage => 'Manage';

  @override
  String get businessGymDetailManageMembers => 'Manage members';

  @override
  String get businessGymDetailManageMembershipTypes =>
      'Manage membership types';

  @override
  String get businessGymDetailManageStaff => 'Manage staff';

  @override
  String get businessGymDetailMembers => 'Members';

  @override
  String businessGymDetailMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get businessGymDetailMembershipTypes => 'Membership types';

  @override
  String get businessGymDetailMembershipTypesHint =>
      'Set up pricing plans members can be enrolled in.';

  @override
  String businessGymDetailMore(int count) {
    return '+ $count more';
  }

  @override
  String get businessGymDetailPosts => 'Posts';

  @override
  String get businessGymDetailScanCheckIns => 'Scan check-ins';

  @override
  String get businessGymDetailSchedule => 'Schedule';

  @override
  String get businessGymDetailStaff => 'Staff';

  @override
  String businessGymDetailStaffCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count staff members',
      one: '1 staff member',
    );
    return '$_temp0';
  }

  @override
  String get businessGymDuration => 'Duration';

  @override
  String get businessGymEditEmployee => 'Edit employee';

  @override
  String get businessGymEditMember => 'Edit member';

  @override
  String get businessGymEmail => 'Email';

  @override
  String get businessGymEmailAlreadyEmployed =>
      'This email is already employed at this gym';

  @override
  String get businessGymEmployeeActions => 'Employee actions';

  @override
  String get businessGymExtend => 'Extend';

  @override
  String get businessGymExtendMembership => 'Extend membership';

  @override
  String businessGymExtendedUntil(String date) {
    return 'Extended until $date';
  }

  @override
  String get businessGymFilterAll => 'All';

  @override
  String get businessGymFirstName => 'First name';

  @override
  String get businessGymFormAddLogo => 'Add logo';

  @override
  String get businessGymFormCreate => 'Create business';

  @override
  String get businessGymFormDelete => 'Delete business';

  @override
  String get businessGymFormDeleteGymAction => 'Delete gym';

  @override
  String get businessGymFormDeleteGymMessage =>
      'This permanently deletes the gym with all its members, staff, membership types, memberships, invoices and posts.';

  @override
  String get businessGymFormDeleteShopAction => 'Delete shop';

  @override
  String get businessGymFormDeleteShopMessage =>
      'This permanently deletes the shop with all its items, vendors and posts.';

  @override
  String businessGymFormDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String businessGymFormDeleted(String name) {
    return '$name deleted';
  }

  @override
  String get businessGymFormFrom => 'From';

  @override
  String get businessGymFormLocation => 'Location';

  @override
  String get businessGymFormName => 'Name';

  @override
  String get businessGymFormSaveChanges => 'Save changes';

  @override
  String get businessGymFormSelectWorkingDay =>
      'Select at least one working day';

  @override
  String get businessGymFormTitleEdit => 'Edit business';

  @override
  String get businessGymFormTitleNew => 'New business';

  @override
  String get businessGymFormTo => 'To';

  @override
  String get businessGymFormType => 'Type';

  @override
  String get businessGymFormTypeGym => 'Gym';

  @override
  String get businessGymFormTypeShop => 'Shop';

  @override
  String get businessGymFormWorkingDays => 'Working days';

  @override
  String get businessGymFormWorkingHours => 'Working hours';

  @override
  String get businessGymGym => 'Gym';

  @override
  String get businessGymInviteAndAdd => 'Invite & add';

  @override
  String get businessGymInviteMemberTitle => 'Invite member';

  @override
  String get businessGymInviteNewMember => 'Invite new member';

  @override
  String get businessGymInviteNewMemberHint => 'Send an invite link by email';

  @override
  String get businessGymInviteNewUserPrompt =>
      'Can\'t find them? Invite a new user';

  @override
  String get businessGymInviteResent => 'Invite resent';

  @override
  String get businessGymInviteResentSuccess => 'Invite resent successfully';

  @override
  String get businessGymKeep => 'Keep';

  @override
  String get businessGymLastName => 'Last name';

  @override
  String get businessGymMemberActions => 'Member actions';

  @override
  String businessGymMembersTitle(String gym) {
    return '$gym — Members';
  }

  @override
  String get businessGymMembershipActions => 'Membership actions';

  @override
  String get businessGymMembershipAssigned => 'Membership assigned';

  @override
  String get businessGymMembershipFallback => 'Membership';

  @override
  String get businessGymMembershipType => 'Membership type';

  @override
  String get businessGymMembershipTypeNotFound =>
      'Membership type not found for this gym';

  @override
  String get businessGymMemberships => 'Memberships';

  @override
  String businessGymMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get businessGymNoMembersFound => 'No members found';

  @override
  String get businessGymNoMembersYet => 'No members yet';

  @override
  String businessGymNoMembershipAt(String gym) {
    return 'No membership at $gym';
  }

  @override
  String get businessGymNoMembershipTypes =>
      'This gym has no membership types yet — add one first.';

  @override
  String get businessGymNoStaffFound => 'No staff found';

  @override
  String get businessGymNoStaffYet => 'No staff yet';

  @override
  String businessGymPlusMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '+$months months',
      one: '+1 month',
    );
    return '$_temp0';
  }

  @override
  String get businessGymRemove => 'Remove';

  @override
  String get businessGymRemoveFromGym => 'Remove from gym';

  @override
  String businessGymRemoveFromGymMessage(String name, String gym) {
    return 'This will remove $name from $gym.';
  }

  @override
  String get businessGymRemoveMemberMessage =>
      'This will remove the member from this gym.';

  @override
  String get businessGymRemoveMemberTitle => 'Remove member?';

  @override
  String get businessGymRemoveStaffMessage =>
      'This will remove them from this gym.';

  @override
  String get businessGymRemoveStaffTitle => 'Remove staff member?';

  @override
  String get businessGymResendInvite => 'Resend invite';

  @override
  String get businessGymRole => 'Role';

  @override
  String businessGymRoleChangedTo(String role) {
    return 'Role changed to $role';
  }

  @override
  String get businessGymRoleEmployee => 'Employee';

  @override
  String get businessGymRoleEmployeeTrainer => 'Employee trainer';

  @override
  String get businessGymRoleEmployeeTrainerShort => 'Emp. trainer';

  @override
  String get businessGymRoleMember => 'Member';

  @override
  String get businessGymRoleVendor => 'Vendor';

  @override
  String get businessGymSearchMembersHint => 'Search members…';

  @override
  String get businessGymSearchStaffHint => 'Search staff…';

  @override
  String get businessGymSendInvite => 'Send invite';

  @override
  String businessGymStaffTitle(String gym) {
    return '$gym — Staff';
  }

  @override
  String get businessGymStatusActive => 'Active';

  @override
  String get businessGymStatusCancelled => 'Cancelled';

  @override
  String get businessGymStatusExpired => 'Expired';

  @override
  String businessGymTypePerMonth(String name, String price) {
    return '$name ($price/mo)';
  }

  @override
  String get businessGymUsername => 'Username';

  @override
  String get businessGymViewProgress => 'View progress';

  @override
  String get businessInvoiceStatusPaid => 'Paid';

  @override
  String get businessInvoiceStatusUnpaid => 'Unpaid';

  @override
  String get businessInvoiceStatusVoid => 'Void';

  @override
  String get businessItemTypeEquipment => 'Equipment';

  @override
  String get businessItemTypeGiftCard => 'Gift card';

  @override
  String get businessItemTypeSupplement => 'Supplement';

  @override
  String get businessMgmtActiveMembership => 'Active membership';

  @override
  String get businessMgmtActiveUntil => 'Active until';

  @override
  String get businessMgmtAddItem => 'Add item';

  @override
  String get businessMgmtAddProductPhoto => 'Add product photo';

  @override
  String get businessMgmtAddType => 'Add type';

  @override
  String get businessMgmtAddVendor => 'Add vendor';

  @override
  String get businessMgmtAll => 'All';

  @override
  String get businessMgmtAllGyms => 'All gyms';

  @override
  String get businessMgmtAlreadyVendor => 'Already a vendor for this shop';

  @override
  String get businessMgmtAutoRenewOn => 'Auto-renew on';

  @override
  String get businessMgmtAutoRenewTurnedOff => 'Auto-renew turned off';

  @override
  String get businessMgmtBillingHistory => 'Billing history';

  @override
  String get businessMgmtBuyMembership => 'Buy a membership';

  @override
  String get businessMgmtClearDate => 'Clear date';

  @override
  String businessMgmtDeleteItemMessage(String name) {
    return 'Remove “$name” from this shop?';
  }

  @override
  String get businessMgmtDeleteItemTitle => 'Delete item?';

  @override
  String businessMgmtDeleteMembershipTypeMessage(String name) {
    return 'This will delete “$name”. Existing memberships referencing it will be kept.';
  }

  @override
  String get businessMgmtDeleteMembershipTypeTitle => 'Delete membership type?';

  @override
  String businessMgmtDeleteNamed(String name) {
    return 'Delete $name';
  }

  @override
  String get businessMgmtDescriptionOptional => 'Description (optional)';

  @override
  String get businessMgmtEditItem => 'Edit item';

  @override
  String get businessMgmtEditMembershipType => 'Edit membership type';

  @override
  String businessMgmtEditNamed(String name) {
    return 'Edit $name';
  }

  @override
  String get businessMgmtEditVendor => 'Edit vendor';

  @override
  String get businessMgmtEmail => 'Email';

  @override
  String get businessMgmtEmailAlreadyVendor =>
      'This email is already a vendor for this shop';

  @override
  String get businessMgmtExtendOrBuy => 'Extend or buy a membership';

  @override
  String get businessMgmtFirstName => 'First name';

  @override
  String get businessMgmtGym => 'Gym';

  @override
  String businessMgmtGymInvoicesTitle(String gymName) {
    return '$gymName — Invoices';
  }

  @override
  String get businessMgmtInStock => 'In stock';

  @override
  String get businessMgmtInvalidNumber => 'Enter a valid number';

  @override
  String get businessMgmtInviteAndAddVendor => 'Invite & add vendor';

  @override
  String get businessMgmtInviteNewUser => 'Can\'t find them? Invite a new user';

  @override
  String get businessMgmtInviteResent => 'Invite resent';

  @override
  String get businessMgmtInviteResentSuccess => 'Invite resent successfully';

  @override
  String get businessMgmtInvoice => 'Invoice';

  @override
  String get businessMgmtInvoiceMarkedPaid => 'Invoice marked paid';

  @override
  String get businessMgmtInvoiceMarkedUnpaid => 'Invoice marked unpaid';

  @override
  String get businessMgmtInvoiceMarkedVoid => 'Invoice marked void';

  @override
  String get businessMgmtInvoicePaidThanks => 'Invoice paid. Thank you!';

  @override
  String get businessMgmtInvoices => 'Invoices';

  @override
  String businessMgmtIssuedOn(String date) {
    return 'Issued $date';
  }

  @override
  String get businessMgmtItemActive => 'Active';

  @override
  String get businessMgmtItemInactive => 'Inactive';

  @override
  String get businessMgmtItems => 'Items';

  @override
  String get businessMgmtLastName => 'Last name';

  @override
  String get businessMgmtManage => 'Manage';

  @override
  String get businessMgmtMarkPaid => 'Mark paid';

  @override
  String get businessMgmtMarkUnpaid => 'Mark unpaid';

  @override
  String get businessMgmtMarkVoid => 'Mark void';

  @override
  String get businessMgmtMembership => 'Membership';

  @override
  String get businessMgmtMembershipExpired => 'Membership expired';

  @override
  String get businessMgmtMembershipHistory => 'Membership history';

  @override
  String businessMgmtMembershipTypesTitle(String gymName) {
    return '$gymName · Membership types';
  }

  @override
  String get businessMgmtMonthlyCost => 'Monthly cost';

  @override
  String businessMgmtMoreCount(int count) {
    return '+ $count more';
  }

  @override
  String get businessMgmtName => 'Name';

  @override
  String get businessMgmtNewItem => 'New item';

  @override
  String get businessMgmtNewMembershipType => 'New membership type';

  @override
  String get businessMgmtNoActiveMembership => 'No active membership';

  @override
  String get businessMgmtNoExpiry => 'No expiry';

  @override
  String get businessMgmtNoInvoicesYet => 'No invoices yet';

  @override
  String get businessMgmtNoItemsYet => 'No items yet';

  @override
  String get businessMgmtNoMembershipBuyHint =>
      'Buy a membership in the app, or ask your gym to set one up.';

  @override
  String get businessMgmtNoMembershipDeskHint =>
      'Ask your gym to set up your membership plan. Payment happens at the front desk.';

  @override
  String get businessMgmtNoMembershipTypesYet => 'No membership types yet';

  @override
  String get businessMgmtNoPaidInvoices => 'No paid invoices';

  @override
  String get businessMgmtNoUnpaidInvoices => 'No unpaid invoices';

  @override
  String get businessMgmtNoVendorsYet => 'No vendors yet';

  @override
  String get businessMgmtNoVoidInvoices => 'No void invoices';

  @override
  String get businessMgmtOrders => 'Orders';

  @override
  String get businessMgmtOrdersSubtitle =>
      'Customer orders, payments and pickups';

  @override
  String get businessMgmtOutOfStock => 'Out of stock';

  @override
  String businessMgmtPayNow(String amount) {
    return 'Pay now · $amount';
  }

  @override
  String get businessMgmtPaymentsAtDesk =>
      'Payments for memberships and invoices happen at your gym\'s front desk.';

  @override
  String businessMgmtPerMonth(String price) {
    return '$price/month';
  }

  @override
  String businessMgmtPerMonthShort(String price) {
    return '$price/mo';
  }

  @override
  String get businessMgmtPickDate => 'Pick date';

  @override
  String get businessMgmtPosts => 'Posts';

  @override
  String get businessMgmtPrice => 'Price';

  @override
  String businessMgmtQuantity(int quantity) {
    return 'Qty: $quantity';
  }

  @override
  String get businessMgmtRemove => 'Remove';

  @override
  String get businessMgmtRemoveFromShop => 'Remove from shop';

  @override
  String businessMgmtRemoveVendorFromShopMessage(String name, String shopName) {
    return 'This will remove $name from $shopName.';
  }

  @override
  String get businessMgmtRemoveVendorMessage =>
      'This will remove them from this shop.';

  @override
  String get businessMgmtRemoveVendorTitle => 'Remove vendor?';

  @override
  String get businessMgmtRenewMembership => 'Renew membership';

  @override
  String get businessMgmtRenewsMonthly => 'Renews automatically every month';

  @override
  String get businessMgmtResendInvite => 'Resend invite';

  @override
  String get businessMgmtSaveChanges => 'Save changes';

  @override
  String get businessMgmtShop => 'Shop';

  @override
  String businessMgmtShopVendorsTitle(String shopName) {
    return '$shopName — Vendors';
  }

  @override
  String get businessMgmtStaffVendors => 'Staff / Vendors';

  @override
  String get businessMgmtTurnOff => 'Turn off';

  @override
  String get businessMgmtTurnOffAutoRenew => 'Turn off auto-renew';

  @override
  String businessMgmtTurnOffAutoRenewMessage(String date) {
    return 'Your membership stays active until $date and won\'t be charged again.';
  }

  @override
  String get businessMgmtTurnOffAutoRenewTitle => 'Turn off auto-renew?';

  @override
  String get businessMgmtType => 'Type';

  @override
  String get businessMgmtTypeActive => 'Active';

  @override
  String get businessMgmtTypeInactive => 'Inactive';

  @override
  String get businessMgmtUnknownMember => 'Unknown member';

  @override
  String businessMgmtUnpaidSummary(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unpaid invoices',
      one: '1 unpaid invoice',
    );
    return '$_temp0 · $amount due';
  }

  @override
  String get businessMgmtUsername => 'Username';

  @override
  String get businessMgmtVendor => 'Vendor';

  @override
  String get businessMgmtVendorActions => 'Vendor actions';

  @override
  String get businessOrderStatusCancelled => 'Cancelled';

  @override
  String get businessOrderStatusFulfilled => 'Fulfilled';

  @override
  String get businessOrderStatusPaid => 'Paid';

  @override
  String get businessOrderStatusPending => 'Pending';

  @override
  String get businessPaymentMethodCard => 'Card';

  @override
  String get businessPaymentMethodPayAtPickup => 'Pay at pickup';

  @override
  String get businessPaymentStatusCancelled => 'Cancelled';

  @override
  String get businessPaymentStatusFailed => 'Failed';

  @override
  String get businessPaymentStatusPaid => 'Paid';

  @override
  String get businessPaymentStatusPending => 'Pending';

  @override
  String get businessPaymentStatusRefunded => 'Refunded';

  @override
  String get businessQuantityDecrease => 'Decrease quantity';

  @override
  String get businessQuantityIncrease => 'Increase quantity';

  @override
  String businessQuantityValue(int value) {
    return 'Quantity $value';
  }

  @override
  String businessShopAddWithPrice(String price) {
    return 'Add · $price';
  }

  @override
  String businessShopAddedToCart(int quantity, String name) {
    return 'Added $quantity × $name to cart';
  }

  @override
  String get businessShopAllStockInCart =>
      'All available stock is in your cart';

  @override
  String businessShopAutoRenewExplanation(String price) {
    return 'You\'re charged $price now and every month after. Turn off auto-renew any time from your membership page.';
  }

  @override
  String businessShopAvailableUntil(String date) {
    return 'Available until $date';
  }

  @override
  String get businessShopAwaitingCardPayment => 'Awaiting card payment';

  @override
  String get businessShopAwaitingYourCardPayment =>
      'This order is waiting for your card payment.';

  @override
  String get businessShopBrowseShops => 'Browse shops';

  @override
  String get businessShopBuyAtFrontDesk =>
      'Buy or renew your membership at your gym\'s front desk.';

  @override
  String get businessShopBuyMembershipTitle => 'Buy a membership';

  @override
  String businessShopBuyerPickedUp(String name) {
    return '$name picked up the order.';
  }

  @override
  String get businessShopCancelOrder => 'Cancel order';

  @override
  String get businessShopCancelOrderTitle => 'Cancel this order?';

  @override
  String businessShopCardOfAmountWillBeRefunded(String total) {
    return 'The card payment of $total will be refunded.';
  }

  @override
  String get businessShopCardPaymentHint =>
      'You\'ll pay securely with Stripe, then pick up your order.';

  @override
  String get businessShopCardUnavailableNow =>
      'Card payments are unavailable right now. You can pay at pickup.';

  @override
  String get businessShopCardUnavailablePayAtPickup =>
      'Card payments aren\'t available yet. Pay when you pick up your order.';

  @override
  String get businessShopCardWillBeRefunded =>
      'The card payment will be refunded.';

  @override
  String get businessShopCart => 'Cart';

  @override
  String get businessShopCartEmpty => 'Your cart is empty';

  @override
  String get businessShopCartEmptyHint => 'Tap a product to add it.';

  @override
  String businessShopCartTotal(String price) {
    return 'Cart · $price';
  }

  @override
  String get businessShopChooseDifferentGym => 'Choose a different gym';

  @override
  String get businessShopClearSearch => 'Clear search';

  @override
  String businessShopConfirmBuyerPaid(String name, String total) {
    return 'Confirm $name paid $total.';
  }

  @override
  String businessShopConfirmCustomerPaid(String total) {
    return 'Confirm the customer paid $total.';
  }

  @override
  String businessShopConfirmPaidAtCounter(String total) {
    return 'Confirm the customer paid $total at the counter.';
  }

  @override
  String get businessShopConfirmingPayment => 'Confirming your payment…';

  @override
  String get businessShopCouldNotOpenPaymentPage =>
      'Couldn\'t open the payment page';

  @override
  String get businessShopCustomer => 'Customer';

  @override
  String get businessShopCustomerPickedUp =>
      'The customer has picked up their order.';

  @override
  String get businessShopCustomerPickedUpOrder =>
      'The customer picked up the order.';

  @override
  String get businessShopDecreaseQuantity => 'Decrease quantity';

  @override
  String get businessShopEmptyCart => 'Empty cart';

  @override
  String get businessShopFilterAll => 'All';

  @override
  String businessShopFromPricePerMonth(String price) {
    return 'From $price/month';
  }

  @override
  String businessShopInCartCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items in cart',
      one: '1 item in cart',
    );
    return '$_temp0';
  }

  @override
  String businessShopInStock(int count) {
    return '$count in stock';
  }

  @override
  String businessShopInYourCart(int count) {
    return '$count in your cart';
  }

  @override
  String get businessShopIncreaseQuantity => 'Increase quantity';

  @override
  String businessShopItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get businessShopItems => 'Items';

  @override
  String get businessShopItemsBackInStock => 'The items go back into stock.';

  @override
  String businessShopLeftCount(int count) {
    return '$count left';
  }

  @override
  String get businessShopLength => 'Length';

  @override
  String get businessShopMarkAsFulfilledTitle => 'Mark as fulfilled?';

  @override
  String get businessShopMarkAsPaidTitle => 'Mark as paid?';

  @override
  String get businessShopMarkFulfilled => 'Mark fulfilled';

  @override
  String get businessShopMarkPaid => 'Mark paid';

  @override
  String get businessShopMembershipPaymentSuccess =>
      'Payment successful. Your membership is active!';

  @override
  String get businessShopMembershipType => 'Membership type';

  @override
  String get businessShopMyOrders => 'My orders';

  @override
  String get businessShopNewOrdersHint =>
      'New orders from customers will show up here.';

  @override
  String get businessShopNoGymSellsMemberships =>
      'No gym sells memberships in the app yet.';

  @override
  String get businessShopNoGymsMatch => 'No gyms match your search';

  @override
  String get businessShopNoMembershipsForSale => 'No memberships for sale';

  @override
  String businessShopNoOrdersWithStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'pending': 'No pending orders',
      'paid': 'No paid orders',
      'fulfilled': 'No fulfilled orders',
      'cancelled': 'No cancelled orders',
      'other': 'No orders',
    });
    return '$_temp0';
  }

  @override
  String get businessShopNoOrdersYet => 'No orders yet';

  @override
  String get businessShopNoOrdersYetMessage =>
      'Products you order from a shop show up here.';

  @override
  String get businessShopNoProductsMatch => 'No products match your search';

  @override
  String get businessShopNoProductsYet => 'This shop has no products yet';

  @override
  String get businessShopNoShopsYet => 'No shops yet';

  @override
  String get businessShopNoShopsYetMessage =>
      'Shops will appear here once they open.';

  @override
  String get businessShopNotYet => 'Not yet';

  @override
  String get businessShopNote => 'Note';

  @override
  String get businessShopNoteForShop => 'Note for the shop (optional)';

  @override
  String businessShopOneTimeExplanation(String price, String gym) {
    return 'One payment of $price. If you already have a membership at $gym, it\'s extended.';
  }

  @override
  String get businessShopOnlinePaymentsUnavailable =>
      'Online payments are not available';

  @override
  String get businessShopOrder => 'Order';

  @override
  String businessShopOrderIdStatusChanged(String status, String id) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'paid': 'Order $id marked as paid.',
      'fulfilled': 'Order $id marked as fulfilled.',
      'cancelled': 'Order $id cancelled.',
      'other': 'Order $id updated.',
    });
    return '$_temp0';
  }

  @override
  String get businessShopOrderPaymentSuccess =>
      'Payment successful. Your order is paid!';

  @override
  String businessShopOrderStatusChanged(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'paid': 'Order marked as paid.',
      'fulfilled': 'Order marked as fulfilled.',
      'cancelled': 'Order cancelled.',
      'other': 'Order updated.',
    });
    return '$_temp0';
  }

  @override
  String businessShopOrderWithId(String id) {
    return 'Order $id';
  }

  @override
  String get businessShopOrders => 'Orders';

  @override
  String get businessShopOutOfStock => 'Out of stock';

  @override
  String businessShopPayAmount(String price) {
    return 'Pay $price';
  }

  @override
  String get businessShopPayByCard => 'Pay by card';

  @override
  String businessShopPayNow(String price) {
    return 'Pay now · $price';
  }

  @override
  String get businessShopPayment => 'Payment';

  @override
  String get businessShopPaymentCancelled => 'Payment cancelled';

  @override
  String get businessShopPaymentFailed =>
      'Payment failed. You have not been charged.';

  @override
  String get businessShopPaymentNotConfirmedYet =>
      'Couldn\'t confirm the payment yet. We\'ll notify you once it\'s done.';

  @override
  String get businessShopPaymentRefunded => 'Payment refunded';

  @override
  String get businessShopPaymentStillProcessing =>
      'Your payment is still processing. We\'ll notify you once it\'s confirmed.';

  @override
  String get businessShopPaymentSuccessful => 'Payment successful';

  @override
  String get businessShopPickupPaymentHint =>
      'Pay at the shop when you pick up your order.';

  @override
  String businessShopPlaceOrderAndPay(String price) {
    return 'Place order & pay $price';
  }

  @override
  String businessShopPlaceOrderTotal(String price) {
    return 'Place order · $price';
  }

  @override
  String get businessShopPlanMonthlyAutoRenew => 'Monthly, auto-renew';

  @override
  String businessShopPlanMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String businessShopPriceEachLineTotal(String price, String total) {
    return '$price each · $total';
  }

  @override
  String businessShopPricePerMonth(String price) {
    return '$price / month';
  }

  @override
  String businessShopProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
    );
    return '$_temp0';
  }

  @override
  String businessShopQuantityValue(int count) {
    return 'Quantity: $count';
  }

  @override
  String get businessShopRefundDone => 'The card payment was refunded.';

  @override
  String get businessShopRefundFailed =>
      'The refund failed. Please refund it from Stripe.';

  @override
  String get businessShopRefundManual => 'Refund the card payment manually.';

  @override
  String get businessShopRemove => 'Remove';

  @override
  String businessShopRemovedFromCart(String items) {
    return 'Removed from your cart (no longer available): $items';
  }

  @override
  String get businessShopSearchGyms => 'Search gyms';

  @override
  String get businessShopSearchProducts => 'Search products';

  @override
  String get businessShopShop => 'Shop';

  @override
  String get businessShopSoldOut => 'Sold out';

  @override
  String get businessShopStatus => 'Status';

  @override
  String businessShopSubscribePerMonth(String price) {
    return 'Subscribe · $price/month';
  }

  @override
  String get businessShopTimelinePlaced => 'Order placed';

  @override
  String get businessShopTotal => 'Total';

  @override
  String get businessShopYourCart => 'Your cart';

  @override
  String get chatAccept => 'Accept';

  @override
  String chatAddCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count people',
      one: 'Add 1 person',
    );
    return '$_temp0';
  }

  @override
  String get chatAddPeople => 'Add people';

  @override
  String get chatAddPeopleTitle => 'Add people';

  @override
  String get chatAlreadyMember => 'Already in the group';

  @override
  String get chatArchive => 'Archive';

  @override
  String get chatArchived => 'Archived';

  @override
  String get chatArchivedSnack => 'Chat archived';

  @override
  String get chatArchivedTitle => 'Archived chats';

  @override
  String get chatAttach => 'Attach';

  @override
  String get chatBlock => 'Block';

  @override
  String get chatBlockConfirmBody =>
      'They won\'t be able to message you or find your profile. They won\'t be told you blocked them.';

  @override
  String chatBlockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String chatBlockedSnack(String name) {
    return '$name is blocked';
  }

  @override
  String get chatCancel => 'Cancel';

  @override
  String get chatClearChat => 'Clear chat';

  @override
  String get chatClearChatConfirm =>
      'Clear this chat\'s history for you? Others in the chat still see it.';

  @override
  String get chatCleared => 'Chat cleared';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatCreateGroup => 'Create group';

  @override
  String get chatDeleteChat => 'Delete chat';

  @override
  String get chatDeleteChatConfirm =>
      'Delete this chat? It\'s removed for you only — the other person still sees it.';

  @override
  String get chatDeleteGroup => 'Delete group';

  @override
  String chatDeleteGroupConfirm(String title) {
    return 'Delete \"$title\" for everyone? This can\'t be undone.';
  }

  @override
  String get chatEditGroup => 'Edit group';

  @override
  String get chatEdited => 'Edited';

  @override
  String get chatEditingMessage => 'Editing message';

  @override
  String get chatEmptyArchived => 'No archived chats';

  @override
  String get chatEmptyInbox => 'No chats yet';

  @override
  String get chatEmptyInboxHint =>
      'Start a conversation with your gym buddies.';

  @override
  String get chatEmptyRequests => 'No message requests';

  @override
  String get chatEmptyRequestsHint =>
      'Messages from people who can\'t message you directly show up here.';

  @override
  String get chatFailed => 'Not sent · Tap to retry';

  @override
  String get chatFollowingSection => 'Following';

  @override
  String get chatGroupDescription => 'Description';

  @override
  String get chatGroupFallback => 'Group chat';

  @override
  String get chatGroupInfo => 'Group info';

  @override
  String get chatGroupName => 'Group name';

  @override
  String get chatGroupNameHint => 'Name your group (optional)';

  @override
  String get chatGroupRequestBanner => 'You\'ve been added to this group';

  @override
  String get chatGroupRequestHint => 'Accept to join the conversation.';

  @override
  String get chatInboxTitle => 'Chats';

  @override
  String get chatInvited => 'Invited';

  @override
  String get chatJumpToLatest => 'Jump to latest';

  @override
  String get chatLeaveGroup => 'Leave group';

  @override
  String chatLeaveGroupConfirm(String title) {
    return 'Leave \"$title\"? You won\'t get new messages from this group.';
  }

  @override
  String get chatMakeAdmin => 'Make admin';

  @override
  String get chatMakeOwner => 'Make group owner';

  @override
  String chatMakeOwnerConfirm(String name) {
    return 'Make $name the group owner? You\'ll stay on as an admin.';
  }

  @override
  String get chatMarkRead => 'Mark as read';

  @override
  String get chatMediaAudio => '🎤 Audio';

  @override
  String get chatMediaFile => '📎 File';

  @override
  String get chatMediaPhoto => '📷 Photo';

  @override
  String get chatMediaVideo => '🎥 Video';

  @override
  String chatMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get chatMembersTitle => 'Members';

  @override
  String get chatMessageHint => 'Message…';

  @override
  String get chatMessageMember => 'Message';

  @override
  String get chatMessageUnsent => 'Message unsent';

  @override
  String get chatMoreOptions => 'More options';

  @override
  String get chatMute => 'Mute';

  @override
  String get chatMutedSnack => 'Notifications muted';

  @override
  String get chatNewMessage => 'New message';

  @override
  String get chatNoAudio => 'No audio yet';

  @override
  String get chatNoFiles => 'No files yet';

  @override
  String get chatNoMedia => 'No photos or videos yet';

  @override
  String get chatNoPeopleFound => 'No people found';

  @override
  String chatNoResults(String query) {
    return 'No chats match \"$query\"';
  }

  @override
  String get chatOpenFile => 'Open file';

  @override
  String get chatOriginalNotFound => 'Couldn\'t find the original message';

  @override
  String get chatPause => 'Pause';

  @override
  String chatPeopleAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people added',
      one: '1 person added',
    );
    return '$_temp0';
  }

  @override
  String get chatPhotoMessage => 'Photo';

  @override
  String get chatPlay => 'Play';

  @override
  String chatPreviewSender(String name, String text) {
    return '$name: $text';
  }

  @override
  String chatPreviewYou(String text) {
    return 'You: $text';
  }

  @override
  String get chatReactions => 'Reactions';

  @override
  String get chatRemoveAdmin => 'Remove as admin';

  @override
  String get chatRemoveAttachment => 'Remove';

  @override
  String get chatRemoveMember => 'Remove from group';

  @override
  String chatRemoveMemberConfirm(String name) {
    return 'Remove $name from the group?';
  }

  @override
  String get chatRemoveMessage => 'Remove for everyone';

  @override
  String get chatReply => 'Reply';

  @override
  String chatReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get chatReplyingToYourself => 'Replying to yourself';

  @override
  String get chatReport => 'Report';

  @override
  String get chatReportHarassment => 'Harassment or bullying';

  @override
  String get chatReportImpersonation => 'Pretending to be someone else';

  @override
  String get chatReportInappropriate => 'Inappropriate content';

  @override
  String get chatReportOther => 'Something else';

  @override
  String get chatReportSent => 'Thanks — we\'ll review it.';

  @override
  String get chatReportSpam => 'Spam';

  @override
  String get chatReportTitle => 'Why are you reporting this?';

  @override
  String chatRequestBanner(String name) {
    return '$name wants to message you';
  }

  @override
  String get chatRequestBannerHint =>
      'They won\'t know you\'ve seen this until you accept.';

  @override
  String get chatRoleAdmin => 'Admin';

  @override
  String get chatRoleOwner => 'Owner';

  @override
  String get chatSaveEdit => 'Save';

  @override
  String chatSayHi(String name) {
    return 'Say hi to $name 👋';
  }

  @override
  String get chatSayHiGroup => 'Say hi to the group 👋';

  @override
  String get chatSearchHint => 'Search';

  @override
  String get chatSearchPeople => 'Search people';

  @override
  String get chatSeen => 'Seen';

  @override
  String get chatSelected => 'Selected';

  @override
  String get chatSend => 'Send';

  @override
  String get chatSending => 'Sending…';

  @override
  String get chatSent => 'Sent';

  @override
  String get chatSharedMedia => 'Media, files and audio';

  @override
  String get chatSomeone => 'Someone';

  @override
  String get chatStartChat => 'Chat';

  @override
  String get chatSuggestedSection => 'Suggested';

  @override
  String chatSysAdded(String who, String name, String targets) {
    String _temp0 = intl.Intl.selectLogic(who, {
      'me': 'You added $targets',
      'other': '$name added $targets',
    });
    return '$_temp0';
  }

  @override
  String chatSysCreated(String who, String name) {
    String _temp0 = intl.Intl.selectLogic(who, {
      'me': 'You created the group',
      'other': '$name created the group',
    });
    return '$_temp0';
  }

  @override
  String chatSysLeft(String who, String name) {
    String _temp0 = intl.Intl.selectLogic(who, {
      'me': 'You left the group',
      'other': '$name left the group',
    });
    return '$_temp0';
  }

  @override
  String chatSysMadeAdmin(String who, String name, String target) {
    String _temp0 = intl.Intl.selectLogic(who, {
      'me': 'You made $target an admin',
      'other': '$name made $target an admin',
    });
    return '$_temp0';
  }

  @override
  String chatSysMadeOwner(String who, String name, String target) {
    String _temp0 = intl.Intl.selectLogic(who, {
      'me': 'You made $target the group owner',
      'other': '$name made $target the group owner',
    });
    return '$_temp0';
  }

  @override
  String chatSysNameCleared(String who, String name) {
    String _temp0 = intl.Intl.selectLogic(who, {
      'me': 'You removed the group name',
      'other': '$name removed the group name',
    });
    return '$_temp0';
  }

  @override
  String chatSysPhoto(String who, String name) {
    String _temp0 = intl.Intl.selectLogic(who, {
      'me': 'You changed the group photo',
      'other': '$name changed the group photo',
    });
    return '$_temp0';
  }

  @override
  String chatSysRemoved(String who, String name, String target) {
    String _temp0 = intl.Intl.selectLogic(who, {
      'me': 'You removed $target',
      'other': '$name removed $target',
    });
    return '$_temp0';
  }

  @override
  String chatSysRemovedAdmin(String who, String name, String target) {
    String _temp0 = intl.Intl.selectLogic(who, {
      'me': 'You removed $target as admin',
      'other': '$name removed $target as admin',
    });
    return '$_temp0';
  }

  @override
  String chatSysRenamed(String who, String name, String title) {
    String _temp0 = intl.Intl.selectLogic(who, {
      'me': 'You named the group \"$title\"',
      'other': '$name named the group \"$title\"',
    });
    return '$_temp0';
  }

  @override
  String chatSysUpdated(String who, String name) {
    String _temp0 = intl.Intl.selectLogic(who, {
      'me': 'You updated the group',
      'other': '$name updated the group',
    });
    return '$_temp0';
  }

  @override
  String get chatTabAudio => 'Audio';

  @override
  String get chatTabChats => 'Chats';

  @override
  String get chatTabFiles => 'Files';

  @override
  String get chatTabMedia => 'Media';

  @override
  String get chatTabRequests => 'Requests';

  @override
  String get chatTapToRemove => 'Tap to remove';

  @override
  String get chatTo => 'To:';

  @override
  String get chatUnarchive => 'Unarchive';

  @override
  String get chatUnarchivedSnack => 'Chat moved to your inbox';

  @override
  String get chatUndo => 'Undo';

  @override
  String get chatUnmute => 'Unmute';

  @override
  String get chatUnmutedSnack => 'Notifications unmuted';

  @override
  String chatUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
    );
    return '$_temp0';
  }

  @override
  String get chatUnsend => 'Unsend';

  @override
  String get chatUnsendConfirmBody =>
      'It will be removed for everyone in this chat.';

  @override
  String get chatUnsendConfirmTitle => 'Unsend message?';

  @override
  String get chatVideoMessage => 'Video';

  @override
  String get chatViewProfile => 'View profile';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatYou => 'You';

  @override
  String get chatYouObject => 'you';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonNo => 'No';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get commonToday => 'Today';

  @override
  String get commonYes => 'Yes';

  @override
  String get feedAddMedia => 'Add photos or videos';

  @override
  String get feedAddMore => 'Add';

  @override
  String get feedAllComments => 'Back to all comments';

  @override
  String get feedCancelReply => 'Cancel reply';

  @override
  String get feedCaptionHint => 'Write a caption…';

  @override
  String get feedCollapseThread => 'Collapse thread';

  @override
  String get feedCommentsHeader => 'Comments';

  @override
  String get feedComposerHint => 'Share a photo or update…';

  @override
  String get feedContinueThread => 'Continue this thread →';

  @override
  String get feedCopied => 'Copied to clipboard';

  @override
  String get feedCopyText => 'Copy text';

  @override
  String get feedDeletedComment => '[deleted]';

  @override
  String get feedDiscard => 'Discard';

  @override
  String get feedDiscardTitle => 'Discard this post?';

  @override
  String get feedDoubleTapToLove => 'Double-tap to love';

  @override
  String get feedEmptyExploreBody => 'Popular public posts will show up here.';

  @override
  String get feedEmptyExploreTitle => 'Nothing to explore yet';

  @override
  String get feedEmptyHomeBody =>
      'Follow people or join a gym to see their posts here.';

  @override
  String get feedEmptyHomeTitle => 'Your feed is empty';

  @override
  String get feedEndOfFeed => 'You\'re all caught up';

  @override
  String get feedExpandThread => 'Expand thread';

  @override
  String get feedExploreAction => 'Explore popular posts';

  @override
  String get feedHiddenComment => '[hidden]';

  @override
  String get feedLoadMoreComments => 'Load more comments';

  @override
  String feedMediaIndex(int index, int count) {
    return '$index/$count';
  }

  @override
  String feedMediaLimit(int count) {
    return 'Up to $count photos or videos per post';
  }

  @override
  String get feedMore => 'more';

  @override
  String get feedMoveLeft => 'Move left';

  @override
  String get feedMoveRight => 'Move right';

  @override
  String get feedMultipleMedia => 'Multiple photos or videos';

  @override
  String get feedNewPost => 'New post';

  @override
  String get feedNoReactions => 'No reactions yet';

  @override
  String get feedOp => 'OP';

  @override
  String feedOpenProfile(String name) {
    return 'Open $name\'s profile';
  }

  @override
  String get feedOriginalPoster => 'Original poster';

  @override
  String get feedPostEmpty => 'Add a photo, video or caption first';

  @override
  String get feedPostNotFound => 'This post isn\'t available anymore.';

  @override
  String get feedPostOptions => 'Post options';

  @override
  String get feedPostTitle => 'Post';

  @override
  String get feedPostUpdated => 'Post updated';

  @override
  String get feedPosted => 'Posted';

  @override
  String feedPostedBy(String name) {
    return 'by $name';
  }

  @override
  String get feedPrivateAccountNote =>
      'Your account is private, so only your followers will see this post.';

  @override
  String get feedPublishing => 'Publishing…';

  @override
  String feedReactionsAll(int count) {
    return 'All $count';
  }

  @override
  String get feedReactionsTitle => 'Reactions';

  @override
  String get feedRemoveMedia => 'Remove';

  @override
  String get feedReorderHint => 'Hold and drag to reorder';

  @override
  String get feedReply => 'Reply';

  @override
  String feedReplyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '1 reply',
    );
    return '$_temp0';
  }

  @override
  String feedReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get feedSending => 'Sending…';

  @override
  String get feedShowLess => 'Show less';

  @override
  String feedShowMoreReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count more replies',
      one: 'Show 1 more reply',
    );
    return '$_temp0';
  }

  @override
  String get feedShowParent => 'Show parent comment';

  @override
  String get feedSortLabel => 'Sort comments';

  @override
  String get feedSortNew => 'New';

  @override
  String get feedSortOld => 'Old';

  @override
  String get feedSortTop => 'Top';

  @override
  String get feedTabExplore => 'Explore';

  @override
  String get feedTabHome => 'Home';

  @override
  String get feedThreadTitle => 'Thread';

  @override
  String feedUploadingProgress(int index, int count) {
    return 'Uploading $index of $count…';
  }

  @override
  String get feedVideo => 'Video';

  @override
  String get feedVisibilityFollowers => 'Followers';

  @override
  String get feedVisibilityFollowersHint =>
      'Only your followers can see this post';

  @override
  String get feedVisibilityLabel => 'Who can see this';

  @override
  String get feedVisibilityPublic => 'Public';

  @override
  String get feedVisibilityPublicHint => 'Anyone can see this post';

  @override
  String get feedWriteReplyHint => 'Write a reply…';

  @override
  String get nutritionAdd => 'Add';

  @override
  String get nutritionAddFoodItem => 'Add food item';

  @override
  String get nutritionAddFoodTitle => 'Add food';

  @override
  String get nutritionAddImage => 'Add image';

  @override
  String get nutritionAddIngredient => 'Add ingredient';

  @override
  String get nutritionAddMineral => 'Add mineral';

  @override
  String nutritionAddNamed(String name) {
    return 'Add $name';
  }

  @override
  String get nutritionAddPhoto => 'Add photo';

  @override
  String get nutritionAddRecipe => 'Add recipe';

  @override
  String get nutritionAddSlot => 'Add Slot';

  @override
  String get nutritionAddStep => 'Add step';

  @override
  String nutritionAddToSlot(String slot) {
    return 'Add to $slot';
  }

  @override
  String get nutritionAddVideo => 'Add video';

  @override
  String get nutritionAddVitamin => 'Add vitamin';

  @override
  String get nutritionAllMineralsAdded => 'All minerals are already added';

  @override
  String get nutritionAllSlotsAdded => 'All meal slots have been added';

  @override
  String get nutritionAllVitaminsAdded => 'All vitamins are already added';

  @override
  String get nutritionAmount => 'Amount';

  @override
  String get nutritionAssign => 'Assign';

  @override
  String get nutritionAssignMealPlanTitle => 'Assign meal plan';

  @override
  String nutritionAssignPlanToQuestion(String plan, String name) {
    return 'Assign \"$plan\" to $name?';
  }

  @override
  String nutritionAssignPlanToSelfQuestion(String plan) {
    return 'Assign \"$plan\" to you?';
  }

  @override
  String get nutritionAssignTo => 'Assign to';

  @override
  String nutritionAssignedBy(String name) {
    return 'Assigned by $name';
  }

  @override
  String get nutritionAssignedByMe => 'Assigned by me';

  @override
  String nutritionAssignedOn(String date) {
    return 'Assigned $date';
  }

  @override
  String get nutritionAssignedToMe => 'Assigned to me';

  @override
  String nutritionAssignmentFor(String name) {
    return 'For $name';
  }

  @override
  String nutritionBarcodeExample(String example) {
    return 'e.g. $example';
  }

  @override
  String nutritionBarcodeNotFound(String code) {
    return 'No product found for barcode $code';
  }

  @override
  String get nutritionBarcodeOptional => 'Barcode (optional)';

  @override
  String nutritionBarcodeValue(String code) {
    return 'Barcode $code';
  }

  @override
  String get nutritionBasicInfo => 'Basic Info';

  @override
  String get nutritionBrandOptional => 'Brand (optional)';

  @override
  String get nutritionCalories => 'Calories';

  @override
  String get nutritionCameraAccessOff => 'Camera access is off';

  @override
  String get nutritionCameraAccessOffHint =>
      'Allow camera access for Gym Bro in your device settings to scan barcodes, or type the code instead.';

  @override
  String get nutritionCameraUnavailable => 'Camera unavailable';

  @override
  String get nutritionCameraUnavailableHint =>
      'The camera could not be started. You can type the barcode number instead.';

  @override
  String get nutritionCancelEditing => 'Cancel editing';

  @override
  String get nutritionCannotBeUndone => 'This cannot be undone.';

  @override
  String get nutritionCarbs => 'Carbs';

  @override
  String get nutritionCarbsLetter => 'C';

  @override
  String get nutritionCarbsShort => 'Carbs';

  @override
  String nutritionChooseDailyPlanFor(String week, String day) {
    return 'Choose daily plan for $week, $day';
  }

  @override
  String get nutritionClearSearch => 'Clear search';

  @override
  String get nutritionClearStartDate => 'Clear start date';

  @override
  String get nutritionClearUnassign => 'Clear / Unassign';

  @override
  String get nutritionComment => 'Comment';

  @override
  String nutritionCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
    );
    return '$_temp0';
  }

  @override
  String get nutritionCommentOptions => 'Comment options';

  @override
  String get nutritionComments => 'Comments';

  @override
  String nutritionCommentsWithCount(int count) {
    return 'Comments ($count)';
  }

  @override
  String nutritionCommunityTitle(String business) {
    return '$business · Community';
  }

  @override
  String get nutritionComputedPerServing => 'Computed per serving';

  @override
  String get nutritionCookMinLabel => 'Cook (min)';

  @override
  String get nutritionCreate => 'Create';

  @override
  String get nutritionCreateItem => 'Create item';

  @override
  String nutritionDailyAveragePlannedDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Daily average · $count planned days',
      one: 'Daily average · 1 planned day',
    );
    return '$_temp0';
  }

  @override
  String nutritionDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String nutritionDaysPlannedOfSeven(int count) {
    return '$count of 7 days planned';
  }

  @override
  String get nutritionDeleteCommentTitle => 'Delete comment?';

  @override
  String get nutritionDeleteFoodItemTitle => 'Delete food item?';

  @override
  String nutritionDeleteMealPlanMessage(String name) {
    return 'Remove \"$name\" permanently? Any assignments of this plan are removed too.';
  }

  @override
  String get nutritionDeleteMealPlanTitle => 'Delete meal plan?';

  @override
  String get nutritionDeletePost => 'Delete post';

  @override
  String get nutritionDeletePostTitle => 'Delete post?';

  @override
  String get nutritionDeleteRecipeTitle => 'Delete recipe?';

  @override
  String get nutritionDeletedUser => 'Deleted user';

  @override
  String get nutritionDescription => 'Description';

  @override
  String get nutritionDragToReorder => 'Drag to reorder';

  @override
  String get nutritionDrinkBeer => 'Beer';

  @override
  String get nutritionDrinkBlackTea => 'Black Tea';

  @override
  String get nutritionDrinkCider => 'Cider';

  @override
  String get nutritionDrinkCocktail => 'Cocktail';

  @override
  String get nutritionDrinkCoffee => 'Coffee';

  @override
  String get nutritionDrinkDairyMilk => 'Dairy Milk';

  @override
  String get nutritionDrinkEnergy => 'Energy Drink';

  @override
  String get nutritionDrinkEspresso => 'Espresso';

  @override
  String get nutritionDrinkFlavouredWater => 'Flavoured Water';

  @override
  String get nutritionDrinkFruitJuice => 'Fruit Juice';

  @override
  String get nutritionDrinkGreenTea => 'Green Tea';

  @override
  String get nutritionDrinkHerbalTea => 'Herbal Tea';

  @override
  String get nutritionDrinkIsotonic => 'Isotonic';

  @override
  String get nutritionDrinkKefir => 'Kefir Drink';

  @override
  String get nutritionDrinkKombucha => 'Kombucha';

  @override
  String get nutritionDrinkMealReplacement => 'Meal Replacement';

  @override
  String get nutritionDrinkPlantMilk => 'Plant Milk';

  @override
  String get nutritionDrinkProteinShake => 'Protein Shake';

  @override
  String get nutritionDrinkShake => 'Shake';

  @override
  String get nutritionDrinkSmoothie => 'Smoothie';

  @override
  String get nutritionDrinkSoda => 'Soda';

  @override
  String get nutritionDrinkSparklingWater => 'Sparkling Water';

  @override
  String get nutritionDrinkSpirit => 'Spirit';

  @override
  String get nutritionDrinkSports => 'Sports Drink';

  @override
  String get nutritionDrinkStillWater => 'Still Water';

  @override
  String get nutritionDrinkVegetableJuice => 'Vegetable Juice';

  @override
  String get nutritionDrinkWine => 'Wine';

  @override
  String get nutritionDuration => 'Duration';

  @override
  String get nutritionEditAmountOrMeal => 'Edit amount or meal';

  @override
  String get nutritionEditDailyPlanTitle => 'Edit Meal Plan';

  @override
  String get nutritionEditFoodItemTitle => 'Edit Food Item';

  @override
  String get nutritionEditMealPlanTitle => 'Edit Meal Plan';

  @override
  String get nutritionEditMicronutrients => 'Edit micronutrients';

  @override
  String get nutritionEditPost => 'Edit post';

  @override
  String get nutritionEditPostTitle => 'Edit Post';

  @override
  String get nutritionEditRecipeTitle => 'Edit Recipe';

  @override
  String get nutritionEdited => 'Edited';

  @override
  String get nutritionEditedLower => 'edited';

  @override
  String get nutritionEditingComment => 'Editing comment';

  @override
  String nutritionEndsOn(String date) {
    return 'Ends $date';
  }

  @override
  String get nutritionEnterBarcode => 'Enter barcode';

  @override
  String get nutritionEnterCodeManually => 'Enter code manually';

  @override
  String get nutritionEnterPositiveNumber => 'Enter a positive number';

  @override
  String get nutritionEnterValidNumber => 'Enter a valid number';

  @override
  String get nutritionFat => 'Fat';

  @override
  String get nutritionFatLetter => 'F';

  @override
  String get nutritionFiber => 'Fiber';

  @override
  String nutritionFiberNoTargets(int fiber) {
    return 'Fiber $fiber g · No meal plan targets for this day';
  }

  @override
  String nutritionFiberWithTargets(int fiber, int target) {
    return 'Fiber $fiber / $target g · Targets from your meal plan';
  }

  @override
  String get nutritionFilterAll => 'All';

  @override
  String get nutritionFoodBabyFood => 'Baby Food';

  @override
  String get nutritionFoodBaking => 'Baking';

  @override
  String get nutritionFoodBeans => 'Beans';

  @override
  String get nutritionFoodBeef => 'Beef';

  @override
  String get nutritionFoodBiscuitCookie => 'Biscuit / Cookie';

  @override
  String get nutritionFoodBreadBakery => 'Bread / Bakery';

  @override
  String get nutritionFoodButter => 'Butter';

  @override
  String get nutritionFoodCanned => 'Canned Food';

  @override
  String get nutritionFoodCerealBar => 'Cereal Bar';

  @override
  String get nutritionFoodCheese => 'Cheese';

  @override
  String get nutritionFoodChips => 'Chips / Crisps';

  @override
  String get nutritionFoodChocolateCandy => 'Chocolate / Candy';

  @override
  String get nutritionFoodCorn => 'Corn / Maize';

  @override
  String get nutritionFoodCream => 'Cream';

  @override
  String get nutritionFoodDiary => 'Food diary';

  @override
  String get nutritionFoodDressing => 'Dressing';

  @override
  String get nutritionFoodEgg => 'Egg';

  @override
  String get nutritionFoodFish => 'Fish';

  @override
  String get nutritionFoodFrozen => 'Frozen Food';

  @override
  String get nutritionFoodFruit => 'Fruit';

  @override
  String get nutritionFoodGameMeat => 'Game Meat';

  @override
  String get nutritionFoodGrainCereal => 'Grain / Cereal';

  @override
  String get nutritionFoodHerbFresh => 'Fresh Herb';

  @override
  String get nutritionFoodJamSpread => 'Jam / Spread';

  @override
  String get nutritionFoodLamb => 'Lamb';

  @override
  String get nutritionFoodLentils => 'Lentils';

  @override
  String get nutritionFoodMilk => 'Milk';

  @override
  String get nutritionFoodMushroom => 'Mushroom';

  @override
  String get nutritionFoodNuts => 'Nuts';

  @override
  String get nutritionFoodOilFat => 'Oil / Fat';

  @override
  String get nutritionFoodPastaNoodle => 'Pasta / Noodle';

  @override
  String get nutritionFoodPlantMilk => 'Plant Milk';

  @override
  String get nutritionFoodPork => 'Pork';

  @override
  String get nutritionFoodPotatoTuber => 'Potato / Tuber';

  @override
  String get nutritionFoodPoultry => 'Poultry';

  @override
  String get nutritionFoodProcessedMeat => 'Processed Meat';

  @override
  String get nutritionFoodReadyMeal => 'Ready Meal';

  @override
  String get nutritionFoodRice => 'Rice';

  @override
  String get nutritionFoodSauceCondiment => 'Sauce / Condiment';

  @override
  String get nutritionFoodSeafood => 'Seafood';

  @override
  String get nutritionFoodSeeds => 'Seeds';

  @override
  String get nutritionFoodSnackBar => 'Snack Bar';

  @override
  String get nutritionFoodSupplementPowder => 'Supplement Powder';

  @override
  String get nutritionFoodSweetener => 'Sweetener';

  @override
  String get nutritionFoodVegetable => 'Vegetable';

  @override
  String get nutritionFoodYogurt => 'Yogurt';

  @override
  String get nutritionFoods => 'Foods';

  @override
  String nutritionHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get nutritionImageUrl => 'Image URL';

  @override
  String get nutritionImages => 'Images';

  @override
  String nutritionImportedFromOff(String name) {
    return 'Imported \"$name\" from Open Food Facts. Check the values before relying on them.';
  }

  @override
  String get nutritionIngredients => 'Ingredients';

  @override
  String get nutritionInstructionHint => 'Instruction…';

  @override
  String get nutritionItemFallback => 'Item';

  @override
  String get nutritionJustNow => 'Just now';

  @override
  String get nutritionKcal => 'kcal';

  @override
  String nutritionKcalEatenSemantics(int eaten) {
    return 'Calories eaten: $eaten kcal';
  }

  @override
  String nutritionKcalLeft(int count) {
    return '$count left';
  }

  @override
  String nutritionKcalOver(int count) {
    return '$count over';
  }

  @override
  String nutritionKcalPer100(int kcal, String per100) {
    return '$kcal kcal $per100';
  }

  @override
  String nutritionKcalPerServing(int kcal) {
    return '$kcal kcal per serving';
  }

  @override
  String get nutritionKcalPerServingLabel => 'kcal per serving';

  @override
  String nutritionKcalRingSemantics(int eaten, int target) {
    return 'Calories: $eaten of $target kcal';
  }

  @override
  String nutritionKcalValue(int kcal) {
    return '$kcal kcal';
  }

  @override
  String nutritionLabelWithUnit(String label, String unit) {
    return '$label ($unit)';
  }

  @override
  String get nutritionLike => 'Like';

  @override
  String nutritionLikeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count likes',
      one: '1 like',
      zero: 'No likes',
    );
    return '$_temp0';
  }

  @override
  String get nutritionLoadMore => 'Load more';

  @override
  String get nutritionLogAction => 'Log';

  @override
  String get nutritionLogAnyway => 'Log anyway';

  @override
  String get nutritionLogPlannedAllDuplicateWarning =>
      'Some meals already have entries today. The planned items will be added on top of them.';

  @override
  String get nutritionLogPlannedMeals => 'Log planned meals';

  @override
  String get nutritionLogPlannedMealsQuestion => 'Log planned meals?';

  @override
  String nutritionLogPlannedSlotDuplicateWarning(String slot) {
    return '$slot already has entries. The planned items will be added on top of them.';
  }

  @override
  String get nutritionLogToDiary => 'Log to diary';

  @override
  String get nutritionLogToToday => 'Log to today';

  @override
  String nutritionLoggedItemToSlot(String name, String slot) {
    return 'Logged $name to $slot';
  }

  @override
  String nutritionLoggedPlannedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Logged $count planned items',
      one: 'Logged 1 planned item',
    );
    return '$_temp0';
  }

  @override
  String nutritionLoggedToSlot(String slot) {
    return 'Logged to $slot';
  }

  @override
  String get nutritionLookUp => 'Look up';

  @override
  String get nutritionLookingUpProduct => 'Looking up product…';

  @override
  String get nutritionMacronutrients => 'Macronutrients';

  @override
  String get nutritionMeal => 'Meal';

  @override
  String nutritionMealCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meals',
      one: '1 meal',
    );
    return '$_temp0';
  }

  @override
  String get nutritionMealPlanFallback => 'Meal plan';

  @override
  String get nutritionMealPlansTitle => 'Meal Plans';

  @override
  String get nutritionMealSlots => 'Meal Slots';

  @override
  String get nutritionMemberFallback => 'member';

  @override
  String get nutritionMicronutrients => 'Micronutrients';

  @override
  String nutritionMicronutrientsOptionalHint(String per100) {
    return 'Optional. Amounts $per100.';
  }

  @override
  String get nutritionMine => 'Mine';

  @override
  String get nutritionMineral => 'Mineral';

  @override
  String get nutritionMinerals => 'Minerals';

  @override
  String nutritionMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String get nutritionMoveToMeal => 'Move to meal';

  @override
  String get nutritionMyself => 'Myself';

  @override
  String get nutritionNameRequiredLabel => 'Name *';

  @override
  String get nutritionNewDailyPlanMenu => 'New Daily Plan';

  @override
  String get nutritionNewDailyPlanTitle => 'New Meal Plan';

  @override
  String get nutritionNewFoodItemTitle => 'New Food Item';

  @override
  String get nutritionNewMealPlanTitle => 'New Meal Plan';

  @override
  String get nutritionNewPost => 'New Post';

  @override
  String get nutritionNewRecipeTitle => 'New Recipe';

  @override
  String get nutritionNextDay => 'Next day';

  @override
  String get nutritionNoAssignmentsByMe =>
      'You haven\'t assigned meal plans to anyone';

  @override
  String get nutritionNoAssignmentsToMe => 'No meal plans assigned to you yet';

  @override
  String get nutritionNoCommentsYet => 'No comments yet';

  @override
  String get nutritionNoDailyPlansFound => 'No daily plans found';

  @override
  String get nutritionNoEntries => 'No entries';

  @override
  String get nutritionNoEntriesYet => 'No entries yet';

  @override
  String get nutritionNoFoodItemsFound => 'No food items found';

  @override
  String get nutritionNoFoodsFound => 'No foods found';

  @override
  String get nutritionNoFoodsFoundHint =>
      'Try another search, or scan the product barcode.';

  @override
  String get nutritionNoIngredientsYet => 'No ingredients added yet';

  @override
  String get nutritionNoMealPlansFound => 'No meal plans found';

  @override
  String get nutritionNoMealsYet => 'No meals added yet';

  @override
  String get nutritionNoMembersMatch => 'No members match your search';

  @override
  String get nutritionNoMembersToCoach =>
      'No members to coach. Members of gyms where you work or train appear here.';

  @override
  String get nutritionNoMicronutrients =>
      'No vitamins or minerals recorded for this item.';

  @override
  String get nutritionNoMicronutrientsAdded => 'No vitamins or minerals added';

  @override
  String get nutritionNoOwnMealPlans =>
      'You haven\'t created any meal plans yet';

  @override
  String get nutritionNoPostsYet => 'No posts yet';

  @override
  String get nutritionNoRecipesFound => 'No recipes found';

  @override
  String get nutritionNoResults => 'No results';

  @override
  String get nutritionNoStepsYet => 'No steps added yet';

  @override
  String get nutritionNoteOptional => 'Note (optional)';

  @override
  String get nutritionNothingLogged => 'Nothing logged';

  @override
  String get nutritionNothingLoggedThisDay => 'No food was logged on this day.';

  @override
  String get nutritionNothingPlanned => 'Nothing planned';

  @override
  String get nutritionNutrient => 'Nutrient';

  @override
  String nutritionNutrientListLoadFailed(String error) {
    return 'Couldn\'t load the nutrient list: $error';
  }

  @override
  String nutritionOfTargetKcal(int target) {
    return 'of $target kcal';
  }

  @override
  String nutritionPcfGrams(int protein, int carbs, int fat) {
    return 'P ${protein}g · C ${carbs}g · F ${fat}g';
  }

  @override
  String nutritionPcfShort(int protein, int carbs, int fat) {
    return 'P $protein · C $carbs · F $fat';
  }

  @override
  String nutritionPer100Unit(String unit) {
    return 'per 100$unit';
  }

  @override
  String get nutritionPerServing => 'per serving';

  @override
  String nutritionPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String nutritionPhotoOf(String name) {
    return 'Photo of $name';
  }

  @override
  String get nutritionPickDate => 'Pick a date';

  @override
  String nutritionPlanAssignedTo(String plan, String name) {
    return '\"$plan\" assigned to $name';
  }

  @override
  String nutritionPlanAssignedToSelf(String plan) {
    return '\"$plan\" assigned to you';
  }

  @override
  String get nutritionPlanNameRequiredLabel => 'Plan name *';

  @override
  String nutritionPlannedSummary(String items, int kcal) {
    return 'Planned: $items · $kcal kcal';
  }

  @override
  String get nutritionPointCameraAtBarcode =>
      'Point the camera at the product barcode';

  @override
  String get nutritionPostAction => 'Post';

  @override
  String get nutritionPostPhoto => 'Post photo';

  @override
  String nutritionPostPhotoOf(int index, int count) {
    return 'Photo $index of $count';
  }

  @override
  String get nutritionPrepMinLabel => 'Prep (min)';

  @override
  String get nutritionPreviousDay => 'Previous day';

  @override
  String get nutritionPrivate => 'Private';

  @override
  String get nutritionProductNotFound => 'Product not found';

  @override
  String nutritionProductNotFoundMessage(String code) {
    return 'Nothing is known for barcode $code. Create the food item yourself?';
  }

  @override
  String get nutritionProtein => 'Protein';

  @override
  String get nutritionProteinLetter => 'P';

  @override
  String get nutritionPublic => 'Public';

  @override
  String get nutritionQtyShort => 'Qty';

  @override
  String get nutritionQuantity => 'Quantity';

  @override
  String nutritionRecipeCookTime(int minutes) {
    return 'Cook $minutes min';
  }

  @override
  String get nutritionRecipeFallback => 'Recipe';

  @override
  String get nutritionRecipeNameRequiredLabel => 'Recipe name *';

  @override
  String nutritionRecipePrepTime(int minutes) {
    return 'Prep $minutes min';
  }

  @override
  String get nutritionRecipes => 'Recipes';

  @override
  String get nutritionRemove => 'Remove';

  @override
  String nutritionRemoveAssignmentMessage(String name) {
    return '\"$name\" will no longer be assigned.';
  }

  @override
  String get nutritionRemoveAssignmentTitle => 'Remove assignment?';

  @override
  String get nutritionRemoveImage => 'Remove image';

  @override
  String get nutritionRemoveIngredient => 'Remove ingredient';

  @override
  String nutritionRemoveNamed(String name) {
    return 'Remove $name';
  }

  @override
  String nutritionRemovePermanently(String name) {
    return 'Remove \"$name\" permanently?';
  }

  @override
  String get nutritionRemovePhoto => 'Remove photo';

  @override
  String get nutritionRemoveSlot => 'Remove slot';

  @override
  String get nutritionRemoveStep => 'Remove step';

  @override
  String get nutritionRemoveVideo => 'Remove video';

  @override
  String nutritionRemovedItem(String name) {
    return 'Removed $name';
  }

  @override
  String get nutritionRestFree => 'Rest / Free';

  @override
  String get nutritionSaveComment => 'Save comment';

  @override
  String get nutritionScanBarcode => 'Scan barcode';

  @override
  String get nutritionSchedule => 'Schedule';

  @override
  String get nutritionSearchDailyPlansHint => 'Search daily plans…';

  @override
  String get nutritionSearchFoodItemsHint => 'Search food items…';

  @override
  String get nutritionSearchFoodsAndRecipes => 'Search foods and recipes';

  @override
  String get nutritionSearchHint => 'Search…';

  @override
  String get nutritionSearchMealPlansHint => 'Search meal plans…';

  @override
  String get nutritionSearchMembersHint => 'Search members…';

  @override
  String get nutritionSearchRecipesHint => 'Search recipes…';

  @override
  String get nutritionSelectMealSlot => 'Select Meal Slot';

  @override
  String get nutritionSelfAssigned => 'Self-assigned';

  @override
  String get nutritionSendComment => 'Send comment';

  @override
  String get nutritionServingUnit => 'Serving unit';

  @override
  String get nutritionServings => 'Servings';

  @override
  String nutritionServingsAmount(num count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$amount servings',
      one: '$amount serving',
    );
    return '$_temp0';
  }

  @override
  String get nutritionServingsRequiredLabel => 'Servings *';

  @override
  String get nutritionSetAsThumbnail => 'Set as thumbnail';

  @override
  String get nutritionShareHint => 'What do you want to share?';

  @override
  String get nutritionSlotAfternoonSnack => 'Afternoon Snack';

  @override
  String get nutritionSlotBreakfast => 'Breakfast';

  @override
  String get nutritionSlotDinner => 'Dinner';

  @override
  String get nutritionSlotEveningSnack => 'Evening Snack';

  @override
  String get nutritionSlotLunch => 'Lunch';

  @override
  String get nutritionSlotMorningSnack => 'Morning Snack';

  @override
  String get nutritionSlotPostWorkout => 'Post-Workout';

  @override
  String get nutritionSlotPreWorkout => 'Pre-Workout';

  @override
  String get nutritionSpiceBlend => 'Seasoning Blend';

  @override
  String get nutritionSpiceDriedHerb => 'Dried Herb';

  @override
  String get nutritionSpiceDryMarinade => 'Dry Marinade';

  @override
  String get nutritionSpiceExtract => 'Extract / Essence';

  @override
  String get nutritionSpiceGround => 'Ground Spice';

  @override
  String get nutritionSpicePepper => 'Pepper';

  @override
  String get nutritionSpiceRub => 'Rub';

  @override
  String get nutritionSpiceSalt => 'Salt';

  @override
  String get nutritionSpiceSeed => 'Spice Seed';

  @override
  String get nutritionSpiceWhole => 'Whole Spice';

  @override
  String get nutritionStartConversation => 'Start the conversation below.';

  @override
  String get nutritionStartDateOptional => 'Start date (optional)';

  @override
  String nutritionStartsOn(String date) {
    return 'Starts $date';
  }

  @override
  String get nutritionStepImageUrlOptional => 'Step image URL (optional)';

  @override
  String nutritionStepNumber(int number) {
    return 'Step $number';
  }

  @override
  String nutritionStepPhoto(int number) {
    return 'Photo for step $number';
  }

  @override
  String get nutritionSteps => 'Steps';

  @override
  String get nutritionSubtypeOther => 'Other';

  @override
  String get nutritionSubtypeRequiredLabel => 'Subtype *';

  @override
  String get nutritionSystem => 'System';

  @override
  String get nutritionTabAssigned => 'Assigned';

  @override
  String get nutritionTabDailyPlans => 'Daily Plans';

  @override
  String get nutritionTabFood => 'Food';

  @override
  String get nutritionTabMyDailyPlans => 'My Daily Plans';

  @override
  String get nutritionTabMyFood => 'My Food';

  @override
  String get nutritionTabMyLibrary => 'My Library';

  @override
  String get nutritionTabMyMealPlans => 'My Meal Plans';

  @override
  String get nutritionTabMyRecipes => 'My Recipes';

  @override
  String get nutritionTabPlans => 'Plans';

  @override
  String get nutritionThumbnail => 'Thumbnail';

  @override
  String get nutritionTitleOptional => 'Title (optional)';

  @override
  String get nutritionTomorrow => 'Tomorrow';

  @override
  String get nutritionTorchOff => 'Turn torch off';

  @override
  String get nutritionTorchOn => 'Turn torch on';

  @override
  String get nutritionTotals => 'Totals';

  @override
  String get nutritionTryAnotherSearch => 'Try another search term.';

  @override
  String get nutritionType => 'Type';

  @override
  String get nutritionTypeDrink => 'Drink';

  @override
  String get nutritionTypeFood => 'Food';

  @override
  String get nutritionTypeSpice => 'Spice';

  @override
  String get nutritionUnassigned => 'Unassigned';

  @override
  String get nutritionUnit => 'Unit';

  @override
  String get nutritionUnitServings => 'servings';

  @override
  String get nutritionUnlike => 'Unlike';

  @override
  String get nutritionUploadPhoto => 'Upload photo';

  @override
  String nutritionUsersDiary(String name) {
    return '$name\'s diary';
  }

  @override
  String nutritionValuesPer(String per100) {
    return 'Values $per100';
  }

  @override
  String nutritionVideoNumber(int number) {
    return 'Video $number';
  }

  @override
  String get nutritionVideoUrl => 'Video URL';

  @override
  String get nutritionVideos => 'Videos';

  @override
  String get nutritionVisibleToAllUsers => 'Visible to all users';

  @override
  String get nutritionVitamin => 'Vitamin';

  @override
  String get nutritionVitamins => 'Vitamins';

  @override
  String nutritionWeekDay(int week, int day) {
    return 'Week $week · Day $day';
  }

  @override
  String nutritionWeekNumber(int number) {
    return 'Week $number';
  }

  @override
  String nutritionWeeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String nutritionWeeksShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wks',
      one: '1 wk',
    );
    return '$_temp0';
  }

  @override
  String get nutritionWriteCommentHint => 'Write a comment…';

  @override
  String get nutritionWriteSomethingFirst => 'Write something first';

  @override
  String get nutritionYesterday => 'Yesterday';

  @override
  String get nutritionYourCoachFallback => 'your coach';

  @override
  String get nutritionYours => 'Yours';

  @override
  String get peopleAccept => 'Accept';

  @override
  String get peopleAddFriend => 'Add friend';

  @override
  String get peopleBio => 'Bio';

  @override
  String get peopleBioHint => 'Tell people about your training';

  @override
  String get peopleBioLess => 'less';

  @override
  String get peopleBioMore => 'more';

  @override
  String get peopleBlock => 'Block';

  @override
  String get peopleBlockBody =>
      'They won\'t be able to find your profile, see your posts or message you, and you won\'t see theirs. Follows and friendship between you are removed. They won\'t be notified.';

  @override
  String peopleBlockTitle(String username) {
    return 'Block @$username?';
  }

  @override
  String peopleBlockedSnack(String username) {
    return '@$username blocked';
  }

  @override
  String get peopleBlockedStateBody =>
      'Unblock to see their profile and interact again.';

  @override
  String get peopleBlockedStateTitle => 'You blocked this account';

  @override
  String get peopleBlockedUsers => 'Blocked users';

  @override
  String get peopleBlockedUsersEmpty => 'You haven\'t blocked anyone.';

  @override
  String get peopleBlockedUsersSubtitle => 'People you\'ve blocked';

  @override
  String peopleCancelFollowRequestTitle(String username) {
    return 'Cancel your follow request to @$username?';
  }

  @override
  String peopleCancelFriendRequestTitle(String name) {
    return 'Cancel your friend request to $name?';
  }

  @override
  String get peopleCancelRequest => 'Cancel request';

  @override
  String get peopleCopyUsername => 'Copy username';

  @override
  String get peopleDecline => 'Decline';

  @override
  String get peopleDiscard => 'Discard';

  @override
  String get peopleDiscardTitle => 'Discard changes?';

  @override
  String get peopleDiscoverable => 'Appear in suggestions & nearby';

  @override
  String get peopleDiscoverableHint =>
      'People can still find you by searching your name.';

  @override
  String get peopleDismiss => 'Dismiss';

  @override
  String peopleDistanceKm(int km) {
    return '~$km km';
  }

  @override
  String get peopleDistanceUnder1 => '< 1 km';

  @override
  String get peopleEditProfile => 'Edit profile';

  @override
  String get peopleEditTitle => 'Edit profile';

  @override
  String get peopleFollow => 'Follow';

  @override
  String get peopleFollowBack => 'Follow back';

  @override
  String peopleFollowRequestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count follow requests',
      one: '1 follow request',
    );
    return '$_temp0';
  }

  @override
  String get peopleFollowRequestsTab => 'Follow requests';

  @override
  String get peopleFollowers => 'Followers';

  @override
  String get peopleFollowing => 'Following';

  @override
  String peopleFriendRequestFrom(String name) {
    return '$name sent you a friend request';
  }

  @override
  String get peopleFriendRequestSent => 'Request sent';

  @override
  String peopleFriendRequestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friend requests',
      one: '1 friend request',
    );
    return '$_temp0';
  }

  @override
  String get peopleFriendRequestsTab => 'Friend requests';

  @override
  String get peopleFriends => 'Friends';

  @override
  String get peopleGoPublicBody =>
      'Anyone will be able to see your posts and follower lists, and all pending follow requests will be accepted.';

  @override
  String get peopleGoPublicConfirm => 'Switch to public';

  @override
  String get peopleGoPublicTitle => 'Switch to a public account?';

  @override
  String get peopleInterestBodybuilding => 'Bodybuilding';

  @override
  String get peopleInterestBoxing => 'Boxing';

  @override
  String get peopleInterestCalisthenics => 'Calisthenics';

  @override
  String get peopleInterestClimbing => 'Climbing';

  @override
  String get peopleInterestCrossfit => 'CrossFit';

  @override
  String get peopleInterestCycling => 'Cycling';

  @override
  String get peopleInterestHiit => 'HIIT';

  @override
  String get peopleInterestHiking => 'Hiking';

  @override
  String get peopleInterestMealPrep => 'Meal prep';

  @override
  String get peopleInterestMobility => 'Mobility';

  @override
  String get peopleInterestNutrition => 'Nutrition';

  @override
  String get peopleInterestOlympicLifting => 'Olympic lifting';

  @override
  String get peopleInterestPilates => 'Pilates';

  @override
  String get peopleInterestPowerlifting => 'Powerlifting';

  @override
  String peopleInterestRemove(String interest) {
    return 'Remove $interest';
  }

  @override
  String get peopleInterestRunning => 'Running';

  @override
  String get peopleInterestStrongman => 'Strongman';

  @override
  String get peopleInterestSwimming => 'Swimming';

  @override
  String get peopleInterestYoga => 'Yoga';

  @override
  String get peopleInterests => 'Interests';

  @override
  String get peopleInterestsHint => 'Add an interest';

  @override
  String peopleInterestsMax(int max) {
    return 'Up to $max interests';
  }

  @override
  String get peopleKeep => 'Keep';

  @override
  String get peopleListEmptyFollowers => 'No followers yet';

  @override
  String get peopleListEmptyFollowing => 'Not following anyone yet';

  @override
  String get peopleListEmptyFriends => 'No friends yet';

  @override
  String get peopleListEmptyMutual => 'No mutual friends';

  @override
  String get peopleLocationDenied =>
      'Location permission is off. You can turn it on in your phone\'s settings.';

  @override
  String get peopleLocationFailed => 'Couldn\'t get your location. Try again.';

  @override
  String get peopleLocationOff => 'Not sharing your location';

  @override
  String get peopleLocationOn =>
      'Sharing your approximate location (about 1 km)';

  @override
  String peopleLocationOnUpdated(String when) {
    return 'Sharing your approximate location · updated $when';
  }

  @override
  String get peopleLocationSection => 'Location sharing';

  @override
  String get peopleLocationServiceOff =>
      'Turn on location services to find people nearby.';

  @override
  String get peopleLocationStop => 'Stop sharing';

  @override
  String get peopleLocationStopped => 'Location sharing stopped';

  @override
  String get peopleLocationUpdate => 'Update now';

  @override
  String get peopleLocationUpdated => 'Location updated';

  @override
  String get peopleLocked => 'Private';

  @override
  String get peopleMessage => 'Message';

  @override
  String get peopleMessageRequestHint =>
      'Your message will arrive as a request';

  @override
  String get peopleMoreOptions => 'More options';

  @override
  String get peopleMoreSuggestions => 'More suggestions';

  @override
  String get peopleMutual => 'Mutual';

  @override
  String peopleMutualFriendsMore(int count, String a, String b) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Friends with $a, $b and $count others',
      one: 'Friends with $a, $b and 1 other',
    );
    return '$_temp0';
  }

  @override
  String peopleMutualFriendsOne(String a) {
    return 'Friends with $a';
  }

  @override
  String peopleMutualFriendsTwo(String a, String b) {
    return 'Friends with $a and $b';
  }

  @override
  String peopleNearbyEmpty(int km) {
    return 'No one within $km km yet.';
  }

  @override
  String get peopleNearbyPrivacyBody =>
      'We store your location rounded to about 1 km and only use it to show distances. Your exact location is never shared with anyone.';

  @override
  String get peopleNearbyPrivacyTitle => 'See people training near you';

  @override
  String get peopleNearbyTitle => 'Nearby';

  @override
  String get peopleNoFollowRequests => 'No follow requests';

  @override
  String get peopleNoFollowRequestsHint =>
      'When your account is private, people who want to follow you show up here.';

  @override
  String get peopleNoFriendRequests => 'No friend requests';

  @override
  String peopleNoMatches(String query) {
    return 'No one matches “$query”';
  }

  @override
  String get peopleNoPosts => 'No posts yet';

  @override
  String get peopleNoSentRequests => 'No pending requests you\'ve sent';

  @override
  String get peopleNoSuggestions =>
      'No suggestions right now. Check in at your gym or add interests to your profile to get better ones.';

  @override
  String get peoplePosts => 'Posts';

  @override
  String get peoplePrivacy => 'Privacy';

  @override
  String get peoplePrivacySubtitle =>
      'Private account, messages, activity status';

  @override
  String get peoplePrivateAccount => 'Private account';

  @override
  String get peoplePrivateAccountHint =>
      'Only people you approve see your photos, videos and follower lists. Anyone can still find you and see your comments and reactions.';

  @override
  String get peoplePrivateBody => 'Follow to see their photos and videos.';

  @override
  String get peoplePrivateRequestedBody =>
      'Your follow request is pending. You\'ll see their photos and videos once they accept.';

  @override
  String get peoplePrivateTitle => 'This account is private';

  @override
  String get peopleProfileUnavailable => 'This profile isn\'t available.';

  @override
  String peopleRadiusKm(int km) {
    return '$km km';
  }

  @override
  String get peopleReasonFollowsYou => 'Follows you';

  @override
  String peopleReasonInterests(String interests) {
    return 'Also into $interests';
  }

  @override
  String peopleReasonMutual(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mutual friends',
      one: '1 mutual friend',
    );
    return '$_temp0';
  }

  @override
  String peopleReasonNearby(int km) {
    return '~$km km away';
  }

  @override
  String get peopleReasonNearbyUnder1 => 'Less than 1 km away';

  @override
  String peopleReasonSameClass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Took $count of the same classes',
      one: 'Took the same class',
    );
    return '$_temp0';
  }

  @override
  String peopleReasonSameGym(String gym) {
    return 'Goes to $gym';
  }

  @override
  String get peopleReasonSameTime => 'Trains at the same times';

  @override
  String get peopleRemove => 'Remove';

  @override
  String get peopleRemoveFollower => 'Remove follower';

  @override
  String get peopleRemoveFollowerBody =>
      'They won\'t be notified that you removed them.';

  @override
  String peopleRemoveFollowerTitle(String username) {
    return 'Remove @$username from your followers?';
  }

  @override
  String get peopleRemoveFriend => 'Remove friend';

  @override
  String get peopleRemoveFriendBody =>
      'You\'ll stay followers of each other unless you also unfollow.';

  @override
  String peopleRemoveFriendTitle(String name) {
    return 'Remove $name from your friends?';
  }

  @override
  String get peopleReport => 'Report';

  @override
  String get peopleReportDetails => 'Details (optional)';

  @override
  String get peopleReportReasonHarassment => 'Harassment or bullying';

  @override
  String get peopleReportReasonImpersonation => 'Pretending to be someone else';

  @override
  String get peopleReportReasonInappropriate => 'Inappropriate content';

  @override
  String get peopleReportReasonOther => 'Something else';

  @override
  String get peopleReportReasonSpam => 'Spam';

  @override
  String get peopleReportSend => 'Send report';

  @override
  String get peopleReportSent => 'Thanks. Our team will review your report.';

  @override
  String peopleReportTitle(String username) {
    return 'Report @$username';
  }

  @override
  String get peopleReportWhy => 'Why are you reporting this account?';

  @override
  String get peopleRequested => 'Requested';

  @override
  String get peopleRequestsSubtitle => 'Follow and friend requests';

  @override
  String get peopleRequestsTitle => 'Requests';

  @override
  String get peopleRespond => 'Respond';

  @override
  String get peopleSaved => 'Profile saved';

  @override
  String get peopleSearchHint => 'Search by name or username';

  @override
  String get peopleSearchInList => 'Search';

  @override
  String get peopleSentTab => 'Sent';

  @override
  String get peopleSettingSaved => 'Saved';

  @override
  String get peopleShare => 'Share';

  @override
  String get peopleShareLocation => 'Share my location';

  @override
  String get peopleShowActivity => 'Show activity status';

  @override
  String get peopleShowActivityHint =>
      'People you\'re connected with can see when you were last active.';

  @override
  String get peopleSuggestionsTitle => 'People you may know';

  @override
  String peopleTrainsAt(String gyms) {
    return 'Trains at $gyms';
  }

  @override
  String get peopleUnblock => 'Unblock';

  @override
  String peopleUnblockedSnack(String username) {
    return '@$username unblocked';
  }

  @override
  String get peopleUnfollow => 'Unfollow';

  @override
  String get peopleUnfollowPrivateBody =>
      'This account is private. You\'ll have to request again to see their photos and videos.';

  @override
  String peopleUnfollowTitle(String username) {
    return 'Unfollow @$username?';
  }

  @override
  String get peopleUsernameCopied => 'Username copied';

  @override
  String get peopleUsernameInvalid =>
      '3–30 letters, numbers, dots or underscores';

  @override
  String get peopleUsernameTaken => 'That username is taken';

  @override
  String get peopleViewProfile => 'View profile';

  @override
  String get peopleWhoCanMessage => 'Who can message me';

  @override
  String get peopleWhoCanMessageHint =>
      'Messages from anyone else land in your message requests.';

  @override
  String get peopleWhoEveryone => 'Everyone';

  @override
  String get peopleWhoFollowing => 'People I follow';

  @override
  String get peopleWhoFriends => 'Friends';

  @override
  String get reactionAngry => 'Angry';

  @override
  String get reactionCelebrate => 'Celebrate';

  @override
  String get reactionClap => 'Clap';

  @override
  String reactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reactions',
      one: '1 reaction',
    );
    return '$_temp0';
  }

  @override
  String get reactionFire => 'Fire';

  @override
  String get reactionHaha => 'Haha';

  @override
  String get reactionLike => 'Like';

  @override
  String get reactionLove => 'Love';

  @override
  String get reactionPickerHint => 'Hold to pick a reaction';

  @override
  String get reactionSad => 'Sad';

  @override
  String get reactionStrong => 'Strong';

  @override
  String get reactionWow => 'Wow';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageSerbian => 'Srpski';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get shellActivateAccount => 'Activate account';

  @override
  String get shellActivateInviteIntro =>
      'Enter the 6-digit code from your invite email along with the email address and a password you\'d like to use.';

  @override
  String get shellActivateInviteTitle => 'Activate invite';

  @override
  String get shellAddBusiness => 'Add business';

  @override
  String get shellAddUser => 'Add user';

  @override
  String get shellAdminBusinessesSubtitle => 'Manage gyms & shops';

  @override
  String get shellAdminInvoicesSubtitle => 'View all membership invoices';

  @override
  String get shellAdminPanel => 'Admin panel';

  @override
  String get shellAdminUsersSubtitle => 'Manage all accounts';

  @override
  String get shellAlreadyYourEmail => 'That\'s already your email';

  @override
  String get shellAuthEmail => 'Email';

  @override
  String get shellAuthFirstName => 'First name';

  @override
  String get shellAuthInvalidEmail => 'Enter a valid email';

  @override
  String get shellAuthLastName => 'Last name';

  @override
  String get shellAuthPassword => 'Password';

  @override
  String shellAuthPasswordMin(int count) {
    return 'Minimum $count characters';
  }

  @override
  String get shellAuthUsername => 'Username';

  @override
  String get shellAvatarAdd => 'Add profile photo';

  @override
  String get shellAvatarChange => 'Change profile photo';

  @override
  String get shellChange => 'Change';

  @override
  String get shellChangeEmail => 'Change email';

  @override
  String get shellChangeEmailIntro =>
      'We\'ll send a confirmation link to the new address. Your email changes once you open it.';

  @override
  String get shellChangePassword => 'Change password';

  @override
  String get shellChats => 'Messages';

  @override
  String shellChatsUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Messages, $count unread chats',
      one: 'Messages, 1 unread chat',
    );
    return '$_temp0';
  }

  @override
  String get shellCheckEmailBody =>
      'We sent you a confirmation link. Please verify your email before logging in.';

  @override
  String get shellCheckEmailTitle => 'Check your email';

  @override
  String get shellChooseShop => 'Choose a shop';

  @override
  String get shellClearSearch => 'Clear search';

  @override
  String get shellConfirmNewEmailTitle => 'Confirm your new email';

  @override
  String get shellConfirmNewPassword => 'Confirm new password';

  @override
  String get shellConfirmPassword => 'Confirm password';

  @override
  String get shellContinueWithGoogle => 'Continue with Google';

  @override
  String shellCouldNotOpenUrl(String url) {
    return 'Could not open $url';
  }

  @override
  String get shellCreateAccount => 'Create account';

  @override
  String get shellCreateUser => 'Create user';

  @override
  String get shellCurrentPassword => 'Current password';

  @override
  String get shellDeleteAccount => 'Delete account';

  @override
  String get shellDeleteAccountFailed => 'Couldn\'t delete account';

  @override
  String get shellDeleteAccountMessage =>
      'This permanently deletes your account, memberships and billing history. This cannot be undone.';

  @override
  String get shellDeleteAccountSubtitle => 'Permanently remove your account';

  @override
  String get shellDeleteAccountTitle => 'Delete account?';

  @override
  String get shellDeleteConfirmWord => 'DELETE';

  @override
  String shellDeleteUserMessage(String name) {
    return 'This permanently deletes $name\'s account, memberships and billing history. This cannot be undone.';
  }

  @override
  String shellDeleteUserTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String shellEditBusiness(String name) {
    return 'Edit $name';
  }

  @override
  String shellEditUser(String name) {
    return 'Edit $name';
  }

  @override
  String get shellEditUserTitle => 'Edit user';

  @override
  String get shellForgotPasswordIntro =>
      'Enter your email and we\'ll send you a link to reset your password.';

  @override
  String get shellForgotPasswordLink => 'Forgot password?';

  @override
  String get shellForgotPasswordTitle => 'Forgot password';

  @override
  String get shellGoToLogin => 'Go to login';

  @override
  String get shellGoogleFailed => 'Google sign-in failed';

  @override
  String get shellGoogleNoIdToken => 'Google did not return an ID token';

  @override
  String get shellGoogleNotSupported =>
      'Google sign-in is not supported on this device';

  @override
  String get shellGyms => 'Gyms';

  @override
  String get shellHaveAccountLogIn => 'Already have an account? Log in';

  @override
  String get shellHaveInviteCode => 'Have an invite code?';

  @override
  String shellHello(String name) {
    return 'Hello, $name';
  }

  @override
  String shellHey(String name) {
    return 'Hey, $name!';
  }

  @override
  String get shellHidePassword => 'Hide password';

  @override
  String get shellHidePasswords => 'Hide passwords';

  @override
  String get shellHomeBackToLogin => 'Back to login';

  @override
  String get shellHomeLogOut => 'Log out';

  @override
  String get shellHomeNotifications => 'Notifications';

  @override
  String shellHomeNotificationsUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Notifications, $count unread',
      one: 'Notifications, 1 unread',
    );
    return '$_temp0';
  }

  @override
  String get shellHomeProfileLoadFailed => 'Could not load profile';

  @override
  String get shellHomeReturnToAdmin => 'Return to admin';

  @override
  String shellHomeViewingAs(String name) {
    return 'Viewing as $name';
  }

  @override
  String get shellHubCheckIn => 'Check in';

  @override
  String get shellHubCheckInSubtitle => 'Show your code at the front desk';

  @override
  String get shellHubClassesSubtitle => 'Browse and book group classes';

  @override
  String get shellHubCommunity => 'Community';

  @override
  String shellHubCommunityOpenFailed(String error) {
    return 'Couldn\'t open community: $error';
  }

  @override
  String get shellHubCommunitySubtitle =>
      'Posts and announcements from your gym';

  @override
  String get shellHubExercises => 'Exercises';

  @override
  String get shellHubExercisesSubtitle => 'Browse and manage exercises';

  @override
  String get shellHubFoodDiary => 'Food diary';

  @override
  String get shellHubFoodDiarySubtitle => 'Log meals and track macros';

  @override
  String get shellHubMealPlans => 'Meal plans';

  @override
  String get shellHubMealPlansSubtitle => 'Food, recipes and nutrition';

  @override
  String get shellHubNotLinked => 'You\'re not linked to a gym or shop yet';

  @override
  String get shellHubProgress => 'Progress';

  @override
  String get shellHubSessions => 'Sessions';

  @override
  String get shellHubSessionsSubtitle => 'Log and review your sessions';

  @override
  String get shellHubStore => 'Store';

  @override
  String get shellHubStoreSubtitle => 'Supplements, gear and your orders';

  @override
  String get shellHubWorkouts => 'Workouts';

  @override
  String get shellHubWorkoutsSubtitle => 'Trainings and routines';

  @override
  String get shellImageAddPhoto => 'Add photo';

  @override
  String get shellImageChange => 'Change photo';

  @override
  String get shellImageChooseFromGallery => 'Choose from gallery';

  @override
  String get shellImageTakePhoto => 'Take a photo';

  @override
  String shellImageUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get shellImageUploading => 'Uploading photo';

  @override
  String shellImpersonateBody(String email) {
    return 'You\'ll see the app exactly as $email does and can act on their behalf. This is recorded in the audit log. Use \"Return to admin\" (or log out) to get back to your account.';
  }

  @override
  String get shellImpersonateConfirm => 'Sign in as user';

  @override
  String shellImpersonateTitle(String name) {
    return 'Sign in as $name?';
  }

  @override
  String get shellInvitationTitle => 'Invitation';

  @override
  String shellInviteAccept(String entity) {
    return 'Accept — join $entity';
  }

  @override
  String get shellInviteAccepted => 'Accepted';

  @override
  String shellInviteBody(String entity, String role) {
    return 'You have been invited to work at $entity as $role.';
  }

  @override
  String get shellInviteCode => 'Invite code';

  @override
  String get shellInviteCodeHint => '6-digit code';

  @override
  String get shellInviteCodeInvalid => 'Enter the 6-digit code';

  @override
  String get shellInviteDecline => 'Decline';

  @override
  String get shellInviteDeclined => 'You declined this invitation';

  @override
  String get shellInviteDeclinedChip => 'Declined';

  @override
  String shellInviteJoined(String entity, String role) {
    return 'You joined $entity as $role';
  }

  @override
  String get shellInviteOrganisationFallback => 'the organisation';

  @override
  String get shellInvitePending => 'Pending response';

  @override
  String get shellInvoices => 'Invoices';

  @override
  String get shellLoadMore => 'Load more';

  @override
  String get shellLogIn => 'Log in';

  @override
  String get shellLogInInstead => 'Log in instead';

  @override
  String get shellMarkAllRead => 'Mark all read';

  @override
  String shellMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get shellMembersYouCoach => 'Members you coach';

  @override
  String get shellMembershipActive => 'Active';

  @override
  String get shellMembershipLoadFailed => 'Couldn\'t load your membership';

  @override
  String shellMembershipValidUntil(String type, String date) {
    return '$type · valid until $date';
  }

  @override
  String get shellMuteBilling => 'Billing';

  @override
  String get shellMuteBillingDescription =>
      'Invoices, payments and expiring memberships';

  @override
  String get shellMuteClasses => 'Classes';

  @override
  String get shellMuteClassesDescription =>
      'Class reminders, changes and cancellations';

  @override
  String get shellMuteCoaching => 'Coaching';

  @override
  String get shellMuteCoachingDescription =>
      'Assigned routines and plans, session feedback';

  @override
  String get shellMuteCommunity => 'Community';

  @override
  String get shellMuteCommunityDescription =>
      'Gym news, comments, replies and reactions to your posts';

  @override
  String get shellMuteFootnote =>
      'Invites always come through. Muted notifications still appear in the app.';

  @override
  String get shellMuteMessages => 'Messages';

  @override
  String get shellMuteMessagesDescription =>
      'New chat messages and being added to groups';

  @override
  String get shellMuteShop => 'Shop';

  @override
  String get shellMuteShopDescription =>
      'Order updates, new orders and restocks';

  @override
  String get shellMuteSocial => 'Followers & friends';

  @override
  String get shellMuteSocialDescription =>
      'New followers, follow and friend requests';

  @override
  String get shellMuteStaff => 'Staff';

  @override
  String get shellMuteStaffDescription =>
      'Shifts and people joining your business';

  @override
  String get shellMyMembership => 'My membership';

  @override
  String get shellMyOrders => 'My orders';

  @override
  String get shellMyOrdersSubtitle => 'Shop orders and pickups';

  @override
  String get shellMyProgress => 'My progress';

  @override
  String get shellMyProgressSubtitle => 'Lifts, body weight and streaks';

  @override
  String get shellNewEmail => 'New email';

  @override
  String get shellNewPassword => 'New password';

  @override
  String get shellNewUserTitle => 'New user';

  @override
  String get shellNoAccountSignUp => 'Don\'t have an account? Sign up';

  @override
  String get shellNoActiveMembership => 'No active membership';

  @override
  String get shellNoBusinesses => 'No businesses yet';

  @override
  String get shellNoCoachedMembers => 'No members at the gyms you coach at yet';

  @override
  String shellNoLongerMember(String name) {
    return '$name is no longer a member';
  }

  @override
  String shellNoMembersMatch(String query) {
    return 'No members match \"$query\"';
  }

  @override
  String get shellNoNotifications => 'No notifications yet';

  @override
  String get shellNoSessionsToday => 'No sessions with you today';

  @override
  String get shellNoUsers => 'No users yet';

  @override
  String get shellNoUsersFound => 'No users found';

  @override
  String get shellNoneScheduled => 'None scheduled';

  @override
  String get shellNotAVendor => 'You\'re not a vendor at any shop yet';

  @override
  String get shellNotAssignedToGym => 'Not assigned to any gym yet';

  @override
  String get shellNotificationUnread => 'Unread';

  @override
  String get shellOffline => 'You\'re offline — showing saved data';

  @override
  String shellOfflinePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You\'re offline — showing saved data · $count changes waiting to sync',
      one: 'You\'re offline — showing saved data · 1 change waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get shellOr => 'or';

  @override
  String shellOrdersForShop(String shop) {
    return 'Orders · $shop';
  }

  @override
  String get shellOwnerAllInvoices => 'All invoices';

  @override
  String get shellOwnerNoGyms =>
      'You don\'t own any gyms yet — add one from the Businesses tab.';

  @override
  String get shellPasswordChanged => 'Password changed';

  @override
  String get shellPasswordsDontMatch => 'Passwords do not match';

  @override
  String get shellPlatformOverview => 'Platform overview';

  @override
  String get shellProfileUpdated => 'Profile updated';

  @override
  String get shellPushChannelDescription =>
      'Class reminders, orders, memberships and messages';

  @override
  String get shellPushNotifications => 'Push notifications';

  @override
  String get shellPushNotificationsSubtitle => 'Alerts on this phone';

  @override
  String get shellPushUnavailable =>
      'Push notifications aren\'t available in this build. You\'ll still find everything under the bell icon; these choices apply on devices that support push.';

  @override
  String shellResetLinkSent(String email) {
    return 'We sent a password reset link to $email.';
  }

  @override
  String get shellResetPasswordIntro =>
      'Enter a new password for your account.';

  @override
  String get shellResetPasswordTitle => 'Reset password';

  @override
  String get shellRole => 'Role';

  @override
  String get shellRoleEmployee => 'Employee';

  @override
  String get shellRoleEmployeeTrainer => 'Employee / Trainer';

  @override
  String get shellRoleEmployeeTrainerShort => 'Emp. trainer';

  @override
  String get shellRoleGymOwner => 'Gym owner';

  @override
  String get shellRoleMember => 'Member';

  @override
  String get shellRoleOwner => 'Owner';

  @override
  String get shellRoleShopOwner => 'Shop owner';

  @override
  String get shellRoleShopVendor => 'Shop vendor';

  @override
  String get shellRoleSuperUser => 'Super user';

  @override
  String get shellRoleTrainer => 'Trainer';

  @override
  String get shellRoleVendor => 'Vendor';

  @override
  String get shellSaveChanges => 'Save changes';

  @override
  String get shellScanCheckIns => 'Scan check-ins';

  @override
  String get shellSearchMembers => 'Search members';

  @override
  String get shellSendLink => 'Send link';

  @override
  String get shellSendMePushesAbout => 'Send me pushes about';

  @override
  String get shellSendResetLink => 'Send reset link';

  @override
  String get shellSessionInProgress => 'Session in progress';

  @override
  String shellSessionStartedInProgress(String time) {
    return 'Started $time · in progress';
  }

  @override
  String get shellSetNewPassword => 'Set new password';

  @override
  String get shellSettings => 'Settings';

  @override
  String get shellSettingsAccount => 'Account';

  @override
  String get shellSettingsAppearance => 'Appearance';

  @override
  String shellSettingsSaveFailed(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String get shellSettingsSubtitle => 'Theme, units, notifications, account';

  @override
  String get shellSettingsTheme => 'Theme';

  @override
  String get shellSettingsUnits => 'Units';

  @override
  String get shellSettingsWeight => 'Weight';

  @override
  String get shellShops => 'Shops';

  @override
  String get shellShowMore => 'Show more';

  @override
  String get shellShowPassword => 'Show password';

  @override
  String get shellShowPasswords => 'Show passwords';

  @override
  String get shellSignInAsThisUser => 'Sign in as this user';

  @override
  String get shellSignUp => 'Sign up';

  @override
  String get shellSignupEmailTaken =>
      'An account with this email already exists.';

  @override
  String get shellSignupEnterCode => 'Enter code';

  @override
  String shellSignupPendingInviteBody(String email) {
    return 'An account for $email was already created by an invite. We\'ve re-sent the invite email — enter the 6-digit code from it to activate your account.';
  }

  @override
  String get shellSignupPendingInviteTitle => 'You have a pending invite';

  @override
  String get shellStatsActiveMemberships => 'Active memberships';

  @override
  String shellStatsEndsInDays(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'in $days days ($date)',
      one: 'in 1 day ($date)',
    );
    return '$_temp0';
  }

  @override
  String shellStatsEndsOn(String gym, String when) {
    return '$gym · ends $when';
  }

  @override
  String get shellStatsEndsToday => 'today';

  @override
  String get shellStatsEndsTomorrow => 'tomorrow';

  @override
  String get shellStatsExpiringSoon => 'Expiring soon';

  @override
  String shellStatsGymCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gyms',
      one: '1 gym',
    );
    return '$_temp0';
  }

  @override
  String get shellStatsInvoicesThisMonth => 'Invoices this month';

  @override
  String get shellStatsMembers => 'Members';

  @override
  String get shellStatsNext14Days => 'next 14 days';

  @override
  String get shellStatsNoneExpiring =>
      'No memberships expiring in the next two weeks';

  @override
  String get shellStatsStaff => 'Staff';

  @override
  String get shellStatsUnpaidInvoices => 'Unpaid invoices';

  @override
  String get shellTabBusinesses => 'Businesses';

  @override
  String get shellTabClasses => 'Classes';

  @override
  String get shellTabDiscover => 'Discover';

  @override
  String get shellTabFeed => 'Feed';

  @override
  String get shellTabGym => 'Gym';

  @override
  String get shellTabHome => 'Home';

  @override
  String get shellTabMembers => 'Members';

  @override
  String get shellTabMembership => 'Membership';

  @override
  String get shellTabMyShop => 'My Shop';

  @override
  String get shellTabProfile => 'Profile';

  @override
  String get shellTabSchedule => 'Schedule';

  @override
  String get shellTabUsers => 'Users';

  @override
  String get shellThemeDark => 'Dark';

  @override
  String get shellThemeLight => 'Light';

  @override
  String get shellThemeSystem => 'System';

  @override
  String shellTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String shellTimeDaysShort(int count) {
    return '${count}d';
  }

  @override
  String shellTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String shellTimeHoursShort(int count) {
    return '${count}h';
  }

  @override
  String shellTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String shellTimeMinutesShort(int count) {
    return '${count}m';
  }

  @override
  String get shellTimeNow => 'now';

  @override
  String get shellTodaysSessions => 'Today\'s sessions';

  @override
  String shellTypeToConfirm(String text) {
    return 'Type $text to confirm.';
  }

  @override
  String get shellUnavailable => 'Unavailable';

  @override
  String get shellUnitKilograms => 'Kilograms';

  @override
  String get shellUnitPounds => 'Pounds';

  @override
  String get shellUpcomingClasses => 'Upcoming classes';

  @override
  String get shellUserSearchAdd => 'Add';

  @override
  String shellUserSearchAddLabel(String name) {
    return 'Add $name';
  }

  @override
  String get shellUserSearchAdding => 'Adding';

  @override
  String get shellUserSearchHint => 'Search by name or username';

  @override
  String shellWelcome(String name) {
    return 'Welcome, $name';
  }

  @override
  String shellWelcomeBack(String name) {
    return 'Welcome back, $name';
  }

  @override
  String get shellYourGym => 'Your gym';

  @override
  String get shellYourGyms => 'Your gyms';

  @override
  String get shellYourShop => 'Your shop';

  @override
  String get shellYourShops => 'Your shops';

  @override
  String socialActiveAgo(String when) {
    return 'Active $when';
  }

  @override
  String get socialActiveNow => 'Active now';

  @override
  String get socialCamera => 'Camera';

  @override
  String get socialFile => 'File';

  @override
  String get socialFileTooLarge => 'Files are limited to 50 MB.';

  @override
  String get socialGallery => 'Photos & videos';

  @override
  String get socialRecordVideo => 'Record video';

  @override
  String get socialRetry => 'Retry';

  @override
  String get socialTakePhoto => 'Take photo';

  @override
  String socialTyping(String name) {
    return '$name is typing…';
  }

  @override
  String get socialTypingSeveral => 'Several people are typing…';

  @override
  String get socialUploadFailed => 'Upload failed. Try again.';

  @override
  String get trainingAssignAction => 'Assign';

  @override
  String trainingAssignAssignedOn(String date) {
    return 'Assigned $date';
  }

  @override
  String get trainingAssignClearDates => 'Clear dates';

  @override
  String trainingAssignConfirm(String routine, String name) {
    return 'Assign \"$routine\" to $name?';
  }

  @override
  String trainingAssignConfirmSelf(String routine) {
    return 'Assign \"$routine\" to yourself?';
  }

  @override
  String get trainingAssignDialogTitle => 'Assign routine';

  @override
  String trainingAssignDone(String routine, String name) {
    return '\"$routine\" assigned to $name';
  }

  @override
  String trainingAssignDoneSelf(String routine) {
    return '\"$routine\" assigned to you';
  }

  @override
  String get trainingAssignEnd => 'End';

  @override
  String trainingAssignEnds(String date) {
    return 'Ends $date';
  }

  @override
  String get trainingAssignNoRoutines => 'No routines found';

  @override
  String get trainingAssignNoteHint => 'e.g. Focus on form, 3 sessions a week';

  @override
  String get trainingAssignNoteLabel => 'Note (optional)';

  @override
  String trainingAssignPickerTitle(String routine) {
    return 'Assign \"$routine\" to…';
  }

  @override
  String get trainingAssignRemoveAction => 'Remove';

  @override
  String trainingAssignRemoveBody(String routine) {
    return '\"$routine\" will no longer be assigned.';
  }

  @override
  String trainingAssignRemoveBodyUser(String routine, String name) {
    return '\"$routine\" will no longer be assigned to $name.';
  }

  @override
  String get trainingAssignRemoveTitle => 'Remove assignment?';

  @override
  String get trainingAssignRemoveTooltip => 'Remove assignment';

  @override
  String get trainingAssignSearchRoutinesHint => 'Search routines…';

  @override
  String get trainingAssignStart => 'Start';

  @override
  String trainingAssignStarts(String date) {
    return 'Starts $date';
  }

  @override
  String get trainingBookingAttended => 'Attended';

  @override
  String get trainingBookingBooked => 'Booked';

  @override
  String get trainingBookingCancelled => 'Cancelled';

  @override
  String get trainingBookingNoShow => 'No-show';

  @override
  String get trainingBookingWaitlisted => 'Waitlisted';

  @override
  String get trainingChartDefaultSeries => 'Progress';

  @override
  String get trainingChartNoData => 'No data in this range';

  @override
  String trainingChartSummary(String series, String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count data points',
      one: '1 data point',
    );
    return '$series chart, $_temp0, last value $value';
  }

  @override
  String get trainingClassAbout => 'About';

  @override
  String get trainingClassApplyToSeries => 'Apply to this and future classes';

  @override
  String get trainingClassApplyToSeriesOff => 'Only this class changes';

  @override
  String get trainingClassApplyToSeriesOn =>
      'Changes apply to every later class in this weekly series';

  @override
  String trainingClassAttendedOf(int attended, int total) {
    return '$attended/$total attended';
  }

  @override
  String get trainingClassAttendedUndo => 'Attended (tap to undo)';

  @override
  String get trainingClassBook => 'Book';

  @override
  String trainingClassBookedAt(String when) {
    return 'Booked $when';
  }

  @override
  String trainingClassBookedFor(String title) {
    return 'You\'re booked for $title';
  }

  @override
  String trainingClassBookedOf(int booked, int capacity) {
    return '$booked/$capacity booked';
  }

  @override
  String get trainingClassBookingCancelled => 'Booking cancelled';

  @override
  String get trainingClassBrowse => 'Browse classes';

  @override
  String get trainingClassCancelBooking => 'Cancel booking';

  @override
  String trainingClassCancelBookingMessage(String title) {
    return 'Your spot in $title will be given to the next person on the waitlist.';
  }

  @override
  String get trainingClassCancelBookingQuestion => 'Cancel booking?';

  @override
  String get trainingClassCancelClass => 'Cancel class';

  @override
  String trainingClassCancelNotifyPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people booked or waitlisted will be notified.',
      one: '1 person booked or waitlisted will be notified.',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassCancelQuestion => 'Cancel class?';

  @override
  String get trainingClassCancelThisAndFuture =>
      'Cancel this and future classes';

  @override
  String get trainingClassCancelThisOnly => 'Cancel this class only';

  @override
  String get trainingClassCancelled => 'Cancelled';

  @override
  String get trainingClassCapacity => 'Capacity';

  @override
  String trainingClassCapacityBelowBooked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people are already booked',
      one: '1 person is already booked',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassCapacityHelper => 'Extra people join a waitlist';

  @override
  String get trainingClassCapacityMax => 'That\'s a lot of people — 500 max';

  @override
  String get trainingClassCapacityMin => 'Enter at least 1';

  @override
  String get trainingClassClassCancelled => 'Class cancelled';

  @override
  String get trainingClassClasses => 'Classes';

  @override
  String get trainingClassClassesCancelled => 'Classes cancelled';

  @override
  String trainingClassCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count classes',
      one: '1 class',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassCreate => 'Create class';

  @override
  String get trainingClassCreateOne => 'Create a class';

  @override
  String get trainingClassCreated => 'Class created';

  @override
  String get trainingClassCurrentTrainer => 'Current trainer';

  @override
  String get trainingClassDescriptionOptional => 'Description (optional)';

  @override
  String get trainingClassDuration => 'Duration';

  @override
  String get trainingClassEdit => 'Edit class';

  @override
  String get trainingClassEnded => 'This class has ended.';

  @override
  String trainingClassEndsAt(String time) {
    return 'Ends at $time';
  }

  @override
  String get trainingClassFull => 'Full';

  @override
  String trainingClassFullWaiting(int count) {
    return 'Full · $count waiting';
  }

  @override
  String get trainingClassGym => 'Gym';

  @override
  String get trainingClassInProgress => 'This class is in progress.';

  @override
  String get trainingClassJoinWaitlist => 'Join waitlist';

  @override
  String get trainingClassJumpToNext => 'Jump to next class';

  @override
  String get trainingClassKeep => 'Keep';

  @override
  String get trainingClassKeepClass => 'Keep class';

  @override
  String get trainingClassLeaveWaitlist => 'Leave waitlist';

  @override
  String trainingClassLeaveWaitlistMessage(String title) {
    return 'You\'ll lose your place in line for $title.';
  }

  @override
  String get trainingClassLeaveWaitlistQuestion => 'Leave waitlist?';

  @override
  String get trainingClassLocationHint => 'e.g. Studio A';

  @override
  String get trainingClassLocationOptional => 'Location (optional)';

  @override
  String get trainingClassMarkAttended => 'Mark attended';

  @override
  String get trainingClassMarkNoShow => 'Mark no-show';

  @override
  String get trainingClassMember => 'Member';

  @override
  String get trainingClassMore => 'More';

  @override
  String get trainingClassMyBookings => 'My bookings';

  @override
  String trainingClassMyBookingsCount(int count) {
    return 'My bookings ($count)';
  }

  @override
  String get trainingClassMyClasses => 'My classes';

  @override
  String trainingClassNameYou(String name) {
    return '$name (you)';
  }

  @override
  String get trainingClassNew => 'New class';

  @override
  String trainingClassNextClass(String title, String day, String time) {
    return 'Next class: $title, $day at $time.';
  }

  @override
  String get trainingClassNoBookings => 'No bookings yet';

  @override
  String get trainingClassNoBookingsMessage =>
      'Classes you book or join the waitlist for show up here.';

  @override
  String get trainingClassNoBookingsYet => 'No one has booked yet';

  @override
  String get trainingClassNoGyms => 'No gyms to schedule at';

  @override
  String get trainingClassNoGymsMessage =>
      'You can create classes at gyms where you are a trainer, staff member or owner.';

  @override
  String get trainingClassNoPast => 'No past classes';

  @override
  String trainingClassNoPastMessage(int days) {
    return 'Classes you taught in the last $days days show up here.';
  }

  @override
  String get trainingClassNoShowUndo => 'No-show (tap to undo)';

  @override
  String get trainingClassNoTrainer => 'No trainer';

  @override
  String get trainingClassNoUpcoming => 'No upcoming classes';

  @override
  String get trainingClassNoUpcomingMessage =>
      'Schedule a one-off class or a weekly series and members can book it.';

  @override
  String get trainingClassNobodyBooked => 'Nobody has booked yet.';

  @override
  String get trainingClassNoneScheduled => 'No classes scheduled';

  @override
  String get trainingClassNoneScheduledMessage =>
      'Your gyms haven\'t scheduled any classes for the next two weeks. Check back soon.';

  @override
  String get trainingClassNoneThisWeek => 'No classes this week';

  @override
  String get trainingClassNoneThisWeekCreate =>
      'Create a class or a weekly series for members to book.';

  @override
  String get trainingClassNoneThisWeekMessage =>
      'Nothing has been scheduled for this week yet.';

  @override
  String get trainingClassNotSignedIn => 'Not signed in';

  @override
  String trainingClassNothingOn(String day) {
    return 'Nothing on $day';
  }

  @override
  String get trainingClassNotifyOnChange =>
      'People who booked are notified if the time or location changes.';

  @override
  String get trainingClassOneOff => 'One-off class';

  @override
  String get trainingClassPast => 'Past';

  @override
  String get trainingClassRefresh => 'Refresh';

  @override
  String get trainingClassRemove => 'Remove';

  @override
  String get trainingClassRemoveBookedMessage =>
      'Their spot will go to the next person on the waitlist.';

  @override
  String get trainingClassRemoveFromClass => 'Remove from class';

  @override
  String trainingClassRemoveQuestion(String name) {
    return 'Remove $name?';
  }

  @override
  String get trainingClassRemoveWaitlistMessage =>
      'They\'ll be taken off the waitlist.';

  @override
  String trainingClassRepeatSummary(String weekday, int weeks) {
    return 'Every $weekday for $weeks weeks';
  }

  @override
  String get trainingClassRepeatWeekly => 'Repeat weekly';

  @override
  String get trainingClassRoster => 'Roster';

  @override
  String get trainingClassSaveChanges => 'Save changes';

  @override
  String get trainingClassSpots => 'Spots';

  @override
  String trainingClassSpotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots left',
      one: '1 spot left',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassStartInFuture => 'Pick a start time in the future';

  @override
  String get trainingClassTitle => 'Class';

  @override
  String get trainingClassTitleHint => 'e.g. Morning HIIT';

  @override
  String get trainingClassTitleLabel => 'Title';

  @override
  String get trainingClassTitleRequired => 'Give the class a title';

  @override
  String get trainingClassUpcoming => 'Upcoming';

  @override
  String trainingClassUpcomingCount(int count) {
    return 'Upcoming ($count)';
  }

  @override
  String get trainingClassUpdated => 'Class updated';

  @override
  String trainingClassWaitlistCount(int count) {
    return 'Waitlist ($count)';
  }

  @override
  String trainingClassWaitlistJoined(int position) {
    return 'Class is full. You\'re #$position on the waitlist.';
  }

  @override
  String get trainingClassWaitlistJoinedNoPosition =>
      'Class is full. You\'re on the waitlist.';

  @override
  String trainingClassWaitlistPosition(int position) {
    return '#$position on the waitlist';
  }

  @override
  String trainingClassWaitlistedPosition(int position) {
    return 'Waitlisted #$position';
  }

  @override
  String get trainingClassWasCancelled => 'This class was cancelled';

  @override
  String get trainingClassWeekly => 'Weekly class';

  @override
  String trainingClassWeeklyCreated(int count) {
    return '$count weekly classes created';
  }

  @override
  String get trainingClassWeeklySeries => 'Part of a weekly series';

  @override
  String get trainingClassWeeks => 'Weeks';

  @override
  String trainingClassWeeksValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassWhen => 'When';

  @override
  String get trainingClassYou => 'You';

  @override
  String get trainingCoachChooseMember => 'Choose a member';

  @override
  String get trainingCoachMyself => 'Myself';

  @override
  String get trainingCoachNoMatches => 'No members match your search';

  @override
  String get trainingCoachNoMembers =>
      'No members to coach yet. Members of gyms where you work or train show up here.';

  @override
  String get trainingCoachNotSignedIn => 'Not signed in';

  @override
  String get trainingCoachSearchHint => 'Search members…';

  @override
  String get trainingCoachYou => 'you';

  @override
  String trainingDropCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drops',
      one: '1 drop',
    );
    return '$_temp0';
  }

  @override
  String get trainingExerciseAddPhoto => 'Add exercise photo';

  @override
  String get trainingExerciseAllMuscles => 'All muscles';

  @override
  String trainingExerciseAlternating(String name) {
    return '$name (alternating)';
  }

  @override
  String get trainingExerciseClearFilter => 'Clear filter';

  @override
  String get trainingExerciseDeleteTitle => 'Delete exercise?';

  @override
  String get trainingExerciseDone => 'Done';

  @override
  String get trainingExerciseEditTitle => 'Edit Exercise';

  @override
  String get trainingExerciseFallbackName => 'Exercise';

  @override
  String trainingExerciseFilterActiveTooltip(String muscle) {
    return 'Filter by muscle (current: $muscle)';
  }

  @override
  String get trainingExerciseFilterTitle => 'Filter by Muscle';

  @override
  String get trainingExerciseFilterTooltip => 'Filter by muscle';

  @override
  String get trainingExerciseMyPrivate => 'My private';

  @override
  String get trainingExerciseNameLabel => 'Exercise name *';

  @override
  String get trainingExerciseNewTitle => 'New Exercise';

  @override
  String get trainingExerciseNoPrivate => 'You have no private exercises';

  @override
  String get trainingExerciseNoneFound => 'No exercises found';

  @override
  String trainingExercisePhoto(String name) {
    return 'Photo of $name';
  }

  @override
  String get trainingExercisePrimaryMuscles => 'Primary Muscles';

  @override
  String get trainingExerciseSearchHint => 'Search exercises…';

  @override
  String get trainingExerciseSecondaryMuscles => 'Secondary Muscles';

  @override
  String get trainingExerciseTapToSelect => 'Tap to select';

  @override
  String get trainingExerciseTargetMuscles => 'Target Muscles';

  @override
  String get trainingExerciseTitle => 'Exercises';

  @override
  String get trainingExerciseVideo => 'Video';

  @override
  String get trainingExerciseVideoUrl => 'Video URL';

  @override
  String get trainingLogBodyweightHint => 'Blank = bodyweight';

  @override
  String get trainingLogChooseExercise => 'Tap to choose an exercise';

  @override
  String trainingLogCouldNotLogSet(String error) {
    return 'Could not log set: $error';
  }

  @override
  String get trainingLogCouldNotStart => 'Could not start';

  @override
  String trainingLogElapsed(String time) {
    return 'Elapsed time $time';
  }

  @override
  String get trainingLogEnterReps => 'Enter the number of reps';

  @override
  String trainingLogEstimated1rm(String weight) {
    return 'Estimated 1RM ≈ $weight';
  }

  @override
  String get trainingLogExercise => 'Exercise';

  @override
  String get trainingLogFinish => 'Finish';

  @override
  String get trainingLogFinishMessage =>
      'This will record the end time of your workout.';

  @override
  String get trainingLogFinishMessageOffline =>
      'This will record the end time of your workout. Sets saved offline will sync when you\'re back online.';

  @override
  String get trainingLogFinishTitle => 'Finish session?';

  @override
  String get trainingLogFirstSetHint => 'Tap below to log your first set';

  @override
  String get trainingLogKeepGoing => 'Keep going';

  @override
  String get trainingLogLog => 'Log';

  @override
  String get trainingLogLogASet => 'Log a Set';

  @override
  String get trainingLogLogSet => 'Log Set';

  @override
  String get trainingLogLogged => 'Logged';

  @override
  String trainingLogNewPr(String exercise) {
    return 'New PR! $exercise';
  }

  @override
  String get trainingLogNewPrShort => 'New PR';

  @override
  String trainingLogNewPrWithE1rm(String exercise, String weight) {
    return 'New PR! $exercise — e1RM $weight';
  }

  @override
  String get trainingLogOfflineSaved =>
      'Saved offline — will sync when you\'re back online';

  @override
  String get trainingLogPending => 'Pending';

  @override
  String get trainingLogPendingSync => 'Pending sync';

  @override
  String get trainingLogPickExercise => 'Pick an exercise first';

  @override
  String get trainingLogPlateTooltip => 'Plate calculator & warm-up';

  @override
  String get trainingLogRepType => 'Rep type';

  @override
  String get trainingLogSavedOfflineTooltip => 'Saved offline — will sync';

  @override
  String trainingLogSetHeader(int number, String type) {
    return 'Set $number · $type';
  }

  @override
  String trainingLogSetHeaderWithRest(int number, String type, String rest) {
    return 'Set $number · $type · rest $rest';
  }

  @override
  String get trainingLogStartRest => 'Start rest timer';

  @override
  String get trainingLogStarting => 'Starting session…';

  @override
  String get trainingLogWeight => 'Weight';

  @override
  String get trainingMeasureAdd => 'Add';

  @override
  String get trainingMeasureBodyFatOptional => 'Body fat (optional)';

  @override
  String trainingMeasureBodyFatValue(String value) {
    return '$value % fat';
  }

  @override
  String get trainingMeasureBodyWeight => 'Body weight';

  @override
  String trainingMeasureChangeSince(String change, String date) {
    return '$change since $date';
  }

  @override
  String trainingMeasureDateLabel(String date) {
    return 'Date: $date';
  }

  @override
  String trainingMeasureDeleteMessage(String date) {
    return 'The entry from $date will be removed.';
  }

  @override
  String get trainingMeasureDeleteTitle => 'Delete measurement?';

  @override
  String get trainingMeasureDeleteTooltip => 'Delete measurement';

  @override
  String get trainingMeasureEditTitle => 'Edit measurement';

  @override
  String get trainingMeasureEmptyMessageOther => 'Nothing logged yet.';

  @override
  String get trainingMeasureEmptyMessageOwn =>
      'Log your body weight regularly to see your trend here.';

  @override
  String get trainingMeasureEmptyTitle => 'No measurements yet';

  @override
  String get trainingMeasureInvalidNumbers => 'Enter valid numbers';

  @override
  String get trainingMeasureLogAction => 'Log measurement';

  @override
  String get trainingMeasureLogHeading => 'Log';

  @override
  String get trainingMeasureNeedValue => 'Enter a weight or a body-fat value';

  @override
  String get trainingMeasureNoteOptional => 'Note (optional)';

  @override
  String get trainingMemberAssign => 'Assign';

  @override
  String get trainingMemberAssignMealPlan => 'Assign meal plan';

  @override
  String get trainingMemberAssignRoutine => 'Assign routine';

  @override
  String trainingMemberAssignedBy(String name) {
    return 'Assigned by $name';
  }

  @override
  String get trainingMemberAssignedByAnotherCoach =>
      'Assigned by another coach';

  @override
  String get trainingMemberAssignedByYou => 'Assigned by you';

  @override
  String get trainingMemberFoodDiary => 'Food diary';

  @override
  String get trainingMemberFoodDiarySubtitle => 'Meals & macros';

  @override
  String get trainingMemberMealPlans => 'Meal plans';

  @override
  String get trainingMemberNoMealPlans => 'No meal plans assigned';

  @override
  String get trainingMemberNoRoutines => 'No routines assigned';

  @override
  String get trainingMemberNoSessions => 'No training sessions logged yet';

  @override
  String get trainingMemberProgramWorkout => 'Program workout';

  @override
  String get trainingMemberProgressSubtitle => 'PRs, volume, body weight';

  @override
  String get trainingMemberRecentSessions => 'Recent sessions';

  @override
  String get trainingMemberRemove => 'Remove';

  @override
  String trainingMemberRemoveAssignmentMessage(String plan, String member) {
    return '\"$plan\" will no longer be assigned to $member.';
  }

  @override
  String get trainingMemberRemoveAssignmentTitle => 'Remove assignment?';

  @override
  String get trainingMemberRoutines => 'Routines';

  @override
  String get trainingMemberSelfAssigned => 'Self-assigned';

  @override
  String get trainingMuscleAbsLower => 'Lower Abs';

  @override
  String get trainingMuscleAbsObliques => 'Obliques';

  @override
  String get trainingMuscleAbsUpper => 'Upper Abs';

  @override
  String get trainingMuscleBackAll => 'Back';

  @override
  String get trainingMuscleBackLats => 'Lats';

  @override
  String get trainingMuscleBackLower => 'Lower Back';

  @override
  String get trainingMuscleBackMid => 'Mid Back';

  @override
  String get trainingMuscleBackRhomboids => 'Rhomboids';

  @override
  String get trainingMuscleBackTraps => 'Traps';

  @override
  String get trainingMuscleBackUpper => 'Upper Back';

  @override
  String get trainingMuscleBiceps => 'Biceps';

  @override
  String get trainingMuscleCalves => 'Calves';

  @override
  String get trainingMuscleChestAll => 'Chest';

  @override
  String get trainingMuscleChestLower => 'Lower Chest';

  @override
  String get trainingMuscleChestUpper => 'Upper Chest';

  @override
  String get trainingMuscleDeltsAll => 'Deltoids';

  @override
  String get trainingMuscleDeltsFront => 'Front Delt';

  @override
  String get trainingMuscleDeltsMedial => 'Side Delt';

  @override
  String get trainingMuscleDeltsRear => 'Rear Delt';

  @override
  String get trainingMuscleForearmsAll => 'Forearms';

  @override
  String get trainingMuscleForearmsBottom => 'Forearms (Bottom)';

  @override
  String get trainingMuscleForearmsTop => 'Forearms (Top)';

  @override
  String get trainingMuscleGlutesAll => 'Glutes';

  @override
  String get trainingMuscleGlutesMaximus => 'Glute Maximus';

  @override
  String get trainingMuscleGlutesMedius => 'Glute Medius';

  @override
  String get trainingMuscleGlutesMinimus => 'Glute Minimus';

  @override
  String get trainingMuscleHamstrings => 'Hamstrings';

  @override
  String get trainingMuscleMapLabel => 'Muscle diagram';

  @override
  String get trainingMuscleMapLegendSecondary => 'Secondary';

  @override
  String get trainingMuscleMapLegendTarget => 'Target';

  @override
  String get trainingMuscleMapNone => 'No muscles highlighted';

  @override
  String trainingMuscleMapPrimary(String muscles) {
    return 'Primary: $muscles';
  }

  @override
  String trainingMuscleMapSecondary(String muscles) {
    return 'Secondary: $muscles';
  }

  @override
  String get trainingMuscleNeck => 'Neck';

  @override
  String get trainingMuscleQuadsAll => 'Quads';

  @override
  String get trainingMuscleQuadsLateral => 'Lateral Quad';

  @override
  String get trainingMuscleQuadsMedial => 'Medial Quad';

  @override
  String get trainingMuscleTricepsAll => 'Triceps';

  @override
  String get trainingMuscleTricepsLateral => 'Triceps Lateral';

  @override
  String get trainingMuscleTricepsLong => 'Triceps Long Head';

  @override
  String get trainingMuscleTricepsMedial => 'Triceps Medial';

  @override
  String get trainingPlanAddCoverPhoto => 'Add cover photo';

  @override
  String get trainingPlanAddDrop => 'Add Drop';

  @override
  String get trainingPlanAddExerciseToSuperset => 'Add Exercise to Superset';

  @override
  String get trainingPlanAddSet => 'Add Set';

  @override
  String get trainingPlanAlternating => 'Alternating';

  @override
  String get trainingPlanAlternatingShort => 'Alt.';

  @override
  String get trainingPlanCollapse => 'Collapse';

  @override
  String trainingPlanDeleteBody(String name) {
    return 'Remove \"$name\" permanently?';
  }

  @override
  String get trainingPlanDeleteTitle => 'Delete training?';

  @override
  String get trainingPlanDescriptionLabel => 'Description';

  @override
  String trainingPlanDropLine(int number, String details) {
    return 'Drop $number: $details';
  }

  @override
  String trainingPlanDropNumber(int number) {
    return 'Drop $number';
  }

  @override
  String get trainingPlanEditTitle => 'Edit Training';

  @override
  String get trainingPlanExpand => 'Expand';

  @override
  String get trainingPlanMakeDropset => 'Make Dropset';

  @override
  String get trainingPlanMusclesTrained => 'Muscles Trained';

  @override
  String get trainingPlanNameLabel => 'Training name *';

  @override
  String get trainingPlanNotes => 'Notes';

  @override
  String get trainingPlanPickExercise => 'Pick exercise';

  @override
  String get trainingPlanProgramme => 'Programme';

  @override
  String get trainingPlanPublic => 'Public';

  @override
  String get trainingPlanPublicSubtitle => 'Visible to all users';

  @override
  String get trainingPlanRemoveDrop => 'Remove drop';

  @override
  String get trainingPlanRemoveExercise => 'Remove exercise';

  @override
  String get trainingPlanRemoveSet => 'Remove set';

  @override
  String get trainingPlanReorderSet => 'Drag to reorder';

  @override
  String trainingPlanRestSeconds(int seconds) {
    return 'Rest ${seconds}s';
  }

  @override
  String get trainingPlanSelectExercise => 'Select exercise…';

  @override
  String get trainingPlanSets => 'Sets';

  @override
  String get trainingPlanStartSession => 'Start Session';

  @override
  String trainingPlateAvailable(String plates) {
    return 'Plates: $plates';
  }

  @override
  String get trainingPlateBar => 'Bar';

  @override
  String get trainingPlateEachSide => 'Each side';

  @override
  String get trainingPlateEmptyBar => 'Empty bar';

  @override
  String get trainingPlateEnterTarget =>
      'Enter a target weight to see the plates for each side.';

  @override
  String get trainingPlateNoWarmup =>
      'Target is at or below the bar — no warm-up plates needed.';

  @override
  String trainingPlateNotExact(
    String target,
    String closest,
    String difference,
  ) {
    return '$target can\'t be loaded exactly. Closest: $closest ($difference).';
  }

  @override
  String trainingPlatePerSide(String plates) {
    return 'Per side: $plates';
  }

  @override
  String trainingPlateSuggestedRamp(String weight) {
    return 'Suggested ramp to $weight';
  }

  @override
  String get trainingPlateTargetWeight => 'Target weight';

  @override
  String get trainingPlateTitle => 'Plate calculator';

  @override
  String trainingPlateTotal(String weight) {
    return 'Total $weight';
  }

  @override
  String get trainingPlateWarmup => 'Warm-up';

  @override
  String get trainingProgressBestE1rm => 'Best e1RM';

  @override
  String get trainingProgressBestVolume => 'Best volume';

  @override
  String trainingProgressChartE1rm(String unit) {
    return 'Estimated 1-rep max ($unit)';
  }

  @override
  String trainingProgressChartVolume(String unit) {
    return 'Session volume ($unit × reps)';
  }

  @override
  String trainingProgressChartWeight(String unit) {
    return 'Heaviest set ($unit)';
  }

  @override
  String trainingProgressE1rm(String weight) {
    return 'e1RM $weight';
  }

  @override
  String get trainingProgressEmptyMessage =>
      'Log a session and your volume, streak and personal records will show up here.';

  @override
  String get trainingProgressEmptyTitle => 'No training logged yet';

  @override
  String get trainingProgressExercises => 'Exercises';

  @override
  String get trainingProgressFilterExercises => 'Filter exercises…';

  @override
  String get trainingProgressHeaviest => 'Heaviest';

  @override
  String get trainingProgressLast30Days => 'last 30 days';

  @override
  String trainingProgressLastSession(String when) {
    return 'Last session: $when';
  }

  @override
  String get trainingProgressMetricE1rm => 'e1RM';

  @override
  String get trainingProgressMetricVolume => 'Volume';

  @override
  String get trainingProgressMetricWeight => 'Best weight';

  @override
  String get trainingProgressNoData => 'No data';

  @override
  String get trainingProgressNoExercises => 'No exercises logged yet';

  @override
  String get trainingProgressNoExercisesMatch => 'No exercises match';

  @override
  String get trainingProgressNoRecentPrs =>
      'No new personal records in the last 30 days. Beat your best estimated 1RM on any lift to set one.';

  @override
  String get trainingProgressNoSessionsInRange => 'No sessions in this range';

  @override
  String get trainingProgressPersonalRecords => 'Personal records';

  @override
  String get trainingProgressRange1m => '1M';

  @override
  String get trainingProgressRange3m => '3M';

  @override
  String get trainingProgressRange6m => '6M';

  @override
  String get trainingProgressRangeAll => 'All';

  @override
  String get trainingProgressRecentPrs => 'Recent PRs';

  @override
  String trainingProgressRepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reps',
      one: '1 rep',
    );
    return '$_temp0';
  }

  @override
  String get trainingProgressSeriesE1rm => 'Estimated 1RM';

  @override
  String get trainingProgressSeriesVolume => 'Session volume';

  @override
  String get trainingProgressSeriesWeight => 'Heaviest set';

  @override
  String trainingProgressSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String get trainingProgressSessionsHeading => 'Sessions';

  @override
  String trainingProgressSessionsInRange(String range) {
    return 'Sessions ($range)';
  }

  @override
  String get trainingProgressStatSessions30d => 'Sessions · 30 days';

  @override
  String get trainingProgressStatSessions7d => 'Sessions · 7 days';

  @override
  String get trainingProgressStatStreak => 'Weekly streak';

  @override
  String get trainingProgressStatVolume30d => 'Volume · 30 days';

  @override
  String get trainingProgressStreakDone => 'Trained this week';

  @override
  String get trainingProgressStreakKeep => 'Train this week to keep it';

  @override
  String get trainingProgressStreakStart => 'Train this week to start one';

  @override
  String trainingProgressStreakWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wks',
      one: '1 wk',
    );
    return '$_temp0';
  }

  @override
  String get trainingProgressTabBody => 'Body';

  @override
  String get trainingProgressTabTraining => 'Training';

  @override
  String get trainingProgressTitle => 'Progress';

  @override
  String trainingProgressTopWeight(String weight) {
    return 'Top $weight';
  }

  @override
  String trainingProgressTrendSemantics(String value) {
    return 'Trend, last value $value';
  }

  @override
  String get trainingProgressYesterday => 'Yesterday';

  @override
  String get trainingRepFailureShort => 'Failure';

  @override
  String get trainingRepTypeCount => 'Reps';

  @override
  String get trainingRepTypeFailure => 'To Failure';

  @override
  String trainingRepsTimes(int count) {
    return '${count}x';
  }

  @override
  String trainingRestAddSeconds(int seconds) {
    return '+$seconds s';
  }

  @override
  String trainingRestAddSecondsTooltip(int seconds) {
    return 'Add $seconds seconds';
  }

  @override
  String trainingRestPresetTooltip(String time) {
    return 'Rest for $time';
  }

  @override
  String trainingRestRemaining(String time) {
    return '$time of rest remaining';
  }

  @override
  String get trainingRestSkip => 'Skip';

  @override
  String get trainingRestTitle => 'Rest';

  @override
  String get trainingRoutineAdd => 'Add';

  @override
  String get trainingRoutineDayHint => 'Day';

  @override
  String get trainingRoutineDeleteTitle => 'Delete routine?';

  @override
  String get trainingRoutineDeleteTooltip => 'Delete routine';

  @override
  String get trainingRoutineEditTitle => 'Edit Routine';

  @override
  String get trainingRoutineEditTooltip => 'Edit routine';

  @override
  String get trainingRoutineInvalidNumber => 'Enter a valid number';

  @override
  String get trainingRoutineInvalidWeeks => 'Enter a valid number of weeks';

  @override
  String get trainingRoutineMine => 'Mine';

  @override
  String get trainingRoutineNameLabel => 'Routine name *';

  @override
  String get trainingRoutineNoTrainings => 'No trainings assigned yet';

  @override
  String get trainingRoutineNoTrainingsAdded => 'No trainings added yet';

  @override
  String get trainingRoutineNumWeeksHint => 'e.g. 12';

  @override
  String get trainingRoutineNumWeeksLabel => 'Number of weeks *';

  @override
  String get trainingRoutinePrivate => 'Private';

  @override
  String get trainingRoutineRemoveTraining => 'Remove training';

  @override
  String get trainingRoutineRestDay => 'Rest day';

  @override
  String get trainingRoutineSchedule => 'Schedule';

  @override
  String get trainingRoutineScheduleType => 'Schedule Type';

  @override
  String get trainingRoutineSearchTrainingsHint => 'Search trainings…';

  @override
  String trainingRoutineTrainingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trainings',
      one: '1 training',
    );
    return '$_temp0';
  }

  @override
  String get trainingRoutineTrainingFallback => 'Training';

  @override
  String trainingRoutineWeek(int week) {
    return 'Week $week';
  }

  @override
  String trainingRoutineWeekShort(int week) {
    return 'Wk $week';
  }

  @override
  String get trainingRoutineWeekShortHint => 'Wk';

  @override
  String get trainingScheduleFixedWeeks => 'Fixed Weeks';

  @override
  String get trainingScheduleHasClasses => 'has classes';

  @override
  String trainingScheduleHours(int hours) {
    return '$hours h';
  }

  @override
  String trainingScheduleHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String trainingScheduleMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String trainingScheduleNextDay(String range) {
    return '$range (+1 day)';
  }

  @override
  String get trainingScheduleNextWeek => 'Next week';

  @override
  String get trainingSchedulePreviousWeek => 'Previous week';

  @override
  String get trainingScheduleThisWeek => 'This week';

  @override
  String get trainingScheduleTitle => 'Schedule';

  @override
  String get trainingScheduleTomorrow => 'Tomorrow';

  @override
  String get trainingScheduleWildcard => 'Wildcard';

  @override
  String get trainingScheduleYesterday => 'Yesterday';

  @override
  String get trainingSessionAddDrop => 'Add drop';

  @override
  String get trainingSessionCommentAthlete => 'Athlete';

  @override
  String get trainingSessionCommentCoach => 'Coach';

  @override
  String trainingSessionCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
    );
    return '$_temp0';
  }

  @override
  String get trainingSessionCommentDeleteMessage =>
      'This comment will be permanently removed.';

  @override
  String get trainingSessionCommentDeleteTitle => 'Delete comment?';

  @override
  String get trainingSessionCommentEditTitle => 'Edit comment';

  @override
  String trainingSessionCommentEdited(String when) {
    return '$when · edited';
  }

  @override
  String get trainingSessionCommentHint => 'Add a comment…';

  @override
  String get trainingSessionCommentOptions => 'Comment options';

  @override
  String get trainingSessionCommentYou => 'You';

  @override
  String get trainingSessionComments => 'Comments';

  @override
  String get trainingSessionDate => 'Date';

  @override
  String get trainingSessionDeleteMessage =>
      'This log entry will be permanently removed.';

  @override
  String get trainingSessionDeleteSetTooltip => 'Delete set';

  @override
  String get trainingSessionDeleteTitle => 'Delete session?';

  @override
  String get trainingSessionDeleteTooltip => 'Delete session';

  @override
  String get trainingSessionDeletedUser => 'Deleted user';

  @override
  String get trainingSessionDetailTitle => 'Session Detail';

  @override
  String trainingSessionDropNumber(int number) {
    return 'Drop $number';
  }

  @override
  String get trainingSessionDuration => 'Duration';

  @override
  String trainingSessionDurationSemantics(String duration) {
    return 'Duration $duration';
  }

  @override
  String trainingSessionEditSetTitle(String title) {
    return 'Edit $title';
  }

  @override
  String get trainingSessionEditSetTooltip => 'Edit set';

  @override
  String get trainingSessionFree => 'Free Session';

  @override
  String get trainingSessionInProgress => 'In progress';

  @override
  String get trainingSessionNoComments =>
      'No comments yet. Coaches and the athlete can leave feedback here.';

  @override
  String get trainingSessionNoReps => 'No reps recorded';

  @override
  String get trainingSessionNoSets => 'No sets logged';

  @override
  String get trainingSessionNote => 'Note';

  @override
  String get trainingSessionNotes => 'Notes';

  @override
  String get trainingSessionPlanned => 'Training Session';

  @override
  String get trainingSessionRemoveDrop => 'Remove drop';

  @override
  String get trainingSessionRepType => 'Type';

  @override
  String get trainingSessionRepsWholeNumber => 'Reps must be a whole number';

  @override
  String get trainingSessionSendComment => 'Send comment';

  @override
  String get trainingSessionSetDeleteMessage =>
      'This logged set will be permanently removed.';

  @override
  String get trainingSessionSetDeleteTitle => 'Delete set?';

  @override
  String trainingSessionSetTitle(int number) {
    return 'Set $number';
  }

  @override
  String trainingSessionSetTitleWithExercise(int number, String exercise) {
    return 'Set $number · $exercise';
  }

  @override
  String trainingSessionSetsLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sets Logged',
      one: '1 Set Logged',
    );
    return '$_temp0';
  }

  @override
  String get trainingSessionTapToEdit => 'Tap a set to edit it.';

  @override
  String trainingSessionTodayAt(String time) {
    return 'Today $time';
  }

  @override
  String get trainingSessionTrainer => 'Trainer';

  @override
  String get trainingSessionWeightNumber => 'Weight must be a number';

  @override
  String trainingSessionYesterdayAt(String time) {
    return 'Yesterday $time';
  }

  @override
  String get trainingSessionsClassesTitle => 'Classes';

  @override
  String get trainingSessionsEmpty => 'No sessions yet';

  @override
  String get trainingSessionsEmptyHint => 'Tap + to start your first workout';

  @override
  String get trainingSessionsMyProgress => 'My progress';

  @override
  String get trainingSessionsNew => 'New Session';

  @override
  String get trainingSessionsNoClasses => 'No classes yet';

  @override
  String get trainingSessionsNoClassesHint =>
      'Sessions you run for members will show up here';

  @override
  String get trainingSessionsTitle => 'Sessions';

  @override
  String get trainingSetTypeCircuit => 'Circuit';

  @override
  String get trainingSetTypeDropset => 'Drop Set';

  @override
  String get trainingSetTypeStandard => 'Straight Set';

  @override
  String get trainingSetTypeSuperset => 'Superset';

  @override
  String get trainingShiftAdd => 'Add shift';

  @override
  String trainingShiftAddOn(String day) {
    return 'Add shift on $day';
  }

  @override
  String get trainingShiftAddOne => 'Add a shift';

  @override
  String get trainingShiftAdded => 'Shift added';

  @override
  String trainingShiftCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shifts',
      one: '1 shift',
    );
    return '$_temp0';
  }

  @override
  String get trainingShiftDelete => 'Delete shift';

  @override
  String trainingShiftDeleteMessage(String name, String day) {
    return '$name\'s shift on $day will be removed.';
  }

  @override
  String trainingShiftDeleteNotifyMessage(String name, String day) {
    return '$name\'s shift on $day will be removed and they\'ll be notified.';
  }

  @override
  String get trainingShiftDeleteQuestion => 'Delete shift?';

  @override
  String get trainingShiftDeleted => 'Shift deleted';

  @override
  String get trainingShiftEdit => 'Edit shift';

  @override
  String trainingShiftEnd(String time) {
    return 'End $time';
  }

  @override
  String trainingShiftEndsNextDay(String duration) {
    return '$duration · ends the next day';
  }

  @override
  String get trainingShiftFree => 'You\'re free. New shifts will show up here.';

  @override
  String get trainingShiftLoadFailed => 'Couldn\'t load shifts';

  @override
  String get trainingShiftMyShifts => 'My shifts';

  @override
  String get trainingShiftNew => 'New shift';

  @override
  String trainingShiftNextDays(int days) {
    return 'Next $days days';
  }

  @override
  String get trainingShiftNextShifts => 'Next shifts';

  @override
  String get trainingShiftNoStaff => 'No staff to schedule';

  @override
  String get trainingShiftNoStaffMessage =>
      'Add employees, employee-trainers or trainers to this gym first.';

  @override
  String get trainingShiftNoUpcoming => 'No upcoming shifts';

  @override
  String get trainingShiftNoUpcomingMessage =>
      'When a manager schedules you, your shifts show up here and you get a notification.';

  @override
  String get trainingShiftNone => 'No shifts';

  @override
  String get trainingShiftNoneThisWeek => 'No shifts this week';

  @override
  String get trainingShiftNoneThisWeekManage =>
      'Plan who\'s working when. Staff get notified about their shifts.';

  @override
  String get trainingShiftNoneThisWeekMessage =>
      'No one has been scheduled for this week yet.';

  @override
  String get trainingShiftNoteHint => 'e.g. Front desk, open up';

  @override
  String get trainingShiftNoteOptional => 'Note (optional)';

  @override
  String get trainingShiftOnNow => 'On now';

  @override
  String get trainingShiftOptions => 'Shift options';

  @override
  String get trainingShiftPickStaff => 'Pick who works this shift';

  @override
  String get trainingShiftSeeAll => 'See all';

  @override
  String get trainingShiftShifts => 'Shifts';

  @override
  String get trainingShiftStaffMember => 'Staff member';

  @override
  String trainingShiftStart(String time) {
    return 'Start $time';
  }

  @override
  String get trainingShiftUpdated => 'Shift updated';

  @override
  String get trainingSideBoth => 'Both';

  @override
  String get trainingSideLeft => 'Left';

  @override
  String get trainingSideRight => 'Right';

  @override
  String get trainingStaffRoleEmployee => 'Employee';

  @override
  String get trainingStaffRoleEmployeeTrainer => 'Employee / Trainer';

  @override
  String get trainingStaffRoleTrainer => 'Trainer';

  @override
  String trainingWeekProgram(int weeks) {
    return '$weeks-Week Program';
  }

  @override
  String trainingWorkoutsAssignedByMe(int count) {
    return 'By me ($count)';
  }

  @override
  String trainingWorkoutsAssignedFor(String name) {
    return 'For $name';
  }

  @override
  String get trainingWorkoutsAssignedForMember => 'For a member';

  @override
  String trainingWorkoutsAssignedFrom(String name) {
    return 'From $name';
  }

  @override
  String get trainingWorkoutsAssignedFromCoach => 'From your coach';

  @override
  String trainingWorkoutsAssignedToMe(int count) {
    return 'Assigned to me ($count)';
  }

  @override
  String get trainingWorkoutsByMeEmpty =>
      'You haven\'t assigned routines to anyone yet.\nOpen a routine and tap Assign.';

  @override
  String get trainingWorkoutsClearSearch => 'Clear search';

  @override
  String get trainingWorkoutsCreate => 'Create';

  @override
  String get trainingWorkoutsMyRoutines => 'My Routines';

  @override
  String get trainingWorkoutsMyTrainings => 'My Trainings';

  @override
  String get trainingWorkoutsNewRoutine => 'New Routine';

  @override
  String get trainingWorkoutsNewTraining => 'New Training';

  @override
  String get trainingWorkoutsNoTrainings => 'No trainings found';

  @override
  String get trainingWorkoutsSelfAssigned => 'Self-assigned';

  @override
  String trainingWorkoutsSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String get trainingWorkoutsTabAssigned => 'Assigned';

  @override
  String get trainingWorkoutsTabLibrary => 'My Library';

  @override
  String get trainingWorkoutsTabRoutines => 'Routines';

  @override
  String get trainingWorkoutsTabTrainings => 'Trainings';

  @override
  String get trainingWorkoutsTitle => 'Workouts';

  @override
  String get trainingWorkoutsToMeEmpty =>
      'No routines assigned to you yet.\nYour coach\'s assignments show up here.';
}
