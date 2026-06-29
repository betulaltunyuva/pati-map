import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_messenger_key.dart';
import 'routes/app_routes.dart';
import 'services/auth_service.dart';
import 'theme/app_colors.dart';
import 'widgets/pati_map_primary_button.dart';

class EmailOtpVerifyPage extends StatefulWidget {
  const EmailOtpVerifyPage({super.key, required this.email});

  final String email;

  @override
  State<EmailOtpVerifyPage> createState() => _EmailOtpVerifyPageState();
}

class _EmailOtpVerifyPageState extends State<EmailOtpVerifyPage> {
  static const int _otpLength = 8;

  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendCooldownSeconds <= 1) {
        t.cancel();
        setState(() => _resendCooldownSeconds = 0);
      } else {
        setState(() => _resendCooldownSeconds--);
      }
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != _otpLength) {
      _showError('Lütfen $_otpLength haneli kodu girin.');
      return;
    }
    setState(() => _isVerifying = true);
    try {
      await AuthService.verifyEmailOtp(
        email: widget.email.trim(),
        token: code,
      );
      await AuthService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'E-postanız doğrulandı. Giriş yapabilirsiniz.',
            ),
          ),
        );
      });
    } on AuthException catch (e) {
      if (mounted) {
        _showError(e.message.isNotEmpty ? e.message : 'Kod doğrulanamadı.');
      }
    } catch (_) {
      if (mounted) {
        _showError('Bir hata oluştu. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldownSeconds > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await AuthService.resendSignupConfirmationEmail(
        email: widget.email.trim(),
      );
      if (!mounted) return;
      _startCooldown(45);
      appMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Doğrulama kodu tekrar gönderildi.'),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) {
        _showError(
          e.message.isNotEmpty ? e.message : 'Kod gönderilemedi.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showError('Kod gönderilirken bir hata oluştu.');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.heading,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Geri',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'E-postayı doğrula',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Şu adrese gönderilen $_otpLength haneli kodu girin:',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: _otpLength,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: '• • • • • • • •',
                      counterText: '',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 24),
                  PatiMapPrimaryButton(
                    label: _isVerifying ? 'Doğrulanıyor…' : 'Kodu Doğrula',
                    onPressed: _isVerifying ? null : _verify,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: (_resendCooldownSeconds > 0 || _isResending)
                        ? null
                        : _resend,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      overlayColor:
                          AppColors.primary.withValues(alpha: 0.08),
                    ),
                    child: Text(
                      _isResending
                          ? 'Gönderiliyor…'
                          : _resendCooldownSeconds > 0
                              ? 'Tekrar gönder (${_resendCooldownSeconds}s)'
                              : 'Kodu Tekrar Gönder',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
