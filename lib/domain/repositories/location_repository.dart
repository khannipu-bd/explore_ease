import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

abstract class LocationRepository {
  Future<Position> getUserCurrentLocation(); // আগের কোড

  Future<LatLng?> searchPlace(String query);
}
