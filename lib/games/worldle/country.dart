import 'dart:math';

/// Ülke veri modeli — isim, ISO kodu ve merkez koordinatları tutar.
import '../../services/language_service.dart';

class Country {
  final String nameTr;
  final String nameEn;
  final String isoCode;
  final double latitude;
  final double longitude;

  const Country({
    required this.nameTr,
    required this.nameEn,
    required this.isoCode,
    required this.latitude,
    required this.longitude,
  });

  String get name => LanguageService().currentLanguage == 'en' ? nameEn : nameTr;

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
  Country(nameTr: 'Afganistan', nameEn: 'Afghanistan', isoCode: 'AF', latitude: 33.9391, longitude: 67.7100),
  Country(nameTr: 'Almanya', nameEn: 'Germany', isoCode: 'DE', latitude: 51.1657, longitude: 10.4515),
  Country(nameTr: 'Amerika Birleşik Devletleri', nameEn: 'United States of America', isoCode: 'US', latitude: 37.0902, longitude: -95.7129),
  Country(nameTr: 'Andorra', nameEn: 'Andorra', isoCode: 'AD', latitude: 42.5063, longitude: 1.5218),
  Country(nameTr: 'Angola', nameEn: 'Angola', isoCode: 'AO', latitude: -11.2027, longitude: 17.8739),
  Country(nameTr: 'Antigua ve Barbuda', nameEn: 'Antigua and Barbuda', isoCode: 'AG', latitude: 17.0608, longitude: -61.7964),
  Country(nameTr: 'Arjantin', nameEn: 'Argentina', isoCode: 'AR', latitude: -38.4161, longitude: -63.6167),
  Country(nameTr: 'Arnavutluk', nameEn: 'Albania', isoCode: 'AL', latitude: 41.1533, longitude: 20.1683),
  Country(nameTr: 'Avustralya', nameEn: 'Australia', isoCode: 'AU', latitude: -25.2744, longitude: 133.7751),
  Country(nameTr: 'Avusturya', nameEn: 'Austria', isoCode: 'AT', latitude: 47.5162, longitude: 14.5501),
  Country(nameTr: 'Azerbaycan', nameEn: 'Azerbaijan', isoCode: 'AZ', latitude: 40.1431, longitude: 47.5769),
  Country(nameTr: 'Bahamalar', nameEn: 'Bahamas', isoCode: 'BS', latitude: 25.0343, longitude: -77.3963),
  Country(nameTr: 'Bahreyn', nameEn: 'Bahrain', isoCode: 'BH', latitude: 25.9304, longitude: 50.6378),
  Country(nameTr: 'Bangladeş', nameEn: 'Bangladesh', isoCode: 'BD', latitude: 23.6850, longitude: 90.3563),
  Country(nameTr: 'Barbados', nameEn: 'Barbados', isoCode: 'BB', latitude: 13.1939, longitude: -59.5432),
  Country(nameTr: 'Batı Sahra', nameEn: 'Western Sahara', isoCode: 'EH', latitude: 24.2155, longitude: -12.8858),
  Country(nameTr: 'Belçika', nameEn: 'Belgium', isoCode: 'BE', latitude: 50.5039, longitude: 4.4699),
  Country(nameTr: 'Belize', nameEn: 'Belize', isoCode: 'BZ', latitude: 17.1899, longitude: -88.4976),
  Country(nameTr: 'Benin', nameEn: 'Benin', isoCode: 'BJ', latitude: 9.3077, longitude: 2.3158),
  Country(nameTr: 'Beyaz Rusya', nameEn: 'Belarus', isoCode: 'BY', latitude: 53.7098, longitude: 27.9534),
  Country(nameTr: 'Bhutan', nameEn: 'Bhutan', isoCode: 'BT', latitude: 27.5142, longitude: 90.4336),
  Country(nameTr: 'Birleşik Arap Emirlikleri', nameEn: 'United Arab Emirates', isoCode: 'AE', latitude: 23.4241, longitude: 53.8478),
  Country(nameTr: 'Birleşik Krallık', nameEn: 'United Kingdom of Great Britain and Northern Ireland', isoCode: 'GB', latitude: 55.3781, longitude: -3.4360),
  Country(nameTr: 'Bolivya', nameEn: 'Bolivia, Plurinational State of', isoCode: 'BO', latitude: -16.2902, longitude: -63.5887),
  Country(nameTr: 'Bosna Hersek', nameEn: 'Bosnia and Herzegovina', isoCode: 'BA', latitude: 43.9159, longitude: 17.6791),
  Country(nameTr: 'Botsvana', nameEn: 'Botswana', isoCode: 'BW', latitude: -22.3285, longitude: 24.6849),
  Country(nameTr: 'Brezilya', nameEn: 'Brazil', isoCode: 'BR', latitude: -14.2350, longitude: -51.9253),
  Country(nameTr: 'Brunei', nameEn: 'Brunei Darussalam', isoCode: 'BN', latitude: 4.5353, longitude: 114.7277),
  Country(nameTr: 'Bulgaristan', nameEn: 'Bulgaria', isoCode: 'BG', latitude: 42.7339, longitude: 25.4858),
  Country(nameTr: 'Burkina Faso', nameEn: 'Burkina Faso', isoCode: 'BF', latitude: 12.2383, longitude: -1.5616),
  Country(nameTr: 'Burundi', nameEn: 'Burundi', isoCode: 'BI', latitude: -3.3731, longitude: 29.9189),
  Country(nameTr: 'Cezayir', nameEn: 'Algeria', isoCode: 'DZ', latitude: 28.0339, longitude: 1.6596),
  Country(nameTr: 'Cibuti', nameEn: 'Djibouti', isoCode: 'DJ', latitude: 11.8251, longitude: 42.5903),
  Country(nameTr: 'Çad', nameEn: 'Chad', isoCode: 'TD', latitude: 15.4542, longitude: 18.7322),
  Country(nameTr: 'Çekya', nameEn: 'Czechia', isoCode: 'CZ', latitude: 49.8175, longitude: 15.4730),
  Country(nameTr: 'Çin', nameEn: 'China', isoCode: 'CN', latitude: 35.8617, longitude: 104.1954),
  Country(nameTr: 'Danimarka', nameEn: 'Denmark', isoCode: 'DK', latitude: 56.2639, longitude: 9.5018),
  Country(nameTr: 'Demokratik Kongo Cumhuriyeti', nameEn: 'DR Congo', isoCode: 'CD', latitude: -4.0383, longitude: 21.7587),
  Country(nameTr: 'Dominik Cumhuriyeti', nameEn: 'Dominican Republic', isoCode: 'DO', latitude: 18.7357, longitude: -70.1627),
  Country(nameTr: 'Ekvador', nameEn: 'Ecuador', isoCode: 'EC', latitude: -1.8312, longitude: -78.1834),
  Country(nameTr: 'El Salvador', nameEn: 'El Salvador', isoCode: 'SV', latitude: 13.7942, longitude: -88.8965),
  Country(nameTr: 'Endonezya', nameEn: 'Indonesia', isoCode: 'ID', latitude: -0.7893, longitude: 113.9213),
  Country(nameTr: 'Ermenistan', nameEn: 'Armenia', isoCode: 'AM', latitude: 40.0691, longitude: 45.0382),
  Country(nameTr: 'Estonya', nameEn: 'Estonia', isoCode: 'EE', latitude: 58.5953, longitude: 25.0136),
  Country(nameTr: 'Etiyopya', nameEn: 'Ethiopia', isoCode: 'ET', latitude: 9.1450, longitude: 40.4897),
  Country(nameTr: 'Fas', nameEn: 'Morocco', isoCode: 'MA', latitude: 31.7917, longitude: -7.0926),
  Country(nameTr: 'Fiji', nameEn: 'Fiji', isoCode: 'FJ', latitude: -16.5782, longitude: 179.4144),
  Country(nameTr: 'Fildişi Sahili', nameEn: 'Côte d\'Ivoire', isoCode: 'CI', latitude: 7.5400, longitude: -5.5471),
  Country(nameTr: 'Filipinler', nameEn: 'Philippines', isoCode: 'PH', latitude: 12.8797, longitude: 121.7740),
  Country(nameTr: 'Filistin', nameEn: 'Palestine, State of', isoCode: 'PS', latitude: 31.9522, longitude: 35.2332),
  Country(nameTr: 'Finlandiya', nameEn: 'Finland', isoCode: 'FI', latitude: 61.9241, longitude: 25.7482),
  Country(nameTr: 'Fransa', nameEn: 'France', isoCode: 'FR', latitude: 46.2276, longitude: 2.2137),
  Country(nameTr: 'Gabon', nameEn: 'Gabon', isoCode: 'GA', latitude: -0.8037, longitude: 11.6094),
  Country(nameTr: 'Galler', nameEn: 'United Kingdom of Great Britain and Northern Ireland', isoCode: 'GB', latitude: 52.1307, longitude: -3.7837),
  Country(nameTr: 'Gambiya', nameEn: 'Gambia', isoCode: 'GM', latitude: 13.4432, longitude: -15.3101),
  Country(nameTr: 'Gana', nameEn: 'Ghana', isoCode: 'GH', latitude: 7.9465, longitude: -1.0232),
  Country(nameTr: 'Gine', nameEn: 'Guinea', isoCode: 'GN', latitude: 9.9456, longitude: -9.6966),
  Country(nameTr: 'Grönland', nameEn: 'Greenland', isoCode: 'GL', latitude: 71.7069, longitude: -42.6043),
  Country(nameTr: 'Guatemala', nameEn: 'Guatemala', isoCode: 'GT', latitude: 15.7835, longitude: -90.2308),
  Country(nameTr: 'Güney Afrika', nameEn: 'South Africa', isoCode: 'ZA', latitude: -30.5595, longitude: 22.9375),
  Country(nameTr: 'Güney Kore', nameEn: 'Korea, Republic of', isoCode: 'KR', latitude: 35.9078, longitude: 127.7669),
  Country(nameTr: 'Gürcistan', nameEn: 'Georgia', isoCode: 'GE', latitude: 42.3154, longitude: 43.3569),
  Country(nameTr: 'Haiti', nameEn: 'Haiti', isoCode: 'HT', latitude: 18.9712, longitude: -72.2852),
  Country(nameTr: 'Hırvatistan', nameEn: 'Croatia', isoCode: 'HR', latitude: 45.1000, longitude: 15.2000),
  Country(nameTr: 'Hindistan', nameEn: 'India', isoCode: 'IN', latitude: 20.5937, longitude: 78.9629),
  Country(nameTr: 'Hollanda', nameEn: 'Netherlands, Kingdom of the', isoCode: 'NL', latitude: 52.1326, longitude: 5.2913),
  Country(nameTr: 'Honduras', nameEn: 'Honduras', isoCode: 'HN', latitude: 15.2000, longitude: -86.2419),
  Country(nameTr: 'Irak', nameEn: 'Iraq', isoCode: 'IQ', latitude: 33.2232, longitude: 43.6793),
  Country(nameTr: 'İran', nameEn: 'Iran, Islamic Republic of', isoCode: 'IR', latitude: 32.4279, longitude: 53.6880),
  Country(nameTr: 'İrlanda', nameEn: 'Ireland', isoCode: 'IE', latitude: 53.4129, longitude: -8.2439),
  Country(nameTr: 'İspanya', nameEn: 'Spain', isoCode: 'ES', latitude: 40.4637, longitude: -3.7492),
  Country(nameTr: 'İsrail', nameEn: 'Israel', isoCode: 'IL', latitude: 31.0461, longitude: 34.8516),
  Country(nameTr: 'İsveç', nameEn: 'Sweden', isoCode: 'SE', latitude: 60.1282, longitude: 18.6435),
  Country(nameTr: 'İsviçre', nameEn: 'Switzerland', isoCode: 'CH', latitude: 46.8182, longitude: 8.2275),
  Country(nameTr: 'İtalya', nameEn: 'Italy', isoCode: 'IT', latitude: 41.8719, longitude: 12.5674),
  Country(nameTr: 'İzlanda', nameEn: 'Iceland', isoCode: 'IS', latitude: 64.9631, longitude: -19.0208),
  Country(nameTr: 'Jamaika', nameEn: 'Jamaica', isoCode: 'JM', latitude: 18.1096, longitude: -77.2975),
  Country(nameTr: 'Japonya', nameEn: 'Japan', isoCode: 'JP', latitude: 36.2048, longitude: 138.2529),
  Country(nameTr: 'Kamboçya', nameEn: 'Cambodia', isoCode: 'KH', latitude: 12.5657, longitude: 104.9910),
  Country(nameTr: 'Kamerun', nameEn: 'Cameroon', isoCode: 'CM', latitude: 7.3697, longitude: 12.3547),
  Country(nameTr: 'Kanada', nameEn: 'Canada', isoCode: 'CA', latitude: 56.1304, longitude: -106.3468),
  Country(nameTr: 'Karadağ', nameEn: 'Montenegro', isoCode: 'ME', latitude: 42.7087, longitude: 19.3744),
  Country(nameTr: 'Katar', nameEn: 'Qatar', isoCode: 'QA', latitude: 25.3548, longitude: 51.1839),
  Country(nameTr: 'Kazakistan', nameEn: 'Kazakhstan', isoCode: 'KZ', latitude: 48.0196, longitude: 66.9237),
  Country(nameTr: 'Kenya', nameEn: 'Kenya', isoCode: 'KE', latitude: -0.0236, longitude: 37.9062),
  Country(nameTr: 'Kıbrıs', nameEn: 'Cyprus', isoCode: 'CY', latitude: 35.1264, longitude: 33.4299),
  Country(nameTr: 'Kırgızistan', nameEn: 'Kyrgyzstan', isoCode: 'KG', latitude: 41.2044, longitude: 74.7661),
  Country(nameTr: 'Kolombiya', nameEn: 'Colombia', isoCode: 'CO', latitude: 4.5709, longitude: -74.2973),
  Country(nameTr: 'Kosta Rika', nameEn: 'Costa Rica', isoCode: 'CR', latitude: 9.7489, longitude: -83.7534),
  Country(nameTr: 'Kuveyt', nameEn: 'Kuwait', isoCode: 'KW', latitude: 29.3117, longitude: 47.4818),
  Country(nameTr: 'Kuzey Kore', nameEn: 'Korea, Democratic People\'s Republic of', isoCode: 'KP', latitude: 40.3399, longitude: 127.5101),
  Country(nameTr: 'Kuzey Makedonya', nameEn: 'North Macedonia', isoCode: 'MK', latitude: 41.6086, longitude: 21.7453),
  Country(nameTr: 'Küba', nameEn: 'Cuba', isoCode: 'CU', latitude: 21.5218, longitude: -77.7812),
  Country(nameTr: 'Letonya', nameEn: 'Latvia', isoCode: 'LV', latitude: 56.8796, longitude: 24.6032),
  Country(nameTr: 'Libya', nameEn: 'Libya', isoCode: 'LY', latitude: 26.3351, longitude: 17.2283),
  Country(nameTr: 'Litvanya', nameEn: 'Lithuania', isoCode: 'LT', latitude: 55.1694, longitude: 23.8813),
  Country(nameTr: 'Lübnan', nameEn: 'Lebanon', isoCode: 'LB', latitude: 33.8547, longitude: 35.8623),
  Country(nameTr: 'Lüksemburg', nameEn: 'Luxembourg', isoCode: 'LU', latitude: 49.8153, longitude: 6.1296),
  Country(nameTr: 'Macaristan', nameEn: 'Hungary', isoCode: 'HU', latitude: 47.1625, longitude: 19.5033),
  Country(nameTr: 'Madagaskar', nameEn: 'Madagascar', isoCode: 'MG', latitude: -18.7669, longitude: 46.8691),
  Country(nameTr: 'Malezya', nameEn: 'Malaysia', isoCode: 'MY', latitude: 4.2105, longitude: 101.9758),
  Country(nameTr: 'Mali', nameEn: 'Mali', isoCode: 'ML', latitude: 17.5707, longitude: -3.9962),
  Country(nameTr: 'Malta', nameEn: 'Malta', isoCode: 'MT', latitude: 35.9375, longitude: 14.3754),
  Country(nameTr: 'Meksika', nameEn: 'Mexico', isoCode: 'MX', latitude: 23.6345, longitude: -102.5528),
  Country(nameTr: 'Mısır', nameEn: 'Egypt', isoCode: 'EG', latitude: 26.8206, longitude: 30.8025),
  Country(nameTr: 'Moğolistan', nameEn: 'Mongolia', isoCode: 'MN', latitude: 46.8625, longitude: 103.8467),
  Country(nameTr: 'Moldova', nameEn: 'Moldova, Republic of', isoCode: 'MD', latitude: 47.4116, longitude: 28.3699),
  Country(nameTr: 'Moritanya', nameEn: 'Mauritania', isoCode: 'MR', latitude: 21.0079, longitude: -10.9408),
  Country(nameTr: 'Namibya', nameEn: 'Namibia', isoCode: 'NA', latitude: -22.9576, longitude: 18.4904),
  Country(nameTr: 'Nepal', nameEn: 'Nepal', isoCode: 'NP', latitude: 28.3949, longitude: 84.1240),
  Country(nameTr: 'Nijer', nameEn: 'Niger', isoCode: 'NE', latitude: 17.6078, longitude: 8.0817),
  Country(nameTr: 'Nijerya', nameEn: 'Nigeria', isoCode: 'NG', latitude: 9.0820, longitude: 8.6753),
  Country(nameTr: 'Nikaragua', nameEn: 'Nicaragua', isoCode: 'NI', latitude: 12.8654, longitude: -85.2072),
  Country(nameTr: 'Norveç', nameEn: 'Norway', isoCode: 'NO', latitude: 60.4720, longitude: 8.4689),
  Country(nameTr: 'Özbekistan', nameEn: 'Uzbekistan', isoCode: 'UZ', latitude: 41.3775, longitude: 64.5853),
  Country(nameTr: 'Pakistan', nameEn: 'Pakistan', isoCode: 'PK', latitude: 30.3753, longitude: 69.3451),
  Country(nameTr: 'Panama', nameEn: 'Panama', isoCode: 'PA', latitude: 8.5380, longitude: -80.7821),
  Country(nameTr: 'Paraguay', nameEn: 'Paraguay', isoCode: 'PY', latitude: -23.4425, longitude: -58.4438),
  Country(nameTr: 'Peru', nameEn: 'Peru', isoCode: 'PE', latitude: -9.1900, longitude: -75.0152),
  Country(nameTr: 'Polonya', nameEn: 'Poland', isoCode: 'PL', latitude: 51.9194, longitude: 19.1451),
  Country(nameTr: 'Portekiz', nameEn: 'Portugal', isoCode: 'PT', latitude: 39.3999, longitude: -8.2245),
  Country(nameTr: 'Romanya', nameEn: 'Romania', isoCode: 'RO', latitude: 45.9432, longitude: 24.9668),
  Country(nameTr: 'Ruanda', nameEn: 'Rwanda', isoCode: 'RW', latitude: -1.9403, longitude: 29.8739),
  Country(nameTr: 'Rusya', nameEn: 'Russian Federation', isoCode: 'RU', latitude: 61.5240, longitude: 105.3188),
  Country(nameTr: 'Senegal', nameEn: 'Senegal', isoCode: 'SN', latitude: 14.4974, longitude: -14.4524),
  Country(nameTr: 'Sırbistan', nameEn: 'Serbia', isoCode: 'RS', latitude: 44.0165, longitude: 21.0059),
  Country(nameTr: 'Singapur', nameEn: 'Singapore', isoCode: 'SG', latitude: 1.3521, longitude: 103.8198),
  Country(nameTr: 'Slovakya', nameEn: 'Slovakia', isoCode: 'SK', latitude: 48.6690, longitude: 19.6990),
  Country(nameTr: 'Slovenya', nameEn: 'Slovenia', isoCode: 'SI', latitude: 46.1512, longitude: 14.9955),
  Country(nameTr: 'Somali', nameEn: 'Somalia', isoCode: 'SO', latitude: 5.1521, longitude: 46.1996),
  Country(nameTr: 'Sri Lanka', nameEn: 'Sri Lanka', isoCode: 'LK', latitude: 7.8731, longitude: 80.7718),
  Country(nameTr: 'Sudan', nameEn: 'Sudan', isoCode: 'SD', latitude: 12.8628, longitude: 30.2176),
  Country(nameTr: 'Suriye', nameEn: 'Syrian Arab Republic', isoCode: 'SY', latitude: 34.8021, longitude: 38.9968),
  Country(nameTr: 'Suudi Arabistan', nameEn: 'Saudi Arabia', isoCode: 'SA', latitude: 23.8859, longitude: 45.0792),
  Country(nameTr: 'Şili', nameEn: 'Chile', isoCode: 'CL', latitude: -35.6751, longitude: -71.5430),
  Country(nameTr: 'Tacikistan', nameEn: 'Tajikistan', isoCode: 'TJ', latitude: 38.8610, longitude: 71.2761),
  Country(nameTr: 'Tanzanya', nameEn: 'Tanzania, United Republic of', isoCode: 'TZ', latitude: -6.3690, longitude: 34.8888),
  Country(nameTr: 'Tayland', nameEn: 'Thailand', isoCode: 'TH', latitude: 15.8700, longitude: 100.9925),
  Country(nameTr: 'Tayvan', nameEn: 'Taiwan, Province of China', isoCode: 'TW', latitude: 23.6978, longitude: 120.9605),
  Country(nameTr: 'Tunus', nameEn: 'Tunisia', isoCode: 'TN', latitude: 33.8869, longitude: 9.5375),
  Country(nameTr: 'Türkiye', nameEn: 'Türkiye', isoCode: 'TR', latitude: 39.9334, longitude: 32.8597),
  Country(nameTr: 'Türkmenistan', nameEn: 'Turkmenistan', isoCode: 'TM', latitude: 38.9697, longitude: 59.5563),
  Country(nameTr: 'Uganda', nameEn: 'Uganda', isoCode: 'UG', latitude: 1.3733, longitude: 32.2903),
  Country(nameTr: 'Ukrayna', nameEn: 'Ukraine', isoCode: 'UA', latitude: 48.3794, longitude: 31.1656),
  Country(nameTr: 'Umman', nameEn: 'Oman', isoCode: 'OM', latitude: 21.4735, longitude: 55.9754),
  Country(nameTr: 'Uruguay', nameEn: 'Uruguay', isoCode: 'UY', latitude: -32.5228, longitude: -55.7658),
  Country(nameTr: 'Ürdün', nameEn: 'Jordan', isoCode: 'JO', latitude: 31.2400, longitude: 36.5100),
  Country(nameTr: 'Venezuela', nameEn: 'Venezuela, Bolivarian Republic of', isoCode: 'VE', latitude: 6.4238, longitude: -66.5897),
  Country(nameTr: 'Vietnam', nameEn: 'Viet Nam', isoCode: 'VN', latitude: 14.0583, longitude: 108.2772),
  Country(nameTr: 'Yemen', nameEn: 'Yemen', isoCode: 'YE', latitude: 15.5527, longitude: 48.5164),
  Country(nameTr: 'Yeni Zelanda', nameEn: 'New Zealand', isoCode: 'NZ', latitude: -40.9006, longitude: 174.8860),
  Country(nameTr: 'Yunanistan', nameEn: 'Greece', isoCode: 'GR', latitude: 39.0742, longitude: 21.8243),
  Country(nameTr: 'Zambiya', nameEn: 'Zambia', isoCode: 'ZM', latitude: -13.1339, longitude: 27.8493),
  Country(nameTr: 'Zimbabve', nameEn: 'Zimbabwe', isoCode: 'ZW', latitude: -19.0154, longitude: 29.1549),
];

/// Rastgele bir ülke döndürür
Country getRandomCountry() {
  final random = Random();
  return allCountries[random.nextInt(allCountries.length)];
}
