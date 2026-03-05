class StringUtils {

  static String formatTotalTime(int totalMinutes) {
    if (totalMinutes <= 0) return "0m";
    
    final int h = totalMinutes ~/ 60;
    final int m = totalMinutes % 60;

    if (h > 0 && m > 0) {
      return "${h}h ${m}m";
    } else if (h > 0) {
      return "${h}h";
    } else {
      return "${m}m";
    }
  }

  
  static String truncateWithMore(String text, int limit) {
    if (text.length <= limit) return text;
    return "${text.substring(0, limit).trim()}+more";
  }
}
