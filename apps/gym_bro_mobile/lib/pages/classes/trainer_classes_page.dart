import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'class_calendar_tab.dart';
import 'customers_tab.dart';
import 'series_list_tab.dart';

/// The trainer's "My classes", as three icon tabs: a calendar of their
/// sessions (upcoming and done), the classes they run (timetables, with a
/// button to create one), and their customers.
class TrainerClassesPage extends StatelessWidget {
  const TrainerClassesPage({super.key, this.initialTab = 0});

  /// 0 calendar, 1 classes, 2 customers.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    Tab tab(IconData icon, String label) => Tab(
      icon: Tooltip(message: label, child: Icon(icon, semanticLabel: label)),
    );
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Column(
        children: [
          Material(
            color: cs.surface,
            child: TabBar(
              tabs: [
                tab(Icons.calendar_month_outlined, l10n.trainerClassesTabCalendar),
                // A coach's whistle; the dumbbell is the Gym tab.
                tab(Icons.sports, l10n.trainerClassesTabClasses),
                tab(Icons.people_outline, l10n.trainerClassesTabCustomers),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [ClassCalendarTab(), ClassSeriesListTab(), CustomersTab()],
            ),
          ),
        ],
      ),
    );
  }
}
