import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/password_text_field.dart';
import '../theme/app_palette.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

const String _webLoginLogoAsset = 'assets/images/patimaplogo2.png';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('E-posta ve sifre zorunludur.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      _showMessage('Giris basarili.');
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on AuthException catch (e) {
      _showMessage(
        e.message.trim().isNotEmpty ? e.message.trim() : 'Giris basarisiz.',
      );
    } catch (_) {
      _showMessage('Giris yapilamadi. Lutfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = AppPalette.primaryBlue;
    const primaryDark = AppPalette.navy;
    const heading = AppPalette.navy;
    const bg = Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mobile = constraints.maxWidth < 768;
                final logoWidth = mobile
                    ? constraints.maxWidth.clamp(160.0, 280.0)
                    : 360.0;

                final brandColumn = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        _webLoginLogoAsset,
                        width: logoWidth,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: mobile ? 12 : 16),
                    Text(
                      'PatiMap Web Panel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primaryDark,
                        fontSize: mobile ? 18 : 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kurum ve ekip yonetimi icin sade, guvenli ve merkezi giris alani.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: mobile ? 13.5 : 15,
                        height: 1.45,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );

                final formCard = Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(mobile ? 18 : 26),
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
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Giris',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: heading,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Devam etmek icin hesap bilgilerinizi kullanin.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-posta',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          PasswordTextField(
                            controller: _passwordController,
                            labelText: 'Sifre',
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _submitting ? null : _onLogin,
                              style: FilledButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                _submitting ? 'Giris yapiliyor...' : 'Panele Giris',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: const Text('Sifremi unuttum'),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: const Text('Hesabin yoksa kayit ol'),
                            ),
                          ),
                        ],
                      ),
                    );

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 16 : 24,
                    vertical: mobile ? 20 : 28,
                  ),
                  child: mobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            brandColumn,
                            const SizedBox(height: 20),
                            formCard,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 36),
                                child: brandColumn,
                              ),
                            ),
                            Expanded(flex: 4, child: formCard),
                          ],
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
