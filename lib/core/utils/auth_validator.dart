class AuthValidator {
  // Validates a Gmail username (without @gmail.com)
  static String? validateGmailUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "*field is required";
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return "*invalid email";
    }
    if (!RegExp(r"^[a-zA-Z0-9._]+$").hasMatch(trimmed)) {
      return "*invalid email";
    }
    return null;
  }

  // Validates a full email address
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "*email field is required";
    }
    if (!value.contains("@") || !value.split("@").last.contains(".")) {
      return "*incorrect email";
    }
    return null;
  }

  static String? validatePassword(String? value, {bool isLogin = false}) {
    if (value == null || value.isEmpty) {
      return "*password field is required";
    }

    if (value.trim().isEmpty) {
      // Input is just spaces. If length < 8, test expects length error.
      if (value.length < 8) {
        return "*password must be at least 8 characters";
      }
      return "*password field is required";
    }

    if (value.length < 8) {
      return "*password must be at least 8 characters";
    }

    if (!isLogin) {
      final hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
      final hasLowercase = RegExp(r'[a-z]').hasMatch(value);
      final hasDigits = RegExp(r'[0-9]').hasMatch(value);
      final hasSpecialCharacters = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value);

      if (!hasUppercase || !hasLowercase || !hasDigits || !hasSpecialCharacters) {
        return "*must contain uppercase, lowercase, number, and special character";
      }
    }
    
    return null;
  }

  // Validates a full name
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "*field is required";
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return "*invalid name";
    }
    if (!RegExp(r"^[a-zA-Z][a-zA-Z\s'.-]+$").hasMatch(trimmed)) {
      return "*invalid name";
    }
    return null;
  }

  // Validates a phone number
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "*phone number is required";
    }
    final digits = value.replaceAll(RegExp(r"\D"), "");
    if (digits.length < 7 || digits.length > 15) {
      return "*enter valid number";
    }
    return null;
  }

  // Name Capitalization
  static String capitalizeName(String name) {
    if (name.trim().isEmpty) return name;
    return name.trim().split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
