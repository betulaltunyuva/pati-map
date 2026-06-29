import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile_snapshot.dart';

const String _avatarBucket = 'profile-images';
/// Kullanıcı bilgisi: `auth.users` metadata + Supabase `profiles` (varsa).
abstract final class ProfileService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<UserProfileSnapshot> loadSnapshot() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const UserProfileSnapshot(
        displayName: 'Misafir',
        email: '—',
        userId: '',
        avatarUrl: null,
      );
    }

    final authEmail = user.email ?? '—';
    final meta = user.userMetadata ?? <String, dynamic>{};
    final authFirst = meta['first_name']?.toString().trim();
    final authLast = meta['last_name']?.toString().trim();

    DateTime? created;
    final createdRaw = user.createdAt;
    if (createdRaw.isNotEmpty) {
      created = DateTime.tryParse(createdRaw);
    }

    String? firstName = authFirst;
    String? lastName = authLast;
    var email = authEmail;
    String? roleLabel;
    var hasProfileRow = false;
    String? avatarUrl = _nullableTrim(meta['avatar_url']?.toString());

    try {
      final row = await _readProfileRow(user.id);
      if (row != null) {
        hasProfileRow = true;
        firstName = _nullableTrim(row['first_name']) ?? firstName;
        lastName = _nullableTrim(row['last_name']) ?? lastName;
        email = _nullableTrim(row['email']) ?? email;
        roleLabel = _nullableTrim(row['role']) ?? roleLabel;
        final rowAvatar = _nullableTrim(row['avatar_url']);
        if (rowAvatar != null) {
          avatarUrl = rowAvatar;
        }
      }
    } catch (_) {
      // Tablo veya RLS yoksa sessizce atla; uygulama auth bilgisiyle devam eder.
    }

    final hasName = (firstName != null && firstName.isNotEmpty) ||
        (lastName != null && lastName.isNotEmpty);
    final displayName = hasName ? '${firstName ?? ''} ${lastName ?? ''}'.trim() : email;

    return UserProfileSnapshot(
      displayName: displayName,
      email: email,
      userId: user.id,
      firstName: firstName,
      lastName: lastName,
      roleLabel: roleLabel,
      accountCreatedAt: created,
      hasProfileRow: hasProfileRow,
      avatarUrl: avatarUrl,
    );
  }

  static Future<void> updateName({
    required String firstName,
    required String lastName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Oturum bulunamadı.');
    }

    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isEmpty || last.isEmpty) {
      throw const AuthException('Ad ve soyad zorunludur.');
    }

    final payload = <String, dynamic>{
      'first_name': first,
      'last_name': last,
      'email': user.email,
    };

    var updated = false;
    try {
      final rows = await _client
          .from('profiles')
          .update(payload)
          .eq('user_id', user.id)
          .select('user_id')
          .limit(1);
      updated = rows.isNotEmpty;
    } catch (_) {}

    if (!updated) {
      try {
        final rows = await _client
            .from('profiles')
            .update(payload)
            .eq('id', user.id)
            .select('id')
            .limit(1);
        updated = rows.isNotEmpty;
      } catch (_) {}
    }

    if (!updated) {
      try {
        await _client.from('profiles').insert({
          'user_id': user.id,
          ...payload,
        });
        updated = true;
      } catch (_) {}
    }

    if (!updated) {
      throw const AuthException('Hesap bilgileri güncellenemedi.');
    }

    // Auth metadata ile de eşitleyelim; profil başlığı auth fallback ile de güncel kalsın.
    try {
      await _client.auth.updateUser(
        UserAttributes(
          data: {'first_name': first, 'last_name': last},
        ),
      );
    } catch (_) {}
  }

  /// Galeriden seçilen dosyayı `profile-images` bucket'ına yükler, public URL'yi
  /// `profiles.avatar_url` ve auth metadata'ya yazar.
  static Future<void> updateAvatar({
    required String localFilePath,
    String? originalFileName,
  }) async {
    final user = _client.auth.currentUser;
    final session = _client.auth.currentSession;
    if (user == null || session == null) {
      throw const AuthException('Oturum bulunamadı.');
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final objectPath = 'avatars/${user.id}-$ts.jpg';

    final storage = _client.storage.from(_avatarBucket);
    final file = File(localFilePath);
    const contentType = 'image/jpeg';

    try {
      await storage.upload(
        objectPath,
        file,
        fileOptions: FileOptions(upsert: true, contentType: contentType),
      );
    } catch (e, st) {
      debugPrint('Avatar upload error: $e\n$st');
      throw AuthException('Profil fotoğrafı yüklenemedi: $e');
    }

    final url = storage.getPublicUrl(objectPath);
    final payload = <String, dynamic>{
      'avatar_url': url,
    };

    var updated = false;
    try {
      final rows = await _client
          .from('profiles')
          .update(payload)
          .eq('user_id', user.id)
          .select('user_id')
          .limit(1);
      updated = rows.isNotEmpty;
    } catch (e, st) {
      debugPrint('Avatar profile update by user_id error: $e\n$st');
    }

    if (!updated) {
      try {
        final rows = await _client
            .from('profiles')
            .update(payload)
            .eq('id', user.id)
            .select('id')
            .limit(1);
        updated = rows.isNotEmpty;
      } catch (e, st) {
        debugPrint('Avatar profile update by id error: $e\n$st');
      }
    }

    if (!updated) {
      try {
        await _client.from('profiles').insert({
          'user_id': user.id,
          'email': user.email,
          ...payload,
        });
        updated = true;
      } catch (e, st) {
        debugPrint('Avatar profile insert error: $e\n$st');
      }
    }

    if (!updated) {
      throw const AuthException('Profil fotoğrafı kaydedilemedi.');
    }

    try {
      await _client.auth.updateUser(
        UserAttributes(data: {'avatar_url': url}),
      );
    } catch (e, st) {
      debugPrint('Avatar auth metadata update error: $e\n$st');
    }
  }

  static Future<Map<String, dynamic>?> _readProfileRow(String userId) async {
    try {
      final rows = await _client
          .from('profiles')
          .select(
            'id, user_id, first_name, last_name, email, role, avatar_url',
          )
          .eq('user_id', userId)
          .limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (_) {}
    try {
      final rows = await _client
          .from('profiles')
          .select(
            'id, user_id, first_name, last_name, email, role, avatar_url',
          )
          .eq('id', userId)
          .limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (_) {}
    return null;
  }

  static String? _nullableTrim(Object? value) {
    final v = value?.toString().trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }
}
