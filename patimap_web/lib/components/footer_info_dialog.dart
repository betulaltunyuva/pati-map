import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class FooterInfoContent {
  const FooterInfoContent({
    required this.title,
    required this.description,
    this.bullets = const [],
  });

  final String title;
  final String description;
  final List<String> bullets;

  static const Map<String, FooterInfoContent> byLabel = {
    'Hakkımızda': FooterInfoContent(
      title: 'Hakkımızda',
      description:
          'PatiMap, sokaktaki hayvanlar için hızlı ihbar ve gönüllü koordinasyonu sunan bir topluluk platformudur.',
      bullets: [
        'İhbarları harita üzerinde görünür kılar.',
        'Gönüllüler ve destek ekipleri aynı panelde buluşur.',
        'Amacımız müdahale süresini kısaltmaktır.',
      ],
    ),
    'Nasıl Çalışır?': FooterInfoContent(
      title: 'Nasıl Çalışır?',
      description: 'Üç adımda ihbar süreci:',
      bullets: [
        'Konum ve fotoğraf ile ihbar oluşturun.',
        'İhbar haritada ve listede görünür.',
        'Gönüllü veya ekip ihbarı üstlenip durumu günceller.',
      ],
    ),
    'İletişim': FooterInfoContent(
      title: 'İletişim',
      description:
          'Sorularınız ve iş birlikleri için bize ulaşabilirsiniz.',
      bullets: [
        'E-posta: destek@patimap.com',
        'Çalışma saatleri: Hafta içi 09:00 – 18:00',
        'Acil ihbarlar için paneldeki harita akışını kullanın.',
      ],
    ),
    'Sık Sorulan Sorular': FooterInfoContent(
      title: 'Sık Sorulan Sorular',
      description: 'En çok sorulan konular:',
      bullets: [
        'İhbar oluşturmak için giriş yapmanız gerekir.',
        'Konum paylaşımı haritada doğru yönlendirme sağlar.',
        'Üstlenilen ihbarlar durum alanından takip edilir.',
        'Yakın veterinerler konumunuza göre listelenir.',
      ],
    ),
    'Acil Durum Rehberi': FooterInfoContent(
      title: 'Acil Durum Rehberi',
      description: 'Acil bir durum gördüğünüzde:',
      bullets: [
        'Önce kendi güvenliğinizi koruyun.',
        'Mümkünse fotoğraf ve net konum ekleyerek ihbar açın.',
        'Yaralı hayvan için en yakın veterineri panelden kontrol edin.',
        'Tehlike varsa yerel resmi birimleri arayın.',
      ],
    ),
    'Destek Merkezi': FooterInfoContent(
      title: 'Destek Merkezi',
      description:
          'Panel kullanımı, hesap ve ihbar süreçleri için yardım merkezi.',
      bullets: [
        'Teknik sorun: Ayarlar → Bildirimler bölümünü kontrol edin.',
        'Hesap: Profil ve şifre işlemleri Ayarlar sayfasındadır.',
        'Geri bildirim: destek@patimap.com adresine yazın.',
      ],
    ),
    'Güncellemeler': FooterInfoContent(
      title: 'Güncellemeler',
      description: 'PatiMap web paneli — güncel sürüm notları:',
      bullets: [
        'Dashboard özet ve risk dağılımı görünümü.',
        'Harita önizleme ve ihbar detay paneli.',
        'Yakın veteriner arama ve ayarlar sayfası.',
      ],
    ),
    'Gizlilik Politikası': FooterInfoContent(
      title: 'Gizlilik Politikası',
      description:
          'Kişisel verileriniz yalnızca hizmet sunumu ve güvenlik amacıyla işlenir.',
      bullets: [
        'Konum verisi ihbar ve harita özellikleri için kullanılır.',
        'Hesap bilgileri yetkisiz erişime karşı korunur.',
        'Veriler üçüncü taraflarla izinsiz paylaşılmaz.',
      ],
    ),
    'Kullanım Şartları': FooterInfoContent(
      title: 'Kullanım Şartları',
      description: 'Platformu kullanırken:',
      bullets: [
        'Doğru ve güncel ihbar bilgisi paylaşın.',
        'Yanıltıcı veya zararlı içerik yüklemeyin.',
        'Topluluk kurallarına ve yerel mevzuata uyun.',
      ],
    ),
    'KVKK': FooterInfoContent(
      title: 'KVKK Aydınlatması',
      description:
          '6698 sayılı Kanun kapsamında veri sorumlusu PatiMap’tir.',
      bullets: [
        'İşlenen veriler: kimlik, iletişim, konum ve ihbar kayıtları.',
        'Haklarınız: erişim, düzeltme, silme ve itiraz.',
        'Talepler için destek@patimap.com adresine başvurabilirsiniz.',
      ],
    ),
    'Çerez Politikası': FooterInfoContent(
      title: 'Çerez Politikası',
      description:
          'Oturum ve tercihlerinizi korumak için gerekli çerezler kullanılır.',
      bullets: [
        'Zorunlu çerezler: oturum ve güvenlik.',
        'Analitik çerezler isteğe bağlıdır.',
        'Tarayıcı ayarlarından çerezleri yönetebilirsiniz.',
      ],
    ),
  };

  static bool showForLabel(BuildContext context, String label) {
    final content = byLabel[label];
    if (content == null) return false;
    showFooterInfoDialog(context, content);
    return true;
  }
}

Future<void> showFooterInfoDialog(
  BuildContext context,
  FooterInfoContent content,
) {
  return showDialog<void>(
    context: context,
    barrierColor: AppPalette.navy.withValues(alpha: 0.35),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: AppPalette.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppPalette.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        content.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppPalette.textMuted,
                      tooltip: 'Kapat',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  content.description,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    fontSize: 14,
                  ),
                ),
                if (content.bullets.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...content.bullets.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 7),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppPalette.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              line,
                              style: const TextStyle(
                                color: AppPalette.navy,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Kapat'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
