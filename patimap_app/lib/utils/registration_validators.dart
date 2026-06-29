abstract final class RegistrationValidators {
  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String? emptyField(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label boş bırakılamaz.';
    }
    return null;
  }

  static String? emailFormat(String email) {
    final t = email.trim();
    if (t.isEmpty) return null;
    if (!_emailPattern.hasMatch(t)) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  static String? passwordMatch(String password, String confirm) {
    if (password != confirm) {
      return 'Şifreler eşleşmiyor.';
    }
    return null;
  }

  static String? passwordLength(String password, {int min = 6}) {
    if (password.length < min) {
      return 'Şifre en az $min karakter olmalıdır.';
    }
    return null;
  }
}
