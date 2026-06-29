/// Guclu sifre kurallari (login sifre sifirlama + ayarlar).
class PasswordRules {
  PasswordRules._();

  static const int minLength = 8;

  static String? validate(String? password) {
    if (password == null || password.isEmpty) {
      return 'Sifre zorunludur.';
    }
    if (password.length < minLength) {
      return 'Sifre en az $minLength karakter olmali.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'En az 1 buyuk harf icermeli.';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'En az 1 kucuk harf icermeli.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'En az 1 rakam icermeli.';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]'))) {
      return 'En az 1 ozel karakter icermeli.';
    }
    return null;
  }

  static String? validateMatch(String password, String confirm) {
    final base = validate(password);
    if (base != null) return base;
    if (password != confirm) {
      return 'Yeni sifre ve tekrar ayni olmali.';
    }
    return null;
  }

  static const List<String> hintLines = [
    'En az 8 karakter',
    'En az 1 buyuk ve 1 kucuk harf',
    'En az 1 rakam ve 1 ozel karakter',
  ];
}
