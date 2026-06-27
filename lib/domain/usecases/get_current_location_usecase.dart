import 'package:geolocator/geolocator.dart';
import '../repositories/location_repository.dart';

class GetCurrentLocationUseCase {
  final LocationRepository repository;

  GetCurrentLocationUseCase({required this.repository});

  Future<Position> execute() async {
    return await repository.getUserCurrentLocation();
  }
}
