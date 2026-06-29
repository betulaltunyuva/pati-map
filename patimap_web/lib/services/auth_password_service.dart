import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/password_rules.dart';

/// Supabase Auth sifre sifirlama ve guncelleme.
class AuthPasswordService {
  AuthPasswordService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String messageForError(Object error) {
    if (error is AuthException) {
      final m = error.message.trim();
      if (m.isNotEmpty) return m;
    }
    return 'Islem tamamlanamadi. Lutfen tekrar deneyin.';
  }

  /// E-postaya sifre sifirlama OTP kodu gonderir.
  /// TODO: Supabase Dashboard > Auth > Email Templates icinde recovery OTP (8 hane) acik olmali.
  static Future<void> sendPasswordResetOtp(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw const AuthException('Gecerli bir e-posta girin.');
    }
    await _client.auth.resetPasswordForEmail(
      normalized,
      // Web panel: redirect URL Dashboard uzerinden OTP girisi icin opsiyonel.
      redirectTo: kIsWeb ? Uri.base.origin : null,
    );
  }

  /// Maildeki kodu dogrular; basarili olunca gecici oturum acilir.
  static Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    final normalized = email.trim().toLowerCase();
    final code = token.trim();
    if (code.length != 8) {
      throw const AuthException('8 haneli kodu eksiksiz girin.');
    }
    final response = await _client.auth.verifyOTP(
      type: OtpType.recovery,
      email: normalized,
      token: code,
    );
    if (response.session == null) {
      throw const AuthException('Kod dogrulanamadi. Lutfen tekrar deneyin.');
    }
  }

  /// Recovery oturumunda yeni sifreyi kaydeder.
  static Future<void> updatePasswordAfterRecovery(String newPassword) async {
    final error = PasswordRules.validate(newPassword);
    if (error != null) {
      throw AuthException(error);
    }
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Oturum acik kullanici: mevcut sifre ile dogrulayip yeni sifre atar.
  static Future<void> changePasswordForCurrentUser({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final matchError = PasswordRules.validateMatch(newPassword, confirmPassword);
    if (matchError != null) {
      throw AuthException(matchError);
    }

    final user = _client.auth.currentUser;
    final email = user?.email?.trim();
    if (email == null || email.isEmpty) {
      throw const AuthException('Oturum bulunamadi. Lutfen tekrar giris yapin.');
    }
    if (currentPassword.isEmpty) {
      throw const AuthException('Mevcut sifrenizi girin.');
    }

    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  static Future<void> signOutAfterPasswordReset() async {
    await _client.auth.signOut();
  }
}
