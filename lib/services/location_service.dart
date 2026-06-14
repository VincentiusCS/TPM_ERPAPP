import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';

import 'geocoding_service.dart';

/// LocationService mengelola validasi lokasi GPS menggunakan geolocator dan Haversine.
class LocationService {
  //kampus 2
  // static const double referenceLatitude = -7.7788;
  // static const double referenceLongitude = 110.4103;
  //Kontrakan
  static const double referenceLatitude = -7.7550938;
  static const double referenceLongitude = 110.4057171;
  static const double toleranceRadiusMeters = 100.0;
  static const Duration gpsTimeout = Duration(seconds: 15);

  /// Radius bumi dalam meter untuk formula Haversine.
  static const double _earthRadiusMeters = 6371000.0;

  final GeolocatorPlatform _geolocator;

  LocationService({GeolocatorPlatform? geolocator})
    : _geolocator = geolocator ?? GeolocatorPlatform.instance;

  /// Memeriksa apakah layanan lokasi aktif dan izin diberikan.
  /// Returns: (isReady, errorMessage?, isPermanentlyDenied)
  Future<({bool isReady, String? errorMessage, bool isPermanentlyDenied})>
  checkLocationPermission() async {
    // Cek apakah layanan GPS aktif
    final serviceEnabled = await _geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return (
        isReady: false,
        errorMessage: 'Aktifkan GPS untuk melanjutkan',
        isPermanentlyDenied: false,
      );
    }

    // Cek status izin lokasi
    var permission = await _geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Minta izin lokasi
      permission = await _geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        return (
          isReady: false,
          errorMessage: 'Izin akses lokasi diperlukan untuk login',
          isPermanentlyDenied: false,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return (
        isReady: false,
        errorMessage: 'Aktifkan izin lokasi di pengaturan aplikasi',
        isPermanentlyDenied: true,
      );
    }

    return (isReady: true, errorMessage: null, isPermanentlyDenied: false);
  }

  /// Mengambil koordinat GPS dan memvalidasi jarak ke titik referensi.
  /// Returns: (isWithinRadius, distanceMeters, errorMessage?, address?)
  Future<
    ({
      bool isWithinRadius,
      double? distanceMeters,
      String? errorMessage,
      String? address,
    })
  >
  validateLocation() async {
    // Cek izin terlebih dahulu
    final permissionResult = await checkLocationPermission();
    if (!permissionResult.isReady) {
      return (
        isWithinRadius: false,
        distanceMeters: null,
        errorMessage: permissionResult.errorMessage,
        address: null,
      );
    }

    // Ambil koordinat GPS — coba last known dulu (instan), lalu getCurrentPosition dengan timeout
    try {
      Position? position;

      // Coba ambil posisi terakhir yang diketahui (sangat cepat, bisa null)
      position = await _geolocator.getLastKnownPosition();

      // Jika tidak ada last known, ambil posisi baru dengan timeout ketat
      if (position == null) {
        position = await _geolocator
            .getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
              ),
            )
            .timeout(gpsTimeout);
      }

      // Hitung jarak menggunakan Haversine
      final distance = calculateHaversineDistance(
        position.latitude,
        position.longitude,
        referenceLatitude,
        referenceLongitude,
      );

      // Reverse geocode untuk mendapatkan nama alamat (non-blocking)
      final address = await GeocodingService.getShortAddress(
        position.latitude,
        position.longitude,
      );

      if (distance <= toleranceRadiusMeters) {
        return (
          isWithinRadius: true,
          distanceMeters: distance,
          errorMessage: null,
          address: address,
        );
      } else {
        return (
          isWithinRadius: false,
          distanceMeters: distance,
          errorMessage: 'Anda berada di luar area yang diizinkan',
          address: address,
        );
      }
    } on TimeoutException {
      return (
        isWithinRadius: false,
        distanceMeters: null,
        errorMessage: 'Gagal mendapatkan lokasi, coba lagi',
        address: null,
      );
    } catch (e) {
      return (
        isWithinRadius: false,
        distanceMeters: null,
        errorMessage: 'Gagal mendapatkan lokasi, coba lagi',
        address: null,
      );
    }
  }

  /// Menghitung jarak antara dua titik koordinat menggunakan formula Haversine.
  /// Returns: jarak dalam meter
  ///
  /// Formula: 2 * R * arcsin(sqrt(sin²((lat2-lat1)/2) + cos(lat1) * cos(lat2) * sin²((lon2-lon1)/2)))
  /// di mana R = 6371000 meter
  double calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final lat1Rad = lat1 * pi / 180.0;
    final lat2Rad = lat2 * pi / 180.0;
    final dLatRad = (lat2 - lat1) * pi / 180.0;
    final dLonRad = (lon2 - lon1) * pi / 180.0;

    final a =
        sin(dLatRad / 2) * sin(dLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLonRad / 2) * sin(dLonRad / 2);

    final c = 2 * asin(sqrt(a));

    return _earthRadiusMeters * c;
  }
}
