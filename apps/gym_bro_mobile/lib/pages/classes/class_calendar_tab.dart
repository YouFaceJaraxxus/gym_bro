import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/class_calendar.dart';
import 'class_detail_page.dart';

/// The trainer's calendar: every session they teach, upcoming and done
/// (cancelled ones too), day by day. Tapping one opens it.
class ClassCalendarTab extends StatefulWidget {
  const ClassCalendarTab({super.key});

  @override
  State<ClassCalendarTab> createState() => _ClassCalendarTabState();
}

class _ClassCalendarTabState extends State<ClassCalendarTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final notSignedIn = context.l10n.trainingClassNotSignedIn;
    return ClassCalendar(
      load: (from, to) async {
        final me = AuthManager.instance.profile?.id;
        if (me == null) throw Exception(notSignedIn);
        final token = await AuthManager.instance.getValidToken();
        return _api.getClasses(
          token,
          trainerId: me,
          from: from,
          to: to,
          includeCancelled: true,
        );
      },
      onTap: (c) => Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => ClassDetailPage(classId: c.id)),
      ),
    );
  }
}
