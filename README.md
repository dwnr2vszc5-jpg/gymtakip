# GymTakip

Mac ve iPhone'da çalışan, iCloud ile senkronlanan kişisel antrenman ve kas gelişimi takip uygulaması.
Fikir [openGym](https://github.com/rcnsh/opengym)'dan geliyor; openGym bir web uygulaması olduğu için bu
uygulama SwiftUI ile Apple cihazlarına özel, yerel olarak yazıldı.

## Neler var?

| Sekme | Ne yapar |
|---|---|
| **Özet** | Sıradaki antrenman, haftalık hedef, seri, toplam hacim, son 7 günde kas başına set (az çalışılan kasları uyarır), kilo ve hedef kilo |
| **Antrenman** | Plandan veya boş antrenman başlat, set/kg/tekrar gir, dinlenme sayacı, ısınma setleri, geçen seferki performansa göre ağırlık önerisi, geçmiş |
| **Program** | Hedef (kas kazanımı, güç, yağ yakımı, genel fitness), seviye, ekipman (salon, evde dambıl, vücut ağırlığı) ve haftada 2-6 güne göre otomatik program. Hareketler, set ve tekrarlar düzenlenebilir |
| **Hareketler** | 873 hareket: iki kareli animasyonla nasıl yapıldığı, adım adım anlatım, çalışan kaslar, YouTube'da video arama, o hareketteki güç gelişim grafiğin |
| **Gelişim** | Kilo, yağ oranı ve 9 vücut ölçüsü (kol, göğüs, bel...) grafikleri; her hareket için tahmini 1RM grafiği ve kişisel rekorlar; haftalık hacim |
| **Profil** (Özet sağ üst) | Ad, boy, hedef kilo, haftalık hedef, iCloud durumu, JSON yedeği dışa/içe aktarma |

Hareket veritabanı [Free Exercise DB](https://github.com/yuhonas/free-exercise-db)'den alındı (kamu malı / Unlicense).
Hareket anlatımları İngilizce, görseller internetten yüklenir.

## Gerekenler

- macOS 14 (Sonoma) veya üstü bir Mac ve App Store'dan ücretsiz **Xcode 16** veya üstü
- iOS 17 veya üstü bir iPhone
- Bir Apple ID. iCloud senkronu için **Apple Developer Program** üyeliği gerekir (yıllık 99 $). Üyelik olmadan da
  uygulama çalışır, sadece verileri Mac ile iPhone arasında yedek dosyasıyla taşırsın.

## Kurulum

1. App Store'dan **Xcode**'u kur ve bir kez aç (ek bileşenleri yüklemesine izin ver).
2. Xcode > Settings > **Accounts** bölümünden Apple ID'ni ekle.
3. Bu klasördeki **GymTakip.xcodeproj** dosyasına çift tıkla.
4. Soldaki listeden en üstteki mavi **GymTakip** projesine, ardından **Signing & Capabilities** sekmesine tıkla.
   - **Team**: kendi adını seç (ücretsiz hesapta "Kişisel Ekip / Personal Team" yazar).
   - **Bundle Identifier** kırmızı hata verirse `com.emre.gymtakip` yerine kendine özgü bir şey yaz, örn. `com.emrehalici.gymtakip`.

### Mac'te çalıştırma

5. Pencerenin üstündeki cihaz menüsünden **My Mac**'i seç ve ▶ düğmesine bas (⌘R).
6. Uygulamayı Xcode'suz açmak için: Product > **Show Build Folder in Finder** > `Products/Debug` içindeki
   **GymTakip.app**'i **Uygulamalar** klasörüne sürükle.

### iPhone'da çalıştırma

7. iPhone'u kabloyla Mac'e bağla, telefonda "Bu bilgisayara güven"e dokun.
8. iPhone'da Ayarlar > Gizlilik ve Güvenlik > **Geliştirici Modu**'nu aç (telefon yeniden başlar).
9. Xcode'da cihaz menüsünden iPhone'unu seç ve ▶'e bas.
10. İlk açılışta "güvenilmeyen geliştirici" uyarısı çıkarsa: Ayarlar > Genel > **VPN ve Cihaz Yönetimi** > Apple ID'ne dokun > Güven.

Ücretsiz Apple ID ile iPhone'a yüklenen uygulama 7 gün sonra açılmaz; telefonu bağlayıp Xcode'dan ▶ ile yeniden
yüklemen yeterli, veriler silinmez. Ücretli üyelikte bu süre 1 yıldır.

### iCloud senkronu (Apple Developer Program gerekli)

11. Signing & Capabilities sekmesinde **+ Capability** > **iCloud**'u ekle. **CloudKit**'i işaretle,
    Containers altında **+** ile `iCloud.com.<senin-bundle-id'n>` adında bir konteyner ekle ve seç.
12. Tekrar **+ Capability** > **Background Modes**'u ekle ve **Remote notifications**'ı işaretle.
13. Uygulamayı hem Mac'e hem iPhone'a yeniden yükle. İki cihazda da aynı Apple hesabıyla iCloud'a giriş yapılmış
    olmalı. İlk senkron birkaç dakika sürebilir. Profil ekranında iCloud durumu görünür.

Kod tarafında ek bir şey gerekmez: uygulama iCloud yetkisini görürse senkronu kendisi açar, görmezse yerel çalışır.

### iCloud olmadan veri taşıma

Özet > sağ üstteki profil simgesi > **Yedeği dışa aktar** ile JSON dosyası oluştur, AirDrop veya iCloud Drive ile
diğer cihaza gönder ve orada **Yedeği içe aktar**'ı seç. Aynı antrenman iki kez eklenmez.

## Proje yapısı

```
GymTakip/
  App/          Uygulama girişi ve sekmeler
  Models/       SwiftData modelleri (iCloud uyumlu) ve Türkçe etiketler
  Library/      Hareket veritabanı, program üretici, ilerleme önerileri, istatistik, yedekleme
  Views/        Ekranlar
  Resources/    exercises.json, ikon ve renkler
```
