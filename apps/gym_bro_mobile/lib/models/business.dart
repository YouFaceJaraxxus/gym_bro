class Business {
  final String id;
  final String name;
  final String location;
  final String? logo;
  final String workingHoursFrom;
  final String workingHoursTo;
  final List<int> workingWeekdays;
  final String type; // 'gym' | 'shop'

  const Business({
    required this.id,
    required this.name,
    required this.location,
    this.logo,
    required this.workingHoursFrom,
    required this.workingHoursTo,
    required this.workingWeekdays,
    required this.type,
  });

  factory Business.fromJson(Map<String, dynamic> json) => Business(
        id: json['id'] as String,
        name: json['name'] as String,
        location: json['location'] as String,
        logo: json['logo'] as String?,
        workingHoursFrom: json['working_hours_from'] as String,
        workingHoursTo: json['working_hours_to'] as String,
        workingWeekdays: List<int>.from(json['working_weekdays'] as List),
        type: json['type'] as String,
      );
}
