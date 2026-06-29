import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/password_text_field.dart';
import '../services/auth_password_service.dart';
import '../theme/app_palette.dart';
import '../utils/password_rules.dart';

const String _webForgotLogoAsset = 'assets/images/patimaplogo2.png';

enum _ForgotStep { email, otp, newPassword }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();
  final _newPassAgainController = TextEditingController();

  _ForgotStep _step = _ForgotStep.email;
  bool _submitting = false;
  bool _otpVerified = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPassController.dispose();
    _newPassAgainController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim().toLowerCase();

  void _showMessage(String text, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? AppPalette.success : null,
        content: Text(text),
      ),
    );
  }

  Future<void> _sendCode() async {
    if (_email.isEmpty || !_email.contains('@')) {
      _showMessage('Gecerli bir e-posta girin.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthPasswordService.sendPasswordResetOtp(_email);
      if (!mounted) return;
      setState(() {
        _step = _ForgotStep.otp;
        _otpVerified = false;
      });
      _showMessage(
        'Sifirlama kodu e-posta adresinize gonderildi.',
        success: true,
      );
    } catch (e) {
      _showMessage(AuthPasswordService.messageForError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 8) {
      _showMessage('8 haneli kodu eksiksiz girin.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthPasswordService.verifyRecoveryOtp(
        email: _email,
        token: code,
      );
      if (!mounted) return;
      setState(() {
        _otpVerified = true;
        _step = _ForgotStep.newPassword;
      });
      _showMessage('Kod dogrulandi. Yeni sifrenizi belirleyin.', success: true);
    } catch (e) {
      _showMessage(AuthPasswordService.messageForError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveNewPassword() async {
    final matchError = PasswordRules.validateMatch(
      _newPassController.text,
      _newPassAgainController.text,
    );
    if (matchError != null) {
      _showMessage(matchError);
      return;
    }
    if (!_otpVerified) {
      _showMessage('Once e-posta kodunu dogrulayin.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await AuthPasswordService.updatePasswordAfterRecovery(
        _newPassController.text,
      );
      await AuthPasswordService.signOutAfterPasswordReset();
      if (!mounted) return;
      _showMessage('Sifreniz guncellendi. Giris yapabilirsiniz.', success: true);
      Navigator.of(context).pop();
    } catch (e) {
      _showMessage(AuthPasswordService.messageForError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = AppPalette.primaryBlue;
    const heading = AppPalette.navy;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Giris ekranina don',
                    ),
                  ),
                  Center(
                    child: Image.asset(
                      _webForgotLogoAsset,
                      width: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sifremi Unuttum',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: heading,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _step == _ForgotStep.email
                        ? 'E-posta adresinize 8 haneli kod gonderilir.'
                        : _step == _ForgotStep.otp
                            ? 'E-postanizdaki 8 haneli kodu girin.'
                            : 'Yeni sifrenizi belirleyin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppPalette.cardBackground,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppPalette.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_step != _ForgotStep.newPassword) ...[
                          TextField(
                            controller: _emailController,
                            enabled: _step == _ForgotStep.email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-posta',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_step == _ForgotStep.otp) ...[
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 8,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: '8 Haneli Kod',
                              prefixIcon: Icon(Icons.pin_outlined),
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_step == _ForgotStep.newPassword) ...[
                          PasswordTextField(
                            controller: _newPassController,
                            labelText: 'Yeni Sifre',
                          ),
                          const SizedBox(height: 12),
                          PasswordTextField(
                            controller: _newPassAgainController,
                            labelText: 'Yeni Sifre Tekrar',
                          ),
                          const SizedBox(height: 10),
                          ...PasswordRules.hintLines.map(
                            (line) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      line,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting ? null : _onPrimaryAction,
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(_primaryButtonLabel),
                          ),
                        ),
                        if (_step == _ForgotStep.otp) ...[
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _submitting ? null : _sendCode,
                            child: const Text('Kodu tekrar gonder'),
                          ),
                        ],
                      ],
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

  String get _primaryButtonLabel {
    if (_submitting) return 'Isleniyor...';
    switch (_step) {
      case _ForgotStep.email:
        return 'Kod Gonder';
      case _ForgotStep.otp:
        return 'Kodu Dogrula';
      case _ForgotStep.newPassword:
        return 'Sifreyi Kaydet';
    }
  }

  Future<void> _onPrimaryAction() async {
    switch (_step) {
      case _ForgotStep.email:
        await _sendCode();
      case _ForgotStep.otp:
        await _verifyCode();
      case _ForgotStep.newPassword:
        await _saveNewPassword();
    }
  }
}
