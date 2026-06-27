import 'package:latlong2/latlong.dart';

import '../repositories/location_repository.dart';

class SearchPlaceUseCase {
  final LocationRepository repository;

  SearchPlaceUseCase({required this.repository});

  Future<LatLng?> execute(String query) async {
    if (query.isEmpty) return null;
    return await repository.searchPlace(query);
  }
}
