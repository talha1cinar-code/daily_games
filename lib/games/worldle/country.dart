import 'dart:math';

/// Ülke veri modeli — isim, ISO kodu ve merkez koordinatları tutar.
class Country {
  final String name;
  final String isoCode;
  final double latitude;
  final double longitude;

  const Country({
    required this.name,
    required this.isoCode,
    required this.latitude,
    required this.longitude,
  });

  /// ISO kodundan bayrak emojisi üretir (🇹🇷, 🇩🇪 vb.)
  String get flagEmoji {
    final codes = isoCode.toUpperCase().codeUnits;
    return String.fromCharCodes(
      codes.map((c) => c + 0x1F1A5), // Regional Indicator Symbol
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Country &&
          runtimeType == other.runtimeType &&
          isoCode == other.isoCode;

  @override
  int get hashCode => isoCode.hashCode;

  @override
  String toString() => '$flagEmoji $name';
}

// ─── Tüm Ülkeler Listesi ────────────────────────────────────────────────
const List<Country> allCountries = [
  Country(name: 'Afganistan', isoCode: 'AF', latitude: 33.9391, longitude: 67.7100),
  Country(name: 'Almanya', isoCode: 'DE', latitude: 51.1657, longitude: 10.4515),
  Country(name: 'Amerika Birleşik Devletleri', isoCode: 'US', latitude: 37.0902, longitude: -95.7129),
  Country(name: 'Andorra', isoCode: 'AD', latitude: 42.5063, longitude: 1.5218),
  Country(name: 'Angola', isoCode: 'AO', latitude: -11.2027, longitude: 17.8739),
  Country(name: 'Antigua ve Barbuda', isoCode: 'AG', latitude: 17.0608, longitude: -61.7964),
  Country(name: 'Arjantin', isoCode: 'AR', latitude: -38.4161, longitude: -63.6167),
  Country(name: 'Arnavutluk', isoCode: 'AL', latitude: 41.1533, longitude: 20.1683),
  Country(name: 'Avustralya', isoCode: 'AU', latitude: -25.2744, longitude: 133.7751),
  Country(name: 'Avusturya', isoCode: 'AT', latitude: 47.5162, longitude: 14.5501),
  Country(name: 'Azerbaycan', isoCode: 'AZ', latitude: 40.1431, longitude: 47.5769),
  Country(name: 'Bahamalar', isoCode: 'BS', latitude: 25.0343, longitude: -77.3963),
  Country(name: 'Bahreyn', isoCode: 'BH', latitude: 25.9304, longitude: 50.6378),
  Country(name: 'Bangladeş', isoCode: 'BD', latitude: 23.6850, longitude: 90.3563),
  Country(name: 'Barbados', isoCode: 'BB', latitude: 13.1939, longitude: -59.5432),
  Country(name: 'Batı Sahra', isoCode: 'EH', latitude: 24.2155, longitude: -12.8858),
  Country(name: 'Belçika', isoCode: 'BE', latitude: 50.5039, longitude: 4.4699),
  Country(name: 'Belize', isoCode: 'BZ', latitude: 17.1899, longitude: -88.4976),
  Country(name: 'Benin', isoCode: 'BJ', latitude: 9.3077, longitude: 2.3158),
  Country(name: 'Beyaz Rusya', isoCode: 'BY', latitude: 53.7098, longitude: 27.9534),
  Country(name: 'Bhutan', isoCode: 'BT', latitude: 27.5142, longitude: 90.4336),
  Country(name: 'Birleşik Arap Emirlikleri', isoCode: 'AE', latitude: 23.4241, longitude: 53.8478),
  Country(name: 'Birleşik Krallık', isoCode: 'GB', latitude: 55.3781, longitude: -3.4360),
  Country(name: 'Bolivya', isoCode: 'BO', latitude: -16.2902, longitude: -63.5887),
  Country(name: 'Bosna Hersek', isoCode: 'BA', latitude: 43.9159, longitude: 17.6791),
  Country(name: 'Botsvana', isoCode: 'BW', latitude: -22.3285, longitude: 24.6849),
  Country(name: 'Brezilya', isoCode: 'BR', latitude: -14.2350, longitude: -51.9253),
  Country(name: 'Brunei', isoCode: 'BN', latitude: 4.5353, longitude: 114.7277),
  Country(name: 'Bulgaristan', isoCode: 'BG', latitude: 42.7339, longitude: 25.4858),
  Country(name: 'Burkina Faso', isoCode: 'BF', latitude: 12.2383, longitude: -1.5616),
  Country(name: 'Burundi', isoCode: 'BI', latitude: -3.3731, longitude: 29.9189),
  Country(name: 'Cezayir', isoCode: 'DZ', latitude: 28.0339, longitude: 1.6596),
  Country(name: 'Cibuti', isoCode: 'DJ', latitude: 11.8251, longitude: 42.5903),
  Country(name: 'Çad', isoCode: 'TD', latitude: 15.4542, longitude: 18.7322),
  Country(name: 'Çekya', isoCode: 'CZ', latitude: 49.8175, longitude: 15.4730),
  Country(name: 'Çin', isoCode: 'CN', latitude: 35.8617, longitude: 104.1954),
  Country(name: 'Danimarka', isoCode: 'DK', latitude: 56.2639, longitude: 9.5018),
  Country(name: 'Demokratik Kongo Cumhuriyeti', isoCode: 'CD', latitude: -4.0383, longitude: 21.7587),
  Country(name: 'Dominik Cumhuriyeti', isoCode: 'DO', latitude: 18.7357, longitude: -70.1627),
  Country(name: 'Ekvador', isoCode: 'EC', latitude: -1.8312, longitude: -78.1834),
  Country(name: 'El Salvador', isoCode: 'SV', latitude: 13.7942, longitude: -88.8965),
  Country(name: 'Endonezya', isoCode: 'ID', latitude: -0.7893, longitude: 113.9213),
  Country(name: 'Ermenistan', isoCode: 'AM', latitude: 40.0691, longitude: 45.0382),
  Country(name: 'Estonya', isoCode: 'EE', latitude: 58.5953, longitude: 25.0136),
  Country(name: 'Etiyopya', isoCode: 'ET', latitude: 9.1450, longitude: 40.4897),
  Country(name: 'Fas', isoCode: 'MA', latitude: 31.7917, longitude: -7.0926),
  Country(name: 'Fiji', isoCode: 'FJ', latitude: -16.5782, longitude: 179.4144),
  Country(name: 'Fildişi Sahili', isoCode: 'CI', latitude: 7.5400, longitude: -5.5471),
  Country(name: 'Filipinler', isoCode: 'PH', latitude: 12.8797, longitude: 121.7740),
  Country(name: 'Filistin', isoCode: 'PS', latitude: 31.9522, longitude: 35.2332),
  Country(name: 'Finlandiya', isoCode: 'FI', latitude: 61.9241, longitude: 25.7482),
  Country(name: 'Fransa', isoCode: 'FR', latitude: 46.2276, longitude: 2.2137),
  Country(name: 'Gabon', isoCode: 'GA', latitude: -0.8037, longitude: 11.6094),
  Country(name: 'Galler', isoCode: 'GB', latitude: 52.1307, longitude: -3.7837),
  Country(name: 'Gambiya', isoCode: 'GM', latitude: 13.4432, longitude: -15.3101),
  Country(name: 'Gana', isoCode: 'GH', latitude: 7.9465, longitude: -1.0232),
  Country(name: 'Gine', isoCode: 'GN', latitude: 9.9456, longitude: -9.6966),
  Country(name: 'Grönland', isoCode: 'GL', latitude: 71.7069, longitude: -42.6043),
  Country(name: 'Guatemala', isoCode: 'GT', latitude: 15.7835, longitude: -90.2308),
  Country(name: 'Güney Afrika', isoCode: 'ZA', latitude: -30.5595, longitude: 22.9375),
  Country(name: 'Güney Kore', isoCode: 'KR', latitude: 35.9078, longitude: 127.7669),
  Country(name: 'Gürcistan', isoCode: 'GE', latitude: 42.3154, longitude: 43.3569),
  Country(name: 'Haiti', isoCode: 'HT', latitude: 18.9712, longitude: -72.2852),
  Country(name: 'Hırvatistan', isoCode: 'HR', latitude: 45.1000, longitude: 15.2000),
  Country(name: 'Hindistan', isoCode: 'IN', latitude: 20.5937, longitude: 78.9629),
  Country(name: 'Hollanda', isoCode: 'NL', latitude: 52.1326, longitude: 5.2913),
  Country(name: 'Honduras', isoCode: 'HN', latitude: 15.2000, longitude: -86.2419),
  Country(name: 'Irak', isoCode: 'IQ', latitude: 33.2232, longitude: 43.6793),
  Country(name: 'İran', isoCode: 'IR', latitude: 32.4279, longitude: 53.6880),
  Country(name: 'İrlanda', isoCode: 'IE', latitude: 53.4129, longitude: -8.2439),
  Country(name: 'İspanya', isoCode: 'ES', latitude: 40.4637, longitude: -3.7492),
  Country(name: 'İsrail', isoCode: 'IL', latitude: 31.0461, longitude: 34.8516),
  Country(name: 'İsveç', isoCode: 'SE', latitude: 60.1282, longitude: 18.6435),
  Country(name: 'İsviçre', isoCode: 'CH', latitude: 46.8182, longitude: 8.2275),
  Country(name: 'İtalya', isoCode: 'IT', latitude: 41.8719, longitude: 12.5674),
  Country(name: 'İzlanda', isoCode: 'IS', latitude: 64.9631, longitude: -19.0208),
  Country(name: 'Jamaika', isoCode: 'JM', latitude: 18.1096, longitude: -77.2975),
  Country(name: 'Japonya', isoCode: 'JP', latitude: 36.2048, longitude: 138.2529),
  Country(name: 'Kamboçya', isoCode: 'KH', latitude: 12.5657, longitude: 104.9910),
  Country(name: 'Kamerun', isoCode: 'CM', latitude: 7.3697, longitude: 12.3547),
  Country(name: 'Kanada', isoCode: 'CA', latitude: 56.1304, longitude: -106.3468),
  Country(name: 'Karadağ', isoCode: 'ME', latitude: 42.7087, longitude: 19.3744),
  Country(name: 'Katar', isoCode: 'QA', latitude: 25.3548, longitude: 51.1839),
  Country(name: 'Kazakistan', isoCode: 'KZ', latitude: 48.0196, longitude: 66.9237),
  Country(name: 'Kenya', isoCode: 'KE', latitude: -0.0236, longitude: 37.9062),
  Country(name: 'Kıbrıs', isoCode: 'CY', latitude: 35.1264, longitude: 33.4299),
  Country(name: 'Kırgızistan', isoCode: 'KG', latitude: 41.2044, longitude: 74.7661),
  Country(name: 'Kolombiya', isoCode: 'CO', latitude: 4.5709, longitude: -74.2973),
  Country(name: 'Kosta Rika', isoCode: 'CR', latitude: 9.7489, longitude: -83.7534),
  Country(name: 'Kuveyt', isoCode: 'KW', latitude: 29.3117, longitude: 47.4818),
  Country(name: 'Kuzey Kore', isoCode: 'KP', latitude: 40.3399, longitude: 127.5101),
  Country(name: 'Kuzey Makedonya', isoCode: 'MK', latitude: 41.6086, longitude: 21.7453),
  Country(name: 'Küba', isoCode: 'CU', latitude: 21.5218, longitude: -77.7812),
  Country(name: 'Letonya', isoCode: 'LV', latitude: 56.8796, longitude: 24.6032),
  Country(name: 'Libya', isoCode: 'LY', latitude: 26.3351, longitude: 17.2283),
  Country(name: 'Litvanya', isoCode: 'LT', latitude: 55.1694, longitude: 23.8813),
  Country(name: 'Lübnan', isoCode: 'LB', latitude: 33.8547, longitude: 35.8623),
  Country(name: 'Lüksemburg', isoCode: 'LU', latitude: 49.8153, longitude: 6.1296),
  Country(name: 'Macaristan', isoCode: 'HU', latitude: 47.1625, longitude: 19.5033),
  Country(name: 'Madagaskar', isoCode: 'MG', latitude: -18.7669, longitude: 46.8691),
  Country(name: 'Malezya', isoCode: 'MY', latitude: 4.2105, longitude: 101.9758),
  Country(name: 'Mali', isoCode: 'ML', latitude: 17.5707, longitude: -3.9962),
  Country(name: 'Malta', isoCode: 'MT', latitude: 35.9375, longitude: 14.3754),
  Country(name: 'Meksika', isoCode: 'MX', latitude: 23.6345, longitude: -102.5528),
  Country(name: 'Mısır', isoCode: 'EG', latitude: 26.8206, longitude: 30.8025),
  Country(name: 'Moğolistan', isoCode: 'MN', latitude: 46.8625, longitude: 103.8467),
  Country(name: 'Moldova', isoCode: 'MD', latitude: 47.4116, longitude: 28.3699),
  Country(name: 'Moritanya', isoCode: 'MR', latitude: 21.0079, longitude: -10.9408),
  Country(name: 'Namibya', isoCode: 'NA', latitude: -22.9576, longitude: 18.4904),
  Country(name: 'Nepal', isoCode: 'NP', latitude: 28.3949, longitude: 84.1240),
  Country(name: 'Nijer', isoCode: 'NE', latitude: 17.6078, longitude: 8.0817),
  Country(name: 'Nijerya', isoCode: 'NG', latitude: 9.0820, longitude: 8.6753),
  Country(name: 'Nikaragua', isoCode: 'NI', latitude: 12.8654, longitude: -85.2072),
  Country(name: 'Norveç', isoCode: 'NO', latitude: 60.4720, longitude: 8.4689),
  Country(name: 'Özbekistan', isoCode: 'UZ', latitude: 41.3775, longitude: 64.5853),
  Country(name: 'Pakistan', isoCode: 'PK', latitude: 30.3753, longitude: 69.3451),
  Country(name: 'Panama', isoCode: 'PA', latitude: 8.5380, longitude: -80.7821),
  Country(name: 'Paraguay', isoCode: 'PY', latitude: -23.4425, longitude: -58.4438),
  Country(name: 'Peru', isoCode: 'PE', latitude: -9.1900, longitude: -75.0152),
  Country(name: 'Polonya', isoCode: 'PL', latitude: 51.9194, longitude: 19.1451),
  Country(name: 'Portekiz', isoCode: 'PT', latitude: 39.3999, longitude: -8.2245),
  Country(name: 'Romanya', isoCode: 'RO', latitude: 45.9432, longitude: 24.9668),
  Country(name: 'Ruanda', isoCode: 'RW', latitude: -1.9403, longitude: 29.8739),
  Country(name: 'Rusya', isoCode: 'RU', latitude: 61.5240, longitude: 105.3188),
  Country(name: 'Senegal', isoCode: 'SN', latitude: 14.4974, longitude: -14.4524),
  Country(name: 'Sırbistan', isoCode: 'RS', latitude: 44.0165, longitude: 21.0059),
  Country(name: 'Singapur', isoCode: 'SG', latitude: 1.3521, longitude: 103.8198),
  Country(name: 'Slovakya', isoCode: 'SK', latitude: 48.6690, longitude: 19.6990),
  Country(name: 'Slovenya', isoCode: 'SI', latitude: 46.1512, longitude: 14.9955),
  Country(name: 'Somali', isoCode: 'SO', latitude: 5.1521, longitude: 46.1996),
  Country(name: 'Sri Lanka', isoCode: 'LK', latitude: 7.8731, longitude: 80.7718),
  Country(name: 'Sudan', isoCode: 'SD', latitude: 12.8628, longitude: 30.2176),
  Country(name: 'Suriye', isoCode: 'SY', latitude: 34.8021, longitude: 38.9968),
  Country(name: 'Suudi Arabistan', isoCode: 'SA', latitude: 23.8859, longitude: 45.0792),
  Country(name: 'Şili', isoCode: 'CL', latitude: -35.6751, longitude: -71.5430),
  Country(name: 'Tacikistan', isoCode: 'TJ', latitude: 38.8610, longitude: 71.2761),
  Country(name: 'Tanzanya', isoCode: 'TZ', latitude: -6.3690, longitude: 34.8888),
  Country(name: 'Tayland', isoCode: 'TH', latitude: 15.8700, longitude: 100.9925),
  Country(name: 'Tayvan', isoCode: 'TW', latitude: 23.6978, longitude: 120.9605),
  Country(name: 'Tunus', isoCode: 'TN', latitude: 33.8869, longitude: 9.5375),
  Country(name: 'Türkiye', isoCode: 'TR', latitude: 39.9334, longitude: 32.8597),
  Country(name: 'Türkmenistan', isoCode: 'TM', latitude: 38.9697, longitude: 59.5563),
  Country(name: 'Uganda', isoCode: 'UG', latitude: 1.3733, longitude: 32.2903),
  Country(name: 'Ukrayna', isoCode: 'UA', latitude: 48.3794, longitude: 31.1656),
  Country(name: 'Umman', isoCode: 'OM', latitude: 21.4735, longitude: 55.9754),
  Country(name: 'Uruguay', isoCode: 'UY', latitude: -32.5228, longitude: -55.7658),
  Country(name: 'Ürdün', isoCode: 'JO', latitude: 31.2400, longitude: 36.5100),
  Country(name: 'Venezuela', isoCode: 'VE', latitude: 6.4238, longitude: -66.5897),
  Country(name: 'Vietnam', isoCode: 'VN', latitude: 14.0583, longitude: 108.2772),
  Country(name: 'Yemen', isoCode: 'YE', latitude: 15.5527, longitude: 48.5164),
  Country(name: 'Yeni Zelanda', isoCode: 'NZ', latitude: -40.9006, longitude: 174.8860),
  Country(name: 'Yunanistan', isoCode: 'GR', latitude: 39.0742, longitude: 21.8243),
  Country(name: 'Zambiya', isoCode: 'ZM', latitude: -13.1339, longitude: 27.8493),
  Country(name: 'Zimbabve', isoCode: 'ZW', latitude: -19.0154, longitude: 29.1549),
];

/// Rastgele bir ülke döndürür
Country getRandomCountry() {
  final random = Random();
  return allCountries[random.nextInt(allCountries.length)];
}
