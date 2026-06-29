import 'package:supabase_flutter/supabase_flutter.dart';

/// JS SDK’deki `signUp(..., { options: { data } })` ile aynı: kullanıcı metadata’sı.
class SignUpOptions {
  const SignUpOptions({this.data});

  final Map<String, dynamic>? data;
}

abstract final class AuthService {
  static GoTrueClient get _auth => Supabase.instance.client.auth;

  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    SignUpOptions? options,
  }) {
    return _auth.signUp(
      email: email,
      password: password,
      data: options?.data,
    );
  }

  static Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return _auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  static Future<ResendResponse> resendSignupConfirmationEmail({
    required String email,
  }) {
    return _auth.resend(
      email: email.trim(),
      type: OtpType.signup,
    );
  }

  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> signOut() => _auth.signOut();
}
