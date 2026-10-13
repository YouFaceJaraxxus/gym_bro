// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Serbian (`sr`).
class AppLocalizationsSr extends AppLocalizations {
  AppLocalizationsSr([String locale = 'sr']) : super(locale);

  @override
  String get appTitle => 'Gym Bro';

  @override
  String get businessCheckInAllTime => 'Ukupno';

  @override
  String get businessCheckInAttendanceTitle => 'Dolasci';

  @override
  String get businessCheckInBusiestHours => 'Najposećeniji termini';

  @override
  String get businessCheckInByStaff => 'prijavilo osoblje';

  @override
  String get businessCheckInCameraDenied => 'Pristup kameri je isključen';

  @override
  String get businessCheckInCameraDeniedMessage =>
      'Dozvoli pristup kameri za Gym Bro u podešavanjima uređaja da bi skenirao kodove članova. Članove i dalje možeš da prijaviš po imenu.';

  @override
  String businessCheckInCameraStartFailed(String code) {
    return 'Kamera nije mogla da se pokrene ($code).';
  }

  @override
  String get businessCheckInCameraUnavailable => 'Kamera nije dostupna';

  @override
  String get businessCheckInCameraUnsupportedMessage =>
      'Ovaj uređaj ne može da skenira kodove. Prijavi članove po imenu.';

  @override
  String get businessCheckInCheckInAction => 'Prijavi';

  @override
  String get businessCheckInCheckIns => 'Prijave';

  @override
  String businessCheckInCheckedInAt(String time) {
    return 'Prijavljen u $time';
  }

  @override
  String get businessCheckInCheckingIn => 'Prijavljivanje…';

  @override
  String get businessCheckInClearSearch => 'Obriši pretragu';

