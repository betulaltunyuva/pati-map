import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile_snapshot.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../utils/report_ui_formatters.dart';
import '../widgets/profile/profile_avatar.dart';
import '../widgets/profile/profile_ui_tokens.dart';

class ProfileAccountPage extends StatefulWidget {
  const ProfileAccountPage({super.key});

  @override
  State<ProfileAccountPage> createState() => _ProfileAccountPageState();
}

class _ProfileAccountPageState extends State<ProfileAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  UserProfileSnapshot? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _editMode = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await ProfileService.loadSnapshot();
    if (!mounted) return;
    _firstName.text = (profile.firstName ?? '').trim();
    _lastName.text = (profile.lastName ?? '').trim();
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    setState(() => _saving = true);
    try {
      await ProfileService.updateName(
        firstName: _firstName.text,
        lastName: _lastName.text,
      );
      await _load();
      if (!mounted) return;
      setState(() => _editMode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Hesap bilgileri güncellendi.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Güncelleme yapılamadı. Lütfen tekrar deneyin.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      await ProfileService.updateAvatar(
        localFilePath: file.path,
        originalFileName: file.name,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Profil fotoğrafı güncellendi.'),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            e.message.trim().isNotEmpty
                ? e.message.trim()
                : 'Fotoğraf yüklenemedi.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Fotoğraf yüklenemedi. Lütfen tekrar deneyin.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Hesap Bilgileri',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.heading,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.heading,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (!_loading && _profile != null)
            TextButton.icon(
              onPressed: _saving
                  ? null
                  : () {
                      setState(() => _editMode = !_editMode);
                    },
              icon: Icon(_editMode ? Icons.close : Icons.edit_outlined, size: 18),
              label: Text(_editMode ? 'Vazgeç' : 'Düzenle'),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _profile == null
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Bilgiler yüklenemedi.')),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: ProfileUiTokens.pagePadding,
                    children: [
                      _AccountHeroCard(profile: _profile!),
                      if (_editMode) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _saving || _uploadingPhoto
                                ? null
                                : _pickAndUploadAvatar,
                            icon: _uploadingPhoto
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : const Icon(Icons.add_a_photo_outlined, size: 20),
                            label: Text(
                              _uploadingPhoto
                                  ? 'Yükleniyor…'
                                  : 'Profil fotoğrafı seç',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_editMode)
                        _AccountEditForm(
                          formKey: _formKey,
                          firstNameController: _firstName,
                          lastNameController: _lastName,
                          email: _profile!.email,
                          roleLabel: _profile!.roleLabel,
                          accountCreatedAt: _profile!.accountCreatedAt,
                          saving: _saving,
                          onSave: _save,
                        )
                      else
                        _AccountReadOnlyCard(profile: _profile!),
                    ],
                  ),
      ),
    );
  }
}

class _AccountHeroCard extends StatelessWidget {
  const _AccountHeroCard({required this.profile});

  final UserProfileSnapshot profile;

  String get _initialLetter {
    final t = profile.displayName.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ProfileUiTokens.cardDecoration().copyWith(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Row(
        children: [
          ProfileAvatar(
            letter: _initialLetter,
            avatarUrl: profile.avatarUrl,
            radius: 32,
            showRing: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.isEmpty ? profile.displayName : profile.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.heading,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    profile.roleLabel ?? 'Gönüllü Kullanıcı',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountReadOnlyCard extends StatelessWidget {
  const _AccountReadOnlyCard({required this.profile});

  final UserProfileSnapshot profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ProfileUiTokens.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kullanıcı Detayları',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.heading,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _infoTile(Icons.person_outline_rounded, 'Ad', profile.firstName ?? '—'),
          _divider(),
          _infoTile(Icons.badge_outlined, 'Soyad', profile.lastName ?? '—'),
          _divider(),
          _infoTile(Icons.mail_outline_rounded, 'E-posta', profile.email),
          if (profile.roleLabel != null) ...[
            _divider(),
            _infoTile(Icons.verified_user_outlined, 'Kullanıcı tipi', profile.roleLabel!),
          ],
          _divider(),
          _infoTile(
            Icons.event_outlined,
            'Kayıt tarihi',
            formatReportDate(profile.accountCreatedAt),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: Color(0xFFE2E8F0));

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.heading,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountEditForm extends StatelessWidget {
  const _AccountEditForm({
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.email,
    required this.roleLabel,
    required this.accountCreatedAt,
    required this.saving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final String email;
  final String? roleLabel;
  final DateTime? accountCreatedAt;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ProfileUiTokens.cardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hesap Bilgilerini Düzenle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.heading,
              ),
            ),
            const SizedBox(height: 14),
            _label('Ad'),
            const SizedBox(height: 6),
            TextFormField(
              controller: firstNameController,
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ad boş bırakılamaz';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _label('Soyad'),
            const SizedBox(height: 6),
            TextFormField(
              controller: lastNameController,
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Soyad boş bırakılamaz';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _label('E-posta'),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: email,
              enabled: false,
              decoration: InputDecoration(
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            if (roleLabel != null) ...[
              const SizedBox(height: 12),
              _label('Kullanıcı tipi'),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: roleLabel,
                enabled: false,
                decoration: InputDecoration(
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Kayıt: ${formatReportDate(accountCreatedAt)}',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.heading,
        fontSize: 13.5,
      ),
    );
  }
}
