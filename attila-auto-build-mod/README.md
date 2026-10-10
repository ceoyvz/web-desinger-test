# Otomatik Şehir İnşaatı – Total War: ATTILA Modu

Her tur başında imparatorluğunuzdaki tüm yerleşimleri tarar ve binaları **otomatik olarak yükseltir**.

## Ne yapar?

- **Kasayı korur:** Kasada her zaman bir yedek bırakır (varsayılan 3000 altın). Turda harcayacağı miktarın da bir sınırı vardır.
- **İhtiyaca göre seçer:**
  - Kamu düzeni düşük olan bölgede önce tapınak ve kilise yükseltir.
  - Kıtlık varsa önce çiftlik yükseltir.
  - Sanitasyon düşükse önce su kemeri ve kanalizasyon yükseltir.
  - Bunların dışında sırayla ana bina, ekonomi ve askeri binalar gelir.
- **Bedelini öder:** İnşaat bedeli kasadan düşülür. `charge_cost = false` yapılırsa inşaat bedava olur (hile modu).
- **Dengeyi korur:** Turda ve bölge başına en fazla kaç bina yapılacağı ayarlanabilir. Bir seviye sınırı da vardır.
- **Parayı boşa harcamaz:** İnşaat komutundan sonra binanın gerçekten değişip değişmediğini kontrol eder. Bina değişmediyse para almaz.
- Varsayılan olarak sadece oyuncunun fraksiyonunda çalışır. Yapay zekâ için de açılabilir.
- Oyunu çökertmez: tüm hatalar yakalanır ve `auto_build_log.txt` dosyasına yazılır.

## Dosyalar

```
pack/campaign/main_attila/
  auto_build.lua          # modun kendisi
  auto_build_config.lua   # AYARLAR (buradan düzenleyin)
  auto_build_data.lua     # bina yükseltme tablosu (ÖRNEK – aşağıda nasıl üretileceği yazıyor)
tools/generate_building_data.py   # oyunun verisinden auto_build_data.lua üretir
tests/                            # Lua 5.1 testleri (sahte oyun motoruyla)
```

## Kurulum

Gerekli program: [RPFM (Rusted PackFile Manager)](https://github.com/Frodo45127/rpfm/releases). Oyun olarak **Attila** seçili olmalı.

### 1) Bina verisini oluşturun (bir kez yapılır)

Bir binanın sonraki seviyesinin ne olduğunu script kendi başına bilemez. Bu bilgi oyunun veritabanından alınır:

1. RPFM ile `Attila/data/data.pack` dosyasını açın.
2. `db/building_levels_tables` tablosuna sağ tıklayın ve **Export → TSV** seçin.
3. Şu komutu çalıştırın:
   ```
   python3 tools/generate_building_data.py building_levels.tsv -o pack/campaign/main_attila/auto_build_data.lua
   ```
4. Bina maliyetleri başka bir tablodaysa o tabloyu da TSV olarak dışa aktarın ve `--costs` ile verin. Maliyet bulunamazsa `default_cost_per_level` ayarına göre tahmin edilir.

### 2) Pack dosyasını oluşturun

1. RPFM'de **PackFile → New PackFile** ile yeni bir pack açın. Türü **Mod** olsun.
2. `pack/` klasörünün içeriğini pack'e ekleyin. Klasör yapısı aynı kalmalı (`campaign/main_attila/...`).
3. `data.pack` içinden `campaign/main_attila/scripting.lua` dosyasını kendi pack'inize kopyalayın ve dosyanın **en sonuna** şunu ekleyin:
   ```lua
   local auto_build = require "auto_build"
   auto_build.init()
   ```
   > Bu dosyadaki diğer `require` satırlarına bakın. Bazı kurulumlarda modül yolu farklı yazılır (ör. `require "data.campaign.main_attila.auto_build"`). Sizin satırınız da onlarla aynı biçimde olmalı.
4. Pack'i `Attila/data/auto_build.pack` olarak kaydedin ve oyunun başlatıcısındaki **Mod Manager**'dan etkinleştirin.

Mod diğer kampanyalarda da çalışır: *Last Roman* ve *Age of Charlemagne* için aynı işlemi o kampanyanın klasöründeki `scripting.lua` ile yapın.

### 3) Test edin

Kampanyayı başlatıp bir tur bitirin. Oyunun ana klasöründe `auto_build_log.txt` oluşmalı. İlk satırlardan biri hangi inşaat komutunun çalıştığını gösterir, örneğin:

```
[AutoBuild] Calisan insaat komutu: instantly_upgrade_building_in_region
[AutoBuild] att_reg_italia_roma: ..._2 -> ..._3 (1200 altin, puan 112.0)
```

## ⚠️ Bilinmesi gerekenler (önemli)

- **İnşaat komutu:** Attila'nın script arayüzünün resmi bir belgesi yok ve "binayı yükselt" komutunun adı Total War oyunlarında sürüme göre değişiyor. Bu yüzden mod bilinen dört komutu sırayla dener:
  - `region_slot_instantly_upgrade_building`
  - `instantly_upgrade_building_in_region`
  - `instantly_upgrade_building`
  - `instant_upgrade_building`

  Hangisinin çalıştığını log dosyasına yazar. Mod bunlardan hangisinin Attila'da çalıştığını henüz gerçek oyunda test edilmedi. Log'da sürekli `basarisiz` görürseniz:
  1. Assembly Kit'teki script belgelerinde doğru komutun adını bulun.
  2. Bu adı `auto_build.lua` içindeki `AB.upgrade_methods` listesine ekleyin.
- **Bekleme süresi yok:** Yükseltme **anında** tamamlanır, normaldeki gibi birkaç tur sürmez. Maliyet alındığı için ekonomik denge büyük ölçüde korunur.
- **Boş slotlar:** Mod boş slotlara yeni bina **kurmaz**, sadece mevcut binaları yükseltir.
- **Kayıt uyumluluğu:** `scripting.lua` dosyasını değiştiren başka modlarla çakışabilir. Böyle bir durumda iki modun `scripting.lua` dosyasını elle birleştirin.

## Testleri çalıştırma

```
pip install lupa
python3 tests/run_tests.py
```

Testler sahte bir oyun motoruyla Lua 5.1 üzerinde şunları kontrol eder:

- ihtiyaca göre önceliklendirme
- bütçe ve kasa yedeği
- bölge sınırı
- kara liste
- yapay zekâ ayarı
- başarısız komutta para alınmaması
- seviye sınırı
- olay kaydı
