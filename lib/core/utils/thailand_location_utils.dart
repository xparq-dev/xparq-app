// lib/core/utils/thailand_location_utils.dart

import 'dart:math' as math;

class ProvinceCoordinate {
  final String name;
  final double latitude;
  final double longitude;

  const ProvinceCoordinate(this.name, this.latitude, this.longitude);
}

const List<ProvinceCoordinate> thailandProvinceCoordinates = [
  ProvinceCoordinate('Amnat Charoen', 15.8911, 104.6256),
  ProvinceCoordinate('Ang Thong', 14.5888, 100.4528),
  ProvinceCoordinate('Bangkok', 13.7563, 100.5018),
  ProvinceCoordinate('Bueng Kan', 18.3619, 103.5042),
  ProvinceCoordinate('Buriram', 15.0008, 103.1118),
  ProvinceCoordinate('Chachoengsao', 13.6889, 101.0778),
  ProvinceCoordinate('Chai Nat', 15.1856, 100.1250),
  ProvinceCoordinate('Chaiyaphum', 15.8068, 102.0315),
  ProvinceCoordinate('Chanthaburi', 12.6096, 102.1038),
  ProvinceCoordinate('Chiang Mai', 18.7883, 98.9853),
  ProvinceCoordinate('Chiang Rai', 19.9071, 99.8310),
  ProvinceCoordinate('Chonburi', 13.3611, 100.9847),
  ProvinceCoordinate('Chumphon', 10.4933, 99.1802),
  ProvinceCoordinate('Kalasin', 16.4328, 103.5065),
  ProvinceCoordinate('Kamphaeng Phet', 16.4828, 99.5227),
  ProvinceCoordinate('Kanchanaburi', 14.0228, 99.5328),
  ProvinceCoordinate('Khon Kaen', 16.4419, 102.8359),
  ProvinceCoordinate('Krabi', 8.0855, 98.9067),
  ProvinceCoordinate('Lampang', 18.2855, 99.4927),
  ProvinceCoordinate('Lamphun', 18.5771, 99.0080),
  ProvinceCoordinate('Loei', 17.4862, 101.7223),
  ProvinceCoordinate('Lopburi', 14.7995, 100.6534),
  ProvinceCoordinate('Mae Hong Son', 19.3015, 97.9685),
  ProvinceCoordinate('Maha Sarakham', 16.1850, 103.3005),
  ProvinceCoordinate('Mukdahan', 16.5434, 104.7236),
  ProvinceCoordinate('Nakhon Nayok', 14.2067, 101.2139),
  ProvinceCoordinate('Nakhon Pathom', 13.8194, 100.0441),
  ProvinceCoordinate('Nakhon Phanom', 17.4074, 104.7816),
  ProvinceCoordinate('Nakhon Ratchasima', 14.9739, 102.0836),
  ProvinceCoordinate('Nakhon Sawan', 15.7042, 100.1372),
  ProvinceCoordinate('Nakhon Si Thammarat', 8.4304, 99.9631),
  ProvinceCoordinate('Nan', 18.7830, 100.7766),
  ProvinceCoordinate('Narathiwat', 6.4255, 101.8253),
  ProvinceCoordinate('Nong Bua Lamphu', 17.2036, 102.4258),
  ProvinceCoordinate('Nong Khai', 17.8783, 102.7413),
  ProvinceCoordinate('Nonthaburi', 13.8591, 100.5217),
  ProvinceCoordinate('Pathum Thani', 14.0208, 100.5250),
  ProvinceCoordinate('Pattani', 6.8702, 101.2500),
  ProvinceCoordinate('Phang Nga', 8.4502, 98.5255),
  ProvinceCoordinate('Phatthalung', 7.6186, 100.0739),
  ProvinceCoordinate('Phayao', 19.1658, 99.9125),
  ProvinceCoordinate('Phetchabun', 16.4191, 101.1600),
  ProvinceCoordinate('Phetchaburi', 13.1118, 99.9436),
  ProvinceCoordinate('Phichit', 16.4412, 100.3541),
  ProvinceCoordinate('Phitsanulok', 16.8211, 100.2659),
  ProvinceCoordinate('Phra Nakhon Si Ayutthaya', 14.3489, 100.5647),
  ProvinceCoordinate('Phrae', 18.1446, 100.1413),
  ProvinceCoordinate('Phuket', 7.8804, 98.3922),
  ProvinceCoordinate('Prachinburi', 14.0494, 101.3725),
  ProvinceCoordinate('Prachuap Khiri Khan', 11.8124, 99.7972),
  ProvinceCoordinate('Ranong', 9.9702, 98.6402),
  ProvinceCoordinate('Ratchaburi', 13.5283, 99.8134),
  ProvinceCoordinate('Rayong', 12.6814, 101.2811),
  ProvinceCoordinate('Roi Et', 16.0538, 103.6521),
  ProvinceCoordinate('Sa Kaeo', 13.8241, 102.0645),
  ProvinceCoordinate('Sakon Nakhon', 17.1539, 104.1352),
  ProvinceCoordinate('Samut Prakan', 13.5991, 100.5962),
  ProvinceCoordinate('Samut Sakhon', 13.5475, 100.2741),
  ProvinceCoordinate('Samut Songkhram', 13.4091, 100.0022),
  ProvinceCoordinate('Saraburi', 14.5289, 100.9121),
  ProvinceCoordinate('Satun', 6.6231, 100.0631),
  ProvinceCoordinate('Sing Buri', 14.8906, 100.3956),
  ProvinceCoordinate('Sisaket', 15.1186, 104.3220),
  ProvinceCoordinate('Songkhla', 7.1891, 100.5954),
  ProvinceCoordinate('Sukhothai', 17.0056, 99.8264),
  ProvinceCoordinate('Suphan Buri', 14.4742, 100.1222),
  ProvinceCoordinate('Surat Thani', 9.1384, 99.3218),
  ProvinceCoordinate('Surin', 14.8818, 103.4936),
  ProvinceCoordinate('Tak', 16.8833, 99.1239),
  ProvinceCoordinate('Trang', 7.5564, 99.6114),
  ProvinceCoordinate('Trat', 12.2428, 102.5175),
  ProvinceCoordinate('Ubon Ratchathani', 15.2448, 104.8475),
  ProvinceCoordinate('Udon Thani', 17.4138, 102.7872),
  ProvinceCoordinate('Uthai Thani', 15.3837, 100.0244),
  ProvinceCoordinate('Uttaradit', 17.6258, 100.1017),
  ProvinceCoordinate('Yala', 6.5411, 101.2814),
  ProvinceCoordinate('Yasothon', 15.7932, 104.1453),
];

/// Finds the nearest Thailand province name for a given lat/lng.
String? findNearestProvince(double lat, double lng) {
  if (lat < 5.0 || lat > 21.0 || lng < 97.0 || lng > 106.0) {
    return null; // Outside Thailand approx.
  }

  String? nearest;
  double minDistance = double.infinity;

  for (final prov in thailandProvinceCoordinates) {
    final dist = _calculateDistance(lat, lng, prov.latitude, prov.longitude);
    if (dist < minDistance) {
      minDistance = dist;
      nearest = prov.name;
    }
  }

  return nearest;
}

double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const p = 0.017453292519943295; // Math.PI / 180
  final a =
      0.5 -
      math.cos((lat2 - lat1) * p) / 2 +
      math.cos(lat1 * p) *
          math.cos(lat2 * p) *
          (1 - math.cos((lon2 - lon1) * p)) /
          2;
  return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
}
