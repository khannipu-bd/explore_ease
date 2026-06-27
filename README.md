# Explore Ease 🗺️

**Explore Ease** is a modern Flutter-based map and navigation application that leverages clean architecture principles to provide precise real-time location tracking, address reverse-geocoding, and routing services.

---

## 🚀 Features

* **Real-time Live Location:** View your exact, pinpoint location on the map with a customized smooth pulse marker.
* **Exact Address Reverse-Geocoding:** Pressing the location button instantly displays the readable current address (Road, Upazila, District) in a premium floating glassmorphic card.
* **Smart Route & ETA Search:** Search for any destination to draw exact route lines via OSRM API, alongside automatic distance and driving ETA calculation.
* **Multi-Layer Map Switching:** Seamlessly switch between **Light Mode**, **Dark Mode**, and **Satellite View** styles.
* **On-Startup Permission Handlers:** Automatically requests runtime precise location permissions the moment the app opens for a hassle-free user experience.

---

## 🛠️ Architecture & Tech Stack

The project strictly follows **Clean Architecture** to ensure maintainability, scalability, and loose coupling between components:

* **Presentation Layer:** Managed using Flutter State Management (`StatefulWidget`), Custom Floating Action Buttons, and Glassmorphic Stack layout.
* **Domain Layer:** Business logic separated neatly into dedicated UseCases (`GetCurrentLocationUseCase`, `SearchPlaceUseCase`).
* **Data Layer:** Handles remote APIs (`OSRM Routing API`, `Nominatim Reverse-Geocoding API`) through clean repository implementations.

### Main Libraries Used:
* `flutter_map` - Highly flexible OpenStreetMap (OSM) viewer.
* `geolocator` - High-accuracy GPS tracking and live hardware permission handler.
* `http` - Clean networking for route data transmission.
* `latlong2` - Coordinate geometry management.

---

## ⚙️ Setup and Installation

Follow these quick steps to get the project running locally on your machine or real device:

### Prerequisites:
Make sure you have Flutter SDK installed (`v3.x` or later suggested). Check your setup using:
```bash
flutter doctor