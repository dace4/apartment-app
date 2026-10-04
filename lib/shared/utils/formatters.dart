//Format an amoubt in Swiss francs with ' exemple => 1850 ; 1'850
String formatChf(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write("'");
    buffer.write(digits[i]);
  }
  return 'CHF $buffer';
}

//Format a swiss room count without a useless ".0"
String formatRooms(double rooms) {
  final number = rooms % 1 == 0 ? rooms.toInt().toString() : rooms.toString();
  return '$number rooms';
}
