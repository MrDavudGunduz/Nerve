//
//  SeedData.swift
//  MapFeature
//
//  Created by Davud Gunduz on 11.04.2026.
//

import Core
import Foundation

// MARK: - SeedData

/// Static collection of geolocated Istanbul news items for development and preview use.
///
/// These items are injected into the cache via ``SwiftDataStorageService``
/// on first launch when the live network is unavailable (Simulator, offline dev).
public enum SeedData {

  /// 20 geolocated Istanbul news items spread across distinct neighborhoods.
  public static let istanbulItems: [NewsItem] = [
    make(
      id: "seed-001",
      headline: "Galata Köprüsü Yenileme Projesi Başladı",
      summary: "Tarihi Galata Köprüsü'nde kapsamlı bir yenileme çalışması bu hafta başladı.",
      source: "İstanbul Büyükşehir",
      category: .other,
      lat: 41.0162, lon: 28.9741
    ),
    make(
      id: "seed-002",
      headline: "Boğaziçi Üniversitesi'nden Yapay Zeka Araştırması",
      summary: "Araştırmacılar doğal dil işlemede çığır açan bir model geliştirdi.",
      source: "BÜ Haber",
      category: .technology,
      lat: 41.0833, lon: 29.0500
    ),
    make(
      id: "seed-003",
      headline: "Kapalıçarşı Ziyaretçi Rekoru Kırdı",
      summary: "Tarihi çarşı bu yılın ilk çeyreğinde 3 milyon ziyaretçiye ulaştı.",
      source: "Turizm Türkiye",
      category: .business,
      lat: 41.0108, lon: 28.9680
    ),
    make(
      id: "seed-004",
      headline: "Beşiktaş-Fenerbahçe Derbisine Hazırlık",
      summary:
        "Vodafone Park'ta oynacak kritik derbi öncesi iki takım da son hazırlıklarını tamamladı.",
      source: "Spor Arena",
      category: .sports,
      lat: 41.0390, lon: 29.0056
    ),
    make(
      id: "seed-005",
      headline: "Kadıköy'de Yeni Metro İstasyonu Açıldı",
      summary: "M4 hattının uzatılmasıyla Kadıköy bağlantısı güçlendirildi.",
      source: "Metro İstanbul",
      category: .other,
      lat: 40.9900, lon: 29.0230
    ),
    make(
      id: "seed-006",
      headline: "Türk Teknoloji Girişimleri Avrupa'yı Fethedyor",
      summary: "İstanbul merkezli 5 startup bu yıl 500 milyon dolar yatırım aldı.",
      source: "TechTR",
      category: .technology,
      lat: 41.0571, lon: 28.9967
    ),
    make(
      id: "seed-007",
      headline: "Ayasofya Restore Çalışmaları Hız Kazandı",
      summary: "Bizans dönemine ait mozaikler hassas tekniklerle restore ediliyor.",
      source: "Kültür Bakanlığı",
      category: .entertainment,
      lat: 41.0086, lon: 28.9802
    ),
    make(
      id: "seed-008",
      headline: "İstanbul Borsası Rekor Kırdı",
      summary: "BIST 100 endeksi Nisan ayında tarihi zirvesini gördü.",
      source: "Bloomberg HT",
      category: .business,
      lat: 41.0422, lon: 28.9876
    ),
    make(
      id: "seed-009",
      headline: "Üsküdar'da Çevre Festivali",
      summary: "Yüzlerce gönüllü sahil temizleme etkinliğinde bir araya geldi.",
      source: "Üsküdar Belediyesi",
      category: .environment,
      lat: 41.0228, lon: 29.0153
    ),
    make(
      id: "seed-010",
      headline: "Galatasaray Şampiyonlar Ligi'nde",
      summary: "Sarı-kırmızılılar Son 16 turuna yükselerek tarihi başarı elde etti.",
      source: "Fanatik",
      category: .sports,
      lat: 41.0651, lon: 28.9833
    ),
    make(
      id: "seed-011",
      headline: "İstanbul Yeni Havalimanı Kapasitesini Artırıyor",
      summary: "3. pist açılışıyla günlük uçuş kapasitesi 2.000'e çıktı.",
      source: "Havacılık Türkiye",
      category: .business,
      lat: 41.2753, lon: 28.7519
    ),
    make(
      id: "seed-012",
      headline: "Taksim Meydanı Yaya Düzenlemesi Tamamlandı",
      summary: "Taksim Meydanı'nın yeni peyzaj düzenlemesi bugün açıldı.",
      source: "Beyoğlu Belediyesi",
      category: .other,
      lat: 41.0369, lon: 28.9850
    ),
    make(
      id: "seed-013",
      headline: "Boğaz'da Yeni Turistik Vapur Hattı",
      summary: "BUDO, Boğaz'ı boydan boya kapsayan yeni deniz ulaşım hattını tanıttı.",
      source: "Deniz Haberleri",
      category: .other,
      lat: 41.0450, lon: 29.0300
    ),
    make(
      id: "seed-014",
      headline: "İstanbul Tıp Fakültesi'nden Kanser Araştırması",
      summary: "Meme kanseri teşhisinde yüzde 95 doğrulukla çalışan AI modeli tanıtıldı.",
      source: "Sağlık Haberleri",
      category: .health,
      lat: 41.0200, lon: 28.9512
    ),
    make(
      id: "seed-015",
      headline: "Dolmabahçe Sarayı'nda Özel Sergi",
      summary: "Osmanlı dönemine ait nadir eserler ilk kez ziyaretçilerle buluşuyor.",
      source: "Müzeler Türkiye",
      category: .entertainment,
      lat: 41.0393, lon: 29.0009
    ),
    make(
      id: "seed-016",
      headline: "Maltepe Sahili'nde Deprem Tatbikatı",
      summary: "8.0 şiddetinde senaryo ile kapsamlı tatbikat gerçekleştirildi.",
      source: "AFAD İstanbul",
      category: .other,
      lat: 40.9342, lon: 29.1292
    ),
    make(
      id: "seed-017",
      headline: "Sarıyer'de Yeni Teknoloji Parkı Açılıyor",
      summary: "500 girişime ev sahipliği yapacak kampüs yıl sonunda kapılarını açıyor.",
      source: "TechPark TR",
      category: .technology,
      lat: 41.1672, lon: 29.0553
    ),
    make(
      id: "seed-018",
      headline: "İstanbul Bienali'nde Türk Sanatçılar",
      summary: "18. İstanbul Bienali dünyadan 60 ülkenin sanatçısını bir araya getiriyor.",
      source: "Sanat Dünyası",
      category: .entertainment,
      lat: 41.0290, lon: 28.9723
    ),
    make(
      id: "seed-019",
      headline: "Pendik'te Raylı Sistem İhalesi",
      summary: "Sabiha Gökçen – Pendik metrosu için ihale süreci başlatıldı.",
      source: "Ulaştırma Bakanlığı",
      category: .politics,
      lat: 40.8780, lon: 29.2320
    ),
    make(
      id: "seed-020",
      headline: "İstanbul'da Hava Kalitesi Endişe Verici",
      summary: "Kış aylarında PM2.5 değerleri WHO sınırlarının 3 katına ulaştı.",
      source: "Çevre Bakanlığı",
      category: .health,
      lat: 41.0130, lon: 28.9550
    ),
  ]

  // MARK: - Private Factory

  private static func make(
    id: String,
    headline: String,
    summary: String,
    source: String,
    category: NewsCategory,
    lat: Double,
    lon: Double
  ) -> NewsItem {
    NewsItem(
      id: id,
      headline: headline,
      summary: summary,
      source: source,
      category: category,
      coordinate: GeoCoordinate(latitude: lat, longitude: lon)!,
      publishedAt: Date(timeIntervalSinceNow: -Double.random(in: 0...86400))
    )
  }
}