  @override
  String businessCheckInCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prijava',
      few: '$count prijave',
      one: '$count prijava',
    );
    return '$_temp0';
  }

  @override
  String businessCheckInDailyChartSemantics(
    int days,
    int total,
    String average,
  ) {
    return 'Grafikon prijava po danima, poslednjih $days dana: ukupno $total, prosečno $average dnevno.';
  }

  @override
  String get businessCheckInDismissHint => 'zatvori';

  @override
  String get businessCheckInGymFallback => 'Teretana';

  @override
  String businessCheckInHourlyChartSemantics(String hours) {
    return 'Grafikon prijava po satima. Najveća gužva: $hours.';
  }

  @override
  String businessCheckInLastDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Poslednjih $days dana',
      few: 'Poslednja $days dana',
      one: 'Poslednji $days dan',
    );
    return '$_temp0';
  }

  @override
  String businessCheckInLastVisit(String when) {
    return 'Poslednji dolazak: $when';
  }

  @override
  String get businessCheckInManual => 'Ručna prijava';

  @override
  String get businessCheckInManualShort => 'Ručno';

  @override
  String get businessCheckInMemberFallback => 'Član';

  @override
  String businessCheckInMembersInDays(int days) {
    return 'Članovi ($days d)';
  }

  @override
  String businessCheckInMembershipEnded(String type, String date) {
    return '$type · istekla $date';
  }

  @override
  String businessCheckInMembershipValidUntil(String type, String date) {
    return '$type · važi do $date';
  }

  @override
  String businessCheckInNewCodeIn(String time) {
    return 'Novi kod za $time';
  }

  @override
  String get businessCheckInNextDay => 'Sledeći dan';

  @override
  String get businessCheckInNoCheckInsInPeriod =>
      'Još nema prijava u ovom periodu.';

  @override
  String get businessCheckInNoGymMessage =>
      'Kada te teretana doda kao člana, ovde će se pojaviti tvoj kod za prijavu.';

  @override
  String get businessCheckInNoGymTitle => 'Nema teretane za prijavu';

  @override
  String get businessCheckInNoMatches => 'Nema članova koji odgovaraju';

  @override
  String get businessCheckInNoMatchesMessage => 'Probaj drugo ime ili e-mail.';

  @override
  String get businessCheckInNoMembers => 'Još nema članova';

  @override
  String get businessCheckInNoMembersMessage =>
      'Ovde se prikazuju članovi dodati u ovu teretanu.';

  @override
  String get businessCheckInNoMembershipOnFile => 'Nema evidentirane članarine';

  @override
  String get businessCheckInNoVisitsInPeriod => 'Nema dolazaka u ovom periodu.';

  @override
  String get businessCheckInNoVisitsMessage =>
      'Ovde će biti prikazane tvoje prijave.';

  @override
  String get businessCheckInNoVisitsTitle => 'Još nema dolazaka';

  @override
  String get businessCheckInNoneOnDay => 'Nema prijava tog dana';

  @override
  String get businessCheckInNoneToday => 'Danas još nema prijava';

  @override
  String get businessCheckInNotEnoughData => 'Još nema dovoljno podataka.';

  @override
  String get businessCheckInOpenScanner => 'Otvori skener';

  @override
  String businessCheckInPeak(String hours) {
    return 'Najveća gužva: $hours';
  }

  @override
  String get businessCheckInPickDayHelp => 'Prikaži prijave za';

  @override
  String get businessCheckInPointCamera => 'Usmeri kameru ka kodu člana';

  @override
  String get businessCheckInPreviousDay => 'Prethodni dan';

  @override
  String get businessCheckInQrNotConfigured =>
      'QR prijava još nije podešena na ovom serveru. Zamoli recepciju da te prijavi po imenu.';

  @override
  String get businessCheckInQrScan => 'QR skeniranje';

  @override
  String businessCheckInQrSemantics(String gym) {
    return 'QR kod za prijavu u teretanu $gym';
  }

  @override
  String get businessCheckInRecentVisits => 'Nedavni dolasci';

  @override
  String get businessCheckInRefreshCode => 'Osveži kod';

  @override
  String businessCheckInRefreshFailed(String error) {
    return 'Osvežavanje nije uspelo: $error';
  }

  @override
  String get businessCheckInRefreshingCode => 'Osvežavanje koda…';

  @override
  String get businessCheckInResultCheckedIn => 'Prijavljen';

  @override
  String get businessCheckInResultDuplicate => 'Već prijavljen';

  @override
  String get businessCheckInResultFailed => 'Prijava nije uspela';

  @override
  String get businessCheckInResultNoMembership => 'Nema aktivnu članarinu';

  @override
  String get businessCheckInScanHint => 'Skeniraj kod člana da ga prijaviš.';

  @override
  String get businessCheckInScanTitle => 'Skeniranje prijave';

  @override
  String get businessCheckInScanTooltip => 'Skeniraj prijave';

  @override
  String get businessCheckInSearchHint =>
      'Pretraži članove po imenu ili e-mailu';

  @override
  String businessCheckInSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prijavljenih u ovoj sesiji',
      few: '$count prijavljena u ovoj sesiji',
      one: '$count prijavljen u ovoj sesiji',
    );
    return '$_temp0';
  }

  @override
  String get businessCheckInShowAtDesk => 'Pokaži ovaj kod na recepciji';

  @override
  String get businessCheckInShowMore => 'Prikaži još';

  @override
  String get businessCheckInStaffNotice =>
      'Ovde si osoblje, ne član. Ovaj kod služi za testiranje skenera.';

  @override
  String get businessCheckInThisWeek => 'Ove nedelje';

  @override
  String get businessCheckInTitle => 'Prijava u teretanu';

  @override
  String get businessCheckInTopMembers => 'Najredovniji članovi';

  @override
  String get businessCheckInTorchOff => 'Isključi blic';

  @override
  String get businessCheckInTorchOn => 'Uključi blic';

  @override
  String businessCheckInTotalPerDay(int count, String average) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prijava',
      few: '$count prijave',
      one: '$count prijava',
    );
    return '$_temp0 · $average dnevno';
  }

  @override
  String get businessCheckInVisitsThisMonth => 'Dolasci ovog meseca';

  @override
  String businessCheckInVisitsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dolazaka',
      few: 'dolaska',
      one: 'dolazak',
    );
    return '$_temp0';
  }

  @override
  String get businessCheckInYesterday => 'Juče';

  @override
  String get businessGymAddEmployee => 'Dodaj zaposlenog';

  @override
  String get businessGymAddExistingUser => 'Dodaj postojećeg korisnika';

  @override
  String get businessGymAddExistingUserHint =>
      'Pretraži korisnike koji su već u sistemu';

  @override
  String get businessGymAddMember => 'Dodaj člana';

  @override
  String get businessGymAllGyms => 'Sve teretane';

  @override
  String get businessGymAllMembersTitle => 'Svi članovi';

  @override
  String get businessGymAllStaffTitle => 'Celo osoblje';

  @override
  String get businessGymAlreadyEmployee => 'Već radi u ovoj teretani';

  @override
  String get businessGymAlreadyMember => 'Već je član';

  @override
  String get businessGymAssign => 'Dodeli';

  @override
  String get businessGymAssignMembership => 'Dodeli članarinu';

  @override
  String get businessGymCancelMembership => 'Otkaži članarinu';

  @override
  String businessGymCancelMembershipMessage(String member, String type) {
    return 'Članarina „$type“ korisnika $member biće označena kao neaktivna. Istorija naplate se čuva.';
  }

  @override
  String get businessGymCancelMembershipTitle => 'Otkazati članarinu?';

  @override
  String get businessGymChange => 'Promeni';

  @override
  String businessGymChangeRoleMessage(String name, String role, String gym) {
    return 'Promeniti ulogu korisnika $name u „$role“ u teretani $gym?';
  }

  @override
  String get businessGymChangeRoleTitle => 'Promeniti ulogu?';

  @override
  String get businessGymClearSearch => 'Obriši pretragu';

  @override
  String businessGymDeleteMembershipMessage(String type) {
    return 'Ovim se trajno brišu članarina „$type“ i njene fakture. Da bi istorija ostala sačuvana, koristi Otkaži.';
  }

  @override
  String get businessGymDeleteMembershipTitle => 'Obrisati članarinu?';

  @override
  String get businessGymDetailAttendance => 'Dolasci';

  @override
  String get businessGymDetailInvoices => 'Fakture';

  @override
  String get businessGymDetailManage => 'Upravljaj';

  @override
  String get businessGymDetailManageMembers => 'Upravljaj članovima';

  @override
  String get businessGymDetailManageMembershipTypes =>
      'Upravljaj vrstama članarina';

  @override
  String get businessGymDetailManageStaff => 'Upravljaj osobljem';

  @override
  String get businessGymDetailMembers => 'Članovi';

  @override
  String businessGymDetailMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count članova',
      few: '$count člana',
      one: '$count član',
    );
    return '$_temp0';
  }

  @override
  String get businessGymDetailMembershipTypes => 'Vrste članarina';

  @override
  String get businessGymDetailMembershipTypesHint =>
      'Podesi cenovne planove na koje se članovi mogu upisati.';

  @override
  String businessGymDetailMore(int count) {
    return '+ još $count';
  }

  @override
  String get businessGymDetailPosts => 'Objave';

  @override
  String get businessGymDetailScanCheckIns => 'Skeniraj prijave';

  @override
  String get businessGymDetailSchedule => 'Raspored';

  @override
  String get businessGymDetailStaff => 'Osoblje';

  @override
  String businessGymDetailStaffCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaposlenih',
      few: '$count zaposlena',
      one: '$count zaposleni',
    );
    return '$_temp0';
  }

  @override
  String get businessGymDuration => 'Trajanje';

  @override
  String get businessGymEditEmployee => 'Izmeni zaposlenog';

  @override
  String get businessGymEditMember => 'Izmeni člana';

  @override
  String get businessGymEmail => 'Imejl';

  @override
  String get businessGymEmailAlreadyEmployed =>
      'Ovaj imejl već pripada zaposlenom u ovoj teretani';

  @override
  String get businessGymEmployeeActions => 'Radnje za zaposlenog';

  @override
  String get businessGymExtend => 'Produži';

  @override
  String get businessGymExtendMembership => 'Produži članarinu';

  @override
  String businessGymExtendedUntil(String date) {
    return 'Produženo do $date';
  }

  @override
  String get businessGymFilterAll => 'Sve';

  @override
  String get businessGymFirstName => 'Ime';

  @override
  String get businessGymFormAddLogo => 'Dodaj logo';

  @override
  String get businessGymFormCreate => 'Kreiraj biznis';

  @override
  String get businessGymFormDelete => 'Obriši biznis';

  @override
  String get businessGymFormDeleteGymAction => 'Obriši teretanu';

  @override
  String get businessGymFormDeleteGymMessage =>
      'Ovim se trajno briše teretana sa svim članovima, osobljem, vrstama članarina, članarinama, fakturama i objavama.';

  @override
  String get businessGymFormDeleteShopAction => 'Obriši prodavnicu';

  @override
  String get businessGymFormDeleteShopMessage =>
      'Ovim se trajno briše prodavnica sa svim artiklima, prodavcima i objavama.';

  @override
  String businessGymFormDeleteTitle(String name) {
    return 'Obrisati $name?';
  }

  @override
  String businessGymFormDeleted(String name) {
    return 'Obrisano: $name';
  }

  @override
  String get businessGymFormFrom => 'Od';

  @override
  String get businessGymFormLocation => 'Lokacija';

  @override
  String get businessGymFormName => 'Naziv';

  @override
  String get businessGymFormSaveChanges => 'Sačuvaj izmene';

  @override
  String get businessGymFormSelectWorkingDay => 'Izaberi bar jedan radni dan';

  @override
  String get businessGymFormTitleEdit => 'Izmeni biznis';

  @override
  String get businessGymFormTitleNew => 'Novi biznis';

  @override
  String get businessGymFormTo => 'Do';

  @override
  String get businessGymFormType => 'Vrsta';

  @override
  String get businessGymFormTypeGym => 'Teretana';

  @override
  String get businessGymFormTypeShop => 'Prodavnica';

  @override
  String get businessGymFormWorkingDays => 'Radni dani';

  @override
  String get businessGymFormWorkingHours => 'Radno vreme';

  @override
  String get businessGymGym => 'Teretana';

  @override
  String get businessGymInviteAndAdd => 'Pozovi i dodaj';

  @override
  String get businessGymInviteMemberTitle => 'Pozovi člana';

  @override
  String get businessGymInviteNewMember => 'Pozovi novog člana';

  @override
  String get businessGymInviteNewMemberHint => 'Pošalji link za poziv imejlom';

  @override
  String get businessGymInviteNewUserPrompt =>
      'Nema ih u pretrazi? Pozovi novog korisnika';

  @override
  String get businessGymInviteResent => 'Pozivnica je ponovo poslata';

  @override
  String get businessGymInviteResentSuccess =>
      'Pozivnica je uspešno ponovo poslata';

  @override
  String get businessGymKeep => 'Zadrži';

  @override
  String get businessGymLastName => 'Prezime';

  @override
  String get businessGymMemberActions => 'Radnje za člana';

  @override
  String businessGymMembersTitle(String gym) {
    return '$gym — Članovi';
  }

  @override
  String get businessGymMembershipActions => 'Radnje za članarinu';

  @override
  String get businessGymMembershipAssigned => 'Članarina je dodeljena';

  @override
  String get businessGymMembershipFallback => 'Članarina';

  @override
  String get businessGymMembershipType => 'Vrsta članarine';

  @override
  String get businessGymMembershipTypeNotFound =>
      'Vrsta članarine nije pronađena za ovu teretanu';

  @override
  String get businessGymMemberships => 'Članarine';

  @override
  String businessGymMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months meseci',
      few: '$months meseca',
      one: '$months mesec',
    );
    return '$_temp0';
  }

  @override
  String get businessGymNoMembersFound => 'Nema pronađenih članova';

  @override
  String get businessGymNoMembersYet => 'Još nema članova';

  @override
  String businessGymNoMembershipAt(String gym) {
    return 'Nema članarine u teretani $gym';
  }

  @override
  String get businessGymNoMembershipTypes =>
      'Ova teretana još nema vrste članarina — prvo dodaj jednu.';

  @override
  String get businessGymNoStaffFound => 'Nema pronađenog osoblja';

  @override
  String get businessGymNoStaffYet => 'Još nema osoblja';

  @override
  String businessGymPlusMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '+$months meseci',
      few: '+$months meseca',
      one: '+$months mesec',
    );
    return '$_temp0';
  }

  @override
  String get businessGymRemove => 'Ukloni';

  @override
  String get businessGymRemoveFromGym => 'Ukloni iz teretane';

  @override
  String businessGymRemoveFromGymMessage(String name, String gym) {
    return 'Korisnik $name biće uklonjen iz teretane $gym.';
  }

  @override
  String get businessGymRemoveMemberMessage =>
      'Član će biti uklonjen iz ove teretane.';

  @override
  String get businessGymRemoveMemberTitle => 'Ukloniti člana?';

  @override
  String get businessGymRemoveStaffMessage =>
      'Zaposleni će biti uklonjen iz ove teretane.';

  @override
  String get businessGymRemoveStaffTitle => 'Ukloniti zaposlenog?';

  @override
  String get businessGymResendInvite => 'Ponovo pošalji pozivnicu';

  @override
  String get businessGymRole => 'Uloga';

  @override
  String businessGymRoleChangedTo(String role) {
    return 'Uloga promenjena: $role';
  }

  @override
  String get businessGymRoleEmployee => 'Zaposleni';

  @override
  String get businessGymRoleEmployeeTrainer => 'Zaposleni trener';

  @override
  String get businessGymRoleEmployeeTrainerShort => 'Zap. trener';

  @override
  String get businessGymRoleMember => 'Član';

  @override
  String get businessGymRoleVendor => 'Prodavac';

  @override
  String get businessGymSearchMembersHint => 'Pretraži članove…';

  @override
  String get businessGymSearchStaffHint => 'Pretraži osoblje…';

  @override
  String get businessGymSendInvite => 'Pošalji pozivnicu';

  @override
  String businessGymStaffTitle(String gym) {
    return '$gym — Osoblje';
  }

  @override
  String get businessGymStatusActive => 'Aktivna';

  @override
  String get businessGymStatusCancelled => 'Otkazana';

  @override
  String get businessGymStatusExpired => 'Istekla';

  @override
  String businessGymTypePerMonth(String name, String price) {
    return '$name ($price/mes.)';
  }

  @override
  String get businessGymUsername => 'Korisničko ime';

  @override
  String get businessGymViewProgress => 'Pogledaj napredak';

  @override
  String get businessInvoiceStatusPaid => 'Plaćeno';

  @override
  String get businessInvoiceStatusUnpaid => 'Neplaćeno';

  @override
  String get businessInvoiceStatusVoid => 'Poništeno';

  @override
  String get businessItemTypeEquipment => 'Oprema';

  @override
  String get businessItemTypeGiftCard => 'Poklon kartica';

  @override
  String get businessItemTypeSupplement => 'Suplement';

  @override
  String get businessMgmtActiveMembership => 'Aktivna članarina';

  @override
  String get businessMgmtActiveUntil => 'Aktivan do';

  @override
  String get businessMgmtAddItem => 'Dodaj artikal';

  @override
  String get businessMgmtAddProductPhoto => 'Dodaj fotografiju proizvoda';

  @override
  String get businessMgmtAddType => 'Dodaj vrstu';

  @override
  String get businessMgmtAddVendor => 'Dodaj prodavca';

  @override
  String get businessMgmtAll => 'Sve';

  @override
  String get businessMgmtAllGyms => 'Sve teretane';

  @override
  String get businessMgmtAlreadyVendor => 'Već je prodavac u ovoj prodavnici';

  @override
  String get businessMgmtAutoRenewOn => 'Automatsko obnavljanje uključeno';

  @override
  String get businessMgmtAutoRenewTurnedOff =>
      'Automatsko obnavljanje je isključeno';

  @override
  String get businessMgmtBillingHistory => 'Istorija plaćanja';

  @override
  String get businessMgmtBuyMembership => 'Kupi članarinu';

  @override
  String get businessMgmtClearDate => 'Obriši datum';

  @override
  String businessMgmtDeleteItemMessage(String name) {
    return 'Ukloniti „$name“ iz ove prodavnice?';
  }

  @override
  String get businessMgmtDeleteItemTitle => 'Obrisati artikal?';

  @override
  String businessMgmtDeleteMembershipTypeMessage(String name) {
    return 'Vrsta „$name“ biće obrisana. Postojeće članarine koje je koriste ostaju sačuvane.';
  }

  @override
  String get businessMgmtDeleteMembershipTypeTitle =>
      'Obrisati vrstu članarine?';

  @override
  String businessMgmtDeleteNamed(String name) {
    return 'Obriši $name';
  }

  @override
  String get businessMgmtDescriptionOptional => 'Opis (opciono)';

  @override
  String get businessMgmtEditItem => 'Izmeni artikal';

  @override
  String get businessMgmtEditMembershipType => 'Izmeni vrstu članarine';

  @override
  String businessMgmtEditNamed(String name) {
    return 'Izmeni $name';
  }

  @override
  String get businessMgmtEditVendor => 'Izmeni prodavca';

  @override
  String get businessMgmtEmail => 'Email';

  @override
  String get businessMgmtEmailAlreadyVendor =>
      'Ovaj email već pripada prodavcu ove prodavnice';

  @override
  String get businessMgmtExtendOrBuy => 'Produži ili kupi članarinu';

  @override
  String get businessMgmtFirstName => 'Ime';

  @override
  String get businessMgmtGym => 'Teretana';

  @override
  String businessMgmtGymInvoicesTitle(String gymName) {
    return '$gymName — fakture';
  }

  @override
  String get businessMgmtInStock => 'Na stanju';

  @override
  String get businessMgmtInvalidNumber => 'Unesi ispravan broj';

  @override
  String get businessMgmtInviteAndAddVendor => 'Pozovi i dodaj prodavca';

  @override
  String get businessMgmtInviteNewUser =>
      'Nema ih u pretrazi? Pozovi novog korisnika';

  @override
  String get businessMgmtInviteResent => 'Pozivnica ponovo poslata';

  @override
  String get businessMgmtInviteResentSuccess =>
      'Pozivnica je uspešno ponovo poslata';

  @override
  String get businessMgmtInvoice => 'Faktura';

  @override
  String get businessMgmtInvoiceMarkedPaid => 'Faktura označena kao plaćena';

  @override
  String get businessMgmtInvoiceMarkedUnpaid =>
      'Faktura označena kao neplaćena';

  @override
  String get businessMgmtInvoiceMarkedVoid => 'Faktura označena kao poništena';

  @override
  String get businessMgmtInvoicePaidThanks => 'Faktura je plaćena. Hvala!';

  @override
  String get businessMgmtInvoices => 'Fakture';

  @override
  String businessMgmtIssuedOn(String date) {
    return 'Izdata $date';
  }

  @override
  String get businessMgmtItemActive => 'Aktivan';

  @override
  String get businessMgmtItemInactive => 'Neaktivan';

  @override
  String get businessMgmtItems => 'Artikli';

  @override
  String get businessMgmtLastName => 'Prezime';

  @override
  String get businessMgmtManage => 'Upravljaj';

  @override
  String get businessMgmtMarkPaid => 'Označi kao plaćenu';

  @override
  String get businessMgmtMarkUnpaid => 'Označi kao neplaćenu';

  @override
  String get businessMgmtMarkVoid => 'Označi kao poništenu';

  @override
  String get businessMgmtMembership => 'Članarina';

  @override
  String get businessMgmtMembershipExpired => 'Članarina je istekla';

  @override
  String get businessMgmtMembershipHistory => 'Istorija članarina';

  @override
  String businessMgmtMembershipTypesTitle(String gymName) {
    return '$gymName · vrste članarine';
  }

  @override
  String get businessMgmtMonthlyCost => 'Mesečna cena';

  @override
  String businessMgmtMoreCount(int count) {
    return '+ još $count';
  }

  @override
  String get businessMgmtName => 'Naziv';

  @override
  String get businessMgmtNewItem => 'Novi artikal';

  @override
  String get businessMgmtNewMembershipType => 'Nova vrsta članarine';

  @override
  String get businessMgmtNoActiveMembership => 'Nemaš aktivnu članarinu';

  @override
  String get businessMgmtNoExpiry => 'Bez isteka';

  @override
  String get businessMgmtNoInvoicesYet => 'Još nema faktura';

  @override
  String get businessMgmtNoItemsYet => 'Još nema artikala';

  @override
  String get businessMgmtNoMembershipBuyHint =>
      'Kupi članarinu u aplikaciji ili zamoli svoju teretanu da ti je podesi.';

  @override
  String get businessMgmtNoMembershipDeskHint =>
      'Zamoli svoju teretanu da ti podesi članarinu. Plaćanje se vrši na recepciji.';

  @override
  String get businessMgmtNoMembershipTypesYet => 'Još nema vrsta članarine';

  @override
  String get businessMgmtNoPaidInvoices => 'Nema plaćenih faktura';

  @override
  String get businessMgmtNoUnpaidInvoices => 'Nema neplaćenih faktura';

  @override
  String get businessMgmtNoVendorsYet => 'Još nema prodavaca';

  @override
  String get businessMgmtNoVoidInvoices => 'Nema poništenih faktura';

  @override
  String get businessMgmtOrders => 'Porudžbine';

  @override
  String get businessMgmtOrdersSubtitle =>
      'Porudžbine kupaca, plaćanja i preuzimanja';

  @override
  String get businessMgmtOutOfStock => 'Nema na stanju';

  @override
  String businessMgmtPayNow(String amount) {
    return 'Plati sada · $amount';
  }

  @override
  String get businessMgmtPaymentsAtDesk =>
      'Članarine i fakture se plaćaju na recepciji tvoje teretane.';

  @override
  String businessMgmtPerMonth(String price) {
    return '$price mesečno';
  }

  @override
  String businessMgmtPerMonthShort(String price) {
    return '$price/mes.';
  }

  @override
  String get businessMgmtPickDate => 'Izaberi datum';

  @override
  String get businessMgmtPosts => 'Objave';

  @override
  String get businessMgmtPrice => 'Cena';

  @override
  String businessMgmtQuantity(int quantity) {
    return 'Na stanju: $quantity';
  }

  @override
  String get businessMgmtRemove => 'Ukloni';

  @override
  String get businessMgmtRemoveFromShop => 'Ukloni iz prodavnice';

  @override
  String businessMgmtRemoveVendorFromShopMessage(String name, String shopName) {
    return 'Korisnik $name biće uklonjen iz prodavnice $shopName.';
  }

  @override
  String get businessMgmtRemoveVendorMessage =>
      'Ova osoba će biti uklonjena iz ove prodavnice.';

  @override
  String get businessMgmtRemoveVendorTitle => 'Ukloniti prodavca?';

  @override
  String get businessMgmtRenewMembership => 'Obnovi članarinu';

  @override
  String get businessMgmtRenewsMonthly =>
      'Automatski se obnavlja svakog meseca';

  @override
  String get businessMgmtResendInvite => 'Ponovo pošalji pozivnicu';

  @override
  String get businessMgmtSaveChanges => 'Sačuvaj izmene';

  @override
  String get businessMgmtShop => 'Prodavnica';

  @override
  String businessMgmtShopVendorsTitle(String shopName) {
    return '$shopName — prodavci';
  }

  @override
  String get businessMgmtStaffVendors => 'Osoblje / prodavci';

  @override
  String get businessMgmtTurnOff => 'Isključi';

  @override
  String get businessMgmtTurnOffAutoRenew => 'Isključi automatsko obnavljanje';

  @override
  String businessMgmtTurnOffAutoRenewMessage(String date) {
    return 'Članarina ostaje aktivna do $date i više neće biti naplaćivana.';
  }

  @override
  String get businessMgmtTurnOffAutoRenewTitle =>
      'Isključiti automatsko obnavljanje?';

  @override
  String get businessMgmtType => 'Vrsta';

  @override
  String get businessMgmtTypeActive => 'Aktivna';

  @override
  String get businessMgmtTypeInactive => 'Neaktivna';

  @override
  String get businessMgmtUnknownMember => 'Nepoznat član';

  @override
  String businessMgmtUnpaidSummary(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neplaćenih faktura',
      few: '$count neplaćene fakture',
      one: '$count neplaćena faktura',
    );
    return '$_temp0 · za plaćanje $amount';
  }

  @override
  String get businessMgmtUsername => 'Korisničko ime';

  @override
  String get businessMgmtVendor => 'Prodavac';

  @override
  String get businessMgmtVendorActions => 'Opcije prodavca';

  @override
  String get businessOrderStatusCancelled => 'Otkazano';

  @override
  String get businessOrderStatusFulfilled => 'Isporučeno';

  @override
  String get businessOrderStatusPaid => 'Plaćeno';

  @override
  String get businessOrderStatusPending => 'Na čekanju';

  @override
  String get businessPaymentMethodCard => 'Kartica';

  @override
  String get businessPaymentMethodPayAtPickup => 'Plaćanje pri preuzimanju';

  @override
  String get businessPaymentStatusCancelled => 'Otkazano';

  @override
  String get businessPaymentStatusFailed => 'Neuspešno';

  @override
  String get businessPaymentStatusPaid => 'Plaćeno';

  @override
  String get businessPaymentStatusPending => 'Na čekanju';

  @override
  String get businessPaymentStatusRefunded => 'Refundirano';

  @override
  String get businessQuantityDecrease => 'Smanji količinu';

  @override
  String get businessQuantityIncrease => 'Povećaj količinu';

  @override
  String businessQuantityValue(int value) {
    return 'Količina $value';
  }

  @override
  String businessShopAddWithPrice(String price) {
    return 'Dodaj · $price';
  }

  @override
  String businessShopAddedToCart(int quantity, String name) {
    return 'Dodato u korpu: $quantity × $name';
  }

  @override
  String get businessShopAllStockInCart =>
      'Sve dostupne zalihe su već u tvojoj korpi';

  @override
  String businessShopAutoRenewExplanation(String price) {
    return 'Sada ti se naplaćuje $price, a zatim svakog meseca. Automatsko obnavljanje možeš isključiti bilo kada na stranici članarine.';
  }

  @override
  String businessShopAvailableUntil(String date) {
    return 'Dostupno do $date';
  }

  @override
  String get businessShopAwaitingCardPayment => 'Čeka se plaćanje karticom';

  @override
  String get businessShopAwaitingYourCardPayment =>
      'Ova porudžbina čeka tvoje plaćanje karticom.';

  @override
  String get businessShopBrowseShops => 'Pregledaj prodavnice';

  @override
  String get businessShopBuyAtFrontDesk =>
      'Kupi ili produži članarinu na recepciji svoje teretane.';

  @override
  String get businessShopBuyMembershipTitle => 'Kupi članarinu';

  @override
  String businessShopBuyerPickedUp(String name) {
    return 'Porudžbina je preuzeta (kupac: $name).';
  }

  @override
  String get businessShopCancelOrder => 'Otkaži porudžbinu';

  @override
  String get businessShopCancelOrderTitle => 'Otkazati ovu porudžbinu?';

  @override
  String businessShopCardOfAmountWillBeRefunded(String total) {
    return 'Plaćanje karticom od $total biće refundirano.';
  }

  @override
  String get businessShopCardPaymentHint =>
      'Platićeš bezbedno preko Stripe-a, a zatim preuzeti porudžbinu.';

  @override
  String get businessShopCardUnavailableNow =>
      'Plaćanje karticom trenutno nije dostupno. Možeš platiti pri preuzimanju.';

  @override
  String get businessShopCardUnavailablePayAtPickup =>
      'Plaćanje karticom još nije dostupno. Platićeš kada preuzmeš porudžbinu.';

  @override
  String get businessShopCardWillBeRefunded =>
      'Plaćanje karticom biće refundirano.';

  @override
  String get businessShopCart => 'Korpa';

  @override
  String get businessShopCartEmpty => 'Korpa je prazna';

  @override
  String get businessShopCartEmptyHint => 'Dodirni artikal da ga dodaš.';

  @override
  String businessShopCartTotal(String price) {
    return 'Korpa · $price';
  }

  @override
  String get businessShopChooseDifferentGym => 'Izaberi drugu teretanu';

  @override
  String get businessShopClearSearch => 'Obriši pretragu';

  @override
  String businessShopConfirmBuyerPaid(String name, String total) {
    return 'Potvrdi uplatu od $total (kupac: $name).';
  }

  @override
  String businessShopConfirmCustomerPaid(String total) {
    return 'Potvrdi da je kupac platio $total.';
  }

  @override
  String businessShopConfirmPaidAtCounter(String total) {
    return 'Potvrdi da je kupac platio $total na kasi.';
  }

  @override
  String get businessShopConfirmingPayment => 'Potvrđujemo tvoje plaćanje…';

  @override
  String get businessShopCouldNotOpenPaymentPage =>
      'Nije moguće otvoriti stranicu za plaćanje';

  @override
  String get businessShopCustomer => 'Kupac';

  @override
  String get businessShopCustomerPickedUp => 'Kupac je preuzeo porudžbinu.';

  @override
  String get businessShopCustomerPickedUpOrder =>
      'Kupac je preuzeo porudžbinu.';

  @override
  String get businessShopDecreaseQuantity => 'Smanji količinu';

  @override
  String get businessShopEmptyCart => 'Isprazni korpu';

  @override
  String get businessShopFilterAll => 'Sve';

  @override
  String businessShopFromPricePerMonth(String price) {
    return 'Od $price mesečno';
  }

  @override
  String businessShopInCartCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artikala u korpi',
      few: '$count artikla u korpi',
      one: '$count artikal u korpi',
    );
    return '$_temp0';
  }

  @override
  String businessShopInStock(int count) {
    return 'Na stanju: $count';
  }

  @override
  String businessShopInYourCart(int count) {
    return 'U tvojoj korpi: $count';
  }

  @override
  String get businessShopIncreaseQuantity => 'Povećaj količinu';

  @override
  String businessShopItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stavki',
      few: '$count stavke',
      one: '$count stavka',
    );
    return '$_temp0';
  }

  @override
  String get businessShopItems => 'Artikli';

  @override
  String get businessShopItemsBackInStock => 'Artikli se vraćaju na stanje.';

  @override
  String businessShopLeftCount(int count) {
    return 'Još $count';
  }

  @override
  String get businessShopLength => 'Trajanje';

  @override
  String get businessShopMarkAsFulfilledTitle => 'Označiti kao isporučeno?';

  @override
  String get businessShopMarkAsPaidTitle => 'Označiti kao plaćeno?';

  @override
  String get businessShopMarkFulfilled => 'Označi kao isporučeno';

  @override
  String get businessShopMarkPaid => 'Označi kao plaćeno';

  @override
  String get businessShopMembershipPaymentSuccess =>
      'Plaćanje uspešno. Tvoja članarina je aktivna!';

  @override
  String get businessShopMembershipType => 'Vrsta članarine';

  @override
  String get businessShopMyOrders => 'Moje porudžbine';

  @override
  String get businessShopNewOrdersHint =>
      'Nove porudžbine kupaca pojaviće se ovde.';

  @override
  String get businessShopNoGymSellsMemberships =>
      'Nijedna teretana još ne prodaje članarine u aplikaciji.';

  @override
  String get businessShopNoGymsMatch => 'Nijedna teretana ne odgovara pretrazi';

  @override
  String get businessShopNoMembershipsForSale => 'Nema članarina u prodaji';

  @override
  String businessShopNoOrdersWithStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'pending': 'Nema porudžbina na čekanju',
      'paid': 'Nema plaćenih porudžbina',
      'fulfilled': 'Nema isporučenih porudžbina',
      'cancelled': 'Nema otkazanih porudžbina',
      'other': 'Nema porudžbina',
    });
    return '$_temp0';
  }

  @override
  String get businessShopNoOrdersYet => 'Još nema porudžbina';

  @override
  String get businessShopNoOrdersYetMessage =>
      'Artikli koje poručiš iz prodavnice pojaviće se ovde.';

  @override
  String get businessShopNoProductsMatch =>
      'Nijedan artikal ne odgovara pretrazi';

  @override
  String get businessShopNoProductsYet => 'Ova prodavnica još nema artikala';

  @override
  String get businessShopNoShopsYet => 'Još nema prodavnica';

  @override
  String get businessShopNoShopsYetMessage =>
      'Prodavnice će se pojaviti ovde kada se otvore.';

  @override
  String get businessShopNotYet => 'Još nije';

  @override
  String get businessShopNote => 'Napomena';

  @override
  String get businessShopNoteForShop => 'Napomena za prodavnicu (opciono)';

  @override
  String businessShopOneTimeExplanation(String price, String gym) {
    return 'Jednokratna uplata od $price. Ako već imaš članarinu u teretani $gym, biće produžena.';
  }

  @override
  String get businessShopOnlinePaymentsUnavailable =>
      'Onlajn plaćanje nije dostupno';

  @override
  String get businessShopOrder => 'Porudžbina';

  @override
  String businessShopOrderIdStatusChanged(String status, String id) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'paid': 'Porudžbina $id je označena kao plaćena.',
      'fulfilled': 'Porudžbina $id je označena kao isporučena.',
      'cancelled': 'Porudžbina $id je otkazana.',
      'other': 'Porudžbina $id je ažurirana.',
    });
    return '$_temp0';
  }

  @override
  String get businessShopOrderPaymentSuccess =>
      'Plaćanje uspešno. Tvoja porudžbina je plaćena!';

  @override
  String businessShopOrderStatusChanged(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'paid': 'Porudžbina je označena kao plaćena.',
      'fulfilled': 'Porudžbina je označena kao isporučena.',
      'cancelled': 'Porudžbina je otkazana.',
      'other': 'Porudžbina je ažurirana.',
    });
    return '$_temp0';
  }

  @override
  String businessShopOrderWithId(String id) {
    return 'Porudžbina $id';
  }

  @override
  String get businessShopOrders => 'Porudžbine';

  @override
  String get businessShopOutOfStock => 'Nema na stanju';

  @override
  String businessShopPayAmount(String price) {
    return 'Plati $price';
  }

  @override
  String get businessShopPayByCard => 'Plati karticom';

  @override
  String businessShopPayNow(String price) {
    return 'Plati sada · $price';
  }

  @override
  String get businessShopPayment => 'Plaćanje';

  @override
  String get businessShopPaymentCancelled => 'Plaćanje otkazano';

  @override
  String get businessShopPaymentFailed =>
      'Plaćanje nije uspelo. Novac ti nije naplaćen.';

  @override
  String get businessShopPaymentNotConfirmedYet =>
      'Plaćanje još nije potvrđeno. Obavestićemo te kada bude gotovo.';

  @override
  String get businessShopPaymentRefunded => 'Novac je refundiran';

  @override
  String get businessShopPaymentStillProcessing =>
      'Tvoje plaćanje se još obrađuje. Obavestićemo te kada bude potvrđeno.';

  @override
  String get businessShopPaymentSuccessful => 'Plaćanje uspešno';

  @override
  String get businessShopPickupPaymentHint =>
      'Plati u prodavnici kada preuzmeš porudžbinu.';

  @override
  String businessShopPlaceOrderAndPay(String price) {
    return 'Poruči i plati $price';
  }

  @override
  String businessShopPlaceOrderTotal(String price) {
    return 'Poruči · $price';
  }

  @override
  String get businessShopPlanMonthlyAutoRenew =>
      'Mesečno, automatsko obnavljanje';

  @override
  String businessShopPlanMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months meseci',
      few: '$months meseca',
      one: '$months mesec',
    );
    return '$_temp0';
  }

  @override
  String businessShopPriceEachLineTotal(String price, String total) {
    return '$price po komadu · $total';
  }

  @override
  String businessShopPricePerMonth(String price) {
    return '$price mesečno';
  }

  @override
  String businessShopProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artikala',
      few: '$count artikla',
      one: '$count artikal',
    );
    return '$_temp0';
  }

  @override
  String businessShopQuantityValue(int count) {
    return 'Količina: $count';
  }

  @override
  String get businessShopRefundDone => 'Plaćanje karticom je refundirano.';

  @override
  String get businessShopRefundFailed =>
      'Refundacija nije uspela. Refundiraj uplatu preko Stripe-a.';

  @override
  String get businessShopRefundManual => 'Refundiraj plaćanje karticom ručno.';

  @override
  String get businessShopRemove => 'Ukloni';

  @override
  String businessShopRemovedFromCart(String items) {
    return 'Uklonjeno iz korpe (više nije dostupno): $items';
  }

  @override
  String get businessShopSearchGyms => 'Pretraži teretane';

  @override
  String get businessShopSearchProducts => 'Pretraži artikle';

  @override
  String get businessShopShop => 'Prodavnica';

  @override
  String get businessShopSoldOut => 'Rasprodato';

  @override
  String get businessShopStatus => 'Status';

  @override
  String businessShopSubscribePerMonth(String price) {
    return 'Pretplati se · $price mesečno';
  }

  @override
  String get businessShopTimelinePlaced => 'Porudžbina kreirana';

  @override
  String get businessShopTotal => 'Ukupno';

  @override
  String get businessShopYourCart => 'Tvoja korpa';

  @override
  String get commonBack => 'Nazad';

  @override
  String get commonCancel => 'Otkaži';

  @override
  String get commonClose => 'Zatvori';

  @override
  String get commonConfirm => 'Potvrdi';

  @override
  String get commonDelete => 'Obriši';

  @override
  String get commonEdit => 'Izmeni';

  @override
  String get commonLoading => 'Učitavanje…';

  @override
  String get commonNo => 'Ne';

  @override
  String get commonOk => 'U redu';

  @override
  String get commonRequired => 'Obavezno polje';

  @override
  String get commonRetry => 'Pokušaj ponovo';

  @override
  String get commonSave => 'Sačuvaj';

  @override
  String get commonSearch => 'Pretraga';

  @override
  String get commonSomethingWentWrong => 'Nešto nije u redu';

  @override
  String get commonToday => 'Danas';

  @override
  String get commonYes => 'Da';

  @override
  String get nutritionAdd => 'Dodaj';

  @override
  String get nutritionAddFoodItem => 'Dodaj namirnicu';

  @override
  String get nutritionAddFoodTitle => 'Dodaj hranu';

  @override
  String get nutritionAddImage => 'Dodaj sliku';

  @override
  String get nutritionAddIngredient => 'Dodaj sastojak';

  @override
  String get nutritionAddMineral => 'Dodaj mineral';

  @override
  String nutritionAddNamed(String name) {
    return 'Dodaj: $name';
  }

  @override
  String get nutritionAddPhoto => 'Dodaj fotografiju';

  @override
  String get nutritionAddRecipe => 'Dodaj recept';

  @override
  String get nutritionAddSlot => 'Dodaj obrok';

  @override
  String get nutritionAddStep => 'Dodaj korak';

  @override
  String nutritionAddToSlot(String slot) {
    return 'Dodaj u: $slot';
  }

  @override
  String get nutritionAddVideo => 'Dodaj video';

  @override
  String get nutritionAddVitamin => 'Dodaj vitamin';

  @override
  String get nutritionAllMineralsAdded => 'Svi minerali su već dodati';

  @override
  String get nutritionAllSlotsAdded => 'Svi obroci su već dodati';

  @override
  String get nutritionAllVitaminsAdded => 'Svi vitamini su već dodati';

  @override
  String get nutritionAmount => 'Količina';

  @override
  String get nutritionAssign => 'Dodeli';

  @override
  String get nutritionAssignMealPlanTitle => 'Dodeli plan ishrane';

  @override
  String nutritionAssignPlanToQuestion(String plan, String name) {
    return 'Dodeliti „$plan” korisniku: $name?';
  }

  @override
  String nutritionAssignPlanToSelfQuestion(String plan) {
    return 'Dodeliti „$plan” sebi?';
  }

  @override
  String get nutritionAssignTo => 'Dodeli';

  @override
  String nutritionAssignedBy(String name) {
    return 'Dodela od: $name';
  }

  @override
  String get nutritionAssignedByMe => 'Koje dodeljujem';

  @override
  String nutritionAssignedOn(String date) {
    return 'Dodeljeno $date';
  }

  @override
  String get nutritionAssignedToMe => 'Dodeljeni meni';

  @override
  String nutritionAssignmentFor(String name) {
    return 'Za: $name';
  }

  @override
  String nutritionBarcodeExample(String example) {
    return 'npr. $example';
  }

  @override
  String nutritionBarcodeNotFound(String code) {
    return 'Nije pronađen proizvod za bar-kod $code';
  }

  @override
  String get nutritionBarcodeOptional => 'Bar-kod (opciono)';

  @override
  String nutritionBarcodeValue(String code) {
    return 'Bar-kod $code';
  }

  @override
  String get nutritionBasicInfo => 'Osnovni podaci';

  @override
  String get nutritionBrandOptional => 'Brend (opciono)';

  @override
  String get nutritionCalories => 'Kalorije';

  @override
  String get nutritionCameraAccessOff => 'Pristup kameri je isključen';

  @override
  String get nutritionCameraAccessOffHint =>
      'Dozvoli Gym Bro aplikaciji pristup kameri u podešavanjima uređaja da bi skenirao bar-kodove ili ručno unesi kod.';

  @override
  String get nutritionCameraUnavailable => 'Kamera nije dostupna';

  @override
  String get nutritionCameraUnavailableHint =>
      'Kamera nije mogla da se pokrene. Možeš ručno da uneseš broj bar-koda.';

  @override
  String get nutritionCancelEditing => 'Otkaži izmenu';

  @override
  String get nutritionCannotBeUndone => 'Ovo ne može da se poništi.';

  @override
  String get nutritionCarbs => 'Ugljeni hidrati';

  @override
  String get nutritionCarbsLetter => 'U';

  @override
  String get nutritionCarbsShort => 'UH';

  @override
  String nutritionChooseDailyPlanFor(String week, String day) {
    return 'Izaberi dnevni plan za $week, $day';
  }

  @override
  String get nutritionClearSearch => 'Obriši pretragu';

  @override
  String get nutritionClearStartDate => 'Obriši datum početka';

  @override
  String get nutritionClearUnassign => 'Obriši / ukloni dodelu';

  @override
  String get nutritionComment => 'Komentariši';

  @override
  String nutritionCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count komentara',
      few: '$count komentara',
      one: '$count komentar',
    );
    return '$_temp0';
  }

  @override
  String get nutritionCommentOptions => 'Opcije komentara';

  @override
  String get nutritionComments => 'Komentari';

  @override
  String nutritionCommentsWithCount(int count) {
    return 'Komentari ($count)';
  }

  @override
  String nutritionCommunityTitle(String business) {
    return '$business · Zajednica';
  }

  @override
  String get nutritionComputedPerServing => 'Izračunato po porciji';

  @override
  String get nutritionCookMinLabel => 'Kuvanje (min)';

  @override
  String get nutritionCreate => 'Napravi';

  @override
  String get nutritionCreateItem => 'Napravi namirnicu';

  @override
  String nutritionDailyAveragePlannedDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dnevni prosek · $count planiranih dana',
      few: 'Dnevni prosek · $count planirana dana',
      one: 'Dnevni prosek · $count planiran dan',
    );
    return '$_temp0';
  }

  @override
  String nutritionDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dana',
      few: '$count dana',
      one: '$count dan',
    );
    return 'pre $_temp0';
  }

  @override
  String nutritionDaysPlannedOfSeven(int count) {
    return 'Planirano $count od 7 dana';
  }

  @override
  String get nutritionDeleteCommentTitle => 'Obrisati komentar?';

  @override
  String get nutritionDeleteFoodItemTitle => 'Obrisati namirnicu?';

  @override
  String nutritionDeleteMealPlanMessage(String name) {
    return 'Trajno ukloniti „$name”? Sve dodele ovog plana takođe će biti uklonjene.';
  }

  @override
  String get nutritionDeleteMealPlanTitle => 'Obrisati plan ishrane?';

  @override
  String get nutritionDeletePost => 'Obriši objavu';

  @override
  String get nutritionDeletePostTitle => 'Obrisati objavu?';

  @override
  String get nutritionDeleteRecipeTitle => 'Obrisati recept?';

  @override
  String get nutritionDeletedUser => 'Obrisan korisnik';

  @override
  String get nutritionDescription => 'Opis';

  @override
  String get nutritionDragToReorder => 'Prevuci za promenu redosleda';

  @override
  String get nutritionDrinkBeer => 'Pivo';

  @override
  String get nutritionDrinkBlackTea => 'Crni čaj';

  @override
  String get nutritionDrinkCider => 'Sajder';

  @override
  String get nutritionDrinkCocktail => 'Koktel';

  @override
  String get nutritionDrinkCoffee => 'Kafa';

  @override
  String get nutritionDrinkDairyMilk => 'Mleko';

  @override
  String get nutritionDrinkEnergy => 'Energetsko piće';

  @override
  String get nutritionDrinkEspresso => 'Espreso';

  @override
  String get nutritionDrinkFlavouredWater => 'Aromatizovana voda';

  @override
  String get nutritionDrinkFruitJuice => 'Voćni sok';

  @override
  String get nutritionDrinkGreenTea => 'Zeleni čaj';

  @override
  String get nutritionDrinkHerbalTea => 'Biljni čaj';

  @override
  String get nutritionDrinkIsotonic => 'Izotonik';

  @override
  String get nutritionDrinkKefir => 'Kefir';

  @override
  String get nutritionDrinkKombucha => 'Kombuha';

  @override
  String get nutritionDrinkMealReplacement => 'Zamena za obrok';

  @override
  String get nutritionDrinkPlantMilk => 'Biljno mleko';

  @override
  String get nutritionDrinkProteinShake => 'Proteinski šejk';

  @override
  String get nutritionDrinkShake => 'Šejk';

  @override
  String get nutritionDrinkSmoothie => 'Smuti';

  @override
  String get nutritionDrinkSoda => 'Gazirani sok';

  @override
  String get nutritionDrinkSparklingWater => 'Gazirana voda';

  @override
  String get nutritionDrinkSpirit => 'Žestoko piće';

  @override
  String get nutritionDrinkSports => 'Sportski napitak';

  @override
  String get nutritionDrinkStillWater => 'Negazirana voda';

  @override
  String get nutritionDrinkVegetableJuice => 'Sok od povrća';

  @override
  String get nutritionDrinkWine => 'Vino';

  @override
  String get nutritionDuration => 'Trajanje';

  @override
  String get nutritionEditAmountOrMeal => 'Izmeni količinu ili obrok';

  @override
  String get nutritionEditDailyPlanTitle => 'Izmeni dnevni plan';

  @override
  String get nutritionEditFoodItemTitle => 'Izmeni namirnicu';

  @override
  String get nutritionEditMealPlanTitle => 'Izmeni plan ishrane';

  @override
  String get nutritionEditMicronutrients => 'Izmeni mikronutrijente';

  @override
  String get nutritionEditPost => 'Izmeni objavu';

  @override
  String get nutritionEditPostTitle => 'Izmeni objavu';

  @override
  String get nutritionEditRecipeTitle => 'Izmeni recept';

  @override
  String get nutritionEdited => 'Izmenjeno';

  @override
  String get nutritionEditedLower => 'izmenjeno';

  @override
  String get nutritionEditingComment => 'Izmena komentara';

  @override
  String nutritionEndsOn(String date) {
    return 'Završava se $date';
  }

  @override
  String get nutritionEnterBarcode => 'Unesi bar-kod';

  @override
  String get nutritionEnterCodeManually => 'Unesi kod ručno';

  @override
  String get nutritionEnterPositiveNumber => 'Unesi pozitivan broj';

  @override
  String get nutritionEnterValidNumber => 'Unesi ispravan broj';

  @override
  String get nutritionFat => 'Masti';

  @override
  String get nutritionFatLetter => 'M';

  @override
  String get nutritionFiber => 'Vlakna';

  @override
  String nutritionFiberNoTargets(int fiber) {
    return 'Vlakna $fiber g · Nema ciljeva iz plana ishrane za ovaj dan';
  }

  @override
  String nutritionFiberWithTargets(int fiber, int target) {
    return 'Vlakna $fiber / $target g · Ciljevi iz tvog plana ishrane';
  }

  @override
  String get nutritionFilterAll => 'Sve';

  @override
  String get nutritionFoodBabyFood => 'Hrana za bebe';

  @override
  String get nutritionFoodBaking => 'Sastojci za pečenje';

  @override
  String get nutritionFoodBeans => 'Pasulj i mahunarke';

  @override
  String get nutritionFoodBeef => 'Govedina';

  @override
  String get nutritionFoodBiscuitCookie => 'Keks';

  @override
  String get nutritionFoodBreadBakery => 'Hleb i peciva';

  @override
  String get nutritionFoodButter => 'Puter';

  @override
  String get nutritionFoodCanned => 'Konzervirana hrana';

  @override
  String get nutritionFoodCerealBar => 'Musli pločica';

  @override
  String get nutritionFoodCheese => 'Sir';

  @override
  String get nutritionFoodChips => 'Čips';

  @override
  String get nutritionFoodChocolateCandy => 'Čokolada i slatkiši';

  @override
  String get nutritionFoodCorn => 'Kukuruz';

  @override
  String get nutritionFoodCream => 'Pavlaka';

  @override
  String get nutritionFoodDiary => 'Dnevnik ishrane';

  @override
  String get nutritionFoodDressing => 'Dresing';

  @override
  String get nutritionFoodEgg => 'Jaja';

  @override
  String get nutritionFoodFish => 'Riba';

  @override
  String get nutritionFoodFrozen => 'Smrznuta hrana';

  @override
  String get nutritionFoodFruit => 'Voće';

  @override
  String get nutritionFoodGameMeat => 'Divljač';

  @override
  String get nutritionFoodGrainCereal => 'Žitarice';

  @override
  String get nutritionFoodHerbFresh => 'Sveže začinsko bilje';

  @override
  String get nutritionFoodJamSpread => 'Džem i namazi';

  @override
  String get nutritionFoodLamb => 'Jagnjetina';

  @override
  String get nutritionFoodLentils => 'Sočivo';

  @override
  String get nutritionFoodMilk => 'Mleko';

  @override
  String get nutritionFoodMushroom => 'Pečurke';

  @override
  String get nutritionFoodNuts => 'Orašasti plodovi';

  @override
  String get nutritionFoodOilFat => 'Ulja i masti';

  @override
  String get nutritionFoodPastaNoodle => 'Testenina';

  @override
  String get nutritionFoodPlantMilk => 'Biljno mleko';

  @override
  String get nutritionFoodPork => 'Svinjetina';

  @override
  String get nutritionFoodPotatoTuber => 'Krompir i krtole';

  @override
  String get nutritionFoodPoultry => 'Piletina i živina';

  @override
  String get nutritionFoodProcessedMeat => 'Mesne prerađevine';

  @override
  String get nutritionFoodReadyMeal => 'Gotovo jelo';

  @override
  String get nutritionFoodRice => 'Pirinač';

  @override
  String get nutritionFoodSauceCondiment => 'Sosevi i dodaci';

  @override
  String get nutritionFoodSeafood => 'Morski plodovi';

  @override
  String get nutritionFoodSeeds => 'Semenke';

  @override
  String get nutritionFoodSnackBar => 'Snek pločica';

  @override
  String get nutritionFoodSupplementPowder => 'Suplement u prahu';

  @override
  String get nutritionFoodSweetener => 'Zaslađivač';

  @override
  String get nutritionFoodVegetable => 'Povrće';

  @override
  String get nutritionFoodYogurt => 'Jogurt';

  @override
  String get nutritionFoods => 'Namirnice';

  @override
  String nutritionHoursAgo(int count) {
    return 'pre $count h';
  }

  @override
  String get nutritionImageUrl => 'URL slike';

  @override
  String get nutritionImages => 'Slike';

  @override
  String nutritionImportedFromOff(String name) {
    return 'Uvezeno „$name” iz Open Food Facts baze. Proveri vrednosti pre nego što se osloniš na njih.';
  }

  @override
  String get nutritionIngredients => 'Sastojci';

  @override
  String get nutritionInstructionHint => 'Uputstvo…';

  @override
  String get nutritionItemFallback => 'Stavka';

  @override
  String get nutritionJustNow => 'Upravo sad';

  @override
  String get nutritionKcal => 'kcal';

  @override
  String nutritionKcalEatenSemantics(int eaten) {
    return 'Unete kalorije: $eaten kcal';
  }

  @override
  String nutritionKcalLeft(int count) {
    return 'još $count';
  }

  @override
  String nutritionKcalOver(int count) {
    return '$count preko';
  }

  @override
  String nutritionKcalPer100(int kcal, String per100) {
    return '$kcal kcal $per100';
  }

  @override
  String nutritionKcalPerServing(int kcal) {
    return '$kcal kcal po porciji';
  }

  @override
  String get nutritionKcalPerServingLabel => 'kcal po porciji';

  @override
  String nutritionKcalRingSemantics(int eaten, int target) {
    return 'Kalorije: $eaten od $target kcal';
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
  String get nutritionLike => 'Sviđa mi se';

  @override
  String nutritionLikeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sviđanja',
      few: '$count sviđanja',
      one: '$count sviđanje',
      zero: 'Nema sviđanja',
    );
    return '$_temp0';
  }

  @override
  String get nutritionLoadMore => 'Učitaj još';

  @override
  String get nutritionLogAction => 'Zabeleži';

  @override
  String get nutritionLogAnyway => 'Ipak zabeleži';

  @override
  String get nutritionLogPlannedAllDuplicateWarning =>
      'Neki obroci već imaju unose za danas. Planirane stavke biće dodate pored njih.';

  @override
  String get nutritionLogPlannedMeals => 'Zabeleži planirane obroke';

  @override
  String get nutritionLogPlannedMealsQuestion => 'Zabeležiti planirane obroke?';

  @override
  String nutritionLogPlannedSlotDuplicateWarning(String slot) {
    return '$slot već ima unose. Planirane stavke biće dodate pored njih.';
  }

  @override
  String get nutritionLogToDiary => 'Upiši u dnevnik';

  @override
  String get nutritionLogToToday => 'Zabeleži za danas';

  @override
  String nutritionLoggedItemToSlot(String name, String slot) {
    return '$name dodato u: $slot';
  }

  @override
  String nutritionLoggedPlannedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zabeleženo $count planiranih stavki',
      few: 'Zabeležene $count planirane stavke',
      one: 'Zabeležena $count planirana stavka',
    );
    return '$_temp0';
  }

  @override
  String nutritionLoggedToSlot(String slot) {
    return 'Dodato u: $slot';
  }

  @override
  String get nutritionLookUp => 'Pretraži';

  @override
  String get nutritionLookingUpProduct => 'Tražim proizvod…';

  @override
  String get nutritionMacronutrients => 'Makronutrijenti';

  @override
  String get nutritionMeal => 'Obrok';

  @override
  String nutritionMealCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count obroka',
      few: '$count obroka',
      one: '$count obrok',
    );
    return '$_temp0';
  }

  @override
  String get nutritionMealPlanFallback => 'Plan ishrane';

  @override
  String get nutritionMealPlansTitle => 'Planovi ishrane';

  @override
  String get nutritionMealSlots => 'Obroci';

  @override
  String get nutritionMemberFallback => 'člana';

  @override
  String get nutritionMicronutrients => 'Mikronutrijenti';

  @override
  String nutritionMicronutrientsOptionalHint(String per100) {
    return 'Opciono. Količine $per100.';
  }

  @override
  String get nutritionMine => 'Moje';

  @override
  String get nutritionMineral => 'Mineral';

  @override
  String get nutritionMinerals => 'Minerali';

  @override
  String nutritionMinutesAgo(int count) {
    return 'pre $count min';
  }

  @override
  String get nutritionMoveToMeal => 'Premesti u obrok';

  @override
  String get nutritionMyself => 'Sebi';

  @override
  String get nutritionNameRequiredLabel => 'Naziv *';

  @override
  String get nutritionNewDailyPlanMenu => 'Novi dnevni plan';

  @override
  String get nutritionNewDailyPlanTitle => 'Novi dnevni plan';

  @override
  String get nutritionNewFoodItemTitle => 'Nova namirnica';

  @override
  String get nutritionNewMealPlanTitle => 'Novi plan ishrane';

  @override
  String get nutritionNewPost => 'Nova objava';

  @override
  String get nutritionNewRecipeTitle => 'Novi recept';

  @override
  String get nutritionNextDay => 'Sledeći dan';

  @override
  String get nutritionNoAssignmentsByMe =>
      'Nema planova ishrane koje si dodelio drugima';

  @override
  String get nutritionNoAssignmentsToMe =>
      'Još ti nije dodeljen nijedan plan ishrane';

  @override
  String get nutritionNoCommentsYet => 'Još nema komentara';

  @override
  String get nutritionNoDailyPlansFound => 'Nema pronađenih dnevnih planova';

  @override
  String get nutritionNoEntries => 'Nema unosa';

  @override
  String get nutritionNoEntriesYet => 'Još nema unosa';

  @override
  String get nutritionNoFoodItemsFound => 'Nema pronađenih namirnica';

  @override
  String get nutritionNoFoodsFound => 'Nema pronađenih namirnica';

  @override
  String get nutritionNoFoodsFoundHint =>
      'Probaj drugu pretragu ili skeniraj bar-kod proizvoda.';

  @override
  String get nutritionNoIngredientsYet => 'Još nema dodatih sastojaka';

  @override
  String get nutritionNoMealPlansFound => 'Nema pronađenih planova ishrane';

  @override
  String get nutritionNoMealsYet => 'Još nema dodatih obroka';

  @override
  String get nutritionNoMembersMatch => 'Nijedan član ne odgovara pretrazi';

  @override
  String get nutritionNoMembersToCoach =>
      'Nema članova koje treniraš. Ovde se prikazuju članovi teretana u kojima radiš ili treniraš.';

  @override
  String get nutritionNoMicronutrients =>
      'Za ovu namirnicu nisu uneti vitamini ni minerali.';

  @override
  String get nutritionNoMicronutrientsAdded =>
      'Nema dodatih vitamina ni minerala';

  @override
  String get nutritionNoOwnMealPlans => 'Još nemaš nijedan svoj plan ishrane';

  @override
  String get nutritionNoPostsYet => 'Još nema objava';

  @override
  String get nutritionNoRecipesFound => 'Nema pronađenih recepata';

  @override
  String get nutritionNoResults => 'Nema rezultata';

  @override
  String get nutritionNoStepsYet => 'Još nema dodatih koraka';

  @override
  String get nutritionNoteOptional => 'Napomena (opciono)';

  @override
  String get nutritionNothingLogged => 'Ništa nije zabeleženo';

  @override
  String get nutritionNothingLoggedThisDay =>
      'Za ovaj dan nije zabeležena hrana.';

  @override
  String get nutritionNothingPlanned => 'Ništa nije planirano';

  @override
  String get nutritionNutrient => 'Nutrijent';

  @override
  String nutritionNutrientListLoadFailed(String error) {
    return 'Učitavanje liste nutrijenata nije uspelo: $error';
  }

  @override
  String nutritionOfTargetKcal(int target) {
    return 'od $target kcal';
  }

  @override
  String nutritionPcfGrams(int protein, int carbs, int fat) {
    return 'P ${protein}g · U ${carbs}g · M ${fat}g';
  }

  @override
  String nutritionPcfShort(int protein, int carbs, int fat) {
    return 'P $protein · U $carbs · M $fat';
  }

  @override
  String nutritionPer100Unit(String unit) {
    return 'na 100$unit';
  }

  @override
  String get nutritionPerServing => 'po porciji';

  @override
  String nutritionPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotografija',
      few: '$count fotografije',
      one: '$count fotografija',
    );
    return '$_temp0';
  }

  @override
  String nutritionPhotoOf(String name) {
    return 'Fotografija: $name';
  }

  @override
  String get nutritionPickDate => 'Izaberi datum';

  @override
  String nutritionPlanAssignedTo(String plan, String name) {
    return '„$plan” dodeljen korisniku: $name';
  }

  @override
  String nutritionPlanAssignedToSelf(String plan) {
    return '„$plan” je dodeljen tebi';
  }

  @override
  String get nutritionPlanNameRequiredLabel => 'Naziv plana *';

  @override
  String nutritionPlannedSummary(String items, int kcal) {
    return 'Planirano: $items · $kcal kcal';
  }

  @override
  String get nutritionPointCameraAtBarcode =>
      'Usmeri kameru ka bar-kodu proizvoda';

  @override
  String get nutritionPostAction => 'Objavi';

  @override
  String get nutritionPostPhoto => 'Fotografija iz objave';

  @override
  String nutritionPostPhotoOf(int index, int count) {
    return 'Fotografija $index od $count';
  }

  @override
  String get nutritionPrepMinLabel => 'Priprema (min)';

  @override
  String get nutritionPreviousDay => 'Prethodni dan';

  @override
  String get nutritionPrivate => 'Privatno';

  @override
  String get nutritionProductNotFound => 'Proizvod nije pronađen';

  @override
  String nutritionProductNotFoundMessage(String code) {
    return 'Nema podataka za bar-kod $code. Da li želiš sam da napraviš namirnicu?';
  }

  @override
  String get nutritionProtein => 'Proteini';

  @override
  String get nutritionProteinLetter => 'P';

  @override
  String get nutritionPublic => 'Javno';

  @override
  String get nutritionQtyShort => 'Kol.';

  @override
  String get nutritionQuantity => 'Količina';

  @override
  String nutritionRecipeCookTime(int minutes) {
    return 'Kuvanje $minutes min';
  }

  @override
  String get nutritionRecipeFallback => 'Recept';

  @override
  String get nutritionRecipeNameRequiredLabel => 'Naziv recepta *';

  @override
  String nutritionRecipePrepTime(int minutes) {
    return 'Priprema $minutes min';
  }

  @override
  String get nutritionRecipes => 'Recepti';

  @override
  String get nutritionRemove => 'Ukloni';

  @override
  String nutritionRemoveAssignmentMessage(String name) {
    return '„$name” više neće biti dodeljen.';
  }

  @override
  String get nutritionRemoveAssignmentTitle => 'Ukloniti dodelu?';

  @override
  String get nutritionRemoveImage => 'Ukloni sliku';

  @override
  String get nutritionRemoveIngredient => 'Ukloni sastojak';

  @override
  String nutritionRemoveNamed(String name) {
    return 'Ukloni: $name';
  }

  @override
  String nutritionRemovePermanently(String name) {
    return 'Trajno ukloniti „$name”?';
  }

  @override
  String get nutritionRemovePhoto => 'Ukloni fotografiju';

  @override
  String get nutritionRemoveSlot => 'Ukloni obrok';

  @override
  String get nutritionRemoveStep => 'Ukloni korak';

  @override
  String get nutritionRemoveVideo => 'Ukloni video';

  @override
  String nutritionRemovedItem(String name) {
    return 'Uklonjeno: $name';
  }

  @override
  String get nutritionRestFree => 'Odmor / slobodno';

  @override
  String get nutritionSaveComment => 'Sačuvaj komentar';

  @override
  String get nutritionScanBarcode => 'Skeniraj bar-kod';

  @override
  String get nutritionSchedule => 'Raspored';

  @override
  String get nutritionSearchDailyPlansHint => 'Pretraži dnevne planove…';

  @override
  String get nutritionSearchFoodItemsHint => 'Pretraži namirnice…';

  @override
  String get nutritionSearchFoodsAndRecipes => 'Pretraži namirnice i recepte';

  @override
  String get nutritionSearchHint => 'Pretraži…';

  @override
  String get nutritionSearchMealPlansHint => 'Pretraži planove ishrane…';

  @override
  String get nutritionSearchMembersHint => 'Pretraži članove…';

  @override
  String get nutritionSearchRecipesHint => 'Pretraži recepte…';

  @override
  String get nutritionSelectMealSlot => 'Izaberi obrok';

  @override
  String get nutritionSelfAssigned => 'Samostalno dodeljen';

  @override
  String get nutritionSendComment => 'Pošalji komentar';

  @override
  String get nutritionServingUnit => 'Jedinica mere';

  @override
  String get nutritionServings => 'Porcije';

  @override
  String nutritionServingsAmount(num count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$amount porcija',
      few: '$amount porcije',
      one: '$amount porcija',
    );
    return '$_temp0';
  }

  @override
  String get nutritionServingsRequiredLabel => 'Broj porcija *';

  @override
  String get nutritionSetAsThumbnail => 'Postavi kao naslovnu sliku';

  @override
  String get nutritionShareHint => 'Šta želiš da podeliš?';

  @override
  String get nutritionSlotAfternoonSnack => 'Popodnevna užina';

  @override
  String get nutritionSlotBreakfast => 'Doručak';

  @override
  String get nutritionSlotDinner => 'Večera';

  @override
  String get nutritionSlotEveningSnack => 'Večernja užina';

  @override
  String get nutritionSlotLunch => 'Ručak';

  @override
  String get nutritionSlotMorningSnack => 'Jutarnja užina';

  @override
  String get nutritionSlotPostWorkout => 'Posle treninga';

  @override
  String get nutritionSlotPreWorkout => 'Pre treninga';

  @override
  String get nutritionSpiceBlend => 'Mešavina začina';

  @override
  String get nutritionSpiceDriedHerb => 'Sušeno začinsko bilje';

  @override
  String get nutritionSpiceDryMarinade => 'Suva marinada';

  @override
  String get nutritionSpiceExtract => 'Ekstrakt / esencija';

  @override
  String get nutritionSpiceGround => 'Mleveni začin';

  @override
  String get nutritionSpicePepper => 'Biber';

  @override
  String get nutritionSpiceRub => 'Začinska mešavina za meso';

  @override
  String get nutritionSpiceSalt => 'So';

  @override
  String get nutritionSpiceSeed => 'Seme začina';

  @override
  String get nutritionSpiceWhole => 'Začin u zrnu';

  @override
  String get nutritionStartConversation => 'Započni razgovor ispod.';

  @override
  String get nutritionStartDateOptional => 'Datum početka (opciono)';

  @override
  String nutritionStartsOn(String date) {
    return 'Počinje $date';
  }

  @override
  String get nutritionStepImageUrlOptional => 'URL slike za korak (opciono)';

  @override
  String nutritionStepNumber(int number) {
    return 'Korak $number';
  }

  @override
  String nutritionStepPhoto(int number) {
    return 'Fotografija za korak $number';
  }

  @override
  String get nutritionSteps => 'Koraci';

  @override
  String get nutritionSubtypeOther => 'Ostalo';

  @override
  String get nutritionSubtypeRequiredLabel => 'Podtip *';

  @override
  String get nutritionSystem => 'Sistemski';

  @override
  String get nutritionTabAssigned => 'Dodeljeni';

  @override
  String get nutritionTabDailyPlans => 'Dnevni planovi';

  @override
  String get nutritionTabFood => 'Namirnice';

  @override
  String get nutritionTabMyDailyPlans => 'Moji dnevni planovi';

  @override
  String get nutritionTabMyFood => 'Moje namirnice';

  @override
  String get nutritionTabMyLibrary => 'Moja biblioteka';

  @override
  String get nutritionTabMyMealPlans => 'Moji planovi ishrane';

  @override
  String get nutritionTabMyRecipes => 'Moji recepti';

  @override
  String get nutritionTabPlans => 'Planovi';

  @override
  String get nutritionThumbnail => 'Naslovna slika';

  @override
  String get nutritionTitleOptional => 'Naslov (opciono)';

  @override
  String get nutritionTomorrow => 'Sutra';

  @override
  String get nutritionTorchOff => 'Isključi baterijsku lampu';

  @override
  String get nutritionTorchOn => 'Uključi baterijsku lampu';

  @override
  String get nutritionTotals => 'Ukupno';

  @override
  String get nutritionTryAnotherSearch => 'Probaj drugi pojam za pretragu.';

  @override
  String get nutritionType => 'Tip';

  @override
  String get nutritionTypeDrink => 'Piće';

  @override
  String get nutritionTypeFood => 'Hrana';

  @override
  String get nutritionTypeSpice => 'Začin';

  @override
  String get nutritionUnassigned => 'Nije dodeljeno';

  @override
  String get nutritionUnit => 'Jedinica';

  @override
  String get nutritionUnitServings => 'porcije';

  @override
  String get nutritionUnlike => 'Ukloni sviđanje';

  @override
  String get nutritionUploadPhoto => 'Otpremi fotografiju';

  @override
  String nutritionUsersDiary(String name) {
    return 'Dnevnik ishrane: $name';
  }

  @override
  String nutritionValuesPer(String per100) {
    return 'Vrednosti $per100';
  }

  @override
  String nutritionVideoNumber(int number) {
    return 'Video $number';
  }

  @override
  String get nutritionVideoUrl => 'URL videa';

  @override
  String get nutritionVideos => 'Video snimci';

  @override
  String get nutritionVisibleToAllUsers => 'Vidljivo svim korisnicima';

  @override
  String get nutritionVitamin => 'Vitamin';

  @override
  String get nutritionVitamins => 'Vitamini';

  @override
  String nutritionWeekDay(int week, int day) {
    return 'Nedelja $week · Dan $day';
  }

  @override
  String nutritionWeekNumber(int number) {
    return 'Nedelja $number';
  }

  @override
  String nutritionWeeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nedelja',
      few: '$count nedelje',
      one: '$count nedelja',
    );
    return '$_temp0';
  }

  @override
  String nutritionWeeksShort(int count) {
    return '$count ned.';
  }

  @override
  String get nutritionWriteCommentHint => 'Napiši komentar…';

  @override
  String get nutritionWriteSomethingFirst => 'Prvo nešto napiši';

  @override
  String get nutritionYesterday => 'Juče';

  @override
  String get nutritionYourCoachFallback => 'tvoj trener';

  @override
  String get nutritionYours => 'Tvoj';

  @override
  String get settingsLanguage => 'Jezik';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageSerbian => 'Srpski';

  @override
  String get settingsLanguageSystem => 'Podrazumevani jezik sistema';

  @override
  String get shellActivateAccount => 'Aktiviraj nalog';

  @override
  String get shellActivateInviteIntro =>
      'Unesi šestocifreni kod iz imejla sa pozivnicom, svoju imejl adresu i lozinku koju želiš da koristiš.';

  @override
  String get shellActivateInviteTitle => 'Aktiviraj pozivnicu';

  @override
  String get shellAddBusiness => 'Dodaj biznis';

  @override
  String get shellAddUser => 'Dodaj korisnika';

  @override
  String get shellAdminBusinessesSubtitle =>
      'Upravljaj teretanama i prodavnicama';

  @override
  String get shellAdminInvoicesSubtitle => 'Pregled svih faktura za članarine';

  @override
  String get shellAdminPanel => 'Admin panel';

  @override
  String get shellAdminUsersSubtitle => 'Upravljaj svim nalozima';

  @override
  String get shellAlreadyYourEmail => 'To je već tvoj imejl';

  @override
  String get shellAuthEmail => 'Imejl';

  @override
  String get shellAuthFirstName => 'Ime';

  @override
  String get shellAuthInvalidEmail => 'Unesi ispravan imejl';

  @override
  String get shellAuthLastName => 'Prezime';

  @override
  String get shellAuthPassword => 'Lozinka';

  @override
  String shellAuthPasswordMin(int count) {
    return 'Najmanje $count karaktera';
  }

  @override
  String get shellAuthUsername => 'Korisničko ime';

  @override
  String get shellAvatarAdd => 'Dodaj profilnu fotografiju';

  @override
  String get shellAvatarChange => 'Promeni profilnu fotografiju';

  @override
  String get shellChange => 'Promeni';

  @override
  String get shellChangeEmail => 'Promeni imejl';

  @override
  String get shellChangeEmailIntro =>
      'Poslaćemo link za potvrdu na novu adresu. Imejl će se promeniti kada ga otvoriš.';

  @override
  String get shellChangePassword => 'Promeni lozinku';

  @override
  String get shellCheckEmailBody =>
      'Poslali smo ti link za potvrdu. Potvrdi imejl pre prijave.';

  @override
  String get shellCheckEmailTitle => 'Proveri imejl';

  @override
  String get shellChooseShop => 'Izaberi prodavnicu';

  @override
  String get shellClearSearch => 'Obriši pretragu';

  @override
  String get shellConfirmNewEmailTitle => 'Potvrdi novi imejl';

  @override
  String get shellConfirmNewPassword => 'Potvrdi novu lozinku';

  @override
  String get shellConfirmPassword => 'Potvrdi lozinku';

  @override
  String get shellContinueWithGoogle => 'Nastavi sa Google nalogom';

  @override
  String shellCouldNotOpenUrl(String url) {
    return 'Nije moguće otvoriti $url';
  }

  @override
  String get shellCreateAccount => 'Napravi nalog';

  @override
  String get shellCreateUser => 'Napravi korisnika';

  @override
  String get shellCurrentPassword => 'Trenutna lozinka';

  @override
  String get shellDeleteAccount => 'Obriši nalog';

  @override
  String get shellDeleteAccountFailed => 'Brisanje naloga nije uspelo';

  @override
  String get shellDeleteAccountMessage =>
      'Ovim se trajno brišu tvoj nalog, članarine i istorija plaćanja. Ovo se ne može poništiti.';

  @override
  String get shellDeleteAccountSubtitle => 'Trajno ukloni svoj nalog';

  @override
  String get shellDeleteAccountTitle => 'Obrisati nalog?';

  @override
  String get shellDeleteConfirmWord => 'OBRIŠI';

  @override
  String shellDeleteUserMessage(String name) {
    return 'Ovim se trajno brišu nalog, članarine i istorija plaćanja korisnika $name. Ovo se ne može poništiti.';
  }

  @override
  String shellDeleteUserTitle(String name) {
    return 'Obrisati korisnika $name?';
  }

  @override
  String shellEditBusiness(String name) {
    return 'Izmeni $name';
  }

  @override
  String shellEditUser(String name) {
    return 'Izmeni korisnika $name';
  }

  @override
  String get shellEditUserTitle => 'Izmena korisnika';

  @override
  String get shellForgotPasswordIntro =>
      'Unesi imejl i poslaćemo ti link za resetovanje lozinke.';

  @override
  String get shellForgotPasswordLink => 'Zaboravio si lozinku?';

  @override
  String get shellForgotPasswordTitle => 'Zaboravljena lozinka';

  @override
  String get shellGoToLogin => 'Idi na prijavu';

  @override
  String get shellGoogleFailed => 'Prijava preko Google naloga nije uspela';

  @override
  String get shellGoogleNoIdToken => 'Google nije vratio ID token';

  @override
  String get shellGoogleNotSupported =>
      'Prijava preko Google naloga nije podržana na ovom uređaju';

  @override
  String get shellGyms => 'Teretane';

  @override
  String get shellHaveAccountLogIn => 'Već imaš nalog? Prijavi se';

  @override
  String get shellHaveInviteCode => 'Imaš kod pozivnice?';

  @override
  String shellHello(String name) {
    return 'Zdravo, $name';
  }

  @override
  String shellHey(String name) {
    return 'Ćao, $name!';
  }

  @override
  String get shellHidePassword => 'Sakrij lozinku';

  @override
  String get shellHidePasswords => 'Sakrij lozinke';

  @override
  String get shellHomeBackToLogin => 'Nazad na prijavu';

  @override
  String get shellHomeLogOut => 'Odjavi se';

  @override
  String get shellHomeNotifications => 'Obaveštenja';

  @override
  String shellHomeNotificationsUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Obaveštenja, $count nepročitanih',
      few: 'Obaveštenja, $count nepročitana',
      one: 'Obaveštenja, $count nepročitano',
    );
    return '$_temp0';
  }

  @override
  String get shellHomeProfileLoadFailed => 'Učitavanje profila nije uspelo';

  @override
  String get shellHomeReturnToAdmin => 'Nazad na admin nalog';

  @override
  String shellHomeViewingAs(String name) {
    return 'Prikaz kao $name';
  }

  @override
  String get shellHubCheckIn => 'Prijava dolaska';

  @override
  String get shellHubCheckInSubtitle => 'Pokaži svoj kod na recepciji';

  @override
  String get shellHubClassesSubtitle => 'Pregledaj i rezerviši grupne časove';

  @override
  String get shellHubCommunity => 'Zajednica';

  @override
  String shellHubCommunityOpenFailed(String error) {
    return 'Zajednica nije mogla da se otvori: $error';
  }

  @override
  String get shellHubCommunitySubtitle =>
      'Objave i obaveštenja iz tvoje teretane';

  @override
  String get shellHubExercises => 'Vežbe';

  @override
  String get shellHubExercisesSubtitle => 'Pregledaj i uređuj vežbe';

  @override
  String get shellHubFoodDiary => 'Dnevnik ishrane';

  @override
  String get shellHubFoodDiarySubtitle => 'Beleži obroke i prati makroe';

  @override
  String get shellHubMealPlans => 'Planovi ishrane';

  @override
  String get shellHubMealPlansSubtitle => 'Namirnice, recepti i ishrana';

  @override
  String get shellHubNotLinked =>
      'Još nisi povezan ni sa jednom teretanom ili prodavnicom';

  @override
  String get shellHubProgress => 'Napredak';

  @override
  String get shellHubSessions => 'Sesije';

  @override
  String get shellHubSessionsSubtitle => 'Beleži i pregledaj svoje sesije';

  @override
  String get shellHubStore => 'Prodavnica';

  @override
  String get shellHubStoreSubtitle => 'Suplementi, oprema i tvoje porudžbine';

  @override
  String get shellHubWorkouts => 'Treninzi';

  @override
  String get shellHubWorkoutsSubtitle => 'Treninzi i rutine';

  @override
  String get shellImageAddPhoto => 'Dodaj fotografiju';

  @override
  String get shellImageChange => 'Promeni fotografiju';

  @override
  String get shellImageChooseFromGallery => 'Izaberi iz galerije';

  @override
  String get shellImageTakePhoto => 'Fotografiši';

  @override
  String shellImageUploadFailed(String error) {
    return 'Otpremanje nije uspelo: $error';
  }

  @override
  String get shellImageUploading => 'Otpremanje fotografije';

  @override
  String shellImpersonateBody(String email) {
    return 'Videćeš aplikaciju tačno kao $email i moći ćeš da radiš u njegovo ime. Ovo se beleži u dnevniku aktivnosti. Koristi „Nazad na admin nalog“ (ili se odjavi) da se vratiš na svoj nalog.';
  }

  @override
  String get shellImpersonateConfirm => 'Prijavi se kao korisnik';

  @override
  String shellImpersonateTitle(String name) {
    return 'Prijaviti se kao $name?';
  }

  @override
  String get shellInvitationTitle => 'Pozivnica';

  @override
  String shellInviteAccept(String entity) {
    return 'Prihvati — pridruži se timu $entity';
  }

  @override
  String get shellInviteAccepted => 'Prihvaćeno';

  @override
  String shellInviteBody(String entity, String role) {
    return 'Pozvan si da radiš u timu $entity kao $role.';
  }

  @override
  String get shellInviteCode => 'Kod pozivnice';

  @override
  String get shellInviteCodeHint => 'Šestocifreni kod';

  @override
  String get shellInviteCodeInvalid => 'Unesi šestocifreni kod';

  @override
  String get shellInviteDecline => 'Odbij';

  @override
  String get shellInviteDeclined => 'Odbio si ovu pozivnicu';

  @override
  String get shellInviteDeclinedChip => 'Odbijeno';

  @override
  String shellInviteJoined(String entity, String role) {
    return 'Pridružio si se timu $entity kao $role';
  }

  @override
  String get shellInviteOrganisationFallback => 'organizacije';

  @override
  String get shellInvitePending => 'Čeka odgovor';

  @override
  String get shellInvoices => 'Fakture';

  @override
  String get shellLoadMore => 'Učitaj još';

  @override
  String get shellLogIn => 'Prijavi se';

  @override
  String get shellLogInInstead => 'Prijavi se umesto toga';

  @override
  String get shellMarkAllRead => 'Označi sve kao pročitano';

  @override
  String shellMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count članova',
      few: '$count člana',
      one: '$count član',
    );
    return '$_temp0';
  }

  @override
  String get shellMembersYouCoach => 'Članovi koje treniraš';

  @override
  String get shellMembershipActive => 'Aktivna';

  @override
  String get shellMembershipLoadFailed => 'Učitavanje članarine nije uspelo';

  @override
  String shellMembershipValidUntil(String type, String date) {
    return '$type · važi do $date';
  }

  @override
  String get shellMuteBilling => 'Plaćanja';

  @override
  String get shellMuteBillingDescription =>
      'Fakture, uplate i članarine koje ističu';

  @override
  String get shellMuteClasses => 'Časovi';

  @override
  String get shellMuteClassesDescription =>
      'Podsetnici, izmene i otkazivanja časova';

  @override
  String get shellMuteCoaching => 'Trening sa trenerom';

  @override
  String get shellMuteCoachingDescription =>
      'Dodeljene rutine i planovi, komentari na treninge';

  @override
  String get shellMuteCommunity => 'Zajednica';

  @override
  String get shellMuteCommunityDescription =>
      'Vesti iz teretane i komentari na tvoje objave';

  @override
  String get shellMuteFootnote =>
      'Pozivnice uvek stižu. Utišana obaveštenja se i dalje prikazuju u aplikaciji.';

  @override
  String get shellMuteShop => 'Prodavnica';

  @override
  String get shellMuteShopDescription =>
      'Status porudžbina, nove porudžbine i dopune zaliha';

  @override
  String get shellMuteStaff => 'Osoblje';

  @override
  String get shellMuteStaffDescription => 'Smene i novi ljudi u tvom biznisu';

  @override
  String get shellMyMembership => 'Moja članarina';

  @override
  String get shellMyOrders => 'Moje porudžbine';

  @override
  String get shellMyOrdersSubtitle => 'Porudžbine iz prodavnice i preuzimanja';

  @override
  String get shellMyProgress => 'Moj napredak';

  @override
  String get shellMyProgressSubtitle => 'Dizanja, telesna težina i nizovi';

  @override
  String get shellNewEmail => 'Novi imejl';

  @override
  String get shellNewPassword => 'Nova lozinka';

  @override
  String get shellNewUserTitle => 'Novi korisnik';

  @override
  String get shellNoAccountSignUp => 'Nemaš nalog? Registruj se';

  @override
  String get shellNoActiveMembership => 'Nemaš aktivnu članarinu';

  @override
  String get shellNoBusinesses => 'Još nema biznisa';

  @override
  String get shellNoCoachedMembers =>
      'Još nema članova u teretanama u kojima treniraš';

  @override
  String shellNoLongerMember(String name) {
    return '$name više nije član';
  }

  @override
  String shellNoMembersMatch(String query) {
    return 'Nijedan član ne odgovara pretrazi „$query“';
  }

  @override
  String get shellNoNotifications => 'Još nema obaveštenja';

  @override
  String get shellNoSessionsToday => 'Danas nemaš treninge';

  @override
  String get shellNoUsers => 'Još nema korisnika';

  @override
  String get shellNoUsersFound => 'Nema pronađenih korisnika';

  @override
  String get shellNoneScheduled => 'Ništa nije zakazano';

  @override
  String get shellNotAVendor => 'Još nisi prodavac ni u jednoj prodavnici';

  @override
  String get shellNotAssignedToGym => 'Još nisi dodeljen nijednoj teretani';

  @override
  String get shellNotificationUnread => 'Nepročitano';

  @override
  String get shellOffline => 'Nisi na mreži — prikazuju se sačuvani podaci';

  @override
  String shellOfflinePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Nisi na mreži — prikazuju se sačuvani podaci · $count izmena čeka sinhronizaciju',
      few:
          'Nisi na mreži — prikazuju se sačuvani podaci · $count izmene čekaju sinhronizaciju',
      one:
          'Nisi na mreži — prikazuju se sačuvani podaci · $count izmena čeka sinhronizaciju',
    );
    return '$_temp0';
  }

  @override
  String get shellOr => 'ili';

  @override
  String shellOrdersForShop(String shop) {
    return 'Porudžbine · $shop';
  }

  @override
  String get shellOwnerAllInvoices => 'Sve fakture';

  @override
  String get shellOwnerNoGyms =>
      'Još nemaš nijednu teretanu — dodaj je na kartici Biznisi.';

  @override
  String get shellPasswordChanged => 'Lozinka je promenjena';

  @override
  String get shellPasswordsDontMatch => 'Lozinke se ne poklapaju';

  @override
  String get shellPlatformOverview => 'Pregled platforme';

  @override
  String get shellProfileUpdated => 'Profil je ažuriran';

  @override
  String get shellPushChannelDescription =>
      'Podsetnici za časove, porudžbine, članarine i poruke';

  @override
  String get shellPushNotifications => 'Push obaveštenja';

  @override
  String get shellPushNotificationsSubtitle => 'Upozorenja na ovom telefonu';

  @override
  String get shellPushUnavailable =>
      'Push obaveštenja nisu dostupna u ovoj verziji. Sve ćeš i dalje naći pod ikonom zvona; ova podešavanja važe na uređajima koji podržavaju push.';

  @override
  String shellResetLinkSent(String email) {
    return 'Poslali smo link za resetovanje lozinke na $email.';
  }

  @override
  String get shellResetPasswordIntro => 'Unesi novu lozinku za svoj nalog.';

  @override
  String get shellResetPasswordTitle => 'Resetovanje lozinke';

  @override
  String get shellRole => 'Uloga';

  @override
  String get shellRoleEmployee => 'Zaposleni';

  @override
  String get shellRoleEmployeeTrainer => 'Zaposleni / trener';

  @override
  String get shellRoleEmployeeTrainerShort => 'Zap. trener';

  @override
  String get shellRoleGymOwner => 'Vlasnik teretane';

  @override
  String get shellRoleMember => 'Član';

  @override
  String get shellRoleOwner => 'Vlasnik';

  @override
  String get shellRoleShopOwner => 'Vlasnik prodavnice';

  @override
  String get shellRoleShopVendor => 'Prodavac';

  @override
  String get shellRoleSuperUser => 'Super korisnik';

  @override
  String get shellRoleTrainer => 'Trener';

  @override
  String get shellRoleVendor => 'Prodavac';

  @override
  String get shellSaveChanges => 'Sačuvaj izmene';

  @override
  String get shellScanCheckIns => 'Skeniraj dolaske';

  @override
  String get shellSearchMembers => 'Pretraži članove';

  @override
  String get shellSendLink => 'Pošalji link';

  @override
  String get shellSendMePushesAbout => 'Šalji mi obaveštenja o';

  @override
  String get shellSendResetLink => 'Pošalji link za resetovanje';

  @override
  String get shellSessionInProgress => 'Trening u toku';

  @override
  String shellSessionStartedInProgress(String time) {
    return 'Počeo u $time · u toku';
  }

  @override
  String get shellSetNewPassword => 'Postavi novu lozinku';

  @override
  String get shellSettings => 'Podešavanja';

  @override
  String get shellSettingsAccount => 'Nalog';

  @override
  String get shellSettingsAppearance => 'Izgled';

  @override
  String shellSettingsSaveFailed(String error) {
    return 'Čuvanje nije uspelo: $error';
  }

  @override
  String get shellSettingsSubtitle => 'Tema, jedinice, obaveštenja, nalog';

  @override
  String get shellSettingsTheme => 'Tema';

  @override
  String get shellSettingsUnits => 'Jedinice';

  @override
  String get shellSettingsWeight => 'Težina';

  @override
  String get shellShops => 'Prodavnice';

  @override
  String get shellShowMore => 'Prikaži još';

  @override
  String get shellShowPassword => 'Prikaži lozinku';

  @override
  String get shellShowPasswords => 'Prikaži lozinke';

  @override
  String get shellSignInAsThisUser => 'Prijavi se kao ovaj korisnik';

  @override
  String get shellSignUp => 'Registruj se';

  @override
  String get shellSignupEmailTaken => 'Nalog sa ovim imejlom već postoji.';

  @override
  String get shellSignupEnterCode => 'Unesi kod';

  @override
  String shellSignupPendingInviteBody(String email) {
    return 'Nalog za $email je već napravljen preko pozivnice. Ponovo smo poslali imejl sa pozivnicom — unesi šestocifreni kod iz njega da aktiviraš nalog.';
  }

  @override
  String get shellSignupPendingInviteTitle => 'Imaš pozivnicu na čekanju';

  @override
  String get shellStatsActiveMemberships => 'Aktivne članarine';

  @override
  String shellStatsEndsInDays(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'za $days dana ($date)',
      few: 'za $days dana ($date)',
      one: 'za $days dan ($date)',
    );
    return '$_temp0';
  }

  @override
  String shellStatsEndsOn(String gym, String when) {
    return '$gym · ističe $when';
  }

  @override
  String get shellStatsEndsToday => 'danas';

  @override
  String get shellStatsEndsTomorrow => 'sutra';

  @override
  String get shellStatsExpiringSoon => 'Uskoro ističu';

  @override
  String shellStatsGymCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count teretana',
      few: '$count teretane',
      one: '$count teretana',
    );
    return '$_temp0';
  }

  @override
  String get shellStatsInvoicesThisMonth => 'Fakture ovog meseca';

  @override
  String get shellStatsMembers => 'Članovi';

  @override
  String get shellStatsNext14Days => 'narednih 14 dana';

  @override
  String get shellStatsNoneExpiring =>
      'Nijedna članarina ne ističe u naredne dve nedelje';

  @override
  String get shellStatsStaff => 'Osoblje';

  @override
  String get shellStatsUnpaidInvoices => 'Neplaćene fakture';

  @override
  String get shellTabBusinesses => 'Biznisi';

  @override
  String get shellTabClasses => 'Časovi';

  @override
  String get shellTabGym => 'Teretana';

  @override
  String get shellTabHome => 'Početna';

  @override
  String get shellTabMembers => 'Članovi';

  @override
  String get shellTabMembership => 'Članarina';

  @override
  String get shellTabMyShop => 'Moja prodavnica';

  @override
  String get shellTabProfile => 'Profil';

  @override
  String get shellTabSchedule => 'Raspored';

  @override
  String get shellTabUsers => 'Korisnici';

  @override
  String get shellThemeDark => 'Tamna';

  @override
  String get shellThemeLight => 'Svetla';

  @override
  String get shellThemeSystem => 'Sistemska';

  @override
  String shellTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pre $count dana',
      few: 'pre $count dana',
      one: 'pre $count dan',
    );
    return '$_temp0';
  }

  @override
  String shellTimeDaysShort(int count) {
    return '$count d';
  }

  @override
  String shellTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pre $count sati',
      few: 'pre $count sata',
      one: 'pre $count sat',
    );
    return '$_temp0';
  }

  @override
  String shellTimeHoursShort(int count) {
    return '$count h';
  }

  @override
  String shellTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pre $count minuta',
      few: 'pre $count minuta',
      one: 'pre $count minut',
    );
    return '$_temp0';
  }

  @override
  String shellTimeMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get shellTimeNow => 'sada';

  @override
  String get shellTodaysSessions => 'Današnji treninzi';

  @override
  String shellTypeToConfirm(String text) {
    return 'Ukucaj $text za potvrdu.';
  }

  @override
  String get shellUnavailable => 'Nedostupno';

  @override
  String get shellUnitKilograms => 'Kilogrami';

  @override
  String get shellUnitPounds => 'Funte';

  @override
  String get shellUpcomingClasses => 'Predstojeći časovi';

  @override
  String get shellUserSearchAdd => 'Dodaj';

  @override
  String shellUserSearchAddLabel(String name) {
    return 'Dodaj korisnika $name';
  }

  @override
  String get shellUserSearchAdding => 'Dodavanje';

  @override
  String get shellUserSearchHint => 'Pretraži po imenu ili korisničkom imenu';

  @override
  String shellWelcome(String name) {
    return 'Dobro došao, $name';
  }

  @override
  String shellWelcomeBack(String name) {
    return 'Dobro došao nazad, $name';
  }

  @override
  String get shellYourGym => 'Tvoja teretana';

  @override
  String get shellYourGyms => 'Tvoje teretane';

  @override
  String get shellYourShop => 'Tvoja prodavnica';

  @override
  String get shellYourShops => 'Tvoje prodavnice';

  @override
  String get trainingAssignAction => 'Dodeli';

  @override
  String trainingAssignAssignedOn(String date) {
    return 'Dodeljeno $date';
  }

  @override
  String get trainingAssignClearDates => 'Obriši datume';

  @override
  String trainingAssignConfirm(String routine, String name) {
    return 'Dodeliti program „$routine“ članu $name?';
  }

  @override
  String trainingAssignConfirmSelf(String routine) {
    return 'Dodeliti program „$routine“ sebi?';
  }

  @override
  String get trainingAssignDialogTitle => 'Dodeli program';

  @override
  String trainingAssignDone(String routine, String name) {
    return 'Program „$routine“ je dodeljen članu $name';
  }

  @override
  String trainingAssignDoneSelf(String routine) {
    return 'Program „$routine“ je dodeljen tebi';
  }

  @override
  String get trainingAssignEnd => 'Kraj';

  @override
  String trainingAssignEnds(String date) {
    return 'Završava se $date';
  }

  @override
  String get trainingAssignNoRoutines => 'Nema pronađenih programa';

  @override
  String get trainingAssignNoteHint =>
      'npr. Fokus na tehniku, 3 treninga nedeljno';

  @override
  String get trainingAssignNoteLabel => 'Napomena (opciono)';

  @override
  String trainingAssignPickerTitle(String routine) {
    return 'Kome dodeliti „$routine“?';
  }

  @override
  String get trainingAssignRemoveAction => 'Ukloni';

  @override
  String trainingAssignRemoveBody(String routine) {
    return 'Program „$routine“ više neće biti dodeljen.';
  }

  @override
  String trainingAssignRemoveBodyUser(String routine, String name) {
    return 'Program „$routine“ više neće biti dodeljen članu $name.';
  }

  @override
  String get trainingAssignRemoveTitle => 'Ukloniti dodelu?';

  @override
  String get trainingAssignRemoveTooltip => 'Ukloni dodelu';

  @override
  String get trainingAssignSearchRoutinesHint => 'Pretraži programe…';

  @override
  String get trainingAssignStart => 'Početak';

  @override
  String trainingAssignStarts(String date) {
    return 'Počinje $date';
  }

  @override
  String get trainingBookingAttended => 'Prisustvovao/la';

  @override
  String get trainingBookingBooked => 'Rezervisano';

  @override
  String get trainingBookingCancelled => 'Otkazano';

  @override
  String get trainingBookingNoShow => 'Nije došao/la';

  @override
  String get trainingBookingWaitlisted => 'Na listi čekanja';

  @override
  String get trainingChartDefaultSeries => 'Napredak';

  @override
  String get trainingChartNoData => 'Nema podataka za ovaj period';

  @override
  String trainingChartSummary(String series, String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tačaka',
      few: '$count tačke',
      one: '$count tačka',
    );
    return 'Grafikon: $series, $_temp0, poslednja vrednost $value';
  }

  @override
  String get trainingClassAbout => 'O času';

  @override
  String get trainingClassApplyToSeries => 'Primeni na ovaj i buduće časove';

  @override
  String get trainingClassApplyToSeriesOff => 'Menja se samo ovaj čas';

  @override
  String get trainingClassApplyToSeriesOn =>
      'Izmene važe za sve kasnije časove u ovoj nedeljnoj seriji';

  @override
  String trainingClassAttendedOf(int attended, int total) {
    return 'Prisutno $attended/$total';
  }

  @override
  String get trainingClassAttendedUndo =>
      'Prisustvovao/la (dodirni da poništiš)';

  @override
  String get trainingClassBook => 'Rezerviši';

  @override
  String trainingClassBookedAt(String when) {
    return 'Rezervisano $when';
  }

  @override
  String trainingClassBookedFor(String title) {
    return 'Rezervisao/la si mesto na času $title';
  }

  @override
  String trainingClassBookedOf(int booked, int capacity) {
    return 'Rezervisano $booked/$capacity';
  }

  @override
  String get trainingClassBookingCancelled => 'Rezervacija je otkazana';

  @override
  String get trainingClassBrowse => 'Pregledaj časove';

  @override
  String get trainingClassCancelBooking => 'Otkaži rezervaciju';

  @override
  String trainingClassCancelBookingMessage(String title) {
    return 'Tvoje mesto na času $title dobiće sledeća osoba sa liste čekanja.';
  }

  @override
  String get trainingClassCancelBookingQuestion => 'Otkazati rezervaciju?';

  @override
  String get trainingClassCancelClass => 'Otkaži čas';

  @override
  String trainingClassCancelNotifyPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count osoba sa rezervacijom ili na listi čekanja biće obavešteno.',
      few: '$count osobe sa rezervacijom ili na listi čekanja biće obaveštene.',
      one: '$count osoba sa rezervacijom ili na listi čekanja biće obaveštena.',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassCancelQuestion => 'Otkazati čas?';

  @override
  String get trainingClassCancelThisAndFuture =>
      'Otkaži ovaj i sve buduće časove';

  @override
  String get trainingClassCancelThisOnly => 'Otkaži samo ovaj čas';

  @override
  String get trainingClassCancelled => 'Otkazano';

  @override
  String get trainingClassCapacity => 'Popunjenost';

  @override
  String trainingClassCapacityBelowBooked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Već je rezervisalo $count osoba',
      few: 'Već su rezervisale $count osobe',
      one: 'Već je rezervisala $count osoba',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassCapacityHelper => 'Ostali idu na listu čekanja';

  @override
  String get trainingClassCapacityMax => 'To je mnogo ljudi — najviše 500';

  @override
  String get trainingClassCapacityMin => 'Unesi najmanje 1';

  @override
  String get trainingClassClassCancelled => 'Čas je otkazan';

  @override
  String get trainingClassClasses => 'Grupni treninzi';

  @override
  String get trainingClassClassesCancelled => 'Časovi su otkazani';

  @override
  String trainingClassCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count časova',
      few: '$count časa',
      one: '$count čas',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassCreate => 'Napravi čas';

  @override
  String get trainingClassCreateOne => 'Napravi čas';

  @override
  String get trainingClassCreated => 'Čas je napravljen';

  @override
  String get trainingClassCurrentTrainer => 'Trenutni trener';

  @override
  String get trainingClassDescriptionOptional => 'Opis (opciono)';

  @override
  String get trainingClassDuration => 'Trajanje';

  @override
  String get trainingClassEdit => 'Izmeni čas';

  @override
  String get trainingClassEnded => 'Ovaj čas je završen.';

  @override
  String trainingClassEndsAt(String time) {
    return 'Završava se u $time';
  }

  @override
  String get trainingClassFull => 'Popunjeno';

  @override
  String trainingClassFullWaiting(int count) {
    return 'Popunjeno · $count čeka';
  }

  @override
  String get trainingClassGym => 'Teretana';

  @override
  String get trainingClassInProgress => 'Ovaj čas je u toku.';

  @override
  String get trainingClassJoinWaitlist => 'Na listu čekanja';

  @override
  String get trainingClassJumpToNext => 'Idi na sledeći čas';

  @override
  String get trainingClassKeep => 'Zadrži';

  @override
  String get trainingClassKeepClass => 'Zadrži čas';

  @override
  String get trainingClassLeaveWaitlist => 'Napusti listu čekanja';

  @override
  String trainingClassLeaveWaitlistMessage(String title) {
    return 'Izgubićeš svoje mesto na listi čekanja za $title.';
  }

  @override
  String get trainingClassLeaveWaitlistQuestion => 'Napustiti listu čekanja?';

  @override
  String get trainingClassLocationHint => 'npr. Sala A';

  @override
  String get trainingClassLocationOptional => 'Lokacija (opciono)';

  @override
  String get trainingClassMarkAttended => 'Označi prisustvo';

  @override
  String get trainingClassMarkNoShow => 'Označi da nije došao/la';

  @override
  String get trainingClassMember => 'Član';

  @override
  String get trainingClassMore => 'Još';

  @override
  String get trainingClassMyBookings => 'Moje rezervacije';

  @override
  String trainingClassMyBookingsCount(int count) {
    return 'Moje rezervacije ($count)';
  }

  @override
  String get trainingClassMyClasses => 'Moji časovi';

  @override
  String trainingClassNameYou(String name) {
    return '$name (ti)';
  }

  @override
  String get trainingClassNew => 'Novi čas';

  @override
  String trainingClassNextClass(String title, String day, String time) {
    return 'Sledeći čas: $title, $day u $time.';
  }

  @override
  String get trainingClassNoBookings => 'Još nemaš rezervacija';

  @override
  String get trainingClassNoBookingsMessage =>
      'Ovde se prikazuju časovi koje rezervišeš ili za koje si na listi čekanja.';

  @override
  String get trainingClassNoBookingsYet => 'Još niko nije rezervisao';

  @override
  String get trainingClassNoGyms => 'Nema teretana za zakazivanje';

  @override
  String get trainingClassNoGymsMessage =>
      'Časove možeš da praviš u teretanama u kojima si trener, zaposleni ili vlasnik.';

  @override
  String get trainingClassNoPast => 'Nema prošlih časova';

  @override
  String trainingClassNoPastMessage(int days) {
    return 'Ovde se prikazuju časovi koje si držao/la u poslednjih $days dana.';
  }

  @override
  String get trainingClassNoShowUndo => 'Nije došao/la (dodirni da poništiš)';

  @override
  String get trainingClassNoTrainer => 'Bez trenera';

  @override
  String get trainingClassNoUpcoming => 'Nema predstojećih časova';

  @override
  String get trainingClassNoUpcomingMessage =>
      'Zakaži jednokratni čas ili nedeljnu seriju i članovi će moći da rezervišu.';

  @override
  String get trainingClassNobodyBooked => 'Još niko nije rezervisao.';

  @override
  String get trainingClassNoneScheduled => 'Nema zakazanih časova';

  @override
  String get trainingClassNoneScheduledMessage =>
      'Tvoje teretane nisu zakazale časove za naredne dve nedelje. Proveri ponovo uskoro.';

  @override
  String get trainingClassNoneThisWeek => 'Nema časova ove nedelje';

  @override
  String get trainingClassNoneThisWeekCreate =>
      'Napravi čas ili nedeljnu seriju časova koje članovi mogu da rezervišu.';

  @override
  String get trainingClassNoneThisWeekMessage =>
      'Za ovu nedelju još ništa nije zakazano.';

  @override
  String get trainingClassNotSignedIn => 'Nisi prijavljen/a';

  @override
  String trainingClassNothingOn(String day) {
    return 'Nema časova — $day';
  }

  @override
  String get trainingClassNotifyOnChange =>
      'Oni koji su rezervisali biće obavešteni ako se promeni vreme ili lokacija.';

  @override
  String get trainingClassOneOff => 'Jednokratni čas';

  @override
  String get trainingClassPast => 'Prošli';

  @override
  String get trainingClassRefresh => 'Osveži';

  @override
  String get trainingClassRemove => 'Ukloni';

  @override
  String get trainingClassRemoveBookedMessage =>
      'Mesto će dobiti sledeća osoba sa liste čekanja.';

  @override
  String get trainingClassRemoveFromClass => 'Ukloni sa časa';

  @override
  String trainingClassRemoveQuestion(String name) {
    return 'Ukloniti: $name?';
  }

  @override
  String get trainingClassRemoveWaitlistMessage =>
      'Biće uklonjen/a sa liste čekanja.';

  @override
  String trainingClassRepeatSummary(String weekday, int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks nedelja',
      few: '$weeks nedelje',
      one: '$weeks nedelje',
    );
    return 'Svake nedelje ($weekday) tokom $_temp0';
  }

  @override
  String get trainingClassRepeatWeekly => 'Ponavljaj svake nedelje';

  @override
  String get trainingClassRoster => 'Spisak polaznika';

  @override
  String get trainingClassSaveChanges => 'Sačuvaj izmene';

  @override
  String get trainingClassSpots => 'Mesta';

  @override
  String trainingClassSpotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Još $count mesta',
      few: 'Još $count mesta',
      one: 'Još $count mesto',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassStartInFuture => 'Izaberi vreme početka u budućnosti';

  @override
  String get trainingClassTitle => 'Čas';

  @override
  String get trainingClassTitleHint => 'npr. Jutarnji HIIT';

  @override
  String get trainingClassTitleLabel => 'Naziv';

  @override
  String get trainingClassTitleRequired => 'Unesi naziv časa';

  @override
  String get trainingClassUpcoming => 'Predstojeći';

  @override
  String trainingClassUpcomingCount(int count) {
    return 'Predstojeći ($count)';
  }

  @override
  String get trainingClassUpdated => 'Čas je izmenjen';

  @override
  String trainingClassWaitlistCount(int count) {
    return 'Lista čekanja ($count)';
  }

  @override
  String trainingClassWaitlistJoined(int position) {
    return 'Čas je popunjen. Ti si #$position na listi čekanja.';
  }

  @override
  String get trainingClassWaitlistJoinedNoPosition =>
      'Čas je popunjen. Na listi čekanja si.';

  @override
  String trainingClassWaitlistPosition(int position) {
    return '#$position na listi čekanja';
  }

  @override
  String trainingClassWaitlistedPosition(int position) {
    return 'Lista čekanja #$position';
  }

  @override
  String get trainingClassWasCancelled => 'Ovaj čas je otkazan';

  @override
  String get trainingClassWeekly => 'Nedeljni čas';

  @override
  String trainingClassWeeklyCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Napravljeno je $count nedeljnih časova',
      few: 'Napravljena su $count nedeljna časa',
      one: 'Napravljen je $count nedeljni čas',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassWeeklySeries => 'Deo nedeljne serije časova';

  @override
  String get trainingClassWeeks => 'Nedelje';

  @override
  String trainingClassWeeksValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nedelja',
      few: '$count nedelje',
      one: '$count nedelja',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassWhen => 'Kada';

  @override
  String get trainingClassYou => 'Ti';

  @override
  String get trainingCoachChooseMember => 'Izaberi člana';

  @override
  String get trainingCoachMyself => 'Ja';

  @override
  String get trainingCoachNoMatches => 'Nijedan član ne odgovara pretrazi';

  @override
  String get trainingCoachNoMembers =>
      'Još nemaš članove koje treniraš. Ovde se prikazuju članovi teretana u kojima radiš ili treniraš.';

  @override
  String get trainingCoachNotSignedIn => 'Nisi prijavljen';

  @override
  String get trainingCoachSearchHint => 'Pretraži članove…';

  @override
  String get trainingCoachYou => 'ti';

  @override
  String trainingDropCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dropova',
      few: '$count dropa',
      one: '$count drop',
    );
    return '$_temp0';
  }

  @override
  String get trainingExerciseAddPhoto => 'Dodaj fotografiju vežbe';

  @override
  String get trainingExerciseAllMuscles => 'Svi mišići';

  @override
  String trainingExerciseAlternating(String name) {
    return '$name (naizmenično)';
  }

  @override
  String get trainingExerciseClearFilter => 'Ukloni filter';

  @override
  String get trainingExerciseDeleteTitle => 'Obrisati vežbu?';

  @override
  String get trainingExerciseDone => 'Gotovo';

  @override
  String get trainingExerciseEditTitle => 'Izmeni vežbu';

  @override
  String get trainingExerciseFallbackName => 'Vežba';

  @override
  String trainingExerciseFilterActiveTooltip(String muscle) {
    return 'Filtriraj po mišiću (trenutno: $muscle)';
  }

  @override
  String get trainingExerciseFilterTitle => 'Filtriraj po mišiću';

  @override
  String get trainingExerciseFilterTooltip => 'Filtriraj po mišiću';

  @override
  String get trainingExerciseMyPrivate => 'Moje privatne';

  @override
  String get trainingExerciseNameLabel => 'Naziv vežbe *';

  @override
  String get trainingExerciseNewTitle => 'Nova vežba';

  @override
  String get trainingExerciseNoPrivate => 'Nemaš privatnih vežbi';

  @override
  String get trainingExerciseNoneFound => 'Nema pronađenih vežbi';

  @override
  String trainingExercisePhoto(String name) {
    return 'Fotografija: $name';
  }

  @override
  String get trainingExercisePrimaryMuscles => 'Primarni mišići';

  @override
  String get trainingExerciseSearchHint => 'Pretraži vežbe…';

  @override
  String get trainingExerciseSecondaryMuscles => 'Sekundarni mišići';

  @override
  String get trainingExerciseTapToSelect => 'Dodirni za izbor';

  @override
  String get trainingExerciseTargetMuscles => 'Ciljni mišići';

  @override
  String get trainingExerciseTitle => 'Vežbe';

  @override
  String get trainingExerciseVideo => 'Video';

  @override
  String get trainingExerciseVideoUrl => 'Link do videa';

  @override
  String get trainingLogBodyweightHint => 'Prazno = telesna težina';

  @override
  String get trainingLogChooseExercise => 'Dodirni da izabereš vežbu';

  @override
  String trainingLogCouldNotLogSet(String error) {
    return 'Serija nije zabeležena: $error';
  }

  @override
  String get trainingLogCouldNotStart => 'Pokretanje nije uspelo';

  @override
  String trainingLogElapsed(String time) {
    return 'Proteklo vreme $time';
  }

  @override
  String get trainingLogEnterReps => 'Unesi broj ponavljanja';

  @override
  String trainingLogEstimated1rm(String weight) {
    return 'Procenjeni 1RM ≈ $weight';
  }

  @override
  String get trainingLogExercise => 'Vežba';

  @override
  String get trainingLogFinish => 'Završi';

  @override
  String get trainingLogFinishMessage =>
      'Ovim se beleži vreme završetka treninga.';

  @override
  String get trainingLogFinishMessageOffline =>
      'Ovim se beleži vreme završetka treninga. Serije sačuvane oflajn sinhronizovaće se kad ponovo budeš onlajn.';

  @override
  String get trainingLogFinishTitle => 'Završiti trening?';

  @override
  String get trainingLogFirstSetHint => 'Dodirni dole da zabeležiš prvu seriju';

  @override
  String get trainingLogKeepGoing => 'Nastavi';

  @override
  String get trainingLogLog => 'Zabeleži';

  @override
  String get trainingLogLogASet => 'Zabeleži seriju';

  @override
  String get trainingLogLogSet => 'Zabeleži seriju';

  @override
  String get trainingLogLogged => 'Zabeleženo';

  @override
  String trainingLogNewPr(String exercise) {
    return 'Novi PR! $exercise';
  }

  @override
  String get trainingLogNewPrShort => 'Novi PR';

  @override
  String trainingLogNewPrWithE1rm(String exercise, String weight) {
    return 'Novi PR! $exercise — e1RM $weight';
  }

  @override
  String get trainingLogOfflineSaved =>
      'Sačuvano oflajn — sinhronizovaće se kad ponovo budeš onlajn';

  @override
  String get trainingLogPending => 'Na čekanju';

  @override
  String get trainingLogPendingSync => 'Čeka sinhronizaciju';

  @override
  String get trainingLogPickExercise => 'Prvo izaberi vežbu';

  @override
  String get trainingLogPlateTooltip => 'Kalkulator tegova i zagrevanje';

  @override
  String get trainingLogRepType => 'Tip ponavljanja';

  @override
  String get trainingLogSavedOfflineTooltip =>
      'Sačuvano oflajn — biće sinhronizovano';

  @override
  String trainingLogSetHeader(int number, String type) {
    return 'Serija $number · $type';
  }

  @override
  String trainingLogSetHeaderWithRest(int number, String type, String rest) {
    return 'Serija $number · $type · odmor $rest';
  }

  @override
  String get trainingLogStartRest => 'Pokreni tajmer odmora';

  @override
  String get trainingLogStarting => 'Pokrećem trening…';

  @override
  String get trainingLogWeight => 'Težina';

  @override
  String get trainingMeasureAdd => 'Dodaj';

  @override
  String get trainingMeasureBodyFatOptional => 'Procenat masti (opciono)';

  @override
  String trainingMeasureBodyFatValue(String value) {
    return '$value % masti';
  }

  @override
  String get trainingMeasureBodyWeight => 'Telesna težina';

  @override
  String trainingMeasureChangeSince(String change, String date) {
    return '$change od $date';
  }

  @override
  String trainingMeasureDateLabel(String date) {
    return 'Datum: $date';
  }

  @override
  String trainingMeasureDeleteMessage(String date) {
    return 'Unos od $date biće uklonjen.';
  }

  @override
  String get trainingMeasureDeleteTitle => 'Obrisati merenje?';

  @override
  String get trainingMeasureDeleteTooltip => 'Obriši merenje';

  @override
  String get trainingMeasureEditTitle => 'Izmeni merenje';

  @override
  String get trainingMeasureEmptyMessageOther => 'Još ništa nije zabeleženo.';

  @override
  String get trainingMeasureEmptyMessageOwn =>
      'Redovno beleži telesnu težinu da bi ovde video/la trend.';

  @override
  String get trainingMeasureEmptyTitle => 'Još nema merenja';

  @override
  String get trainingMeasureInvalidNumbers => 'Unesi ispravne brojeve';

  @override
  String get trainingMeasureLogAction => 'Zabeleži merenje';

  @override
  String get trainingMeasureLogHeading => 'Dnevnik';

  @override
  String get trainingMeasureNeedValue => 'Unesi težinu ili procenat masti';

  @override
  String get trainingMeasureNoteOptional => 'Beleška (opciono)';

  @override
  String get trainingMemberAssign => 'Dodeli';

  @override
  String get trainingMemberAssignMealPlan => 'Dodeli plan ishrane';

  @override
  String get trainingMemberAssignRoutine => 'Dodeli program';

  @override
  String trainingMemberAssignedBy(String name) {
    return 'Dodelio/la: $name';
  }

  @override
  String get trainingMemberAssignedByAnotherCoach => 'Dodelio drugi trener';

  @override
  String get trainingMemberAssignedByYou => 'Dodelio/la si ti';

  @override
  String get trainingMemberFoodDiary => 'Dnevnik ishrane';

  @override
  String get trainingMemberFoodDiarySubtitle => 'Obroci i makroi';

  @override
  String get trainingMemberMealPlans => 'Planovi ishrane';

  @override
  String get trainingMemberNoMealPlans => 'Nema dodeljenih planova ishrane';

  @override
  String get trainingMemberNoRoutines => 'Nema dodeljenih programa';

  @override
  String get trainingMemberNoSessions => 'Još nema zabeleženih treninga';

  @override
  String get trainingMemberProgramWorkout => 'Trening iz programa';

  @override
  String get trainingMemberProgressSubtitle =>
      'Rekordi, volumen, telesna težina';

  @override
  String get trainingMemberRecentSessions => 'Nedavni treninzi';

  @override
  String get trainingMemberRemove => 'Ukloni';

  @override
  String trainingMemberRemoveAssignmentMessage(String plan, String member) {
    return '„$plan“ više neće biti dodeljen korisniku $member.';
  }

  @override
  String get trainingMemberRemoveAssignmentTitle => 'Ukloniti dodelu?';

  @override
  String get trainingMemberRoutines => 'Programi';

  @override
  String get trainingMemberSelfAssigned => 'Samostalno dodeljeno';

  @override
  String get trainingMuscleAbsLower => 'Donji trbušnjaci';

  @override
  String get trainingMuscleAbsObliques => 'Kosi trbušnjaci';

  @override
  String get trainingMuscleAbsUpper => 'Gornji trbušnjaci';

  @override
  String get trainingMuscleBackAll => 'Leđa';

  @override
  String get trainingMuscleBackLats => 'Latisimus';

  @override
  String get trainingMuscleBackLower => 'Donja leđa';

  @override
  String get trainingMuscleBackMid => 'Srednja leđa';

  @override
  String get trainingMuscleBackRhomboids => 'Romboidi';

  @override
  String get trainingMuscleBackTraps => 'Trapez';

  @override
  String get trainingMuscleBackUpper => 'Gornja leđa';

  @override
  String get trainingMuscleBiceps => 'Biceps';

  @override
  String get trainingMuscleCalves => 'Listovi';

  @override
  String get trainingMuscleChestAll => 'Grudi';

  @override
  String get trainingMuscleChestLower => 'Donje grudi';

  @override
  String get trainingMuscleChestUpper => 'Gornje grudi';

  @override
  String get trainingMuscleDeltsAll => 'Ramena';

  @override
  String get trainingMuscleDeltsFront => 'Prednje rame';

  @override
  String get trainingMuscleDeltsMedial => 'Bočno rame';

  @override
  String get trainingMuscleDeltsRear => 'Zadnje rame';

  @override
  String get trainingMuscleForearmsAll => 'Podlaktice';

  @override
  String get trainingMuscleForearmsBottom => 'Podlaktice (donja strana)';

  @override
  String get trainingMuscleForearmsTop => 'Podlaktice (gornja strana)';

  @override
  String get trainingMuscleGlutesAll => 'Gluteus';

  @override
  String get trainingMuscleGlutesMaximus => 'Veliki gluteus';

  @override
  String get trainingMuscleGlutesMedius => 'Srednji gluteus';

  @override
  String get trainingMuscleGlutesMinimus => 'Mali gluteus';

  @override
  String get trainingMuscleHamstrings => 'Zadnja loža';

  @override
  String get trainingMuscleMapLabel => 'Dijagram mišića';

  @override
  String get trainingMuscleMapLegendSecondary => 'Sekundarni';

  @override
  String get trainingMuscleMapLegendTarget => 'Ciljni';

  @override
  String get trainingMuscleMapNone => 'Nijedan mišić nije označen';

  @override
  String trainingMuscleMapPrimary(String muscles) {
    return 'Primarni: $muscles';
  }

  @override
  String trainingMuscleMapSecondary(String muscles) {
    return 'Sekundarni: $muscles';
  }

  @override
  String get trainingMuscleNeck => 'Vrat';

  @override
  String get trainingMuscleQuadsAll => 'Kvadriceps';

  @override
  String get trainingMuscleQuadsLateral => 'Spoljašnji kvadriceps';

  @override
  String get trainingMuscleQuadsMedial => 'Unutrašnji kvadriceps';

  @override
  String get trainingMuscleTricepsAll => 'Triceps';

  @override
  String get trainingMuscleTricepsLateral => 'Bočna glava tricepsa';

  @override
  String get trainingMuscleTricepsLong => 'Duga glava tricepsa';

  @override
  String get trainingMuscleTricepsMedial => 'Medijalna glava tricepsa';

  @override
  String get trainingPlanAddCoverPhoto => 'Dodaj naslovnu fotografiju';

  @override
  String get trainingPlanAddDrop => 'Dodaj drop';

  @override
  String get trainingPlanAddExerciseToSuperset => 'Dodaj vežbu u superseriju';

  @override
  String get trainingPlanAddSet => 'Dodaj seriju';

  @override
  String get trainingPlanAlternating => 'Naizmenično';

  @override
  String get trainingPlanAlternatingShort => 'Naizm.';

  @override
  String get trainingPlanCollapse => 'Skupi';

  @override
  String trainingPlanDeleteBody(String name) {
    return 'Trajno obrisati „$name“?';
  }

  @override
  String get trainingPlanDeleteTitle => 'Obrisati trening?';

  @override
  String get trainingPlanDescriptionLabel => 'Opis';

  @override
  String trainingPlanDropLine(int number, String details) {
    return 'Drop $number: $details';
  }

  @override
  String trainingPlanDropNumber(int number) {
    return 'Drop $number';
  }

  @override
  String get trainingPlanEditTitle => 'Izmeni trening';

  @override
  String get trainingPlanExpand => 'Proširi';

  @override
  String get trainingPlanMakeDropset => 'Napravi drop set';

  @override
  String get trainingPlanMusclesTrained => 'Mišići koji se treniraju';

  @override
  String get trainingPlanNameLabel => 'Naziv treninga *';

  @override
  String get trainingPlanNotes => 'Beleške';

  @override
  String get trainingPlanPickExercise => 'Izaberi vežbu';

  @override
  String get trainingPlanProgramme => 'Plan treninga';

  @override
  String get trainingPlanPublic => 'Javno';

  @override
  String get trainingPlanPublicSubtitle => 'Vidljivo svim korisnicima';

  @override
  String get trainingPlanRemoveDrop => 'Ukloni drop';

  @override
  String get trainingPlanRemoveExercise => 'Ukloni vežbu';

  @override
  String get trainingPlanRemoveSet => 'Ukloni seriju';

  @override
  String get trainingPlanReorderSet => 'Prevuci za promenu redosleda';

  @override
  String trainingPlanRestSeconds(int seconds) {
    return 'Odmor $seconds s';
  }

  @override
  String get trainingPlanSelectExercise => 'Izaberi vežbu…';

  @override
  String get trainingPlanSets => 'Serije';

  @override
  String get trainingPlanStartSession => 'Započni trening';

  @override
  String trainingPlateAvailable(String plates) {
    return 'Tegovi: $plates';
  }

  @override
  String get trainingPlateBar => 'Šipka';

  @override
  String get trainingPlateEachSide => 'Svaka strana';

  @override
  String get trainingPlateEmptyBar => 'Prazna šipka';

  @override
  String get trainingPlateEnterTarget =>
      'Unesi ciljnu težinu da vidiš tegove za svaku stranu.';

  @override
  String get trainingPlateNoWarmup =>
      'Cilj je jednak ili manji od šipke — tegovi za zagrevanje nisu potrebni.';

  @override
  String trainingPlateNotExact(
    String target,
    String closest,
    String difference,
  ) {
    return '$target ne može da se natovari tačno. Najbliže: $closest ($difference).';
  }

  @override
  String trainingPlatePerSide(String plates) {
    return 'Po strani: $plates';
  }

  @override
  String trainingPlateSuggestedRamp(String weight) {
    return 'Predlog zagrevanja do $weight';
  }

  @override
  String get trainingPlateTargetWeight => 'Ciljna težina';

  @override
  String get trainingPlateTitle => 'Kalkulator tegova';

  @override
  String trainingPlateTotal(String weight) {
    return 'Ukupno $weight';
  }

  @override
  String get trainingPlateWarmup => 'Zagrevanje';

  @override
  String get trainingProgressBestE1rm => 'Najbolji e1RM';

  @override
  String get trainingProgressBestVolume => 'Najveći volumen';

  @override
  String trainingProgressChartE1rm(String unit) {
    return 'Procenjeni 1RM ($unit)';
  }

  @override
  String trainingProgressChartVolume(String unit) {
    return 'Volumen treninga ($unit × ponavljanja)';
  }

  @override
  String trainingProgressChartWeight(String unit) {
    return 'Najteža serija ($unit)';
  }

  @override
  String trainingProgressE1rm(String weight) {
    return 'e1RM $weight';
  }

  @override
  String get trainingProgressEmptyMessage =>
      'Zabeleži trening i ovde će se pojaviti tvoj volumen, niz i lični rekordi.';

  @override
  String get trainingProgressEmptyTitle => 'Još nema zabeleženih treninga';

  @override
  String get trainingProgressExercises => 'Vežbe';

  @override
  String get trainingProgressFilterExercises => 'Filtriraj vežbe…';

  @override
  String get trainingProgressHeaviest => 'Najteže';

  @override
  String get trainingProgressLast30Days => 'poslednjih 30 dana';

  @override
  String trainingProgressLastSession(String when) {
    return 'Poslednji trening: $when';
  }

  @override
  String get trainingProgressMetricE1rm => 'e1RM';

  @override
  String get trainingProgressMetricVolume => 'Volumen';

  @override
  String get trainingProgressMetricWeight => 'Najveća težina';

  @override
  String get trainingProgressNoData => 'Nema podataka';

  @override
  String get trainingProgressNoExercises => 'Još nema zabeleženih vežbi';

  @override
  String get trainingProgressNoExercisesMatch => 'Nijedna vežba ne odgovara';

  @override
  String get trainingProgressNoRecentPrs =>
      'Nema novih ličnih rekorda u poslednjih 30 dana. Nadmaši svoj najbolji procenjeni 1RM na bilo kojoj vežbi da postaviš novi.';

  @override
  String get trainingProgressNoSessionsInRange =>
      'Nema treninga u ovom periodu';

  @override
  String get trainingProgressPersonalRecords => 'Lični rekordi';

  @override
  String get trainingProgressRange1m => '1 mes.';

  @override
  String get trainingProgressRange3m => '3 mes.';

  @override
  String get trainingProgressRange6m => '6 mes.';

  @override
  String get trainingProgressRangeAll => 'Sve';

  @override
  String get trainingProgressRecentPrs => 'Nedavni rekordi';

  @override
  String trainingProgressRepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ponavljanja',
      few: '$count ponavljanja',
      one: '$count ponavljanje',
    );
    return '$_temp0';
  }

  @override
  String get trainingProgressSeriesE1rm => 'Procenjeni 1RM';

  @override
  String get trainingProgressSeriesVolume => 'Volumen treninga';

  @override
  String get trainingProgressSeriesWeight => 'Najteža serija';

  @override
  String trainingProgressSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count treninga',
      few: '$count treninga',
      one: '$count trening',
    );
    return '$_temp0';
  }

  @override
  String get trainingProgressSessionsHeading => 'Treninzi';

  @override
  String trainingProgressSessionsInRange(String range) {
    return 'Treninzi ($range)';
  }

  @override
  String get trainingProgressStatSessions30d => 'Treninzi · 30 dana';

  @override
  String get trainingProgressStatSessions7d => 'Treninzi · 7 dana';

  @override
  String get trainingProgressStatStreak => 'Nedeljni niz';

  @override
  String get trainingProgressStatVolume30d => 'Volumen · 30 dana';

  @override
  String get trainingProgressStreakDone => 'Trenirao/la si ove nedelje';

  @override
  String get trainingProgressStreakKeep => 'Treniraj ove nedelje da ga zadržiš';

  @override
  String get trainingProgressStreakStart =>
      'Treniraj ove nedelje da ga započneš';

  @override
  String trainingProgressStreakWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ned.',
      few: '$count ned.',
      one: '$count ned.',
    );
    return '$_temp0';
  }

  @override
  String get trainingProgressTabBody => 'Telo';

  @override
  String get trainingProgressTabTraining => 'Trening';

  @override
  String get trainingProgressTitle => 'Napredak';

  @override
  String trainingProgressTopWeight(String weight) {
    return 'Najviše $weight';
  }

  @override
  String trainingProgressTrendSemantics(String value) {
    return 'Trend, poslednja vrednost $value';
  }

  @override
  String get trainingProgressYesterday => 'Juče';

  @override
  String get trainingRepFailureShort => 'Otkaz';

  @override
  String get trainingRepTypeCount => 'Ponavljanja';

  @override
  String get trainingRepTypeFailure => 'Do otkaza';

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
    return 'Dodaj $seconds sekundi';
  }

  @override
  String trainingRestPresetTooltip(String time) {
    return 'Odmor $time';
  }

  @override
  String trainingRestRemaining(String time) {
    return 'Preostalo odmora: $time';
  }

  @override
  String get trainingRestSkip => 'Preskoči';

  @override
  String get trainingRestTitle => 'Odmor';

  @override
  String get trainingRoutineAdd => 'Dodaj';

  @override
  String get trainingRoutineDayHint => 'Dan';

  @override
  String get trainingRoutineDeleteTitle => 'Obrisati program?';

  @override
  String get trainingRoutineDeleteTooltip => 'Obriši program';

  @override
  String get trainingRoutineEditTitle => 'Izmeni program';

  @override
  String get trainingRoutineEditTooltip => 'Izmeni program';

  @override
  String get trainingRoutineInvalidNumber => 'Unesi ispravan broj';

  @override
  String get trainingRoutineInvalidWeeks => 'Unesi ispravan broj nedelja';

  @override
  String get trainingRoutineMine => 'Moj';

  @override
  String get trainingRoutineNameLabel => 'Naziv programa *';

  @override
  String get trainingRoutineNoTrainings => 'Još nema dodeljenih treninga';

  @override
  String get trainingRoutineNoTrainingsAdded => 'Još nema dodatih treninga';

  @override
  String get trainingRoutineNumWeeksHint => 'npr. 12';

  @override
  String get trainingRoutineNumWeeksLabel => 'Broj nedelja *';

  @override
  String get trainingRoutinePrivate => 'Privatno';

  @override
  String get trainingRoutineRemoveTraining => 'Ukloni trening';

  @override
  String get trainingRoutineRestDay => 'Dan odmora';

  @override
  String get trainingRoutineSchedule => 'Raspored';

  @override
  String get trainingRoutineScheduleType => 'Tip rasporeda';

  @override
  String get trainingRoutineSearchTrainingsHint => 'Pretraži treninge…';

  @override
  String trainingRoutineTrainingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count treninga',
      few: '$count treninga',
      one: '$count trening',
    );
    return '$_temp0';
  }

  @override
  String get trainingRoutineTrainingFallback => 'Trening';

  @override
  String trainingRoutineWeek(int week) {
    return 'Nedelja $week';
  }

  @override
  String trainingRoutineWeekShort(int week) {
    return 'Ned. $week';
  }

  @override
  String get trainingRoutineWeekShortHint => 'Ned.';

  @override
  String get trainingScheduleFixedWeeks => 'Fiksne nedelje';

  @override
  String get trainingScheduleHasClasses => 'ima časova';

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
    return '$range (+1 dan)';
  }

  @override
  String get trainingScheduleNextWeek => 'Sledeća nedelja';

  @override
  String get trainingSchedulePreviousWeek => 'Prethodna nedelja';

  @override
  String get trainingScheduleThisWeek => 'Ove nedelje';

  @override
  String get trainingScheduleTitle => 'Raspored';

  @override
  String get trainingScheduleTomorrow => 'Sutra';

  @override
  String get trainingScheduleWildcard => 'Slobodan raspored';

  @override
  String get trainingScheduleYesterday => 'Juče';

  @override
  String get trainingSessionAddDrop => 'Dodaj drop';

  @override
  String get trainingSessionCommentAthlete => 'Sportista';

  @override
  String get trainingSessionCommentCoach => 'Trener';

  @override
  String trainingSessionCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count komentara',
      few: '$count komentara',
      one: '$count komentar',
    );
    return '$_temp0';
  }

  @override
  String get trainingSessionCommentDeleteMessage =>
      'Ovaj komentar će biti trajno uklonjen.';

  @override
  String get trainingSessionCommentDeleteTitle => 'Obrisati komentar?';

  @override
  String get trainingSessionCommentEditTitle => 'Izmeni komentar';

  @override
  String trainingSessionCommentEdited(String when) {
    return '$when · izmenjeno';
  }

  @override
  String get trainingSessionCommentHint => 'Dodaj komentar…';

  @override
  String get trainingSessionCommentOptions => 'Opcije komentara';

  @override
  String get trainingSessionCommentYou => 'Ti';

  @override
  String get trainingSessionComments => 'Komentari';

  @override
  String get trainingSessionDate => 'Datum';

  @override
  String get trainingSessionDeleteMessage =>
      'Ovaj zapis će biti trajno uklonjen.';

  @override
  String get trainingSessionDeleteSetTooltip => 'Obriši seriju';

  @override
  String get trainingSessionDeleteTitle => 'Obrisati trening?';

  @override
  String get trainingSessionDeleteTooltip => 'Obriši trening';

  @override
  String get trainingSessionDeletedUser => 'Obrisan korisnik';

  @override
  String get trainingSessionDetailTitle => 'Detalji treninga';

  @override
  String trainingSessionDropNumber(int number) {
    return 'Drop $number';
  }

  @override
  String get trainingSessionDuration => 'Trajanje';

  @override
  String trainingSessionDurationSemantics(String duration) {
    return 'Trajanje $duration';
  }

  @override
  String trainingSessionEditSetTitle(String title) {
    return 'Izmeni: $title';
  }

  @override
  String get trainingSessionEditSetTooltip => 'Izmeni seriju';

  @override
  String get trainingSessionFree => 'Slobodan trening';

  @override
  String get trainingSessionInProgress => 'U toku';

  @override
  String get trainingSessionNoComments =>
      'Još nema komentara. Treneri i sportista ovde mogu da ostave povratnu informaciju.';

  @override
  String get trainingSessionNoReps => 'Nema zabeleženih ponavljanja';

  @override
  String get trainingSessionNoSets => 'Nema zabeleženih serija';

  @override
  String get trainingSessionNote => 'Beleška';

  @override
  String get trainingSessionNotes => 'Beleške';

  @override
  String get trainingSessionPlanned => 'Trening po planu';

  @override
  String get trainingSessionRemoveDrop => 'Ukloni drop';

  @override
  String get trainingSessionRepType => 'Tip';

  @override
  String get trainingSessionRepsWholeNumber =>
      'Ponavljanja moraju biti ceo broj';

  @override
  String get trainingSessionSendComment => 'Pošalji komentar';

  @override
  String get trainingSessionSetDeleteMessage =>
      'Ova zabeležena serija će biti trajno uklonjena.';

  @override
  String get trainingSessionSetDeleteTitle => 'Obrisati seriju?';

  @override
  String trainingSessionSetTitle(int number) {
    return 'Serija $number';
  }

  @override
  String trainingSessionSetTitleWithExercise(int number, String exercise) {
    return 'Serija $number · $exercise';
  }

  @override
  String trainingSessionSetsLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zabeleženih serija',
      few: '$count zabeležene serije',
      one: '$count zabeležena serija',
    );
    return '$_temp0';
  }

  @override
  String get trainingSessionTapToEdit => 'Dodirni seriju da je izmeniš.';

  @override
  String trainingSessionTodayAt(String time) {
    return 'Danas $time';
  }

  @override
  String get trainingSessionTrainer => 'Trener';

  @override
  String get trainingSessionWeightNumber => 'Težina mora biti broj';

  @override
  String trainingSessionYesterdayAt(String time) {
    return 'Juče $time';
  }

  @override
  String get trainingSessionsClassesTitle => 'Časovi';

  @override
  String get trainingSessionsEmpty => 'Još nema treninga';

  @override
  String get trainingSessionsEmptyHint => 'Dodirni + da započneš prvi trening';

  @override
  String get trainingSessionsMyProgress => 'Moj napredak';

  @override
  String get trainingSessionsNew => 'Novi trening';

  @override
  String get trainingSessionsNoClasses => 'Još nema časova';

  @override
  String get trainingSessionsNoClassesHint =>
      'Ovde će se pojaviti treninzi koje vodiš za članove';

  @override
  String get trainingSessionsTitle => 'Treninzi';

  @override
  String get trainingSetTypeCircuit => 'Kružni trening';

  @override
  String get trainingSetTypeDropset => 'Drop set';

  @override
  String get trainingSetTypeStandard => 'Klasična serija';

  @override
  String get trainingSetTypeSuperset => 'Superserija';

  @override
  String get trainingShiftAdd => 'Dodaj smenu';

  @override
  String trainingShiftAddOn(String day) {
    return 'Dodaj smenu — $day';
  }

  @override
  String get trainingShiftAddOne => 'Dodaj smenu';

  @override
  String get trainingShiftAdded => 'Smena je dodata';

  @override
  String trainingShiftCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count smena',
      few: '$count smene',
      one: '$count smena',
    );
    return '$_temp0';
  }

  @override
  String get trainingShiftDelete => 'Obriši smenu';

  @override
  String trainingShiftDeleteMessage(String name, String day) {
    return 'Smena ($name, $day) biće uklonjena.';
  }

  @override
  String trainingShiftDeleteNotifyMessage(String name, String day) {
    return 'Smena ($name, $day) biće uklonjena i ta osoba će biti obaveštena.';
  }

  @override
  String get trainingShiftDeleteQuestion => 'Obrisati smenu?';

  @override
  String get trainingShiftDeleted => 'Smena je obrisana';

  @override
  String get trainingShiftEdit => 'Izmeni smenu';

  @override
  String trainingShiftEnd(String time) {
    return 'Kraj $time';
  }

  @override
  String trainingShiftEndsNextDay(String duration) {
    return '$duration · završava se sutradan';
  }

  @override
  String get trainingShiftFree =>
      'Slobodan/na si. Nove smene će se pojaviti ovde.';

  @override
  String get trainingShiftLoadFailed => 'Učitavanje smena nije uspelo';

  @override
  String get trainingShiftMyShifts => 'Moje smene';

  @override
  String get trainingShiftNew => 'Nova smena';

  @override
  String trainingShiftNextDays(int days) {
    return 'Narednih $days dana';
  }

  @override
  String get trainingShiftNextShifts => 'Sledeće smene';

  @override
  String get trainingShiftNoStaff => 'Nema zaposlenih za raspored';

  @override
  String get trainingShiftNoStaffMessage =>
      'Prvo dodaj zaposlene, zaposlene trenere ili trenere u ovu teretanu.';

  @override
  String get trainingShiftNoUpcoming => 'Nema predstojećih smena';

  @override
  String get trainingShiftNoUpcomingMessage =>
      'Kada te menadžer rasporedi, tvoje smene će se pojaviti ovde i dobićeš obaveštenje.';

  @override
  String get trainingShiftNone => 'Nema smena';

  @override
  String get trainingShiftNoneThisWeek => 'Nema smena ove nedelje';

  @override
  String get trainingShiftNoneThisWeekManage =>
      'Isplaniraj ko kada radi. Zaposleni dobijaju obaveštenja o svojim smenama.';

  @override
  String get trainingShiftNoneThisWeekMessage =>
      'Za ovu nedelju još niko nije raspoređen.';

  @override
  String get trainingShiftNoteHint => 'npr. Recepcija, otvaranje';

  @override
  String get trainingShiftNoteOptional => 'Napomena (opciono)';

  @override
  String get trainingShiftOnNow => 'U toku';

  @override
  String get trainingShiftOptions => 'Opcije smene';

  @override
  String get trainingShiftPickStaff => 'Izaberi ko radi u ovoj smeni';

  @override
  String get trainingShiftSeeAll => 'Prikaži sve';

  @override
  String get trainingShiftShifts => 'Smene';

  @override
  String get trainingShiftStaffMember => 'Zaposleni';

  @override
  String trainingShiftStart(String time) {
    return 'Početak $time';
  }

  @override
  String get trainingShiftUpdated => 'Smena je izmenjena';

  @override
  String get trainingSideBoth => 'Obe strane';

  @override
  String get trainingSideLeft => 'Leva';

  @override
  String get trainingSideRight => 'Desna';

  @override
  String get trainingStaffRoleEmployee => 'Zaposleni';

  @override
  String get trainingStaffRoleEmployeeTrainer => 'Zaposleni / trener';

  @override
  String get trainingStaffRoleTrainer => 'Trener';

  @override
  String trainingWeekProgram(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'Program od $weeks nedelja',
      few: 'Program od $weeks nedelje',
      one: 'Program od $weeks nedelje',
    );
    return '$_temp0';
  }

  @override
  String trainingWorkoutsAssignedByMe(int count) {
    return 'Od mene ($count)';
  }

  @override
  String trainingWorkoutsAssignedFor(String name) {
    return 'Za: $name';
  }

  @override
  String get trainingWorkoutsAssignedForMember => 'Za člana';

  @override
  String trainingWorkoutsAssignedFrom(String name) {
    return 'Od: $name';
  }

  @override
  String get trainingWorkoutsAssignedFromCoach => 'Od tvog trenera';

  @override
  String trainingWorkoutsAssignedToMe(int count) {
    return 'Dodeljeno meni ($count)';
  }

  @override
  String get trainingWorkoutsByMeEmpty =>
      'Još nikome nisi dodelio program.\nOtvori program i dodirni Dodeli.';

  @override
  String get trainingWorkoutsClearSearch => 'Obriši pretragu';

  @override
  String get trainingWorkoutsCreate => 'Napravi';

  @override
  String get trainingWorkoutsMyRoutines => 'Moji programi';

  @override
  String get trainingWorkoutsMyTrainings => 'Moji treninzi';

  @override
  String get trainingWorkoutsNewRoutine => 'Novi program';

  @override
  String get trainingWorkoutsNewTraining => 'Novi trening';

  @override
  String get trainingWorkoutsNoTrainings => 'Nema pronađenih treninga';

  @override
  String get trainingWorkoutsSelfAssigned => 'Samostalno dodeljeno';

  @override
  String trainingWorkoutsSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serija',
      few: '$count serije',
      one: '$count serija',
    );
    return '$_temp0';
  }

  @override
  String get trainingWorkoutsTabAssigned => 'Dodeljeno';

  @override
  String get trainingWorkoutsTabLibrary => 'Moja biblioteka';

  @override
  String get trainingWorkoutsTabRoutines => 'Programi';

  @override
  String get trainingWorkoutsTabTrainings => 'Treninzi';

  @override
  String get trainingWorkoutsTitle => 'Treninzi';

  @override
  String get trainingWorkoutsToMeEmpty =>
      'Još ti nije dodeljen nijedan program.\nOvde se prikazuju programi koje ti dodeli trener.';
}

