
void main() {
  final unitPattern = 'l|liter|liters|g|gram';
  // Correct regex with word boundaries
  final unitRegex = RegExp(r'\b(' + unitPattern + r')\b', caseSensitive: false);

  final tests = [
    '4 large potatoes',
    '4 l water',
    '10 grams sugar',
    '10g sugar',
    'onions',
    '1 heads lettuce'
  ];

  for (var t in tests) {
    final match = unitRegex.firstMatch(t);
    if (match != null) {
      print('Match in "$t": unit="${match.group(1)}" at ${match.start}');
    } else {
      print('No match in "$t"');
    }
  }
}
