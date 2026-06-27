import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../data/datasources/location_remote_data_source.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../domain/usecases/get_current_location_usecase.dart';
import '../../domain/usecases/search_place_usecase.dart';

enum MapViewType { light, dark, satellite }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  bool _isLoading = false;
  LatLng _currentCenter = const LatLng(23.8103, 90.4125); // ঢাকা

  LatLng? _userCurrentLatLng;
  String _distanceResult = "";
  String _etaResult = "";
  String _currentAddressResult = "";

  MapViewType _currentMapType = MapViewType.light;

  late final GetCurrentLocationUseCase _getCurrentLocationUseCase;
  late final SearchPlaceUseCase _searchPlaceUseCase;

  final Map<MapViewType, String> _mapUrlTemplates = {
    MapViewType.light: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapViewType.dark:
        'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}{r}.png',
    MapViewType.satellite:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  };

  @override
  void initState() {
    super.initState();
    // 🌟 ১. অ্যাপ ওপেন হওয়ামাত্রই লোকেশন পারমিশন চাইবে
    _checkPermissionOnStartup();

    final dataSource = LocationRemoteDataSource();
    final repository = LocationRepositoryImpl(dataSource: dataSource);
    _getCurrentLocationUseCase = GetCurrentLocationUseCase(
      repository: repository,
    );
    _searchPlaceUseCase = SearchPlaceUseCase(repository: repository);
    _getSilentCurrentLocation();
  }

  /// 🌟 ২. স্টার্টআপে পারমিশন চেক ও রিকোয়েস্ট করার মেথড
  Future<void> _checkPermissionOnStartup() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar("Please enable Location Services/GPS.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar("Location permission denied. GPS features won't work.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar(
        "Location permission permanently denied. Please enable it from settings.",
      );
    }
  }

  Future<void> _getSilentCurrentLocation() async {
    try {
      Position position = await _getCurrentLocationUseCase.execute();
      _userCurrentLatLng = LatLng(position.latitude, position.longitude);
    } catch (_) {}
  }

  Future<void> _getRouteAndETA(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];

        final double durationInSeconds = data['routes'][0]['duration']
            .toDouble();
        final int durationInMinutes = (durationInSeconds / 60).round();

        List<LatLng> routeCoordinates = coordinates.map((coord) {
          return LatLng(coord[1], coord[0]);
        }).toList();

        setState(() {
          if (durationInMinutes >= 60) {
            int hours = durationInMinutes ~/ 60;
            int minutes = durationInMinutes % 60;
            _etaResult =
                "⏱️ Time: " +
                hours.toString() +
                "h " +
                minutes.toString() +
                "m (Drive)";
          } else {
            _etaResult =
                "⏱️ Time: " + durationInMinutes.toString() + " mins (Drive)";
          }

          _polylines = [
            Polyline(
              points: routeCoordinates,
              strokeWidth: 5.0,
              color: _currentMapType == MapViewType.dark
                  ? Colors.cyanAccent
                  : Colors.blueAccent,
            ),
          ];
        });
      }
    } catch (e) {
      _showSnackBar("Could not fetch route line.");
    }
  }

  Future<void> _handleLocationTracking() async {
    setState(() {
      _isLoading = true;
      _distanceResult = "";
      _currentAddressResult = "";
    });
    try {
      Position position = await _getCurrentLocationUseCase.execute();
      _userCurrentLatLng = LatLng(position.latitude, position.longitude);
      _mapController.move(_userCurrentLatLng!, 18.5);

      bool addressFound = false;

      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
        );

        final response = await http
            .get(
              url,
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
              },
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final address = data['address'];

          String road =
              address['road'] ??
              address['suburb'] ??
              address['village'] ??
              address['neighbourhood'] ??
              "";
          String upazila = address['county'] ?? address['city_district'] ?? "";
          String district = address['state_district'] ?? address['state'] ?? "";

          List<String> parts = [];
          if (road.isNotEmpty) parts.add(road);
          if (upazila.isNotEmpty) parts.add(upazila);
          if (district.isNotEmpty) parts.add(district);

          setState(() {
            if (parts.isNotEmpty) {
              _currentAddressResult = "🏠 " + parts.join(", ");
            } else {
              _currentAddressResult = "🏠 " + (data['display_name'] ?? "");
            }
          });
          if (_currentAddressResult.length > 5) addressFound = true;
        }
      } catch (_) {}

      if (!addressFound) {
        try {
          final backupUrl = Uri.parse(
            'https://geocode.maps.co/reverse?lat=${position.latitude}&lon=${position.longitude}',
          );
          final backupResponse = await http
              .get(backupUrl)
              .timeout(const Duration(seconds: 4));
          if (backupResponse.statusCode == 200) {
            final data = json.decode(backupResponse.body);
            setState(() {
              _currentAddressResult =
                  "🏠 " + (data['display_name'] ?? "Location Verified");
            });
            addressFound = true;
          }
        } catch (_) {}
      }

      if (!addressFound) {
        setState(() {
          _currentAddressResult =
              "📍 Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)} (Address Server Busy)";
        });
      }

      setState(() {
        _markers = [
          Marker(
            point: _userCurrentLatLng!,
            width: 80,
            height: 80,
            child: Icon(
              Icons.my_location_rounded,
              color: _currentMapType == MapViewType.dark
                  ? Colors.cyanAccent
                  : Colors.blueAccent,
              size: 40,
            ),
          ),
        ];
        _polylines.clear();
        _etaResult = "";
      });
    } catch (e) {
      _showSnackBar("GPS Error: Please enable location services.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSearch() async {
    if (_searchController.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _currentAddressResult = "";
    });
    FocusScope.of(context).unfocus();

    try {
      LatLng? searchedLatLng = await _searchPlaceUseCase.execute(
        _searchController.text,
      );
      if (searchedLatLng != null) {
        _mapController.move(searchedLatLng, 17.0);

        if (_userCurrentLatLng != null) {
          await _getRouteAndETA(_userCurrentLatLng!, searchedLatLng);

          double distanceInMeters = Geolocator.distanceBetween(
            _userCurrentLatLng!.latitude,
            _userCurrentLatLng!.longitude,
            searchedLatLng.latitude,
            searchedLatLng.longitude,
          );
          double distanceInKm = distanceInMeters / 1000;

          setState(() {
            _distanceResult =
                "📍 Distance: " + distanceInKm.toStringAsFixed(1) + " KM away";
            _markers = [
              Marker(
                point: _userCurrentLatLng!,
                width: 80,
                height: 80,
                child: Icon(
                  Icons.my_location_rounded,
                  color: _currentMapType == MapViewType.dark
                      ? Colors.cyanAccent
                      : Colors.blueAccent,
                  size: 35,
                ),
              ),
              Marker(
                point: searchedLatLng,
                width: 80,
                height: 80,
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.redAccent,
                  size: 45,
                ),
              ),
            ];
          });
        } else {
          await _getSilentCurrentLocation();
          _showSnackBar("Target marked. Enable GPS to see the route line.");
        }
      } else {
        _showSnackBar('Place not found! Try another name.');
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _mapUrlTemplates[_currentMapType]!,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.explore_ease.map_app_v2',
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),

          // গ্লাস-মরফিজম সার্চ বার
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: _currentMapType == MapViewType.dark
                        ? Colors.black.withOpacity(0.6)
                        : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: _currentMapType == MapViewType.dark
                            ? Colors.cyanAccent
                            : Colors.blueAccent,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: _currentMapType == MapViewType.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search for a route...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _handleSearch(),
                        ),
                      ),
                      IconButton(
                        icon: CircleAvatar(
                          backgroundColor: _currentMapType == MapViewType.dark
                              ? Colors.cyanAccent
                              : Colors.blueAccent,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: _currentMapType == MapViewType.dark
                                ? Colors.black
                                : Colors.white,
                            size: 20,
                          ),
                        ),
                        onPressed: _handleSearch,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ডান পাশের ম্যাপ টাইপ সুইচার বাটনসমূহ
          Positioned(
            top: 130,
            right: 20,
            child: Column(
              children: [
                _buildMapTypeButton(Icons.wb_sunny_rounded, MapViewType.light),
                const SizedBox(height: 10),
                _buildMapTypeButton(Icons.nightlight_round, MapViewType.dark),
                const SizedBox(height: 10),
                _buildMapTypeButton(
                  Icons.public_rounded,
                  MapViewType.satellite,
                ),
              ],
            ),
          ),

          // বর্তমান এক্সাক্ট ঠিকানা দেখানোর কার্ড
          if (_currentAddressResult.isNotEmpty)
            Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withOpacity(0.95),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.pin_drop_rounded,
                            color: Colors.cyanAccent,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "YOUR CURRENT LOCATION",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentAddressResult,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ডিস্ট্যান্স এবং ETA দেখানোর কার্ড
          if (_distanceResult.isNotEmpty)
            Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withOpacity(0.95),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.alt_route_rounded,
                            color: Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "ROUTE TO " +
                                    _searchController.text.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _distanceResult,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_etaResult.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _etaResult,
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: _currentMapType == MapViewType.dark
                    ? Colors.cyanAccent
                    : Colors.blueAccent,
              ),
            ),

          // স্ট্যান্ডার্ড সাইজ জিপিএস লোকেশন বাটন
          Positioned(
            bottom: 30,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        (_currentMapType == MapViewType.dark
                                ? Colors.cyanAccent
                                : Colors.blueAccent)
                            .withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _handleLocationTracking,
                backgroundColor: _currentMapType == MapViewType.dark
                    ? Colors.cyanAccent
                    : Colors.blueAccent,
                shape: const CircleBorder(),
                child: Icon(
                  Icons.gps_fixed_rounded,
                  color: _currentMapType == MapViewType.dark
                      ? Colors.black
                      : Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTypeButton(IconData icon, MapViewType type) {
    bool isSelected = _currentMapType == type;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10),
        ],
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: isSelected
            ? (_currentMapType == MapViewType.dark
                  ? Colors.cyanAccent
                  : Colors.blueAccent)
            : Colors.white,
        child: IconButton(
          icon: Icon(
            icon,
            color: isSelected
                ? (_currentMapType == MapViewType.dark
                      ? Colors.black
                      : Colors.white)
                : Colors.grey.shade800,
            size: 22,
          ),
          onPressed: () {
            setState(() {
              _currentMapType = type;
              if (_polylines.isNotEmpty &&
                  _userCurrentLatLng != null &&
                  _markers.length > 1) {
                _polylines[0] = Polyline(
                  points: _polylines[0].points,
                  strokeWidth: 5.0,
                  color: _currentMapType == MapViewType.dark
                      ? Colors.cyanAccent
                      : Colors.blueAccent,
                );
              }
            });
          },
        ),
      ),
    );
  }
}
