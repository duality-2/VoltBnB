import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_webservice/geocoding.dart';

class GeocodingService {
  GeocodingService() : _geocoding = GoogleMapsGeocoding(apiKey: _apiKey);

  static String get _apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  final GoogleMapsGeocoding _geocoding;

  Future<({double lat, double lng})?> geocodeAddress(String address) async {
    if (_apiKey.isEmpty || address.trim().isEmpty) {
      return null;
    }

    final response = await _geocoding.searchByAddress(address);
    if (response.results.isEmpty) {
      return null;
    }

    final location = response.results.first.geometry.location;
    return (lat: location.lat, lng: location.lng);
  }
}
