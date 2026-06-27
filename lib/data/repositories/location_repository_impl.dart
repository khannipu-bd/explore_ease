import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_remote_data_source.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationRemoteDataSource dataSource;
  LocationRepositoryImpl({required this.dataSource});

  @override
  Future<Position> getUserCurrentLocation() async {
    return await dataSource.getRawLocation();
  }

  @override
  Future<LatLng?> searchPlace(String query) async {
    return await dataSource.searchLocationByName(query);
  }
}
