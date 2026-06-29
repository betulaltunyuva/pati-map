import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants/app_assets.dart';
import 'models/email_otp_verify_args.dart';
import 'routes/app_routes.dart';
import 'services/auth_service.dart';
import 'theme/app_colors.dart';
import 'utils/registration_validators.dart';
import 'widgets/pati_map_primary_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _termsAccepted = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).maybePop();
  }

  String? _collectValidationError() {
    final firstName = _firstNameController.text;
    final lastName = _lastNameController.text;
    final email = _emailController.text;
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    final checks = <String?>[
      RegistrationValidators.emptyField(firstName, 'Ad'),
      RegistrationValidators.emptyField(lastName, 'Soyad'),
      RegistrationValidators.emptyField(email, 'E-posta'),
      RegistrationValidators.emptyField(password, 'Şifre'),
      RegistrationValidators.emptyField(confirm, 'Şifre tekrar'),
      if (email.trim().isNotEmpty)
        RegistrationValidators.emailFormat(email),
      if (password.isNotEmpty)
        RegistrationValidators.passwordLength(password),
      if (password.isNotEmpty && confirm.isNotEmpty)
        RegistrationValidators.passwordMatch(password, confirm),
    ];

    for (final msg in checks) {
      if (msg != null) return msg;
    }

    if (!_termsAccepted) {
      return 'Kullanım koşullarını kabul etmelisiniz.';
    }

    return null;
  }

  Future<void> _onRegisterPressed() async {
    FocusScope.of(context).unfocus();
    final error = _collectValidationError();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      await AuthService.signUpWithEmail(
        email: email,
        password: password,
        options: SignUpOptions(
          data: {
            'first_name': first,
            'last_name': last,
          },
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.emailOtpVerify,
        arguments: EmailOtpVerifyArgs(email: email),
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message.isNotEmpty ? e.message : 'Kayıt başarısız oldu.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _goToLogin,
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.heading,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Geri',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            AppAssets.logoPng,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kayıt Ol',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hesabını oluştur ve topluluğa katıl',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Ad',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _lastNameController,
                    textCapitalization: TextCapitalization.words,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Soyad',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmController,
                    obscureText: !_confirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Şifre Tekrar',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _confirmPasswordVisible =
                                !_confirmPasswordVisible;
                          });
                        },
                        icon: Icon(
                          _confirmPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _termsAccepted,
                    onChanged: (value) {
                      setState(() {
                        _termsAccepted = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Kullanım koşullarını kabul ediyorum',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade800,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PatiMapPrimaryButton(
                    label: _isSubmitting ? 'Kaydediliyor…' : 'Kayıt Ol',
                    onPressed: _isSubmitting ? null : _onRegisterPressed,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _goToLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        overlayColor:
                            AppColors.primary.withValues(alpha: 0.08),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                          children: const [
                            TextSpan(text: 'Zaten hesabın var mı? '),
                            TextSpan(
                              text: 'Giriş Yap',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
