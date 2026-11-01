// Display units for tape measurements. The API stores centimetres; people
// who weigh in pounds see inches, everyone else centimetres.

const double cmPerInch = 2.54;

/// 'in' for a pound user, else 'cm'.
String lengthUnitFor(String weightUnit) => weightUnit == 'lb' ? 'in' : 'cm';

/// [cm] in the display unit for [weightUnit].
double toDisplayLength(double cm, String weightUnit) => weightUnit == 'lb' ? cm / cmPerInch : cm;

/// A display-unit value back to cm, rounded to one decimal (the API's precision).
double fromDisplayLength(double value, String weightUnit) {
  final cm = weightUnit == 'lb' ? value * cmPerInch : value;
  return (cm * 10).round() / 10;
}
