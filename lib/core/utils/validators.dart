/// Reusable `TextFormField` validators. Each returns `null` when valid and an
/// error string otherwise.
class Validators {
  const Validators._();

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final re = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!re.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Use at least 6 characters';
    return null;
  }

  /// Confirm-password check — [value] must equal [original].
  static String? matches(String? value, String original,
      {String field = 'Passwords'}) {
    if (value == null || value.isEmpty) return 'Please re-enter your password';
    if (value != original) return '$field do not match';
    return null;
  }

  /// A username handle: 4–20 characters, letters/digits/dot/underscore, and it
  /// must start with a letter.
  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    final v = value.trim();
    if (v.length < 4 || v.length > 20) return 'Use 4 to 20 characters';
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9._]*$').hasMatch(v)) {
      return 'Start with a letter; letters, numbers, . and _ only';
    }
    return null;
  }

  /// RSBSA registry number — the national farmer registry ID used to confirm a
  /// farmer really is a Tubungan resident. Format varies across issuances, so
  /// this checks shape (digits and dashes, 8–20 characters) rather than a rigid
  /// mask that would reject valid cards.
  static String? rsbsa(String? value, {bool optional = false}) {
    if (value == null || value.trim().isEmpty) {
      return optional ? null : 'RSBSA number is required';
    }
    final v = value.trim();
    if (!RegExp(r'^[0-9\-]{8,20}$').hasMatch(v)) {
      return 'Enter the number as printed on your RSBSA card';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Contact number is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 13) {
      return 'Enter a valid contact number';
    }
    return null;
  }

  static String? positiveNumber(String? value, {String field = 'Value'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid number';
    if (parsed <= 0) return '$field must be greater than zero';
    return null;
  }

  static String? nonNegativeNumber(String? value, {String field = 'Value'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return '$field cannot be negative';
    return null;
  }

  static String? percentage(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = double.tryParse(value);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0 || parsed > 100) return 'Must be between 0 and 100';
    return null;
  }
}