/// The translations for Serbian, using the Latin script (`sr_Latn`).
class AppLocalizationsSrLatn extends AppLocalizationsSr {
  AppLocalizationsSrLatn() : super('sr_Latn');

  @override
  String get appTitle => 'Gym Bro';

  @override
  String get businessCheckInAllTime => 'Ukupno';

  @override
  String get businessCheckInAttendanceTitle => 'Dolasci';

  @override
  String get businessCheckInBusiestHours => 'Najposećeniji termini';

  @override
  String get businessCheckInByStaff => 'prijavilo osoblje';

  @override
  String get businessCheckInCameraDenied => 'Pristup kameri je isključen';

  @override
  String get businessCheckInCameraDeniedMessage =>
      'Dozvoli pristup kameri za Gym Bro u podešavanjima uređaja da bi skenirao kodove članova. Članove i dalje možeš da prijaviš po imenu.';

  @override
  String businessCheckInCameraStartFailed(String code) {
    return 'Kamera nije mogla da se pokrene ($code).';
  }

  @override
  String get businessCheckInCameraUnavailable => 'Kamera nije dostupna';

  @override
  String get businessCheckInCameraUnsupportedMessage =>
      'Ovaj uređaj ne može da skenira kodove. Prijavi članove po imenu.';

  @override
  String get businessCheckInCheckInAction => 'Prijavi';

