
void main() {
  final unitPattern = 'l|liter|liters';
  // The current code uses r'\\b'
  final unitRegex1 = RegExp(r'\\b(' + unitPattern + r')\\b', caseSensitive: false);
  // The proposed fix uses r'\b'
  final unitRegex2 = RegExp(r'\b(' + unitPattern + r')\b', caseSensitive: false);

  final input = '4 large potatoes';
  
  print('Regex 1 (r"\\\\b"): ${unitRegex1.hasMatch(input)}');
  if (unitRegex1.hasMatch(input)) {
    final m = unitRegex1.firstMatch(input)!;
    print('Match 1: "${m.group(0)}" at ${m.start}');
  }

  print('Regex 2 (r"\\b"): ${unitRegex2.hasMatch(input)}');
  if (unitRegex2.hasMatch(input)) {
    final m = unitRegex2.firstMatch(input)!;
    print('Match 2: "${m.group(0)}" at ${m.start}');
  }
  
  final input2 = '4 l water';
  print('Regex 2 on "4 l water": ${unitRegex2.hasMatch(input2)}');
  if (unitRegex2.hasMatch(input2)) {
    final m = unitRegex2.firstMatch(input2)!;
    print('Match: "${m.group(1)}" at ${m.start}');
  }
}