  @override
  String get businessCheckInCheckIns => 'Prijave';

  @override
  String businessCheckInCheckedInAt(String time) {
    return 'Prijavljen u $time';
  }

  @override
  String get businessCheckInCheckingIn => 'Prijavljivanje…';

  @override
  String get businessCheckInClearSearch => 'Obriši pretragu';

  @override
  String businessCheckInCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prijava',
      few: '$count prijave',
      one: '$count prijava',
    );
    return '$_temp0';
  }

  @override
  String businessCheckInDailyChartSemantics(
    int days,
    int total,
    String average,
  ) {
    return 'Grafikon prijava po danima, poslednjih $days dana: ukupno $total, prosečno $average dnevno.';
  }

  @override
  String get businessCheckInDismissHint => 'zatvori';

  @override
  String get businessCheckInGymFallback => 'Teretana';

  @override
  String businessCheckInHourlyChartSemantics(String hours) {
    return 'Grafikon prijava po satima. Najveća gužva: $hours.';
  }

  @override
  String businessCheckInLastDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Poslednjih $days dana',
      few: 'Poslednja $days dana',
      one: 'Poslednji $days dan',
    );
    return '$_temp0';
  }

  @override
  String businessCheckInLastVisit(String when) {
    return 'Poslednji dolazak: $when';
  }

  @override
  String get businessCheckInManual => 'Ručna prijava';

  @override
  String get businessCheckInManualShort => 'Ručno';

  @override
  String get businessCheckInMemberFallback => 'Član';

  @override
  String businessCheckInMembersInDays(int days) {
    return 'Članovi ($days d)';
  }

  @override
  String businessCheckInMembershipEnded(String type, String date) {
    return '$type · istekla $date';
  }

  @override
  String businessCheckInMembershipValidUntil(String type, String date) {
    return '$type · važi do $date';
  }

  @override
  String businessCheckInNewCodeIn(String time) {
    return 'Novi kod za $time';
  }

  @override
  String get businessCheckInNextDay => 'Sledeći dan';

  @override
  String get businessCheckInNoCheckInsInPeriod =>
      'Još nema prijava u ovom periodu.';

  @override
  String get businessCheckInNoGymMessage =>
      'Kada te teretana doda kao člana, ovde će se pojaviti tvoj kod za prijavu.';

  @override
  String get businessCheckInNoGymTitle => 'Nema teretane za prijavu';

  @override
  String get businessCheckInNoMatches => 'Nema članova koji odgovaraju';

  @override
  String get businessCheckInNoMatchesMessage => 'Probaj drugo ime ili e-mail.';

  @override
  String get businessCheckInNoMembers => 'Još nema članova';

  @override
  String get businessCheckInNoMembersMessage =>
      'Ovde se prikazuju članovi dodati u ovu teretanu.';

  @override
  String get businessCheckInNoMembershipOnFile => 'Nema evidentirane članarine';

  @override
  String get businessCheckInNoVisitsInPeriod => 'Nema dolazaka u ovom periodu.';

  @override
  String get businessCheckInNoVisitsMessage =>
      'Ovde će biti prikazane tvoje prijave.';

  @override
  String get businessCheckInNoVisitsTitle => 'Još nema dolazaka';

  @override
  String get businessCheckInNoneOnDay => 'Nema prijava tog dana';

  @override
  String get businessCheckInNoneToday => 'Danas još nema prijava';

  @override
  String get businessCheckInNotEnoughData => 'Još nema dovoljno podataka.';

  @override
  String get businessCheckInOpenScanner => 'Otvori skener';

  @override
  String businessCheckInPeak(String hours) {
    return 'Najveća gužva: $hours';
  }

  @override
  String get businessCheckInPickDayHelp => 'Prikaži prijave za';

  @override
  String get businessCheckInPointCamera => 'Usmeri kameru ka kodu člana';

  @override
  String get businessCheckInPreviousDay => 'Prethodni dan';

  @override
  String get businessCheckInQrNotConfigured =>
      'QR prijava još nije podešena na ovom serveru. Zamoli recepciju da te prijavi po imenu.';

  @override
  String get businessCheckInQrScan => 'QR skeniranje';

  @override
  String businessCheckInQrSemantics(String gym) {
    return 'QR kod za prijavu u teretanu $gym';
  }

  @override
  String get businessCheckInRecentVisits => 'Nedavni dolasci';

  @override
  String get businessCheckInRefreshCode => 'Osveži kod';

  @override
  String businessCheckInRefreshFailed(String error) {
    return 'Osvežavanje nije uspelo: $error';
  }

  @override
  String get businessCheckInRefreshingCode => 'Osvežavanje koda…';

  @override
  String get businessCheckInResultCheckedIn => 'Prijavljen';

  @override
  String get businessCheckInResultDuplicate => 'Već prijavljen';

  @override
  String get businessCheckInResultFailed => 'Prijava nije uspela';

  @override
  String get businessCheckInResultNoMembership => 'Nema aktivnu članarinu';

  @override
  String get businessCheckInScanHint => 'Skeniraj kod člana da ga prijaviš.';

  @override
  String get businessCheckInScanTitle => 'Skeniranje prijave';

  @override
  String get businessCheckInScanTooltip => 'Skeniraj prijave';

  @override
  String get businessCheckInSearchHint =>
      'Pretraži članove po imenu ili e-mailu';

  @override
  String businessCheckInSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prijavljenih u ovoj sesiji',
      few: '$count prijavljena u ovoj sesiji',
      one: '$count prijavljen u ovoj sesiji',
    );
    return '$_temp0';
  }

  @override
  String get businessCheckInShowAtDesk => 'Pokaži ovaj kod na recepciji';

  @override
  String get businessCheckInShowMore => 'Prikaži još';

  @override
  String get businessCheckInStaffNotice =>
      'Ovde si osoblje, ne član. Ovaj kod služi za testiranje skenera.';

  @override
  String get businessCheckInThisWeek => 'Ove nedelje';

  @override
  String get businessCheckInTitle => 'Prijava u teretanu';

  @override
  String get businessCheckInTopMembers => 'Najredovniji članovi';

  @override
  String get businessCheckInTorchOff => 'Isključi blic';

  @override
  String get businessCheckInTorchOn => 'Uključi blic';

  @override
  String businessCheckInTotalPerDay(int count, String average) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prijava',
      few: '$count prijave',
      one: '$count prijava',
    );
    return '$_temp0 · $average dnevno';
  }

  @override
  String get businessCheckInVisitsThisMonth => 'Dolasci ovog meseca';

  @override
  String businessCheckInVisitsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dolazaka',
      few: 'dolaska',
      one: 'dolazak',
    );
    return '$_temp0';
  }

  @override
  String get businessCheckInYesterday => 'Juče';

  @override
  String get businessGymAddEmployee => 'Dodaj zaposlenog';

  @override
  String get businessGymAddExistingUser => 'Dodaj postojećeg korisnika';

  @override
  String get businessGymAddExistingUserHint =>
      'Pretraži korisnike koji su već u sistemu';

  @override
  String get businessGymAddMember => 'Dodaj člana';

  @override
  String get businessGymAllGyms => 'Sve teretane';

  @override
  String get businessGymAllMembersTitle => 'Svi članovi';

  @override
  String get businessGymAllStaffTitle => 'Celo osoblje';

  @override
  String get businessGymAlreadyEmployee => 'Već radi u ovoj teretani';

  @override
  String get businessGymAlreadyMember => 'Već je član';

  @override
  String get businessGymAssign => 'Dodeli';

  @override
  String get businessGymAssignMembership => 'Dodeli članarinu';

  @override
  String get businessGymCancelMembership => 'Otkaži članarinu';

  @override
  String businessGymCancelMembershipMessage(String member, String type) {
    return 'Članarina „$type“ korisnika $member biće označena kao neaktivna. Istorija naplate se čuva.';
  }

  @override
  String get businessGymCancelMembershipTitle => 'Otkazati članarinu?';

  @override
  String get businessGymChange => 'Promeni';

  @override
  String businessGymChangeRoleMessage(String name, String role, String gym) {
    return 'Promeniti ulogu korisnika $name u „$role“ u teretani $gym?';
  }

  @override
  String get businessGymChangeRoleTitle => 'Promeniti ulogu?';

  @override
  String get businessGymClearSearch => 'Obriši pretragu';

  @override
  String businessGymDeleteMembershipMessage(String type) {
    return 'Ovim se trajno brišu članarina „$type“ i njene fakture. Da bi istorija ostala sačuvana, koristi Otkaži.';
  }

  @override
  String get businessGymDeleteMembershipTitle => 'Obrisati članarinu?';

  @override
  String get businessGymDetailAttendance => 'Dolasci';

  @override
  String get businessGymDetailInvoices => 'Fakture';

  @override
  String get businessGymDetailManage => 'Upravljaj';

  @override
  String get businessGymDetailManageMembers => 'Upravljaj članovima';

  @override
  String get businessGymDetailManageMembershipTypes =>
      'Upravljaj vrstama članarina';

  @override
  String get businessGymDetailManageStaff => 'Upravljaj osobljem';

  @override
  String get businessGymDetailMembers => 'Članovi';

  @override
  String businessGymDetailMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count članova',
      few: '$count člana',
      one: '$count član',
    );
    return '$_temp0';
  }

  @override
  String get businessGymDetailMembershipTypes => 'Vrste članarina';

  @override
  String get businessGymDetailMembershipTypesHint =>
      'Podesi cenovne planove na koje se članovi mogu upisati.';

  @override
  String businessGymDetailMore(int count) {
    return '+ još $count';
  }

  @override
  String get businessGymDetailPosts => 'Objave';

  @override
  String get businessGymDetailScanCheckIns => 'Skeniraj prijave';

  @override
  String get businessGymDetailSchedule => 'Raspored';

  @override
  String get businessGymDetailStaff => 'Osoblje';

  @override
  String businessGymDetailStaffCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaposlenih',
      few: '$count zaposlena',
      one: '$count zaposleni',
    );
    return '$_temp0';
  }

  @override
  String get businessGymDuration => 'Trajanje';

  @override
  String get businessGymEditEmployee => 'Izmeni zaposlenog';

  @override
  String get businessGymEditMember => 'Izmeni člana';

  @override
  String get businessGymEmail => 'Imejl';

  @override
  String get businessGymEmailAlreadyEmployed =>
      'Ovaj imejl već pripada zaposlenom u ovoj teretani';

  @override
  String get businessGymEmployeeActions => 'Radnje za zaposlenog';

  @override
  String get businessGymExtend => 'Produži';

  @override
  String get businessGymExtendMembership => 'Produži članarinu';

  @override
  String businessGymExtendedUntil(String date) {
    return 'Produženo do $date';
  }

  @override
  String get businessGymFilterAll => 'Sve';

  @override
  String get businessGymFirstName => 'Ime';

  @override
  String get businessGymFormAddLogo => 'Dodaj logo';

  @override
  String get businessGymFormCreate => 'Kreiraj biznis';

  @override
  String get businessGymFormDelete => 'Obriši biznis';

  @override
  String get businessGymFormDeleteGymAction => 'Obriši teretanu';

  @override
  String get businessGymFormDeleteGymMessage =>
      'Ovim se trajno briše teretana sa svim članovima, osobljem, vrstama članarina, članarinama, fakturama i objavama.';

  @override
  String get businessGymFormDeleteShopAction => 'Obriši prodavnicu';

  @override
  String get businessGymFormDeleteShopMessage =>
      'Ovim se trajno briše prodavnica sa svim artiklima, prodavcima i objavama.';

  @override
  String businessGymFormDeleteTitle(String name) {
    return 'Obrisati $name?';
  }

  @override
  String businessGymFormDeleted(String name) {
    return 'Obrisano: $name';
  }

  @override
  String get businessGymFormFrom => 'Od';

  @override
  String get businessGymFormLocation => 'Lokacija';

  @override
  String get businessGymFormName => 'Naziv';

  @override
  String get businessGymFormSaveChanges => 'Sačuvaj izmene';

  @override
  String get businessGymFormSelectWorkingDay => 'Izaberi bar jedan radni dan';

  @override
  String get businessGymFormTitleEdit => 'Izmeni biznis';

  @override
  String get businessGymFormTitleNew => 'Novi biznis';

  @override
  String get businessGymFormTo => 'Do';

  @override
  String get businessGymFormType => 'Vrsta';

  @override
  String get businessGymFormTypeGym => 'Teretana';

  @override
  String get businessGymFormTypeShop => 'Prodavnica';

  @override
  String get businessGymFormWorkingDays => 'Radni dani';

  @override
  String get businessGymFormWorkingHours => 'Radno vreme';

  @override
  String get businessGymGym => 'Teretana';

  @override
  String get businessGymInviteAndAdd => 'Pozovi i dodaj';

  @override
  String get businessGymInviteMemberTitle => 'Pozovi člana';

  @override
  String get businessGymInviteNewMember => 'Pozovi novog člana';

  @override
  String get businessGymInviteNewMemberHint => 'Pošalji link za poziv imejlom';

  @override
  String get businessGymInviteNewUserPrompt =>
      'Nema ih u pretrazi? Pozovi novog korisnika';

  @override
  String get businessGymInviteResent => 'Pozivnica je ponovo poslata';

  @override
  String get businessGymInviteResentSuccess =>
      'Pozivnica je uspešno ponovo poslata';

  @override
  String get businessGymKeep => 'Zadrži';

  @override
  String get businessGymLastName => 'Prezime';

  @override
  String get businessGymMemberActions => 'Radnje za člana';

  @override
  String businessGymMembersTitle(String gym) {
    return '$gym — Članovi';
  }

  @override
  String get businessGymMembershipActions => 'Radnje za članarinu';

  @override
  String get businessGymMembershipAssigned => 'Članarina je dodeljena';

  @override
  String get businessGymMembershipFallback => 'Članarina';

  @override
  String get businessGymMembershipType => 'Vrsta članarine';

  @override
  String get businessGymMembershipTypeNotFound =>
      'Vrsta članarine nije pronađena za ovu teretanu';

  @override
  String get businessGymMemberships => 'Članarine';

  @override
  String businessGymMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months meseci',
      few: '$months meseca',
      one: '$months mesec',
    );
    return '$_temp0';
  }

  @override
  String get businessGymNoMembersFound => 'Nema pronađenih članova';

  @override
  String get businessGymNoMembersYet => 'Još nema članova';

  @override
  String businessGymNoMembershipAt(String gym) {
    return 'Nema članarine u teretani $gym';
  }

  @override
  String get businessGymNoMembershipTypes =>
      'Ova teretana još nema vrste članarina — prvo dodaj jednu.';

  @override
  String get businessGymNoStaffFound => 'Nema pronađenog osoblja';

  @override
  String get businessGymNoStaffYet => 'Još nema osoblja';

  @override
  String businessGymPlusMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '+$months meseci',
      few: '+$months meseca',
      one: '+$months mesec',
    );
    return '$_temp0';
  }

  @override
  String get businessGymRemove => 'Ukloni';

  @override
  String get businessGymRemoveFromGym => 'Ukloni iz teretane';

  @override
  String businessGymRemoveFromGymMessage(String name, String gym) {
    return 'Korisnik $name biće uklonjen iz teretane $gym.';
  }

  @override
  String get businessGymRemoveMemberMessage =>
      'Član će biti uklonjen iz ove teretane.';

  @override
  String get businessGymRemoveMemberTitle => 'Ukloniti člana?';

  @override
  String get businessGymRemoveStaffMessage =>
      'Zaposleni će biti uklonjen iz ove teretane.';

  @override
  String get businessGymRemoveStaffTitle => 'Ukloniti zaposlenog?';

  @override
  String get businessGymResendInvite => 'Ponovo pošalji pozivnicu';

  @override
  String get businessGymRole => 'Uloga';

  @override
  String businessGymRoleChangedTo(String role) {
    return 'Uloga promenjena: $role';
  }

  @override
  String get businessGymRoleEmployee => 'Zaposleni';

  @override
  String get businessGymRoleEmployeeTrainer => 'Zaposleni trener';

  @override
  String get businessGymRoleEmployeeTrainerShort => 'Zap. trener';

  @override
  String get businessGymRoleMember => 'Član';

  @override
  String get businessGymRoleVendor => 'Prodavac';

  @override
  String get businessGymSearchMembersHint => 'Pretraži članove…';

  @override
  String get businessGymSearchStaffHint => 'Pretraži osoblje…';

  @override
  String get businessGymSendInvite => 'Pošalji pozivnicu';

  @override
  String businessGymStaffTitle(String gym) {
    return '$gym — Osoblje';
  }

  @override
  String get businessGymStatusActive => 'Aktivna';

  @override
  String get businessGymStatusCancelled => 'Otkazana';

  @override
  String get businessGymStatusExpired => 'Istekla';

  @override
  String businessGymTypePerMonth(String name, String price) {
    return '$name ($price/mes.)';
  }

  @override
  String get businessGymUsername => 'Korisničko ime';

  @override
  String get businessGymViewProgress => 'Pogledaj napredak';

  @override
  String get businessInvoiceStatusPaid => 'Plaćeno';

  @override
  String get businessInvoiceStatusUnpaid => 'Neplaćeno';

  @override
  String get businessInvoiceStatusVoid => 'Poništeno';

  @override
  String get businessItemTypeEquipment => 'Oprema';

  @override
  String get businessItemTypeGiftCard => 'Poklon kartica';

  @override
  String get businessItemTypeSupplement => 'Suplement';

  @override
  String get businessMgmtActiveMembership => 'Aktivna članarina';

  @override
  String get businessMgmtActiveUntil => 'Aktivan do';

  @override
  String get businessMgmtAddItem => 'Dodaj artikal';

  @override
  String get businessMgmtAddProductPhoto => 'Dodaj fotografiju proizvoda';

  @override
  String get businessMgmtAddType => 'Dodaj vrstu';

  @override
  String get businessMgmtAddVendor => 'Dodaj prodavca';

  @override
  String get businessMgmtAll => 'Sve';

  @override
  String get businessMgmtAllGyms => 'Sve teretane';

  @override
  String get businessMgmtAlreadyVendor => 'Već je prodavac u ovoj prodavnici';

  @override
  String get businessMgmtAutoRenewOn => 'Automatsko obnavljanje uključeno';

  @override
  String get businessMgmtAutoRenewTurnedOff =>
      'Automatsko obnavljanje je isključeno';

  @override
  String get businessMgmtBillingHistory => 'Istorija plaćanja';

  @override
  String get businessMgmtBuyMembership => 'Kupi članarinu';

  @override
  String get businessMgmtClearDate => 'Obriši datum';

  @override
  String businessMgmtDeleteItemMessage(String name) {
    return 'Ukloniti „$name“ iz ove prodavnice?';
  }

  @override
  String get businessMgmtDeleteItemTitle => 'Obrisati artikal?';

  @override
  String businessMgmtDeleteMembershipTypeMessage(String name) {
    return 'Vrsta „$name“ biće obrisana. Postojeće članarine koje je koriste ostaju sačuvane.';
  }

  @override
  String get businessMgmtDeleteMembershipTypeTitle =>
      'Obrisati vrstu članarine?';

  @override
  String businessMgmtDeleteNamed(String name) {
    return 'Obriši $name';
  }

  @override
  String get businessMgmtDescriptionOptional => 'Opis (opciono)';

  @override
  String get businessMgmtEditItem => 'Izmeni artikal';

  @override
  String get businessMgmtEditMembershipType => 'Izmeni vrstu članarine';

  @override
  String businessMgmtEditNamed(String name) {
    return 'Izmeni $name';
  }

  @override
  String get businessMgmtEditVendor => 'Izmeni prodavca';

  @override
  String get businessMgmtEmail => 'Email';

  @override
  String get businessMgmtEmailAlreadyVendor =>
      'Ovaj email već pripada prodavcu ove prodavnice';

  @override
  String get businessMgmtExtendOrBuy => 'Produži ili kupi članarinu';

  @override
  String get businessMgmtFirstName => 'Ime';

  @override
  String get businessMgmtGym => 'Teretana';

  @override
  String businessMgmtGymInvoicesTitle(String gymName) {
    return '$gymName — fakture';
  }

  @override
  String get businessMgmtInStock => 'Na stanju';

  @override
  String get businessMgmtInvalidNumber => 'Unesi ispravan broj';

  @override
  String get businessMgmtInviteAndAddVendor => 'Pozovi i dodaj prodavca';

  @override
  String get businessMgmtInviteNewUser =>
      'Nema ih u pretrazi? Pozovi novog korisnika';

  @override
  String get businessMgmtInviteResent => 'Pozivnica ponovo poslata';

  @override
  String get businessMgmtInviteResentSuccess =>
      'Pozivnica je uspešno ponovo poslata';

  @override
  String get businessMgmtInvoice => 'Faktura';

  @override
  String get businessMgmtInvoiceMarkedPaid => 'Faktura označena kao plaćena';

  @override
  String get businessMgmtInvoiceMarkedUnpaid =>
      'Faktura označena kao neplaćena';

  @override
  String get businessMgmtInvoiceMarkedVoid => 'Faktura označena kao poništena';

  @override
  String get businessMgmtInvoicePaidThanks => 'Faktura je plaćena. Hvala!';

  @override
  String get businessMgmtInvoices => 'Fakture';

  @override
  String businessMgmtIssuedOn(String date) {
    return 'Izdata $date';
  }

  @override
  String get businessMgmtItemActive => 'Aktivan';

  @override
  String get businessMgmtItemInactive => 'Neaktivan';

  @override
  String get businessMgmtItems => 'Artikli';

  @override
  String get businessMgmtLastName => 'Prezime';

  @override
  String get businessMgmtManage => 'Upravljaj';

  @override
  String get businessMgmtMarkPaid => 'Označi kao plaćenu';

  @override
  String get businessMgmtMarkUnpaid => 'Označi kao neplaćenu';

  @override
  String get businessMgmtMarkVoid => 'Označi kao poništenu';

  @override
  String get businessMgmtMembership => 'Članarina';

  @override
  String get businessMgmtMembershipExpired => 'Članarina je istekla';

  @override
  String get businessMgmtMembershipHistory => 'Istorija članarina';

  @override
  String businessMgmtMembershipTypesTitle(String gymName) {
    return '$gymName · vrste članarine';
  }

  @override
  String get businessMgmtMonthlyCost => 'Mesečna cena';

  @override
  String businessMgmtMoreCount(int count) {
    return '+ još $count';
  }

  @override
  String get businessMgmtName => 'Naziv';

  @override
  String get businessMgmtNewItem => 'Novi artikal';

  @override
  String get businessMgmtNewMembershipType => 'Nova vrsta članarine';

  @override
  String get businessMgmtNoActiveMembership => 'Nemaš aktivnu članarinu';

  @override
  String get businessMgmtNoExpiry => 'Bez isteka';

  @override
  String get businessMgmtNoInvoicesYet => 'Još nema faktura';

  @override
  String get businessMgmtNoItemsYet => 'Još nema artikala';

  @override
  String get businessMgmtNoMembershipBuyHint =>
      'Kupi članarinu u aplikaciji ili zamoli svoju teretanu da ti je podesi.';

  @override
  String get businessMgmtNoMembershipDeskHint =>
      'Zamoli svoju teretanu da ti podesi članarinu. Plaćanje se vrši na recepciji.';

  @override
  String get businessMgmtNoMembershipTypesYet => 'Još nema vrsta članarine';

  @override
  String get businessMgmtNoPaidInvoices => 'Nema plaćenih faktura';

  @override
  String get businessMgmtNoUnpaidInvoices => 'Nema neplaćenih faktura';

  @override
  String get businessMgmtNoVendorsYet => 'Još nema prodavaca';

  @override
  String get businessMgmtNoVoidInvoices => 'Nema poništenih faktura';

  @override
  String get businessMgmtOrders => 'Porudžbine';

  @override
  String get businessMgmtOrdersSubtitle =>
      'Porudžbine kupaca, plaćanja i preuzimanja';

  @override
  String get businessMgmtOutOfStock => 'Nema na stanju';

  @override
  String businessMgmtPayNow(String amount) {
    return 'Plati sada · $amount';
  }

  @override
  String get businessMgmtPaymentsAtDesk =>
      'Članarine i fakture se plaćaju na recepciji tvoje teretane.';

  @override
  String businessMgmtPerMonth(String price) {
    return '$price mesečno';
  }

  @override
  String businessMgmtPerMonthShort(String price) {
    return '$price/mes.';
  }

  @override
  String get businessMgmtPickDate => 'Izaberi datum';

  @override
  String get businessMgmtPosts => 'Objave';

  @override
  String get businessMgmtPrice => 'Cena';

  @override
  String businessMgmtQuantity(int quantity) {
    return 'Na stanju: $quantity';
  }

  @override
  String get businessMgmtRemove => 'Ukloni';

  @override
  String get businessMgmtRemoveFromShop => 'Ukloni iz prodavnice';

  @override
  String businessMgmtRemoveVendorFromShopMessage(String name, String shopName) {
    return 'Korisnik $name biće uklonjen iz prodavnice $shopName.';
  }

  @override
  String get businessMgmtRemoveVendorMessage =>
      'Ova osoba će biti uklonjena iz ove prodavnice.';

  @override
  String get businessMgmtRemoveVendorTitle => 'Ukloniti prodavca?';

  @override
  String get businessMgmtRenewMembership => 'Obnovi članarinu';

  @override
  String get businessMgmtRenewsMonthly =>
      'Automatski se obnavlja svakog meseca';

  @override
  String get businessMgmtResendInvite => 'Ponovo pošalji pozivnicu';

  @override
  String get businessMgmtSaveChanges => 'Sačuvaj izmene';

  @override
  String get businessMgmtShop => 'Prodavnica';

  @override
  String businessMgmtShopVendorsTitle(String shopName) {
    return '$shopName — prodavci';
  }

  @override
  String get businessMgmtStaffVendors => 'Osoblje / prodavci';

  @override
  String get businessMgmtTurnOff => 'Isključi';

  @override
  String get businessMgmtTurnOffAutoRenew => 'Isključi automatsko obnavljanje';

  @override
  String businessMgmtTurnOffAutoRenewMessage(String date) {
    return 'Članarina ostaje aktivna do $date i više neće biti naplaćivana.';
  }

  @override
  String get businessMgmtTurnOffAutoRenewTitle =>
      'Isključiti automatsko obnavljanje?';

  @override
  String get businessMgmtType => 'Vrsta';

  @override
  String get businessMgmtTypeActive => 'Aktivna';

  @override
  String get businessMgmtTypeInactive => 'Neaktivna';

  @override
  String get businessMgmtUnknownMember => 'Nepoznat član';

  @override
  String businessMgmtUnpaidSummary(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neplaćenih faktura',
      few: '$count neplaćene fakture',
      one: '$count neplaćena faktura',
    );
    return '$_temp0 · za plaćanje $amount';
  }

  @override
  String get businessMgmtUsername => 'Korisničko ime';

  @override
  String get businessMgmtVendor => 'Prodavac';

  @override
  String get businessMgmtVendorActions => 'Opcije prodavca';

  @override
  String get businessOrderStatusCancelled => 'Otkazano';

  @override
  String get businessOrderStatusFulfilled => 'Isporučeno';

  @override
  String get businessOrderStatusPaid => 'Plaćeno';

  @override
  String get businessOrderStatusPending => 'Na čekanju';

  @override
  String get businessPaymentMethodCard => 'Kartica';

  @override
  String get businessPaymentMethodPayAtPickup => 'Plaćanje pri preuzimanju';

  @override
  String get businessPaymentStatusCancelled => 'Otkazano';

  @override
  String get businessPaymentStatusFailed => 'Neuspešno';

  @override
  String get businessPaymentStatusPaid => 'Plaćeno';

  @override
  String get businessPaymentStatusPending => 'Na čekanju';

  @override
  String get businessPaymentStatusRefunded => 'Refundirano';

  @override
  String get businessQuantityDecrease => 'Smanji količinu';

  @override
  String get businessQuantityIncrease => 'Povećaj količinu';

  @override
  String businessQuantityValue(int value) {
    return 'Količina $value';
  }

  @override
  String businessShopAddWithPrice(String price) {
    return 'Dodaj · $price';
  }

  @override
  String businessShopAddedToCart(int quantity, String name) {
    return 'Dodato u korpu: $quantity × $name';
  }

  @override
  String get businessShopAllStockInCart =>
      'Sve dostupne zalihe su već u tvojoj korpi';

  @override
  String businessShopAutoRenewExplanation(String price) {
    return 'Sada ti se naplaćuje $price, a zatim svakog meseca. Automatsko obnavljanje možeš isključiti bilo kada na stranici članarine.';
  }

  @override
  String businessShopAvailableUntil(String date) {
    return 'Dostupno do $date';
  }

  @override
  String get businessShopAwaitingCardPayment => 'Čeka se plaćanje karticom';

  @override
  String get businessShopAwaitingYourCardPayment =>
      'Ova porudžbina čeka tvoje plaćanje karticom.';

  @override
  String get businessShopBrowseShops => 'Pregledaj prodavnice';

  @override
  String get businessShopBuyAtFrontDesk =>
      'Kupi ili produži članarinu na recepciji svoje teretane.';

  @override
  String get businessShopBuyMembershipTitle => 'Kupi članarinu';

  @override
  String businessShopBuyerPickedUp(String name) {
    return 'Porudžbina je preuzeta (kupac: $name).';
  }

  @override
  String get businessShopCancelOrder => 'Otkaži porudžbinu';

  @override
  String get businessShopCancelOrderTitle => 'Otkazati ovu porudžbinu?';

  @override
  String businessShopCardOfAmountWillBeRefunded(String total) {
    return 'Plaćanje karticom od $total biće refundirano.';
  }

  @override
  String get businessShopCardPaymentHint =>
      'Platićeš bezbedno preko Stripe-a, a zatim preuzeti porudžbinu.';

  @override
  String get businessShopCardUnavailableNow =>
      'Plaćanje karticom trenutno nije dostupno. Možeš platiti pri preuzimanju.';

  @override
  String get businessShopCardUnavailablePayAtPickup =>
      'Plaćanje karticom još nije dostupno. Platićeš kada preuzmeš porudžbinu.';

  @override
  String get businessShopCardWillBeRefunded =>
      'Plaćanje karticom biće refundirano.';

  @override
  String get businessShopCart => 'Korpa';

  @override
  String get businessShopCartEmpty => 'Korpa je prazna';

  @override
  String get businessShopCartEmptyHint => 'Dodirni artikal da ga dodaš.';

  @override
  String businessShopCartTotal(String price) {
    return 'Korpa · $price';
  }

  @override
  String get businessShopChooseDifferentGym => 'Izaberi drugu teretanu';

  @override
  String get businessShopClearSearch => 'Obriši pretragu';

  @override
  String businessShopConfirmBuyerPaid(String name, String total) {
    return 'Potvrdi uplatu od $total (kupac: $name).';
  }

  @override
  String businessShopConfirmCustomerPaid(String total) {
    return 'Potvrdi da je kupac platio $total.';
  }

  @override
  String businessShopConfirmPaidAtCounter(String total) {
    return 'Potvrdi da je kupac platio $total na kasi.';
  }

  @override
  String get businessShopConfirmingPayment => 'Potvrđujemo tvoje plaćanje…';

  @override
  String get businessShopCouldNotOpenPaymentPage =>
      'Nije moguće otvoriti stranicu za plaćanje';

  @override
  String get businessShopCustomer => 'Kupac';

  @override
  String get businessShopCustomerPickedUp => 'Kupac je preuzeo porudžbinu.';

  @override
  String get businessShopCustomerPickedUpOrder =>
      'Kupac je preuzeo porudžbinu.';

  @override
  String get businessShopDecreaseQuantity => 'Smanji količinu';

  @override
  String get businessShopEmptyCart => 'Isprazni korpu';

  @override
  String get businessShopFilterAll => 'Sve';

  @override
  String businessShopFromPricePerMonth(String price) {
    return 'Od $price mesečno';
  }

  @override
  String businessShopInCartCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artikala u korpi',
      few: '$count artikla u korpi',
      one: '$count artikal u korpi',
    );
    return '$_temp0';
  }

  @override
  String businessShopInStock(int count) {
    return 'Na stanju: $count';
  }

  @override
  String businessShopInYourCart(int count) {
    return 'U tvojoj korpi: $count';
  }

  @override
  String get businessShopIncreaseQuantity => 'Povećaj količinu';

  @override
  String businessShopItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stavki',
      few: '$count stavke',
      one: '$count stavka',
    );
    return '$_temp0';
  }

  @override
  String get businessShopItems => 'Artikli';

  @override
  String get businessShopItemsBackInStock => 'Artikli se vraćaju na stanje.';

  @override
  String businessShopLeftCount(int count) {
    return 'Još $count';
  }

  @override
  String get businessShopLength => 'Trajanje';

  @override
  String get businessShopMarkAsFulfilledTitle => 'Označiti kao isporučeno?';

  @override
  String get businessShopMarkAsPaidTitle => 'Označiti kao plaćeno?';

  @override
  String get businessShopMarkFulfilled => 'Označi kao isporučeno';

  @override
  String get businessShopMarkPaid => 'Označi kao plaćeno';

  @override
  String get businessShopMembershipPaymentSuccess =>
      'Plaćanje uspešno. Tvoja članarina je aktivna!';

  @override
  String get businessShopMembershipType => 'Vrsta članarine';

  @override
  String get businessShopMyOrders => 'Moje porudžbine';

  @override
  String get businessShopNewOrdersHint =>
      'Nove porudžbine kupaca pojaviće se ovde.';

  @override
  String get businessShopNoGymSellsMemberships =>
      'Nijedna teretana još ne prodaje članarine u aplikaciji.';

  @override
  String get businessShopNoGymsMatch => 'Nijedna teretana ne odgovara pretrazi';

  @override
  String get businessShopNoMembershipsForSale => 'Nema članarina u prodaji';

  @override
  String businessShopNoOrdersWithStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'pending': 'Nema porudžbina na čekanju',
      'paid': 'Nema plaćenih porudžbina',
      'fulfilled': 'Nema isporučenih porudžbina',
      'cancelled': 'Nema otkazanih porudžbina',
      'other': 'Nema porudžbina',
    });
    return '$_temp0';
  }

  @override
  String get businessShopNoOrdersYet => 'Još nema porudžbina';

  @override
  String get businessShopNoOrdersYetMessage =>
      'Artikli koje poručiš iz prodavnice pojaviće se ovde.';

  @override
  String get businessShopNoProductsMatch =>
      'Nijedan artikal ne odgovara pretrazi';

  @override
  String get businessShopNoProductsYet => 'Ova prodavnica još nema artikala';

  @override
  String get businessShopNoShopsYet => 'Još nema prodavnica';

  @override
  String get businessShopNoShopsYetMessage =>
      'Prodavnice će se pojaviti ovde kada se otvore.';

  @override
  String get businessShopNotYet => 'Još nije';

  @override
  String get businessShopNote => 'Napomena';

  @override
  String get businessShopNoteForShop => 'Napomena za prodavnicu (opciono)';

  @override
  String businessShopOneTimeExplanation(String price, String gym) {
    return 'Jednokratna uplata od $price. Ako već imaš članarinu u teretani $gym, biće produžena.';
  }

  @override
  String get businessShopOnlinePaymentsUnavailable =>
      'Onlajn plaćanje nije dostupno';

  @override
  String get businessShopOrder => 'Porudžbina';

  @override
  String businessShopOrderIdStatusChanged(String status, String id) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'paid': 'Porudžbina $id je označena kao plaćena.',
      'fulfilled': 'Porudžbina $id je označena kao isporučena.',
      'cancelled': 'Porudžbina $id je otkazana.',
      'other': 'Porudžbina $id je ažurirana.',
    });
    return '$_temp0';
  }

  @override
  String get businessShopOrderPaymentSuccess =>
      'Plaćanje uspešno. Tvoja porudžbina je plaćena!';

  @override
  String businessShopOrderStatusChanged(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'paid': 'Porudžbina je označena kao plaćena.',
      'fulfilled': 'Porudžbina je označena kao isporučena.',
      'cancelled': 'Porudžbina je otkazana.',
      'other': 'Porudžbina je ažurirana.',
    });
    return '$_temp0';
  }

  @override
  String businessShopOrderWithId(String id) {
    return 'Porudžbina $id';
  }

  @override
  String get businessShopOrders => 'Porudžbine';

  @override
  String get businessShopOutOfStock => 'Nema na stanju';

  @override
  String businessShopPayAmount(String price) {
    return 'Plati $price';
  }

  @override
  String get businessShopPayByCard => 'Plati karticom';

  @override
  String businessShopPayNow(String price) {
    return 'Plati sada · $price';
  }

  @override
  String get businessShopPayment => 'Plaćanje';

  @override
  String get businessShopPaymentCancelled => 'Plaćanje otkazano';

  @override
  String get businessShopPaymentFailed =>
      'Plaćanje nije uspelo. Novac ti nije naplaćen.';

  @override
  String get businessShopPaymentNotConfirmedYet =>
      'Plaćanje još nije potvrđeno. Obavestićemo te kada bude gotovo.';

  @override
  String get businessShopPaymentRefunded => 'Novac je refundiran';

  @override
  String get businessShopPaymentStillProcessing =>
      'Tvoje plaćanje se još obrađuje. Obavestićemo te kada bude potvrđeno.';

  @override
  String get businessShopPaymentSuccessful => 'Plaćanje uspešno';

  @override
  String get businessShopPickupPaymentHint =>
      'Plati u prodavnici kada preuzmeš porudžbinu.';

  @override
  String businessShopPlaceOrderAndPay(String price) {
    return 'Poruči i plati $price';
  }

  @override
  String businessShopPlaceOrderTotal(String price) {
    return 'Poruči · $price';
  }

  @override
  String get businessShopPlanMonthlyAutoRenew =>
      'Mesečno, automatsko obnavljanje';

  @override
  String businessShopPlanMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months meseci',
      few: '$months meseca',
      one: '$months mesec',
    );
    return '$_temp0';
  }

  @override
  String businessShopPriceEachLineTotal(String price, String total) {
    return '$price po komadu · $total';
  }

  @override
  String businessShopPricePerMonth(String price) {
    return '$price mesečno';
  }

  @override
  String businessShopProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artikala',
      few: '$count artikla',
      one: '$count artikal',
    );
    return '$_temp0';
  }

  @override
  String businessShopQuantityValue(int count) {
    return 'Količina: $count';
  }

  @override
  String get businessShopRefundDone => 'Plaćanje karticom je refundirano.';

  @override
  String get businessShopRefundFailed =>
      'Refundacija nije uspela. Refundiraj uplatu preko Stripe-a.';

  @override
  String get businessShopRefundManual => 'Refundiraj plaćanje karticom ručno.';

  @override
  String get businessShopRemove => 'Ukloni';

  @override
  String businessShopRemovedFromCart(String items) {
    return 'Uklonjeno iz korpe (više nije dostupno): $items';
  }

  @override
  String get businessShopSearchGyms => 'Pretraži teretane';

  @override
  String get businessShopSearchProducts => 'Pretraži artikle';

  @override
  String get businessShopShop => 'Prodavnica';

  @override
  String get businessShopSoldOut => 'Rasprodato';

  @override
  String get businessShopStatus => 'Status';

  @override
  String businessShopSubscribePerMonth(String price) {
    return 'Pretplati se · $price mesečno';
  }

  @override
  String get businessShopTimelinePlaced => 'Porudžbina kreirana';

  @override
  String get businessShopTotal => 'Ukupno';

  @override
  String get businessShopYourCart => 'Tvoja korpa';

  @override
  String get commonBack => 'Nazad';

  @override
  String get commonCancel => 'Otkaži';

  @override
  String get commonClose => 'Zatvori';

  @override
  String get commonConfirm => 'Potvrdi';

  @override
  String get commonDelete => 'Obriši';

  @override
  String get commonEdit => 'Izmeni';

  @override
  String get commonLoading => 'Učitavanje…';

  @override
  String get commonNo => 'Ne';

  @override
  String get commonOk => 'U redu';

  @override
  String get commonRequired => 'Obavezno polje';

  @override
  String get commonRetry => 'Pokušaj ponovo';

  @override
  String get commonSave => 'Sačuvaj';

  @override
  String get commonSearch => 'Pretraga';

  @override
  String get commonSomethingWentWrong => 'Nešto nije u redu';

  @override
  String get commonToday => 'Danas';

  @override
  String get commonYes => 'Da';

  @override
  String get nutritionAdd => 'Dodaj';

  @override
  String get nutritionAddFoodItem => 'Dodaj namirnicu';

  @override
  String get nutritionAddFoodTitle => 'Dodaj hranu';

  @override
  String get nutritionAddImage => 'Dodaj sliku';

  @override
  String get nutritionAddIngredient => 'Dodaj sastojak';

  @override
  String get nutritionAddMineral => 'Dodaj mineral';

  @override
  String nutritionAddNamed(String name) {
    return 'Dodaj: $name';
  }

  @override
  String get nutritionAddPhoto => 'Dodaj fotografiju';

  @override
  String get nutritionAddRecipe => 'Dodaj recept';

  @override
  String get nutritionAddSlot => 'Dodaj obrok';

  @override
  String get nutritionAddStep => 'Dodaj korak';

  @override
  String nutritionAddToSlot(String slot) {
    return 'Dodaj u: $slot';
  }

  @override
  String get nutritionAddVideo => 'Dodaj video';

  @override
  String get nutritionAddVitamin => 'Dodaj vitamin';

  @override
  String get nutritionAllMineralsAdded => 'Svi minerali su već dodati';

  @override
  String get nutritionAllSlotsAdded => 'Svi obroci su već dodati';

  @override
  String get nutritionAllVitaminsAdded => 'Svi vitamini su već dodati';

  @override
  String get nutritionAmount => 'Količina';

  @override
  String get nutritionAssign => 'Dodeli';

  @override
  String get nutritionAssignMealPlanTitle => 'Dodeli plan ishrane';

  @override
  String nutritionAssignPlanToQuestion(String plan, String name) {
    return 'Dodeliti „$plan” korisniku: $name?';
  }

  @override
  String nutritionAssignPlanToSelfQuestion(String plan) {
    return 'Dodeliti „$plan” sebi?';
  }

  @override
  String get nutritionAssignTo => 'Dodeli';

  @override
  String nutritionAssignedBy(String name) {
    return 'Dodela od: $name';
  }

  @override
  String get nutritionAssignedByMe => 'Koje dodeljujem';

  @override
  String nutritionAssignedOn(String date) {
    return 'Dodeljeno $date';
  }

  @override
  String get nutritionAssignedToMe => 'Dodeljeni meni';

  @override
  String nutritionAssignmentFor(String name) {
    return 'Za: $name';
  }

  @override
  String nutritionBarcodeExample(String example) {
    return 'npr. $example';
  }

  @override
  String nutritionBarcodeNotFound(String code) {
    return 'Nije pronađen proizvod za bar-kod $code';
  }

  @override
  String get nutritionBarcodeOptional => 'Bar-kod (opciono)';

  @override
  String nutritionBarcodeValue(String code) {
    return 'Bar-kod $code';
  }

  @override
  String get nutritionBasicInfo => 'Osnovni podaci';

  @override
  String get nutritionBrandOptional => 'Brend (opciono)';

  @override
  String get nutritionCalories => 'Kalorije';

  @override
  String get nutritionCameraAccessOff => 'Pristup kameri je isključen';

  @override
  String get nutritionCameraAccessOffHint =>
      'Dozvoli Gym Bro aplikaciji pristup kameri u podešavanjima uređaja da bi skenirao bar-kodove ili ručno unesi kod.';

  @override
  String get nutritionCameraUnavailable => 'Kamera nije dostupna';

  @override
  String get nutritionCameraUnavailableHint =>
      'Kamera nije mogla da se pokrene. Možeš ručno da uneseš broj bar-koda.';

  @override
  String get nutritionCancelEditing => 'Otkaži izmenu';

  @override
  String get nutritionCannotBeUndone => 'Ovo ne može da se poništi.';

  @override
  String get nutritionCarbs => 'Ugljeni hidrati';

  @override
  String get nutritionCarbsLetter => 'U';

  @override
  String get nutritionCarbsShort => 'UH';

  @override
  String nutritionChooseDailyPlanFor(String week, String day) {
    return 'Izaberi dnevni plan za $week, $day';
  }

  @override
  String get nutritionClearSearch => 'Obriši pretragu';

  @override
  String get nutritionClearStartDate => 'Obriši datum početka';

  @override
  String get nutritionClearUnassign => 'Obriši / ukloni dodelu';

  @override
  String get nutritionComment => 'Komentariši';

  @override
  String nutritionCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count komentara',
      few: '$count komentara',
      one: '$count komentar',
    );
    return '$_temp0';
  }

  @override
  String get nutritionCommentOptions => 'Opcije komentara';

  @override
  String get nutritionComments => 'Komentari';

  @override
  String nutritionCommentsWithCount(int count) {
    return 'Komentari ($count)';
  }

  @override
  String nutritionCommunityTitle(String business) {
    return '$business · Zajednica';
  }

  @override
  String get nutritionComputedPerServing => 'Izračunato po porciji';

  @override
  String get nutritionCookMinLabel => 'Kuvanje (min)';

  @override
  String get nutritionCreate => 'Napravi';

  @override
  String get nutritionCreateItem => 'Napravi namirnicu';

  @override
  String nutritionDailyAveragePlannedDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dnevni prosek · $count planiranih dana',
      few: 'Dnevni prosek · $count planirana dana',
      one: 'Dnevni prosek · $count planiran dan',
    );
    return '$_temp0';
  }

  @override
  String nutritionDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dana',
      few: '$count dana',
      one: '$count dan',
    );
    return 'pre $_temp0';
  }

  @override
  String nutritionDaysPlannedOfSeven(int count) {
    return 'Planirano $count od 7 dana';
  }

  @override
  String get nutritionDeleteCommentTitle => 'Obrisati komentar?';

  @override
  String get nutritionDeleteFoodItemTitle => 'Obrisati namirnicu?';

  @override
  String nutritionDeleteMealPlanMessage(String name) {
    return 'Trajno ukloniti „$name”? Sve dodele ovog plana takođe će biti uklonjene.';
  }

  @override
  String get nutritionDeleteMealPlanTitle => 'Obrisati plan ishrane?';

  @override
  String get nutritionDeletePost => 'Obriši objavu';

  @override
  String get nutritionDeletePostTitle => 'Obrisati objavu?';

  @override
  String get nutritionDeleteRecipeTitle => 'Obrisati recept?';

  @override
  String get nutritionDeletedUser => 'Obrisan korisnik';

  @override
  String get nutritionDescription => 'Opis';

  @override
  String get nutritionDragToReorder => 'Prevuci za promenu redosleda';

  @override
  String get nutritionDrinkBeer => 'Pivo';

  @override
  String get nutritionDrinkBlackTea => 'Crni čaj';

  @override
  String get nutritionDrinkCider => 'Sajder';

  @override
  String get nutritionDrinkCocktail => 'Koktel';

  @override
  String get nutritionDrinkCoffee => 'Kafa';

  @override
  String get nutritionDrinkDairyMilk => 'Mleko';

  @override
  String get nutritionDrinkEnergy => 'Energetsko piće';

  @override
  String get nutritionDrinkEspresso => 'Espreso';

  @override
  String get nutritionDrinkFlavouredWater => 'Aromatizovana voda';

  @override
  String get nutritionDrinkFruitJuice => 'Voćni sok';

  @override
  String get nutritionDrinkGreenTea => 'Zeleni čaj';

  @override
  String get nutritionDrinkHerbalTea => 'Biljni čaj';

  @override
  String get nutritionDrinkIsotonic => 'Izotonik';

  @override
  String get nutritionDrinkKefir => 'Kefir';

  @override
  String get nutritionDrinkKombucha => 'Kombuha';

  @override
  String get nutritionDrinkMealReplacement => 'Zamena za obrok';

  @override
  String get nutritionDrinkPlantMilk => 'Biljno mleko';

  @override
  String get nutritionDrinkProteinShake => 'Proteinski šejk';

  @override
  String get nutritionDrinkShake => 'Šejk';

  @override
  String get nutritionDrinkSmoothie => 'Smuti';

  @override
  String get nutritionDrinkSoda => 'Gazirani sok';

  @override
  String get nutritionDrinkSparklingWater => 'Gazirana voda';

  @override
  String get nutritionDrinkSpirit => 'Žestoko piće';

  @override
  String get nutritionDrinkSports => 'Sportski napitak';

  @override
  String get nutritionDrinkStillWater => 'Negazirana voda';

  @override
  String get nutritionDrinkVegetableJuice => 'Sok od povrća';

  @override
  String get nutritionDrinkWine => 'Vino';

  @override
  String get nutritionDuration => 'Trajanje';

  @override
  String get nutritionEditAmountOrMeal => 'Izmeni količinu ili obrok';

  @override
  String get nutritionEditDailyPlanTitle => 'Izmeni dnevni plan';

  @override
  String get nutritionEditFoodItemTitle => 'Izmeni namirnicu';

  @override
  String get nutritionEditMealPlanTitle => 'Izmeni plan ishrane';

  @override
  String get nutritionEditMicronutrients => 'Izmeni mikronutrijente';

  @override
  String get nutritionEditPost => 'Izmeni objavu';

  @override
  String get nutritionEditPostTitle => 'Izmeni objavu';

  @override
  String get nutritionEditRecipeTitle => 'Izmeni recept';

  @override
  String get nutritionEdited => 'Izmenjeno';

  @override
  String get nutritionEditedLower => 'izmenjeno';

  @override
  String get nutritionEditingComment => 'Izmena komentara';

  @override
  String nutritionEndsOn(String date) {
    return 'Završava se $date';
  }

  @override
  String get nutritionEnterBarcode => 'Unesi bar-kod';

  @override
  String get nutritionEnterCodeManually => 'Unesi kod ručno';

  @override
  String get nutritionEnterPositiveNumber => 'Unesi pozitivan broj';

  @override
  String get nutritionEnterValidNumber => 'Unesi ispravan broj';

  @override
  String get nutritionFat => 'Masti';

  @override
  String get nutritionFatLetter => 'M';

  @override
  String get nutritionFiber => 'Vlakna';

  @override
  String nutritionFiberNoTargets(int fiber) {
    return 'Vlakna $fiber g · Nema ciljeva iz plana ishrane za ovaj dan';
  }

  @override
  String nutritionFiberWithTargets(int fiber, int target) {
    return 'Vlakna $fiber / $target g · Ciljevi iz tvog plana ishrane';
  }

  @override
  String get nutritionFilterAll => 'Sve';

  @override
  String get nutritionFoodBabyFood => 'Hrana za bebe';

  @override
  String get nutritionFoodBaking => 'Sastojci za pečenje';

  @override
  String get nutritionFoodBeans => 'Pasulj i mahunarke';

  @override
  String get nutritionFoodBeef => 'Govedina';

  @override
  String get nutritionFoodBiscuitCookie => 'Keks';

  @override
  String get nutritionFoodBreadBakery => 'Hleb i peciva';

  @override
  String get nutritionFoodButter => 'Puter';

  @override
  String get nutritionFoodCanned => 'Konzervirana hrana';

  @override
  String get nutritionFoodCerealBar => 'Musli pločica';

  @override
  String get nutritionFoodCheese => 'Sir';

  @override
  String get nutritionFoodChips => 'Čips';

  @override
  String get nutritionFoodChocolateCandy => 'Čokolada i slatkiši';

  @override
  String get nutritionFoodCorn => 'Kukuruz';

  @override
  String get nutritionFoodCream => 'Pavlaka';

  @override
  String get nutritionFoodDiary => 'Dnevnik ishrane';

  @override
  String get nutritionFoodDressing => 'Dresing';

  @override
  String get nutritionFoodEgg => 'Jaja';

  @override
  String get nutritionFoodFish => 'Riba';

  @override
  String get nutritionFoodFrozen => 'Smrznuta hrana';

  @override
  String get nutritionFoodFruit => 'Voće';

  @override
  String get nutritionFoodGameMeat => 'Divljač';

  @override
  String get nutritionFoodGrainCereal => 'Žitarice';

  @override
  String get nutritionFoodHerbFresh => 'Sveže začinsko bilje';

  @override
  String get nutritionFoodJamSpread => 'Džem i namazi';

  @override
  String get nutritionFoodLamb => 'Jagnjetina';

  @override
  String get nutritionFoodLentils => 'Sočivo';

  @override
  String get nutritionFoodMilk => 'Mleko';

  @override
  String get nutritionFoodMushroom => 'Pečurke';

  @override
  String get nutritionFoodNuts => 'Orašasti plodovi';

  @override
  String get nutritionFoodOilFat => 'Ulja i masti';

  @override
  String get nutritionFoodPastaNoodle => 'Testenina';

  @override
  String get nutritionFoodPlantMilk => 'Biljno mleko';

  @override
  String get nutritionFoodPork => 'Svinjetina';

  @override
  String get nutritionFoodPotatoTuber => 'Krompir i krtole';

  @override
  String get nutritionFoodPoultry => 'Piletina i živina';

  @override
  String get nutritionFoodProcessedMeat => 'Mesne prerađevine';

  @override
  String get nutritionFoodReadyMeal => 'Gotovo jelo';

  @override
  String get nutritionFoodRice => 'Pirinač';

  @override
  String get nutritionFoodSauceCondiment => 'Sosevi i dodaci';

  @override
  String get nutritionFoodSeafood => 'Morski plodovi';

  @override
  String get nutritionFoodSeeds => 'Semenke';

  @override
  String get nutritionFoodSnackBar => 'Snek pločica';

  @override
  String get nutritionFoodSupplementPowder => 'Suplement u prahu';

  @override
  String get nutritionFoodSweetener => 'Zaslađivač';

  @override
  String get nutritionFoodVegetable => 'Povrće';

  @override
  String get nutritionFoodYogurt => 'Jogurt';

  @override
  String get nutritionFoods => 'Namirnice';

  @override
  String nutritionHoursAgo(int count) {
    return 'pre $count h';
  }

  @override
  String get nutritionImageUrl => 'URL slike';

  @override
  String get nutritionImages => 'Slike';

  @override
  String nutritionImportedFromOff(String name) {
    return 'Uvezeno „$name” iz Open Food Facts baze. Proveri vrednosti pre nego što se osloniš na njih.';
  }

  @override
  String get nutritionIngredients => 'Sastojci';

  @override
  String get nutritionInstructionHint => 'Uputstvo…';

  @override
  String get nutritionItemFallback => 'Stavka';

  @override
  String get nutritionJustNow => 'Upravo sad';

  @override
  String get nutritionKcal => 'kcal';

  @override
  String nutritionKcalEatenSemantics(int eaten) {
    return 'Unete kalorije: $eaten kcal';
  }

  @override
  String nutritionKcalLeft(int count) {
    return 'još $count';
  }

  @override
  String nutritionKcalOver(int count) {
    return '$count preko';
  }

  @override
  String nutritionKcalPer100(int kcal, String per100) {
    return '$kcal kcal $per100';
  }

  @override
  String nutritionKcalPerServing(int kcal) {
    return '$kcal kcal po porciji';
  }

  @override
  String get nutritionKcalPerServingLabel => 'kcal po porciji';

  @override
  String nutritionKcalRingSemantics(int eaten, int target) {
    return 'Kalorije: $eaten od $target kcal';
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
  String get nutritionLike => 'Sviđa mi se';

  @override
  String nutritionLikeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sviđanja',
      few: '$count sviđanja',
      one: '$count sviđanje',
      zero: 'Nema sviđanja',
    );
    return '$_temp0';
  }

  @override
  String get nutritionLoadMore => 'Učitaj još';

  @override
  String get nutritionLogAction => 'Zabeleži';

  @override
  String get nutritionLogAnyway => 'Ipak zabeleži';

  @override
  String get nutritionLogPlannedAllDuplicateWarning =>
      'Neki obroci već imaju unose za danas. Planirane stavke biće dodate pored njih.';

  @override
  String get nutritionLogPlannedMeals => 'Zabeleži planirane obroke';

  @override
  String get nutritionLogPlannedMealsQuestion => 'Zabeležiti planirane obroke?';

  @override
  String nutritionLogPlannedSlotDuplicateWarning(String slot) {
    return '$slot već ima unose. Planirane stavke biće dodate pored njih.';
  }

  @override
  String get nutritionLogToDiary => 'Upiši u dnevnik';

  @override
  String get nutritionLogToToday => 'Zabeleži za danas';

  @override
  String nutritionLoggedItemToSlot(String name, String slot) {
    return '$name dodato u: $slot';
  }

  @override
  String nutritionLoggedPlannedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zabeleženo $count planiranih stavki',
      few: 'Zabeležene $count planirane stavke',
      one: 'Zabeležena $count planirana stavka',
    );
    return '$_temp0';
  }

  @override
  String nutritionLoggedToSlot(String slot) {
    return 'Dodato u: $slot';
  }

  @override
  String get nutritionLookUp => 'Pretraži';

  @override
  String get nutritionLookingUpProduct => 'Tražim proizvod…';

  @override
  String get nutritionMacronutrients => 'Makronutrijenti';

  @override
  String get nutritionMeal => 'Obrok';

  @override
  String nutritionMealCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count obroka',
      few: '$count obroka',
      one: '$count obrok',
    );
    return '$_temp0';
  }

  @override
  String get nutritionMealPlanFallback => 'Plan ishrane';

  @override
  String get nutritionMealPlansTitle => 'Planovi ishrane';

  @override
  String get nutritionMealSlots => 'Obroci';

  @override
  String get nutritionMemberFallback => 'člana';

  @override
  String get nutritionMicronutrients => 'Mikronutrijenti';

  @override
  String nutritionMicronutrientsOptionalHint(String per100) {
    return 'Opciono. Količine $per100.';
  }

  @override
  String get nutritionMine => 'Moje';

  @override
  String get nutritionMineral => 'Mineral';

  @override
  String get nutritionMinerals => 'Minerali';

  @override
  String nutritionMinutesAgo(int count) {
    return 'pre $count min';
  }

  @override
  String get nutritionMoveToMeal => 'Premesti u obrok';

  @override
  String get nutritionMyself => 'Sebi';

  @override
  String get nutritionNameRequiredLabel => 'Naziv *';

  @override
  String get nutritionNewDailyPlanMenu => 'Novi dnevni plan';

  @override
  String get nutritionNewDailyPlanTitle => 'Novi dnevni plan';

  @override
  String get nutritionNewFoodItemTitle => 'Nova namirnica';

  @override
  String get nutritionNewMealPlanTitle => 'Novi plan ishrane';

  @override
  String get nutritionNewPost => 'Nova objava';

  @override
  String get nutritionNewRecipeTitle => 'Novi recept';

  @override
  String get nutritionNextDay => 'Sledeći dan';

  @override
  String get nutritionNoAssignmentsByMe =>
      'Nema planova ishrane koje si dodelio drugima';

  @override
  String get nutritionNoAssignmentsToMe =>
      'Još ti nije dodeljen nijedan plan ishrane';

  @override
  String get nutritionNoCommentsYet => 'Još nema komentara';

  @override
  String get nutritionNoDailyPlansFound => 'Nema pronađenih dnevnih planova';

  @override
  String get nutritionNoEntries => 'Nema unosa';

  @override
  String get nutritionNoEntriesYet => 'Još nema unosa';

  @override
  String get nutritionNoFoodItemsFound => 'Nema pronađenih namirnica';

  @override
  String get nutritionNoFoodsFound => 'Nema pronađenih namirnica';

  @override
  String get nutritionNoFoodsFoundHint =>
      'Probaj drugu pretragu ili skeniraj bar-kod proizvoda.';

  @override
  String get nutritionNoIngredientsYet => 'Još nema dodatih sastojaka';

  @override
  String get nutritionNoMealPlansFound => 'Nema pronađenih planova ishrane';

  @override
  String get nutritionNoMealsYet => 'Još nema dodatih obroka';

  @override
  String get nutritionNoMembersMatch => 'Nijedan član ne odgovara pretrazi';

  @override
  String get nutritionNoMembersToCoach =>
      'Nema članova koje treniraš. Ovde se prikazuju članovi teretana u kojima radiš ili treniraš.';

  @override
  String get nutritionNoMicronutrients =>
      'Za ovu namirnicu nisu uneti vitamini ni minerali.';

  @override
  String get nutritionNoMicronutrientsAdded =>
      'Nema dodatih vitamina ni minerala';

  @override
  String get nutritionNoOwnMealPlans => 'Još nemaš nijedan svoj plan ishrane';

  @override
  String get nutritionNoPostsYet => 'Još nema objava';

  @override
  String get nutritionNoRecipesFound => 'Nema pronađenih recepata';

  @override
  String get nutritionNoResults => 'Nema rezultata';

  @override
  String get nutritionNoStepsYet => 'Još nema dodatih koraka';

  @override
  String get nutritionNoteOptional => 'Napomena (opciono)';

  @override
  String get nutritionNothingLogged => 'Ništa nije zabeleženo';

  @override
  String get nutritionNothingLoggedThisDay =>
      'Za ovaj dan nije zabeležena hrana.';

  @override
  String get nutritionNothingPlanned => 'Ništa nije planirano';

  @override
  String get nutritionNutrient => 'Nutrijent';

  @override
  String nutritionNutrientListLoadFailed(String error) {
    return 'Učitavanje liste nutrijenata nije uspelo: $error';
  }

  @override
  String nutritionOfTargetKcal(int target) {
    return 'od $target kcal';
  }

  @override
  String nutritionPcfGrams(int protein, int carbs, int fat) {
    return 'P ${protein}g · U ${carbs}g · M ${fat}g';
  }

  @override
  String nutritionPcfShort(int protein, int carbs, int fat) {
    return 'P $protein · U $carbs · M $fat';
  }

  @override
  String nutritionPer100Unit(String unit) {
    return 'na 100$unit';
  }

  @override
  String get nutritionPerServing => 'po porciji';

  @override
  String nutritionPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotografija',
      few: '$count fotografije',
      one: '$count fotografija',
    );
    return '$_temp0';
  }

  @override
  String nutritionPhotoOf(String name) {
    return 'Fotografija: $name';
  }

  @override
  String get nutritionPickDate => 'Izaberi datum';

  @override
  String nutritionPlanAssignedTo(String plan, String name) {
    return '„$plan” dodeljen korisniku: $name';
  }

  @override
  String nutritionPlanAssignedToSelf(String plan) {
    return '„$plan” je dodeljen tebi';
  }

  @override
  String get nutritionPlanNameRequiredLabel => 'Naziv plana *';

  @override
  String nutritionPlannedSummary(String items, int kcal) {
    return 'Planirano: $items · $kcal kcal';
  }

  @override
  String get nutritionPointCameraAtBarcode =>
      'Usmeri kameru ka bar-kodu proizvoda';

  @override
  String get nutritionPostAction => 'Objavi';

  @override
  String get nutritionPostPhoto => 'Fotografija iz objave';

  @override
  String nutritionPostPhotoOf(int index, int count) {
    return 'Fotografija $index od $count';
  }

  @override
  String get nutritionPrepMinLabel => 'Priprema (min)';

  @override
  String get nutritionPreviousDay => 'Prethodni dan';

  @override
  String get nutritionPrivate => 'Privatno';

  @override
  String get nutritionProductNotFound => 'Proizvod nije pronađen';

  @override
  String nutritionProductNotFoundMessage(String code) {
    return 'Nema podataka za bar-kod $code. Da li želiš sam da napraviš namirnicu?';
  }

  @override
  String get nutritionProtein => 'Proteini';

  @override
  String get nutritionProteinLetter => 'P';

  @override
  String get nutritionPublic => 'Javno';

  @override
  String get nutritionQtyShort => 'Kol.';

  @override
  String get nutritionQuantity => 'Količina';

  @override
  String nutritionRecipeCookTime(int minutes) {
    return 'Kuvanje $minutes min';
  }

  @override
  String get nutritionRecipeFallback => 'Recept';

  @override
  String get nutritionRecipeNameRequiredLabel => 'Naziv recepta *';

  @override
  String nutritionRecipePrepTime(int minutes) {
    return 'Priprema $minutes min';
  }

  @override
  String get nutritionRecipes => 'Recepti';

  @override
  String get nutritionRemove => 'Ukloni';

  @override
  String nutritionRemoveAssignmentMessage(String name) {
    return '„$name” više neće biti dodeljen.';
  }

  @override
  String get nutritionRemoveAssignmentTitle => 'Ukloniti dodelu?';

  @override
  String get nutritionRemoveImage => 'Ukloni sliku';

  @override
  String get nutritionRemoveIngredient => 'Ukloni sastojak';

  @override
  String nutritionRemoveNamed(String name) {
    return 'Ukloni: $name';
  }

  @override
  String nutritionRemovePermanently(String name) {
    return 'Trajno ukloniti „$name”?';
  }

  @override
  String get nutritionRemovePhoto => 'Ukloni fotografiju';

  @override
  String get nutritionRemoveSlot => 'Ukloni obrok';

  @override
  String get nutritionRemoveStep => 'Ukloni korak';

  @override
  String get nutritionRemoveVideo => 'Ukloni video';

  @override
  String nutritionRemovedItem(String name) {
    return 'Uklonjeno: $name';
  }

  @override
  String get nutritionRestFree => 'Odmor / slobodno';

  @override
  String get nutritionSaveComment => 'Sačuvaj komentar';

  @override
  String get nutritionScanBarcode => 'Skeniraj bar-kod';

  @override
  String get nutritionSchedule => 'Raspored';

  @override
  String get nutritionSearchDailyPlansHint => 'Pretraži dnevne planove…';

  @override
  String get nutritionSearchFoodItemsHint => 'Pretraži namirnice…';

  @override
  String get nutritionSearchFoodsAndRecipes => 'Pretraži namirnice i recepte';

  @override
  String get nutritionSearchHint => 'Pretraži…';

  @override
  String get nutritionSearchMealPlansHint => 'Pretraži planove ishrane…';

  @override
  String get nutritionSearchMembersHint => 'Pretraži članove…';

  @override
  String get nutritionSearchRecipesHint => 'Pretraži recepte…';

  @override
  String get nutritionSelectMealSlot => 'Izaberi obrok';

  @override
  String get nutritionSelfAssigned => 'Samostalno dodeljen';

  @override
  String get nutritionSendComment => 'Pošalji komentar';

  @override
  String get nutritionServingUnit => 'Jedinica mere';

  @override
  String get nutritionServings => 'Porcije';

  @override
  String nutritionServingsAmount(num count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$amount porcija',
      few: '$amount porcije',
      one: '$amount porcija',
    );
    return '$_temp0';
  }

  @override
  String get nutritionServingsRequiredLabel => 'Broj porcija *';

  @override
  String get nutritionSetAsThumbnail => 'Postavi kao naslovnu sliku';

  @override
  String get nutritionShareHint => 'Šta želiš da podeliš?';

  @override
  String get nutritionSlotAfternoonSnack => 'Popodnevna užina';

  @override
  String get nutritionSlotBreakfast => 'Doručak';

  @override
  String get nutritionSlotDinner => 'Večera';

  @override
  String get nutritionSlotEveningSnack => 'Večernja užina';

  @override
  String get nutritionSlotLunch => 'Ručak';

  @override
  String get nutritionSlotMorningSnack => 'Jutarnja užina';

  @override
  String get nutritionSlotPostWorkout => 'Posle treninga';

  @override
  String get nutritionSlotPreWorkout => 'Pre treninga';

  @override
  String get nutritionSpiceBlend => 'Mešavina začina';

  @override
  String get nutritionSpiceDriedHerb => 'Sušeno začinsko bilje';

  @override
  String get nutritionSpiceDryMarinade => 'Suva marinada';

  @override
  String get nutritionSpiceExtract => 'Ekstrakt / esencija';

  @override
  String get nutritionSpiceGround => 'Mleveni začin';

  @override
  String get nutritionSpicePepper => 'Biber';

  @override
  String get nutritionSpiceRub => 'Začinska mešavina za meso';

  @override
  String get nutritionSpiceSalt => 'So';

  @override
  String get nutritionSpiceSeed => 'Seme začina';

  @override
  String get nutritionSpiceWhole => 'Začin u zrnu';

  @override
  String get nutritionStartConversation => 'Započni razgovor ispod.';

  @override
  String get nutritionStartDateOptional => 'Datum početka (opciono)';

  @override
  String nutritionStartsOn(String date) {
    return 'Počinje $date';
  }

  @override
  String get nutritionStepImageUrlOptional => 'URL slike za korak (opciono)';

  @override
  String nutritionStepNumber(int number) {
    return 'Korak $number';
  }

  @override
  String nutritionStepPhoto(int number) {
    return 'Fotografija za korak $number';
  }

  @override
  String get nutritionSteps => 'Koraci';

  @override
  String get nutritionSubtypeOther => 'Ostalo';

  @override
  String get nutritionSubtypeRequiredLabel => 'Podtip *';

  @override
  String get nutritionSystem => 'Sistemski';

  @override
  String get nutritionTabAssigned => 'Dodeljeni';

  @override
  String get nutritionTabDailyPlans => 'Dnevni planovi';

  @override
  String get nutritionTabFood => 'Namirnice';

  @override
  String get nutritionTabMyDailyPlans => 'Moji dnevni planovi';

  @override
  String get nutritionTabMyFood => 'Moje namirnice';

  @override
  String get nutritionTabMyLibrary => 'Moja biblioteka';

  @override
  String get nutritionTabMyMealPlans => 'Moji planovi ishrane';

  @override
  String get nutritionTabMyRecipes => 'Moji recepti';

  @override
  String get nutritionTabPlans => 'Planovi';

  @override
  String get nutritionThumbnail => 'Naslovna slika';

  @override
  String get nutritionTitleOptional => 'Naslov (opciono)';

  @override
  String get nutritionTomorrow => 'Sutra';

  @override
  String get nutritionTorchOff => 'Isključi baterijsku lampu';

  @override
  String get nutritionTorchOn => 'Uključi baterijsku lampu';

  @override
  String get nutritionTotals => 'Ukupno';

  @override
  String get nutritionTryAnotherSearch => 'Probaj drugi pojam za pretragu.';

  @override
  String get nutritionType => 'Tip';

  @override
  String get nutritionTypeDrink => 'Piće';

  @override
  String get nutritionTypeFood => 'Hrana';

  @override
  String get nutritionTypeSpice => 'Začin';

  @override
  String get nutritionUnassigned => 'Nije dodeljeno';

  @override
  String get nutritionUnit => 'Jedinica';

  @override
  String get nutritionUnitServings => 'porcije';

  @override
  String get nutritionUnlike => 'Ukloni sviđanje';

  @override
  String get nutritionUploadPhoto => 'Otpremi fotografiju';

  @override
  String nutritionUsersDiary(String name) {
    return 'Dnevnik ishrane: $name';
  }

  @override
  String nutritionValuesPer(String per100) {
    return 'Vrednosti $per100';
  }

  @override
  String nutritionVideoNumber(int number) {
    return 'Video $number';
  }

  @override
  String get nutritionVideoUrl => 'URL videa';

  @override
  String get nutritionVideos => 'Video snimci';

  @override
  String get nutritionVisibleToAllUsers => 'Vidljivo svim korisnicima';

  @override
  String get nutritionVitamin => 'Vitamin';

  @override
  String get nutritionVitamins => 'Vitamini';

  @override
  String nutritionWeekDay(int week, int day) {
    return 'Nedelja $week · Dan $day';
  }

  @override
  String nutritionWeekNumber(int number) {
    return 'Nedelja $number';
  }

  @override
  String nutritionWeeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nedelja',
      few: '$count nedelje',
      one: '$count nedelja',
    );
    return '$_temp0';
  }

  @override
  String nutritionWeeksShort(int count) {
    return '$count ned.';
  }

  @override
  String get nutritionWriteCommentHint => 'Napiši komentar…';

  @override
  String get nutritionWriteSomethingFirst => 'Prvo nešto napiši';

  @override
  String get nutritionYesterday => 'Juče';

  @override
  String get nutritionYourCoachFallback => 'tvoj trener';

  @override
  String get nutritionYours => 'Tvoj';

  @override
  String get settingsLanguage => 'Jezik';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageSerbian => 'Srpski';

  @override
  String get settingsLanguageSystem => 'Podrazumevani jezik sistema';

  @override
  String get shellActivateAccount => 'Aktiviraj nalog';

  @override
  String get shellActivateInviteIntro =>
      'Unesi šestocifreni kod iz imejla sa pozivnicom, svoju imejl adresu i lozinku koju želiš da koristiš.';

  @override
  String get shellActivateInviteTitle => 'Aktiviraj pozivnicu';

  @override
  String get shellAddBusiness => 'Dodaj biznis';

  @override
  String get shellAddUser => 'Dodaj korisnika';

  @override
  String get shellAdminBusinessesSubtitle =>
      'Upravljaj teretanama i prodavnicama';

  @override
  String get shellAdminInvoicesSubtitle => 'Pregled svih faktura za članarine';

  @override
  String get shellAdminPanel => 'Admin panel';

  @override
  String get shellAdminUsersSubtitle => 'Upravljaj svim nalozima';

  @override
  String get shellAlreadyYourEmail => 'To je već tvoj imejl';

  @override
  String get shellAuthEmail => 'Imejl';

  @override
  String get shellAuthFirstName => 'Ime';

  @override
  String get shellAuthInvalidEmail => 'Unesi ispravan imejl';

  @override
  String get shellAuthLastName => 'Prezime';

  @override
  String get shellAuthPassword => 'Lozinka';

  @override
  String shellAuthPasswordMin(int count) {
    return 'Najmanje $count karaktera';
  }

  @override
  String get shellAuthUsername => 'Korisničko ime';

  @override
  String get shellAvatarAdd => 'Dodaj profilnu fotografiju';

  @override
  String get shellAvatarChange => 'Promeni profilnu fotografiju';

  @override
  String get shellChange => 'Promeni';

  @override
  String get shellChangeEmail => 'Promeni imejl';

  @override
  String get shellChangeEmailIntro =>
      'Poslaćemo link za potvrdu na novu adresu. Imejl će se promeniti kada ga otvoriš.';

  @override
  String get shellChangePassword => 'Promeni lozinku';

  @override
  String get shellCheckEmailBody =>
      'Poslali smo ti link za potvrdu. Potvrdi imejl pre prijave.';

  @override
  String get shellCheckEmailTitle => 'Proveri imejl';

  @override
  String get shellChooseShop => 'Izaberi prodavnicu';

  @override
  String get shellClearSearch => 'Obriši pretragu';

  @override
  String get shellConfirmNewEmailTitle => 'Potvrdi novi imejl';

  @override
  String get shellConfirmNewPassword => 'Potvrdi novu lozinku';

  @override
  String get shellConfirmPassword => 'Potvrdi lozinku';

  @override
  String get shellContinueWithGoogle => 'Nastavi sa Google nalogom';

  @override
  String shellCouldNotOpenUrl(String url) {
    return 'Nije moguće otvoriti $url';
  }

  @override
  String get shellCreateAccount => 'Napravi nalog';

  @override
  String get shellCreateUser => 'Napravi korisnika';

  @override
  String get shellCurrentPassword => 'Trenutna lozinka';

  @override
  String get shellDeleteAccount => 'Obriši nalog';

  @override
  String get shellDeleteAccountFailed => 'Brisanje naloga nije uspelo';

  @override
  String get shellDeleteAccountMessage =>
      'Ovim se trajno brišu tvoj nalog, članarine i istorija plaćanja. Ovo se ne može poništiti.';

  @override
  String get shellDeleteAccountSubtitle => 'Trajno ukloni svoj nalog';

  @override
  String get shellDeleteAccountTitle => 'Obrisati nalog?';

  @override
  String get shellDeleteConfirmWord => 'OBRIŠI';

  @override
  String shellDeleteUserMessage(String name) {
    return 'Ovim se trajno brišu nalog, članarine i istorija plaćanja korisnika $name. Ovo se ne može poništiti.';
  }

  @override
  String shellDeleteUserTitle(String name) {
    return 'Obrisati korisnika $name?';
  }

  @override
  String shellEditBusiness(String name) {
    return 'Izmeni $name';
  }

  @override
  String shellEditUser(String name) {
    return 'Izmeni korisnika $name';
  }

  @override
  String get shellEditUserTitle => 'Izmena korisnika';

  @override
  String get shellForgotPasswordIntro =>
      'Unesi imejl i poslaćemo ti link za resetovanje lozinke.';

  @override
  String get shellForgotPasswordLink => 'Zaboravio si lozinku?';

  @override
  String get shellForgotPasswordTitle => 'Zaboravljena lozinka';

  @override
  String get shellGoToLogin => 'Idi na prijavu';

  @override
  String get shellGoogleFailed => 'Prijava preko Google naloga nije uspela';

  @override
  String get shellGoogleNoIdToken => 'Google nije vratio ID token';

  @override
  String get shellGoogleNotSupported =>
      'Prijava preko Google naloga nije podržana na ovom uređaju';

  @override
  String get shellGyms => 'Teretane';

  @override
  String get shellHaveAccountLogIn => 'Već imaš nalog? Prijavi se';

  @override
  String get shellHaveInviteCode => 'Imaš kod pozivnice?';

  @override
  String shellHello(String name) {
    return 'Zdravo, $name';
  }

  @override
  String shellHey(String name) {
    return 'Ćao, $name!';
  }

  @override
  String get shellHidePassword => 'Sakrij lozinku';

  @override
  String get shellHidePasswords => 'Sakrij lozinke';

  @override
  String get shellHomeBackToLogin => 'Nazad na prijavu';

  @override
  String get shellHomeLogOut => 'Odjavi se';

  @override
  String get shellHomeNotifications => 'Obaveštenja';

  @override
  String shellHomeNotificationsUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Obaveštenja, $count nepročitanih',
      few: 'Obaveštenja, $count nepročitana',
      one: 'Obaveštenja, $count nepročitano',
    );
    return '$_temp0';
  }

  @override
  String get shellHomeProfileLoadFailed => 'Učitavanje profila nije uspelo';

  @override
  String get shellHomeReturnToAdmin => 'Nazad na admin nalog';

  @override
  String shellHomeViewingAs(String name) {
    return 'Prikaz kao $name';
  }

  @override
  String get shellHubCheckIn => 'Prijava dolaska';

  @override
  String get shellHubCheckInSubtitle => 'Pokaži svoj kod na recepciji';

  @override
  String get shellHubClassesSubtitle => 'Pregledaj i rezerviši grupne časove';

  @override
  String get shellHubCommunity => 'Zajednica';

  @override
  String shellHubCommunityOpenFailed(String error) {
    return 'Zajednica nije mogla da se otvori: $error';
  }

  @override
  String get shellHubCommunitySubtitle =>
      'Objave i obaveštenja iz tvoje teretane';

  @override
  String get shellHubExercises => 'Vežbe';

  @override
  String get shellHubExercisesSubtitle => 'Pregledaj i uređuj vežbe';

  @override
  String get shellHubFoodDiary => 'Dnevnik ishrane';

  @override
  String get shellHubFoodDiarySubtitle => 'Beleži obroke i prati makroe';

  @override
  String get shellHubMealPlans => 'Planovi ishrane';

  @override
  String get shellHubMealPlansSubtitle => 'Namirnice, recepti i ishrana';

  @override
  String get shellHubNotLinked =>
      'Još nisi povezan ni sa jednom teretanom ili prodavnicom';

  @override
  String get shellHubProgress => 'Napredak';

  @override
  String get shellHubSessions => 'Sesije';

  @override
  String get shellHubSessionsSubtitle => 'Beleži i pregledaj svoje sesije';

  @override
  String get shellHubStore => 'Prodavnica';

  @override
  String get shellHubStoreSubtitle => 'Suplementi, oprema i tvoje porudžbine';

  @override
  String get shellHubWorkouts => 'Treninzi';

  @override
  String get shellHubWorkoutsSubtitle => 'Treninzi i rutine';

  @override
  String get shellImageAddPhoto => 'Dodaj fotografiju';

  @override
  String get shellImageChange => 'Promeni fotografiju';

  @override
  String get shellImageChooseFromGallery => 'Izaberi iz galerije';

  @override
  String get shellImageTakePhoto => 'Fotografiši';

  @override
  String shellImageUploadFailed(String error) {
    return 'Otpremanje nije uspelo: $error';
  }

  @override
  String get shellImageUploading => 'Otpremanje fotografije';

  @override
  String shellImpersonateBody(String email) {
    return 'Videćeš aplikaciju tačno kao $email i moći ćeš da radiš u njegovo ime. Ovo se beleži u dnevniku aktivnosti. Koristi „Nazad na admin nalog“ (ili se odjavi) da se vratiš na svoj nalog.';
  }

  @override
  String get shellImpersonateConfirm => 'Prijavi se kao korisnik';

  @override
  String shellImpersonateTitle(String name) {
    return 'Prijaviti se kao $name?';
  }

  @override
  String get shellInvitationTitle => 'Pozivnica';

  @override
  String shellInviteAccept(String entity) {
    return 'Prihvati — pridruži se timu $entity';
  }

  @override
  String get shellInviteAccepted => 'Prihvaćeno';

  @override
  String shellInviteBody(String entity, String role) {
    return 'Pozvan si da radiš u timu $entity kao $role.';
  }

  @override
  String get shellInviteCode => 'Kod pozivnice';

  @override
  String get shellInviteCodeHint => 'Šestocifreni kod';

  @override
  String get shellInviteCodeInvalid => 'Unesi šestocifreni kod';

  @override
  String get shellInviteDecline => 'Odbij';

  @override
  String get shellInviteDeclined => 'Odbio si ovu pozivnicu';

  @override
  String get shellInviteDeclinedChip => 'Odbijeno';

  @override
  String shellInviteJoined(String entity, String role) {
    return 'Pridružio si se timu $entity kao $role';
  }

  @override
  String get shellInviteOrganisationFallback => 'organizacije';

  @override
  String get shellInvitePending => 'Čeka odgovor';

  @override
  String get shellInvoices => 'Fakture';

  @override
  String get shellLoadMore => 'Učitaj još';

  @override
  String get shellLogIn => 'Prijavi se';

  @override
  String get shellLogInInstead => 'Prijavi se umesto toga';

  @override
  String get shellMarkAllRead => 'Označi sve kao pročitano';

  @override
  String shellMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count članova',
      few: '$count člana',
      one: '$count član',
    );
    return '$_temp0';
  }

  @override
  String get shellMembersYouCoach => 'Članovi koje treniraš';

  @override
  String get shellMembershipActive => 'Aktivna';

  @override
  String get shellMembershipLoadFailed => 'Učitavanje članarine nije uspelo';

  @override
  String shellMembershipValidUntil(String type, String date) {
    return '$type · važi do $date';
  }

  @override
  String get shellMuteBilling => 'Plaćanja';

  @override
  String get shellMuteBillingDescription =>
      'Fakture, uplate i članarine koje ističu';

  @override
  String get shellMuteClasses => 'Časovi';

  @override
  String get shellMuteClassesDescription =>
      'Podsetnici, izmene i otkazivanja časova';

  @override
  String get shellMuteCoaching => 'Trening sa trenerom';

  @override
  String get shellMuteCoachingDescription =>
      'Dodeljene rutine i planovi, komentari na treninge';

  @override
  String get shellMuteCommunity => 'Zajednica';

  @override
  String get shellMuteCommunityDescription =>
      'Vesti iz teretane i komentari na tvoje objave';

  @override
  String get shellMuteFootnote =>
      'Pozivnice uvek stižu. Utišana obaveštenja se i dalje prikazuju u aplikaciji.';

  @override
  String get shellMuteShop => 'Prodavnica';

  @override
  String get shellMuteShopDescription =>
      'Status porudžbina, nove porudžbine i dopune zaliha';

  @override
  String get shellMuteStaff => 'Osoblje';

  @override
  String get shellMuteStaffDescription => 'Smene i novi ljudi u tvom biznisu';

  @override
  String get shellMyMembership => 'Moja članarina';

  @override
  String get shellMyOrders => 'Moje porudžbine';

  @override
  String get shellMyOrdersSubtitle => 'Porudžbine iz prodavnice i preuzimanja';

  @override
  String get shellMyProgress => 'Moj napredak';

  @override
  String get shellMyProgressSubtitle => 'Dizanja, telesna težina i nizovi';

  @override
  String get shellNewEmail => 'Novi imejl';

  @override
  String get shellNewPassword => 'Nova lozinka';

  @override
  String get shellNewUserTitle => 'Novi korisnik';

  @override
  String get shellNoAccountSignUp => 'Nemaš nalog? Registruj se';

  @override
  String get shellNoActiveMembership => 'Nemaš aktivnu članarinu';

  @override
  String get shellNoBusinesses => 'Još nema biznisa';

  @override
  String get shellNoCoachedMembers =>
      'Još nema članova u teretanama u kojima treniraš';

  @override
  String shellNoLongerMember(String name) {
    return '$name više nije član';
  }

  @override
  String shellNoMembersMatch(String query) {
    return 'Nijedan član ne odgovara pretrazi „$query“';
  }

  @override
  String get shellNoNotifications => 'Još nema obaveštenja';

  @override
  String get shellNoSessionsToday => 'Danas nemaš treninge';

  @override
  String get shellNoUsers => 'Još nema korisnika';

  @override
  String get shellNoUsersFound => 'Nema pronađenih korisnika';

  @override
  String get shellNoneScheduled => 'Ništa nije zakazano';

  @override
  String get shellNotAVendor => 'Još nisi prodavac ni u jednoj prodavnici';

  @override
  String get shellNotAssignedToGym => 'Još nisi dodeljen nijednoj teretani';

  @override
  String get shellNotificationUnread => 'Nepročitano';

  @override
  String get shellOffline => 'Nisi na mreži — prikazuju se sačuvani podaci';

  @override
  String shellOfflinePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Nisi na mreži — prikazuju se sačuvani podaci · $count izmena čeka sinhronizaciju',
      few:
          'Nisi na mreži — prikazuju se sačuvani podaci · $count izmene čekaju sinhronizaciju',
      one:
          'Nisi na mreži — prikazuju se sačuvani podaci · $count izmena čeka sinhronizaciju',
    );
    return '$_temp0';
  }

  @override
  String get shellOr => 'ili';

  @override
  String shellOrdersForShop(String shop) {
    return 'Porudžbine · $shop';
  }

  @override
  String get shellOwnerAllInvoices => 'Sve fakture';

  @override
  String get shellOwnerNoGyms =>
      'Još nemaš nijednu teretanu — dodaj je na kartici Biznisi.';

  @override
  String get shellPasswordChanged => 'Lozinka je promenjena';

  @override
  String get shellPasswordsDontMatch => 'Lozinke se ne poklapaju';

  @override
  String get shellPlatformOverview => 'Pregled platforme';

  @override
  String get shellProfileUpdated => 'Profil je ažuriran';

  @override
  String get shellPushChannelDescription =>
      'Podsetnici za časove, porudžbine, članarine i poruke';

  @override
  String get shellPushNotifications => 'Push obaveštenja';

  @override
  String get shellPushNotificationsSubtitle => 'Upozorenja na ovom telefonu';

  @override
  String get shellPushUnavailable =>
      'Push obaveštenja nisu dostupna u ovoj verziji. Sve ćeš i dalje naći pod ikonom zvona; ova podešavanja važe na uređajima koji podržavaju push.';

  @override
  String shellResetLinkSent(String email) {
    return 'Poslali smo link za resetovanje lozinke na $email.';
  }

  @override
  String get shellResetPasswordIntro => 'Unesi novu lozinku za svoj nalog.';

  @override
  String get shellResetPasswordTitle => 'Resetovanje lozinke';

  @override
  String get shellRole => 'Uloga';

  @override
  String get shellRoleEmployee => 'Zaposleni';

  @override
  String get shellRoleEmployeeTrainer => 'Zaposleni / trener';

  @override
  String get shellRoleEmployeeTrainerShort => 'Zap. trener';

  @override
  String get shellRoleGymOwner => 'Vlasnik teretane';

  @override
  String get shellRoleMember => 'Član';

  @override
  String get shellRoleOwner => 'Vlasnik';

  @override
  String get shellRoleShopOwner => 'Vlasnik prodavnice';

  @override
  String get shellRoleShopVendor => 'Prodavac';

  @override
  String get shellRoleSuperUser => 'Super korisnik';

  @override
  String get shellRoleTrainer => 'Trener';

  @override
  String get shellRoleVendor => 'Prodavac';

  @override
  String get shellSaveChanges => 'Sačuvaj izmene';

  @override
  String get shellScanCheckIns => 'Skeniraj dolaske';

  @override
  String get shellSearchMembers => 'Pretraži članove';

  @override
  String get shellSendLink => 'Pošalji link';

  @override
  String get shellSendMePushesAbout => 'Šalji mi obaveštenja o';

  @override
  String get shellSendResetLink => 'Pošalji link za resetovanje';

  @override
  String get shellSessionInProgress => 'Trening u toku';

  @override
  String shellSessionStartedInProgress(String time) {
    return 'Počeo u $time · u toku';
  }

  @override
  String get shellSetNewPassword => 'Postavi novu lozinku';

  @override
  String get shellSettings => 'Podešavanja';

  @override
  String get shellSettingsAccount => 'Nalog';

  @override
  String get shellSettingsAppearance => 'Izgled';

  @override
  String shellSettingsSaveFailed(String error) {
    return 'Čuvanje nije uspelo: $error';
  }

  @override
  String get shellSettingsSubtitle => 'Tema, jedinice, obaveštenja, nalog';

  @override
  String get shellSettingsTheme => 'Tema';

  @override
  String get shellSettingsUnits => 'Jedinice';

  @override
  String get shellSettingsWeight => 'Težina';

  @override
  String get shellShops => 'Prodavnice';

  @override
  String get shellShowMore => 'Prikaži još';

  @override
  String get shellShowPassword => 'Prikaži lozinku';

  @override
  String get shellShowPasswords => 'Prikaži lozinke';

  @override
  String get shellSignInAsThisUser => 'Prijavi se kao ovaj korisnik';

  @override
  String get shellSignUp => 'Registruj se';

  @override
  String get shellSignupEmailTaken => 'Nalog sa ovim imejlom već postoji.';

  @override
  String get shellSignupEnterCode => 'Unesi kod';

  @override
  String shellSignupPendingInviteBody(String email) {
    return 'Nalog za $email je već napravljen preko pozivnice. Ponovo smo poslali imejl sa pozivnicom — unesi šestocifreni kod iz njega da aktiviraš nalog.';
  }

  @override
  String get shellSignupPendingInviteTitle => 'Imaš pozivnicu na čekanju';

  @override
  String get shellStatsActiveMemberships => 'Aktivne članarine';

  @override
  String shellStatsEndsInDays(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'za $days dana ($date)',
      few: 'za $days dana ($date)',
      one: 'za $days dan ($date)',
    );
    return '$_temp0';
  }

  @override
  String shellStatsEndsOn(String gym, String when) {
    return '$gym · ističe $when';
  }

  @override
  String get shellStatsEndsToday => 'danas';

  @override
  String get shellStatsEndsTomorrow => 'sutra';

  @override
  String get shellStatsExpiringSoon => 'Uskoro ističu';

  @override
  String shellStatsGymCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count teretana',
      few: '$count teretane',
      one: '$count teretana',
    );
    return '$_temp0';
  }

  @override
  String get shellStatsInvoicesThisMonth => 'Fakture ovog meseca';

  @override
  String get shellStatsMembers => 'Članovi';

  @override
  String get shellStatsNext14Days => 'narednih 14 dana';

  @override
  String get shellStatsNoneExpiring =>
      'Nijedna članarina ne ističe u naredne dve nedelje';

  @override
  String get shellStatsStaff => 'Osoblje';

  @override
  String get shellStatsUnpaidInvoices => 'Neplaćene fakture';

  @override
  String get shellTabBusinesses => 'Biznisi';

  @override
  String get shellTabClasses => 'Časovi';

  @override
  String get shellTabGym => 'Teretana';

  @override
  String get shellTabHome => 'Početna';

  @override
  String get shellTabMembers => 'Članovi';

  @override
  String get shellTabMembership => 'Članarina';

  @override
  String get shellTabMyShop => 'Moja prodavnica';

  @override
  String get shellTabProfile => 'Profil';

  @override
  String get shellTabSchedule => 'Raspored';

  @override
  String get shellTabUsers => 'Korisnici';

  @override
  String get shellThemeDark => 'Tamna';

  @override
  String get shellThemeLight => 'Svetla';

  @override
  String get shellThemeSystem => 'Sistemska';

  @override
  String shellTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pre $count dana',
      few: 'pre $count dana',
      one: 'pre $count dan',
    );
    return '$_temp0';
  }

  @override
  String shellTimeDaysShort(int count) {
    return '$count d';
  }

  @override
  String shellTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pre $count sati',
      few: 'pre $count sata',
      one: 'pre $count sat',
    );
    return '$_temp0';
  }

  @override
  String shellTimeHoursShort(int count) {
    return '$count h';
  }

  @override
  String shellTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pre $count minuta',
      few: 'pre $count minuta',
      one: 'pre $count minut',
    );
    return '$_temp0';
  }

  @override
  String shellTimeMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get shellTimeNow => 'sada';

  @override
  String get shellTodaysSessions => 'Današnji treninzi';

  @override
  String shellTypeToConfirm(String text) {
    return 'Ukucaj $text za potvrdu.';
  }

  @override
  String get shellUnavailable => 'Nedostupno';

  @override
  String get shellUnitKilograms => 'Kilogrami';

  @override
  String get shellUnitPounds => 'Funte';

  @override
  String get shellUpcomingClasses => 'Predstojeći časovi';

  @override
  String get shellUserSearchAdd => 'Dodaj';

  @override
  String shellUserSearchAddLabel(String name) {
    return 'Dodaj korisnika $name';
  }

  @override
  String get shellUserSearchAdding => 'Dodavanje';

  @override
  String get shellUserSearchHint => 'Pretraži po imenu ili korisničkom imenu';

  @override
  String shellWelcome(String name) {
    return 'Dobro došao, $name';
  }

  @override
  String shellWelcomeBack(String name) {
    return 'Dobro došao nazad, $name';
  }

  @override
  String get shellYourGym => 'Tvoja teretana';

  @override
  String get shellYourGyms => 'Tvoje teretane';

  @override
  String get shellYourShop => 'Tvoja prodavnica';

  @override
  String get shellYourShops => 'Tvoje prodavnice';

  @override
  String get trainingAssignAction => 'Dodeli';

  @override
  String trainingAssignAssignedOn(String date) {
    return 'Dodeljeno $date';
  }

  @override
  String get trainingAssignClearDates => 'Obriši datume';

  @override
  String trainingAssignConfirm(String routine, String name) {
    return 'Dodeliti program „$routine“ članu $name?';
  }

  @override
  String trainingAssignConfirmSelf(String routine) {
    return 'Dodeliti program „$routine“ sebi?';
  }

  @override
  String get trainingAssignDialogTitle => 'Dodeli program';

  @override
  String trainingAssignDone(String routine, String name) {
    return 'Program „$routine“ je dodeljen članu $name';
  }

  @override
  String trainingAssignDoneSelf(String routine) {
    return 'Program „$routine“ je dodeljen tebi';
  }

  @override
  String get trainingAssignEnd => 'Kraj';

  @override
  String trainingAssignEnds(String date) {
    return 'Završava se $date';
  }

  @override
  String get trainingAssignNoRoutines => 'Nema pronađenih programa';

  @override
  String get trainingAssignNoteHint =>
      'npr. Fokus na tehniku, 3 treninga nedeljno';

  @override
  String get trainingAssignNoteLabel => 'Napomena (opciono)';

  @override
  String trainingAssignPickerTitle(String routine) {
    return 'Kome dodeliti „$routine“?';
  }

  @override
  String get trainingAssignRemoveAction => 'Ukloni';

  @override
  String trainingAssignRemoveBody(String routine) {
    return 'Program „$routine“ više neće biti dodeljen.';
  }

  @override
  String trainingAssignRemoveBodyUser(String routine, String name) {
    return 'Program „$routine“ više neće biti dodeljen članu $name.';
  }

  @override
  String get trainingAssignRemoveTitle => 'Ukloniti dodelu?';

  @override
  String get trainingAssignRemoveTooltip => 'Ukloni dodelu';

  @override
  String get trainingAssignSearchRoutinesHint => 'Pretraži programe…';

  @override
  String get trainingAssignStart => 'Početak';

  @override
  String trainingAssignStarts(String date) {
    return 'Počinje $date';
  }

  @override
  String get trainingBookingAttended => 'Prisustvovao/la';

  @override
  String get trainingBookingBooked => 'Rezervisano';

  @override
  String get trainingBookingCancelled => 'Otkazano';

  @override
  String get trainingBookingNoShow => 'Nije došao/la';

  @override
  String get trainingBookingWaitlisted => 'Na listi čekanja';

  @override
  String get trainingChartDefaultSeries => 'Napredak';

  @override
  String get trainingChartNoData => 'Nema podataka za ovaj period';

  @override
  String trainingChartSummary(String series, String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tačaka',
      few: '$count tačke',
      one: '$count tačka',
    );
    return 'Grafikon: $series, $_temp0, poslednja vrednost $value';
  }

  @override
  String get trainingClassAbout => 'O času';

  @override
  String get trainingClassApplyToSeries => 'Primeni na ovaj i buduće časove';

  @override
  String get trainingClassApplyToSeriesOff => 'Menja se samo ovaj čas';

  @override
  String get trainingClassApplyToSeriesOn =>
      'Izmene važe za sve kasnije časove u ovoj nedeljnoj seriji';

  @override
  String trainingClassAttendedOf(int attended, int total) {
    return 'Prisutno $attended/$total';
  }

  @override
  String get trainingClassAttendedUndo =>
      'Prisustvovao/la (dodirni da poništiš)';

  @override
  String get trainingClassBook => 'Rezerviši';

  @override
  String trainingClassBookedAt(String when) {
    return 'Rezervisano $when';
  }

  @override
  String trainingClassBookedFor(String title) {
    return 'Rezervisao/la si mesto na času $title';
  }

  @override
  String trainingClassBookedOf(int booked, int capacity) {
    return 'Rezervisano $booked/$capacity';
  }

  @override
  String get trainingClassBookingCancelled => 'Rezervacija je otkazana';

  @override
  String get trainingClassBrowse => 'Pregledaj časove';

  @override
  String get trainingClassCancelBooking => 'Otkaži rezervaciju';

  @override
  String trainingClassCancelBookingMessage(String title) {
    return 'Tvoje mesto na času $title dobiće sledeća osoba sa liste čekanja.';
  }

  @override
  String get trainingClassCancelBookingQuestion => 'Otkazati rezervaciju?';

  @override
  String get trainingClassCancelClass => 'Otkaži čas';

  @override
  String trainingClassCancelNotifyPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count osoba sa rezervacijom ili na listi čekanja biće obavešteno.',
      few: '$count osobe sa rezervacijom ili na listi čekanja biće obaveštene.',
      one: '$count osoba sa rezervacijom ili na listi čekanja biće obaveštena.',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassCancelQuestion => 'Otkazati čas?';

  @override
  String get trainingClassCancelThisAndFuture =>
      'Otkaži ovaj i sve buduće časove';

  @override
  String get trainingClassCancelThisOnly => 'Otkaži samo ovaj čas';

  @override
  String get trainingClassCancelled => 'Otkazano';

  @override
  String get trainingClassCapacity => 'Popunjenost';

  @override
  String trainingClassCapacityBelowBooked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Već je rezervisalo $count osoba',
      few: 'Već su rezervisale $count osobe',
      one: 'Već je rezervisala $count osoba',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassCapacityHelper => 'Ostali idu na listu čekanja';

  @override
  String get trainingClassCapacityMax => 'To je mnogo ljudi — najviše 500';

  @override
  String get trainingClassCapacityMin => 'Unesi najmanje 1';

  @override
  String get trainingClassClassCancelled => 'Čas je otkazan';

  @override
  String get trainingClassClasses => 'Grupni treninzi';

  @override
  String get trainingClassClassesCancelled => 'Časovi su otkazani';

  @override
  String trainingClassCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count časova',
      few: '$count časa',
      one: '$count čas',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassCreate => 'Napravi čas';

  @override
  String get trainingClassCreateOne => 'Napravi čas';

  @override
  String get trainingClassCreated => 'Čas je napravljen';

  @override
  String get trainingClassCurrentTrainer => 'Trenutni trener';

  @override
  String get trainingClassDescriptionOptional => 'Opis (opciono)';

  @override
  String get trainingClassDuration => 'Trajanje';

  @override
  String get trainingClassEdit => 'Izmeni čas';

  @override
  String get trainingClassEnded => 'Ovaj čas je završen.';

  @override
  String trainingClassEndsAt(String time) {
    return 'Završava se u $time';
  }

  @override
  String get trainingClassFull => 'Popunjeno';

  @override
  String trainingClassFullWaiting(int count) {
    return 'Popunjeno · $count čeka';
  }

  @override
  String get trainingClassGym => 'Teretana';

  @override
  String get trainingClassInProgress => 'Ovaj čas je u toku.';

  @override
  String get trainingClassJoinWaitlist => 'Na listu čekanja';

  @override
  String get trainingClassJumpToNext => 'Idi na sledeći čas';

  @override
  String get trainingClassKeep => 'Zadrži';

  @override
  String get trainingClassKeepClass => 'Zadrži čas';

  @override
  String get trainingClassLeaveWaitlist => 'Napusti listu čekanja';

  @override
  String trainingClassLeaveWaitlistMessage(String title) {
    return 'Izgubićeš svoje mesto na listi čekanja za $title.';
  }

  @override
  String get trainingClassLeaveWaitlistQuestion => 'Napustiti listu čekanja?';

  @override
  String get trainingClassLocationHint => 'npr. Sala A';

  @override
  String get trainingClassLocationOptional => 'Lokacija (opciono)';

  @override
  String get trainingClassMarkAttended => 'Označi prisustvo';

  @override
  String get trainingClassMarkNoShow => 'Označi da nije došao/la';

  @override
  String get trainingClassMember => 'Član';

  @override
  String get trainingClassMore => 'Još';

  @override
  String get trainingClassMyBookings => 'Moje rezervacije';

  @override
  String trainingClassMyBookingsCount(int count) {
    return 'Moje rezervacije ($count)';
  }

  @override
  String get trainingClassMyClasses => 'Moji časovi';

  @override
  String trainingClassNameYou(String name) {
    return '$name (ti)';
  }

  @override
  String get trainingClassNew => 'Novi čas';

  @override
  String trainingClassNextClass(String title, String day, String time) {
    return 'Sledeći čas: $title, $day u $time.';
  }

  @override
  String get trainingClassNoBookings => 'Još nemaš rezervacija';

  @override
  String get trainingClassNoBookingsMessage =>
      'Ovde se prikazuju časovi koje rezervišeš ili za koje si na listi čekanja.';

  @override
  String get trainingClassNoBookingsYet => 'Još niko nije rezervisao';

  @override
  String get trainingClassNoGyms => 'Nema teretana za zakazivanje';

  @override
  String get trainingClassNoGymsMessage =>
      'Časove možeš da praviš u teretanama u kojima si trener, zaposleni ili vlasnik.';

  @override
  String get trainingClassNoPast => 'Nema prošlih časova';

  @override
  String trainingClassNoPastMessage(int days) {
    return 'Ovde se prikazuju časovi koje si držao/la u poslednjih $days dana.';
  }

  @override
  String get trainingClassNoShowUndo => 'Nije došao/la (dodirni da poništiš)';

  @override
  String get trainingClassNoTrainer => 'Bez trenera';

  @override
  String get trainingClassNoUpcoming => 'Nema predstojećih časova';

  @override
  String get trainingClassNoUpcomingMessage =>
      'Zakaži jednokratni čas ili nedeljnu seriju i članovi će moći da rezervišu.';

  @override
  String get trainingClassNobodyBooked => 'Još niko nije rezervisao.';

  @override
  String get trainingClassNoneScheduled => 'Nema zakazanih časova';

  @override
  String get trainingClassNoneScheduledMessage =>
      'Tvoje teretane nisu zakazale časove za naredne dve nedelje. Proveri ponovo uskoro.';

  @override
  String get trainingClassNoneThisWeek => 'Nema časova ove nedelje';

  @override
  String get trainingClassNoneThisWeekCreate =>
      'Napravi čas ili nedeljnu seriju časova koje članovi mogu da rezervišu.';

  @override
  String get trainingClassNoneThisWeekMessage =>
      'Za ovu nedelju još ništa nije zakazano.';

  @override
  String get trainingClassNotSignedIn => 'Nisi prijavljen/a';

  @override
  String trainingClassNothingOn(String day) {
    return 'Nema časova — $day';
  }

  @override
  String get trainingClassNotifyOnChange =>
      'Oni koji su rezervisali biće obavešteni ako se promeni vreme ili lokacija.';

  @override
  String get trainingClassOneOff => 'Jednokratni čas';

  @override
  String get trainingClassPast => 'Prošli';

  @override
  String get trainingClassRefresh => 'Osveži';

  @override
  String get trainingClassRemove => 'Ukloni';

  @override
  String get trainingClassRemoveBookedMessage =>
      'Mesto će dobiti sledeća osoba sa liste čekanja.';

  @override
  String get trainingClassRemoveFromClass => 'Ukloni sa časa';

  @override
  String trainingClassRemoveQuestion(String name) {
    return 'Ukloniti: $name?';
  }

  @override
  String get trainingClassRemoveWaitlistMessage =>
      'Biće uklonjen/a sa liste čekanja.';

  @override
  String trainingClassRepeatSummary(String weekday, int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks nedelja',
      few: '$weeks nedelje',
      one: '$weeks nedelje',
    );
    return 'Svake nedelje ($weekday) tokom $_temp0';
  }

  @override
  String get trainingClassRepeatWeekly => 'Ponavljaj svake nedelje';

  @override
  String get trainingClassRoster => 'Spisak polaznika';

  @override
  String get trainingClassSaveChanges => 'Sačuvaj izmene';

  @override
  String get trainingClassSpots => 'Mesta';

  @override
  String trainingClassSpotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Još $count mesta',
      few: 'Još $count mesta',
      one: 'Još $count mesto',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassStartInFuture => 'Izaberi vreme početka u budućnosti';

  @override
  String get trainingClassTitle => 'Čas';

  @override
  String get trainingClassTitleHint => 'npr. Jutarnji HIIT';

  @override
  String get trainingClassTitleLabel => 'Naziv';

  @override
  String get trainingClassTitleRequired => 'Unesi naziv časa';

  @override
  String get trainingClassUpcoming => 'Predstojeći';

  @override
  String trainingClassUpcomingCount(int count) {
    return 'Predstojeći ($count)';
  }

  @override
  String get trainingClassUpdated => 'Čas je izmenjen';

  @override
  String trainingClassWaitlistCount(int count) {
    return 'Lista čekanja ($count)';
  }

  @override
  String trainingClassWaitlistJoined(int position) {
    return 'Čas je popunjen. Ti si #$position na listi čekanja.';
  }

  @override
  String get trainingClassWaitlistJoinedNoPosition =>
      'Čas je popunjen. Na listi čekanja si.';

  @override
  String trainingClassWaitlistPosition(int position) {
    return '#$position na listi čekanja';
  }

  @override
  String trainingClassWaitlistedPosition(int position) {
    return 'Lista čekanja #$position';
  }

  @override
  String get trainingClassWasCancelled => 'Ovaj čas je otkazan';

  @override
  String get trainingClassWeekly => 'Nedeljni čas';

  @override
  String trainingClassWeeklyCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Napravljeno je $count nedeljnih časova',
      few: 'Napravljena su $count nedeljna časa',
      one: 'Napravljen je $count nedeljni čas',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassWeeklySeries => 'Deo nedeljne serije časova';

  @override
  String get trainingClassWeeks => 'Nedelje';

  @override
  String trainingClassWeeksValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nedelja',
      few: '$count nedelje',
      one: '$count nedelja',
    );
    return '$_temp0';
  }

  @override
  String get trainingClassWhen => 'Kada';

  @override
  String get trainingClassYou => 'Ti';

  @override
  String get trainingCoachChooseMember => 'Izaberi člana';

  @override
  String get trainingCoachMyself => 'Ja';

  @override
  String get trainingCoachNoMatches => 'Nijedan član ne odgovara pretrazi';

  @override
  String get trainingCoachNoMembers =>
      'Još nemaš članove koje treniraš. Ovde se prikazuju članovi teretana u kojima radiš ili treniraš.';

  @override
  String get trainingCoachNotSignedIn => 'Nisi prijavljen';

  @override
  String get trainingCoachSearchHint => 'Pretraži članove…';

  @override
  String get trainingCoachYou => 'ti';

  @override
  String trainingDropCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dropova',
      few: '$count dropa',
      one: '$count drop',
    );
    return '$_temp0';
  }

  @override
  String get trainingExerciseAddPhoto => 'Dodaj fotografiju vežbe';

  @override
  String get trainingExerciseAllMuscles => 'Svi mišići';

  @override
  String trainingExerciseAlternating(String name) {
    return '$name (naizmenično)';
  }

  @override
  String get trainingExerciseClearFilter => 'Ukloni filter';

  @override
  String get trainingExerciseDeleteTitle => 'Obrisati vežbu?';

  @override
  String get trainingExerciseDone => 'Gotovo';

  @override
  String get trainingExerciseEditTitle => 'Izmeni vežbu';

  @override
  String get trainingExerciseFallbackName => 'Vežba';

  @override
  String trainingExerciseFilterActiveTooltip(String muscle) {
    return 'Filtriraj po mišiću (trenutno: $muscle)';
  }

  @override
  String get trainingExerciseFilterTitle => 'Filtriraj po mišiću';

  @override
  String get trainingExerciseFilterTooltip => 'Filtriraj po mišiću';

  @override
  String get trainingExerciseMyPrivate => 'Moje privatne';

  @override
  String get trainingExerciseNameLabel => 'Naziv vežbe *';

  @override
  String get trainingExerciseNewTitle => 'Nova vežba';

  @override
  String get trainingExerciseNoPrivate => 'Nemaš privatnih vežbi';

  @override
  String get trainingExerciseNoneFound => 'Nema pronađenih vežbi';

  @override
  String trainingExercisePhoto(String name) {
    return 'Fotografija: $name';
  }

  @override
  String get trainingExercisePrimaryMuscles => 'Primarni mišići';

  @override
  String get trainingExerciseSearchHint => 'Pretraži vežbe…';

  @override
  String get trainingExerciseSecondaryMuscles => 'Sekundarni mišići';

  @override
  String get trainingExerciseTapToSelect => 'Dodirni za izbor';

  @override
  String get trainingExerciseTargetMuscles => 'Ciljni mišići';

  @override
  String get trainingExerciseTitle => 'Vežbe';

  @override
  String get trainingExerciseVideo => 'Video';

  @override
  String get trainingExerciseVideoUrl => 'Link do videa';

  @override
  String get trainingLogBodyweightHint => 'Prazno = telesna težina';

  @override
  String get trainingLogChooseExercise => 'Dodirni da izabereš vežbu';

  @override
  String trainingLogCouldNotLogSet(String error) {
    return 'Serija nije zabeležena: $error';
  }

  @override
  String get trainingLogCouldNotStart => 'Pokretanje nije uspelo';

  @override
  String trainingLogElapsed(String time) {
    return 'Proteklo vreme $time';
  }

  @override
  String get trainingLogEnterReps => 'Unesi broj ponavljanja';

  @override
  String trainingLogEstimated1rm(String weight) {
    return 'Procenjeni 1RM ≈ $weight';
  }

  @override
  String get trainingLogExercise => 'Vežba';

  @override
  String get trainingLogFinish => 'Završi';

  @override
  String get trainingLogFinishMessage =>
      'Ovim se beleži vreme završetka treninga.';

  @override
  String get trainingLogFinishMessageOffline =>
      'Ovim se beleži vreme završetka treninga. Serije sačuvane oflajn sinhronizovaće se kad ponovo budeš onlajn.';

  @override
  String get trainingLogFinishTitle => 'Završiti trening?';

  @override
  String get trainingLogFirstSetHint => 'Dodirni dole da zabeležiš prvu seriju';

  @override
  String get trainingLogKeepGoing => 'Nastavi';

  @override
  String get trainingLogLog => 'Zabeleži';

  @override
  String get trainingLogLogASet => 'Zabeleži seriju';

  @override
  String get trainingLogLogSet => 'Zabeleži seriju';

  @override
  String get trainingLogLogged => 'Zabeleženo';

  @override
  String trainingLogNewPr(String exercise) {
    return 'Novi PR! $exercise';
  }

  @override
  String get trainingLogNewPrShort => 'Novi PR';

  @override
  String trainingLogNewPrWithE1rm(String exercise, String weight) {
    return 'Novi PR! $exercise — e1RM $weight';
  }

  @override
  String get trainingLogOfflineSaved =>
      'Sačuvano oflajn — sinhronizovaće se kad ponovo budeš onlajn';

  @override
  String get trainingLogPending => 'Na čekanju';

  @override
  String get trainingLogPendingSync => 'Čeka sinhronizaciju';

  @override
  String get trainingLogPickExercise => 'Prvo izaberi vežbu';

  @override
  String get trainingLogPlateTooltip => 'Kalkulator tegova i zagrevanje';

  @override
  String get trainingLogRepType => 'Tip ponavljanja';

  @override
  String get trainingLogSavedOfflineTooltip =>
      'Sačuvano oflajn — biće sinhronizovano';

  @override
  String trainingLogSetHeader(int number, String type) {
    return 'Serija $number · $type';
  }

  @override
  String trainingLogSetHeaderWithRest(int number, String type, String rest) {
    return 'Serija $number · $type · odmor $rest';
  }

  @override
  String get trainingLogStartRest => 'Pokreni tajmer odmora';

  @override
  String get trainingLogStarting => 'Pokrećem trening…';

  @override
  String get trainingLogWeight => 'Težina';

  @override
  String get trainingMeasureAdd => 'Dodaj';

  @override
  String get trainingMeasureBodyFatOptional => 'Procenat masti (opciono)';

  @override
  String trainingMeasureBodyFatValue(String value) {
    return '$value % masti';
  }

  @override
  String get trainingMeasureBodyWeight => 'Telesna težina';

  @override
  String trainingMeasureChangeSince(String change, String date) {
    return '$change od $date';
  }

  @override
  String trainingMeasureDateLabel(String date) {
    return 'Datum: $date';
  }

  @override
  String trainingMeasureDeleteMessage(String date) {
    return 'Unos od $date biće uklonjen.';
  }

  @override
  String get trainingMeasureDeleteTitle => 'Obrisati merenje?';

  @override
  String get trainingMeasureDeleteTooltip => 'Obriši merenje';

  @override
  String get trainingMeasureEditTitle => 'Izmeni merenje';

  @override
  String get trainingMeasureEmptyMessageOther => 'Još ništa nije zabeleženo.';

  @override
  String get trainingMeasureEmptyMessageOwn =>
      'Redovno beleži telesnu težinu da bi ovde video/la trend.';

  @override
  String get trainingMeasureEmptyTitle => 'Još nema merenja';

  @override
  String get trainingMeasureInvalidNumbers => 'Unesi ispravne brojeve';

  @override
  String get trainingMeasureLogAction => 'Zabeleži merenje';

  @override
  String get trainingMeasureLogHeading => 'Dnevnik';

  @override
  String get trainingMeasureNeedValue => 'Unesi težinu ili procenat masti';

  @override
  String get trainingMeasureNoteOptional => 'Beleška (opciono)';

  @override
  String get trainingMemberAssign => 'Dodeli';

  @override
  String get trainingMemberAssignMealPlan => 'Dodeli plan ishrane';

  @override
  String get trainingMemberAssignRoutine => 'Dodeli program';

  @override
  String trainingMemberAssignedBy(String name) {
    return 'Dodelio/la: $name';
  }

  @override
  String get trainingMemberAssignedByAnotherCoach => 'Dodelio drugi trener';

  @override
  String get trainingMemberAssignedByYou => 'Dodelio/la si ti';

  @override
  String get trainingMemberFoodDiary => 'Dnevnik ishrane';

  @override
  String get trainingMemberFoodDiarySubtitle => 'Obroci i makroi';

  @override
  String get trainingMemberMealPlans => 'Planovi ishrane';

  @override
  String get trainingMemberNoMealPlans => 'Nema dodeljenih planova ishrane';

  @override
  String get trainingMemberNoRoutines => 'Nema dodeljenih programa';

  @override
  String get trainingMemberNoSessions => 'Još nema zabeleženih treninga';

  @override
  String get trainingMemberProgramWorkout => 'Trening iz programa';

  @override
  String get trainingMemberProgressSubtitle =>
      'Rekordi, volumen, telesna težina';

  @override
  String get trainingMemberRecentSessions => 'Nedavni treninzi';

  @override
  String get trainingMemberRemove => 'Ukloni';

  @override
  String trainingMemberRemoveAssignmentMessage(String plan, String member) {
    return '„$plan“ više neće biti dodeljen korisniku $member.';
  }

  @override
  String get trainingMemberRemoveAssignmentTitle => 'Ukloniti dodelu?';

  @override
  String get trainingMemberRoutines => 'Programi';

  @override
  String get trainingMemberSelfAssigned => 'Samostalno dodeljeno';

  @override
  String get trainingMuscleAbsLower => 'Donji trbušnjaci';

  @override
  String get trainingMuscleAbsObliques => 'Kosi trbušnjaci';

  @override
  String get trainingMuscleAbsUpper => 'Gornji trbušnjaci';

  @override
  String get trainingMuscleBackAll => 'Leđa';

  @override
  String get trainingMuscleBackLats => 'Latisimus';

  @override
  String get trainingMuscleBackLower => 'Donja leđa';

  @override
  String get trainingMuscleBackMid => 'Srednja leđa';

  @override
  String get trainingMuscleBackRhomboids => 'Romboidi';

  @override
  String get trainingMuscleBackTraps => 'Trapez';

  @override
  String get trainingMuscleBackUpper => 'Gornja leđa';

  @override
  String get trainingMuscleBiceps => 'Biceps';

  @override
  String get trainingMuscleCalves => 'Listovi';

  @override
  String get trainingMuscleChestAll => 'Grudi';

  @override
  String get trainingMuscleChestLower => 'Donje grudi';

  @override
  String get trainingMuscleChestUpper => 'Gornje grudi';

  @override
  String get trainingMuscleDeltsAll => 'Ramena';

  @override
  String get trainingMuscleDeltsFront => 'Prednje rame';

  @override
  String get trainingMuscleDeltsMedial => 'Bočno rame';

  @override
  String get trainingMuscleDeltsRear => 'Zadnje rame';

  @override
  String get trainingMuscleForearmsAll => 'Podlaktice';

  @override
  String get trainingMuscleForearmsBottom => 'Podlaktice (donja strana)';

  @override
  String get trainingMuscleForearmsTop => 'Podlaktice (gornja strana)';

  @override
  String get trainingMuscleGlutesAll => 'Gluteus';

  @override
  String get trainingMuscleGlutesMaximus => 'Veliki gluteus';

  @override
  String get trainingMuscleGlutesMedius => 'Srednji gluteus';

  @override
  String get trainingMuscleGlutesMinimus => 'Mali gluteus';

  @override
  String get trainingMuscleHamstrings => 'Zadnja loža';

  @override
  String get trainingMuscleMapLabel => 'Dijagram mišića';

  @override
  String get trainingMuscleMapLegendSecondary => 'Sekundarni';

  @override
  String get trainingMuscleMapLegendTarget => 'Ciljni';

  @override
  String get trainingMuscleMapNone => 'Nijedan mišić nije označen';

  @override
  String trainingMuscleMapPrimary(String muscles) {
    return 'Primarni: $muscles';
  }

  @override
  String trainingMuscleMapSecondary(String muscles) {
    return 'Sekundarni: $muscles';
  }

  @override
  String get trainingMuscleNeck => 'Vrat';

  @override
  String get trainingMuscleQuadsAll => 'Kvadriceps';

  @override
  String get trainingMuscleQuadsLateral => 'Spoljašnji kvadriceps';

  @override
  String get trainingMuscleQuadsMedial => 'Unutrašnji kvadriceps';

  @override
  String get trainingMuscleTricepsAll => 'Triceps';

  @override
  String get trainingMuscleTricepsLateral => 'Bočna glava tricepsa';

  @override
  String get trainingMuscleTricepsLong => 'Duga glava tricepsa';

  @override
  String get trainingMuscleTricepsMedial => 'Medijalna glava tricepsa';

  @override
  String get trainingPlanAddCoverPhoto => 'Dodaj naslovnu fotografiju';

  @override
  String get trainingPlanAddDrop => 'Dodaj drop';

  @override
  String get trainingPlanAddExerciseToSuperset => 'Dodaj vežbu u superseriju';

  @override
  String get trainingPlanAddSet => 'Dodaj seriju';

  @override
  String get trainingPlanAlternating => 'Naizmenično';

  @override
  String get trainingPlanAlternatingShort => 'Naizm.';

  @override
  String get trainingPlanCollapse => 'Skupi';

  @override
  String trainingPlanDeleteBody(String name) {
    return 'Trajno obrisati „$name“?';
  }

  @override
  String get trainingPlanDeleteTitle => 'Obrisati trening?';

  @override
  String get trainingPlanDescriptionLabel => 'Opis';

  @override
  String trainingPlanDropLine(int number, String details) {
    return 'Drop $number: $details';
  }

  @override
  String trainingPlanDropNumber(int number) {
    return 'Drop $number';
  }

  @override
  String get trainingPlanEditTitle => 'Izmeni trening';

  @override
  String get trainingPlanExpand => 'Proširi';

  @override
  String get trainingPlanMakeDropset => 'Napravi drop set';

  @override
  String get trainingPlanMusclesTrained => 'Mišići koji se treniraju';

  @override
  String get trainingPlanNameLabel => 'Naziv treninga *';

  @override
  String get trainingPlanNotes => 'Beleške';

  @override
  String get trainingPlanPickExercise => 'Izaberi vežbu';

  @override
  String get trainingPlanProgramme => 'Plan treninga';

  @override
  String get trainingPlanPublic => 'Javno';

  @override
  String get trainingPlanPublicSubtitle => 'Vidljivo svim korisnicima';

  @override
  String get trainingPlanRemoveDrop => 'Ukloni drop';

  @override
  String get trainingPlanRemoveExercise => 'Ukloni vežbu';

  @override
  String get trainingPlanRemoveSet => 'Ukloni seriju';

  @override
  String get trainingPlanReorderSet => 'Prevuci za promenu redosleda';

  @override
  String trainingPlanRestSeconds(int seconds) {
    return 'Odmor $seconds s';
  }

  @override
  String get trainingPlanSelectExercise => 'Izaberi vežbu…';

  @override
  String get trainingPlanSets => 'Serije';

  @override
  String get trainingPlanStartSession => 'Započni trening';

  @override
  String trainingPlateAvailable(String plates) {
    return 'Tegovi: $plates';
  }

  @override
  String get trainingPlateBar => 'Šipka';

  @override
  String get trainingPlateEachSide => 'Svaka strana';

  @override
  String get trainingPlateEmptyBar => 'Prazna šipka';

  @override
  String get trainingPlateEnterTarget =>
      'Unesi ciljnu težinu da vidiš tegove za svaku stranu.';

  @override
  String get trainingPlateNoWarmup =>
      'Cilj je jednak ili manji od šipke — tegovi za zagrevanje nisu potrebni.';

  @override
  String trainingPlateNotExact(
    String target,
    String closest,
    String difference,
  ) {
    return '$target ne može da se natovari tačno. Najbliže: $closest ($difference).';
  }

  @override
  String trainingPlatePerSide(String plates) {
    return 'Po strani: $plates';
  }

  @override
  String trainingPlateSuggestedRamp(String weight) {
    return 'Predlog zagrevanja do $weight';
  }

  @override
  String get trainingPlateTargetWeight => 'Ciljna težina';

  @override
  String get trainingPlateTitle => 'Kalkulator tegova';

  @override
  String trainingPlateTotal(String weight) {
    return 'Ukupno $weight';
  }

  @override
  String get trainingPlateWarmup => 'Zagrevanje';

  @override
  String get trainingProgressBestE1rm => 'Najbolji e1RM';

  @override
  String get trainingProgressBestVolume => 'Najveći volumen';

  @override
  String trainingProgressChartE1rm(String unit) {
    return 'Procenjeni 1RM ($unit)';
  }

  @override
  String trainingProgressChartVolume(String unit) {
    return 'Volumen treninga ($unit × ponavljanja)';
  }

  @override
  String trainingProgressChartWeight(String unit) {
    return 'Najteža serija ($unit)';
  }

  @override
  String trainingProgressE1rm(String weight) {
    return 'e1RM $weight';
  }

  @override
  String get trainingProgressEmptyMessage =>
      'Zabeleži trening i ovde će se pojaviti tvoj volumen, niz i lični rekordi.';

  @override
  String get trainingProgressEmptyTitle => 'Još nema zabeleženih treninga';

  @override
  String get trainingProgressExercises => 'Vežbe';

  @override
  String get trainingProgressFilterExercises => 'Filtriraj vežbe…';

  @override
  String get trainingProgressHeaviest => 'Najteže';

  @override
  String get trainingProgressLast30Days => 'poslednjih 30 dana';

  @override
  String trainingProgressLastSession(String when) {
    return 'Poslednji trening: $when';
  }

  @override
  String get trainingProgressMetricE1rm => 'e1RM';

  @override
  String get trainingProgressMetricVolume => 'Volumen';

  @override
  String get trainingProgressMetricWeight => 'Najveća težina';

  @override
  String get trainingProgressNoData => 'Nema podataka';

  @override
  String get trainingProgressNoExercises => 'Još nema zabeleženih vežbi';

  @override
  String get trainingProgressNoExercisesMatch => 'Nijedna vežba ne odgovara';

  @override
  String get trainingProgressNoRecentPrs =>
      'Nema novih ličnih rekorda u poslednjih 30 dana. Nadmaši svoj najbolji procenjeni 1RM na bilo kojoj vežbi da postaviš novi.';

  @override
  String get trainingProgressNoSessionsInRange =>
      'Nema treninga u ovom periodu';

  @override
  String get trainingProgressPersonalRecords => 'Lični rekordi';

  @override
  String get trainingProgressRange1m => '1 mes.';

  @override
  String get trainingProgressRange3m => '3 mes.';

  @override
  String get trainingProgressRange6m => '6 mes.';

  @override
  String get trainingProgressRangeAll => 'Sve';

  @override
  String get trainingProgressRecentPrs => 'Nedavni rekordi';

  @override
  String trainingProgressRepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ponavljanja',
      few: '$count ponavljanja',
      one: '$count ponavljanje',
    );
    return '$_temp0';
  }

  @override
  String get trainingProgressSeriesE1rm => 'Procenjeni 1RM';

  @override
  String get trainingProgressSeriesVolume => 'Volumen treninga';

  @override
  String get trainingProgressSeriesWeight => 'Najteža serija';

  @override
  String trainingProgressSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count treninga',
      few: '$count treninga',
      one: '$count trening',
    );
    return '$_temp0';
  }

  @override
  String get trainingProgressSessionsHeading => 'Treninzi';

  @override
  String trainingProgressSessionsInRange(String range) {
    return 'Treninzi ($range)';
  }

  @override
  String get trainingProgressStatSessions30d => 'Treninzi · 30 dana';

  @override
  String get trainingProgressStatSessions7d => 'Treninzi · 7 dana';

  @override
  String get trainingProgressStatStreak => 'Nedeljni niz';

  @override
  String get trainingProgressStatVolume30d => 'Volumen · 30 dana';

  @override
  String get trainingProgressStreakDone => 'Trenirao/la si ove nedelje';

  @override
  String get trainingProgressStreakKeep => 'Treniraj ove nedelje da ga zadržiš';

  @override
  String get trainingProgressStreakStart =>
      'Treniraj ove nedelje da ga započneš';

  @override
  String trainingProgressStreakWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ned.',
      few: '$count ned.',
      one: '$count ned.',
    );
    return '$_temp0';
  }

  @override
  String get trainingProgressTabBody => 'Telo';

  @override
  String get trainingProgressTabTraining => 'Trening';

  @override
  String get trainingProgressTitle => 'Napredak';

  @override
  String trainingProgressTopWeight(String weight) {
    return 'Najviše $weight';
  }

  @override
  String trainingProgressTrendSemantics(String value) {
    return 'Trend, poslednja vrednost $value';
  }

  @override
  String get trainingProgressYesterday => 'Juče';

  @override
  String get trainingRepFailureShort => 'Otkaz';

  @override
  String get trainingRepTypeCount => 'Ponavljanja';

  @override
  String get trainingRepTypeFailure => 'Do otkaza';

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
    return 'Dodaj $seconds sekundi';
  }

  @override
  String trainingRestPresetTooltip(String time) {
    return 'Odmor $time';
  }

  @override
  String trainingRestRemaining(String time) {
    return 'Preostalo odmora: $time';
  }

  @override
  String get trainingRestSkip => 'Preskoči';

  @override
  String get trainingRestTitle => 'Odmor';

  @override
  String get trainingRoutineAdd => 'Dodaj';

  @override
  String get trainingRoutineDayHint => 'Dan';

  @override
  String get trainingRoutineDeleteTitle => 'Obrisati program?';

  @override
  String get trainingRoutineDeleteTooltip => 'Obriši program';

  @override
  String get trainingRoutineEditTitle => 'Izmeni program';

  @override
  String get trainingRoutineEditTooltip => 'Izmeni program';

  @override
  String get trainingRoutineInvalidNumber => 'Unesi ispravan broj';

  @override
  String get trainingRoutineInvalidWeeks => 'Unesi ispravan broj nedelja';

  @override
  String get trainingRoutineMine => 'Moj';

  @override
  String get trainingRoutineNameLabel => 'Naziv programa *';

  @override
  String get trainingRoutineNoTrainings => 'Još nema dodeljenih treninga';

  @override
  String get trainingRoutineNoTrainingsAdded => 'Još nema dodatih treninga';

  @override
  String get trainingRoutineNumWeeksHint => 'npr. 12';

  @override
  String get trainingRoutineNumWeeksLabel => 'Broj nedelja *';

  @override
  String get trainingRoutinePrivate => 'Privatno';

  @override
  String get trainingRoutineRemoveTraining => 'Ukloni trening';

  @override
  String get trainingRoutineRestDay => 'Dan odmora';

  @override
  String get trainingRoutineSchedule => 'Raspored';

  @override
  String get trainingRoutineScheduleType => 'Tip rasporeda';

  @override
  String get trainingRoutineSearchTrainingsHint => 'Pretraži treninge…';

  @override
  String trainingRoutineTrainingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count treninga',
      few: '$count treninga',
      one: '$count trening',
    );
    return '$_temp0';
  }

  @override
  String get trainingRoutineTrainingFallback => 'Trening';

  @override
  String trainingRoutineWeek(int week) {
    return 'Nedelja $week';
  }

  @override
  String trainingRoutineWeekShort(int week) {
    return 'Ned. $week';
  }

  @override
  String get trainingRoutineWeekShortHint => 'Ned.';

  @override
  String get trainingScheduleFixedWeeks => 'Fiksne nedelje';

  @override
  String get trainingScheduleHasClasses => 'ima časova';

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
    return '$range (+1 dan)';
  }

  @override
  String get trainingScheduleNextWeek => 'Sledeća nedelja';

  @override
  String get trainingSchedulePreviousWeek => 'Prethodna nedelja';

  @override
  String get trainingScheduleThisWeek => 'Ove nedelje';

  @override
  String get trainingScheduleTitle => 'Raspored';

  @override
  String get trainingScheduleTomorrow => 'Sutra';

  @override
  String get trainingScheduleWildcard => 'Slobodan raspored';

  @override
  String get trainingScheduleYesterday => 'Juče';

  @override
  String get trainingSessionAddDrop => 'Dodaj drop';

  @override
  String get trainingSessionCommentAthlete => 'Sportista';

  @override
  String get trainingSessionCommentCoach => 'Trener';

  @override
  String trainingSessionCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count komentara',
      few: '$count komentara',
      one: '$count komentar',
    );
    return '$_temp0';
  }

  @override
  String get trainingSessionCommentDeleteMessage =>
      'Ovaj komentar će biti trajno uklonjen.';

  @override
  String get trainingSessionCommentDeleteTitle => 'Obrisati komentar?';

  @override
  String get trainingSessionCommentEditTitle => 'Izmeni komentar';

  @override
  String trainingSessionCommentEdited(String when) {
    return '$when · izmenjeno';
  }

  @override
  String get trainingSessionCommentHint => 'Dodaj komentar…';

  @override
  String get trainingSessionCommentOptions => 'Opcije komentara';

  @override
  String get trainingSessionCommentYou => 'Ti';

  @override
  String get trainingSessionComments => 'Komentari';

  @override
  String get trainingSessionDate => 'Datum';

  @override
  String get trainingSessionDeleteMessage =>
      'Ovaj zapis će biti trajno uklonjen.';

  @override
  String get trainingSessionDeleteSetTooltip => 'Obriši seriju';

  @override
  String get trainingSessionDeleteTitle => 'Obrisati trening?';

  @override
  String get trainingSessionDeleteTooltip => 'Obriši trening';

  @override
  String get trainingSessionDeletedUser => 'Obrisan korisnik';

  @override
  String get trainingSessionDetailTitle => 'Detalji treninga';

  @override
  String trainingSessionDropNumber(int number) {
    return 'Drop $number';
  }

  @override
  String get trainingSessionDuration => 'Trajanje';

  @override
  String trainingSessionDurationSemantics(String duration) {
    return 'Trajanje $duration';
  }

  @override
  String trainingSessionEditSetTitle(String title) {
    return 'Izmeni: $title';
  }

  @override
  String get trainingSessionEditSetTooltip => 'Izmeni seriju';

  @override
  String get trainingSessionFree => 'Slobodan trening';

  @override
  String get trainingSessionInProgress => 'U toku';

  @override
  String get trainingSessionNoComments =>
      'Još nema komentara. Treneri i sportista ovde mogu da ostave povratnu informaciju.';

  @override
  String get trainingSessionNoReps => 'Nema zabeleženih ponavljanja';

  @override
  String get trainingSessionNoSets => 'Nema zabeleženih serija';

  @override
  String get trainingSessionNote => 'Beleška';

  @override
  String get trainingSessionNotes => 'Beleške';

  @override
  String get trainingSessionPlanned => 'Trening po planu';

  @override
  String get trainingSessionRemoveDrop => 'Ukloni drop';

  @override
  String get trainingSessionRepType => 'Tip';

  @override
  String get trainingSessionRepsWholeNumber =>
      'Ponavljanja moraju biti ceo broj';

  @override
  String get trainingSessionSendComment => 'Pošalji komentar';

  @override
  String get trainingSessionSetDeleteMessage =>
      'Ova zabeležena serija će biti trajno uklonjena.';

  @override
  String get trainingSessionSetDeleteTitle => 'Obrisati seriju?';

  @override
  String trainingSessionSetTitle(int number) {
    return 'Serija $number';
  }

  @override
  String trainingSessionSetTitleWithExercise(int number, String exercise) {
    return 'Serija $number · $exercise';
  }

  @override
  String trainingSessionSetsLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zabeleženih serija',
      few: '$count zabeležene serije',
      one: '$count zabeležena serija',
    );
    return '$_temp0';
  }

  @override
  String get trainingSessionTapToEdit => 'Dodirni seriju da je izmeniš.';

  @override
  String trainingSessionTodayAt(String time) {
    return 'Danas $time';
  }

  @override
  String get trainingSessionTrainer => 'Trener';

  @override
  String get trainingSessionWeightNumber => 'Težina mora biti broj';

  @override
  String trainingSessionYesterdayAt(String time) {
    return 'Juče $time';
  }

  @override
  String get trainingSessionsClassesTitle => 'Časovi';

  @override
  String get trainingSessionsEmpty => 'Još nema treninga';

  @override
  String get trainingSessionsEmptyHint => 'Dodirni + da započneš prvi trening';

  @override
  String get trainingSessionsMyProgress => 'Moj napredak';

  @override
  String get trainingSessionsNew => 'Novi trening';

  @override
  String get trainingSessionsNoClasses => 'Još nema časova';

  @override
  String get trainingSessionsNoClassesHint =>
      'Ovde će se pojaviti treninzi koje vodiš za članove';

  @override
  String get trainingSessionsTitle => 'Treninzi';

  @override
  String get trainingSetTypeCircuit => 'Kružni trening';

  @override
  String get trainingSetTypeDropset => 'Drop set';

  @override
  String get trainingSetTypeStandard => 'Klasična serija';

  @override
  String get trainingSetTypeSuperset => 'Superserija';

  @override
  String get trainingShiftAdd => 'Dodaj smenu';

  @override
  String trainingShiftAddOn(String day) {
    return 'Dodaj smenu — $day';
  }

  @override
  String get trainingShiftAddOne => 'Dodaj smenu';

  @override
  String get trainingShiftAdded => 'Smena je dodata';

  @override
  String trainingShiftCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count smena',
      few: '$count smene',
      one: '$count smena',
    );
    return '$_temp0';
  }

  @override
  String get trainingShiftDelete => 'Obriši smenu';

  @override
  String trainingShiftDeleteMessage(String name, String day) {
    return 'Smena ($name, $day) biće uklonjena.';
  }

  @override
  String trainingShiftDeleteNotifyMessage(String name, String day) {
    return 'Smena ($name, $day) biće uklonjena i ta osoba će biti obaveštena.';
  }

  @override
  String get trainingShiftDeleteQuestion => 'Obrisati smenu?';

  @override
  String get trainingShiftDeleted => 'Smena je obrisana';

  @override
  String get trainingShiftEdit => 'Izmeni smenu';

  @override
  String trainingShiftEnd(String time) {
    return 'Kraj $time';
  }

  @override
  String trainingShiftEndsNextDay(String duration) {
    return '$duration · završava se sutradan';
  }

  @override
  String get trainingShiftFree =>
      'Slobodan/na si. Nove smene će se pojaviti ovde.';

  @override
  String get trainingShiftLoadFailed => 'Učitavanje smena nije uspelo';

  @override
  String get trainingShiftMyShifts => 'Moje smene';

  @override
  String get trainingShiftNew => 'Nova smena';

  @override
  String trainingShiftNextDays(int days) {
    return 'Narednih $days dana';
  }

  @override
  String get trainingShiftNextShifts => 'Sledeće smene';

  @override
  String get trainingShiftNoStaff => 'Nema zaposlenih za raspored';

  @override
  String get trainingShiftNoStaffMessage =>
      'Prvo dodaj zaposlene, zaposlene trenere ili trenere u ovu teretanu.';

  @override
  String get trainingShiftNoUpcoming => 'Nema predstojećih smena';

  @override
  String get trainingShiftNoUpcomingMessage =>
      'Kada te menadžer rasporedi, tvoje smene će se pojaviti ovde i dobićeš obaveštenje.';

  @override
  String get trainingShiftNone => 'Nema smena';

  @override
  String get trainingShiftNoneThisWeek => 'Nema smena ove nedelje';

  @override
  String get trainingShiftNoneThisWeekManage =>
      'Isplaniraj ko kada radi. Zaposleni dobijaju obaveštenja o svojim smenama.';

  @override
  String get trainingShiftNoneThisWeekMessage =>
      'Za ovu nedelju još niko nije raspoređen.';

  @override
  String get trainingShiftNoteHint => 'npr. Recepcija, otvaranje';

  @override
  String get trainingShiftNoteOptional => 'Napomena (opciono)';

  @override
  String get trainingShiftOnNow => 'U toku';

  @override
  String get trainingShiftOptions => 'Opcije smene';

  @override
  String get trainingShiftPickStaff => 'Izaberi ko radi u ovoj smeni';

  @override
  String get trainingShiftSeeAll => 'Prikaži sve';

  @override
  String get trainingShiftShifts => 'Smene';

  @override
  String get trainingShiftStaffMember => 'Zaposleni';

  @override
  String trainingShiftStart(String time) {
    return 'Početak $time';
  }

  @override
  String get trainingShiftUpdated => 'Smena je izmenjena';

  @override
  String get trainingSideBoth => 'Obe strane';

  @override
  String get trainingSideLeft => 'Leva';

  @override
  String get trainingSideRight => 'Desna';

  @override
  String get trainingStaffRoleEmployee => 'Zaposleni';

  @override
  String get trainingStaffRoleEmployeeTrainer => 'Zaposleni / trener';

  @override
  String get trainingStaffRoleTrainer => 'Trener';

  @override
  String trainingWeekProgram(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'Program od $weeks nedelja',
      few: 'Program od $weeks nedelje',
      one: 'Program od $weeks nedelje',
    );
    return '$_temp0';
  }

  @override
  String trainingWorkoutsAssignedByMe(int count) {
    return 'Od mene ($count)';
  }

  @override
  String trainingWorkoutsAssignedFor(String name) {
    return 'Za: $name';
  }

  @override
  String get trainingWorkoutsAssignedForMember => 'Za člana';

  @override
  String trainingWorkoutsAssignedFrom(String name) {
    return 'Od: $name';
  }

  @override
  String get trainingWorkoutsAssignedFromCoach => 'Od tvog trenera';

  @override
  String trainingWorkoutsAssignedToMe(int count) {
    return 'Dodeljeno meni ($count)';
  }

  @override
  String get trainingWorkoutsByMeEmpty =>
      'Još nikome nisi dodelio program.\nOtvori program i dodirni Dodeli.';

  @override
  String get trainingWorkoutsClearSearch => 'Obriši pretragu';

  @override
  String get trainingWorkoutsCreate => 'Napravi';

  @override
  String get trainingWorkoutsMyRoutines => 'Moji programi';

  @override
  String get trainingWorkoutsMyTrainings => 'Moji treninzi';

  @override
  String get trainingWorkoutsNewRoutine => 'Novi program';

  @override
  String get trainingWorkoutsNewTraining => 'Novi trening';

  @override
  String get trainingWorkoutsNoTrainings => 'Nema pronađenih treninga';

  @override
  String get trainingWorkoutsSelfAssigned => 'Samostalno dodeljeno';

  @override
  String trainingWorkoutsSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serija',
      few: '$count serije',
      one: '$count serija',
    );
    return '$_temp0';
  }

  @override
  String get trainingWorkoutsTabAssigned => 'Dodeljeno';

  @override
  String get trainingWorkoutsTabLibrary => 'Moja biblioteka';

  @override
  String get trainingWorkoutsTabRoutines => 'Programi';

  @override
  String get trainingWorkoutsTabTrainings => 'Treninzi';

  @override
  String get trainingWorkoutsTitle => 'Treninzi';

  @override
  String get trainingWorkoutsToMeEmpty =>
      'Još ti nije dodeljen nijedan program.\nOvde se prikazuju programi koje ti dodeli trener.';
}
