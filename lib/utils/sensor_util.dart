import 'dart:async';

import 'package:flutter/services.dart' as flutter;
import 'package:sensors_plus/sensors_plus.dart';

/// Enum representing device orientation detected from accelerometer data.
enum AppOrientation {
  portrait,
  landscape,
}

/// SensorUtil subscribes to accelerometerEventStream() from sensors_plus
/// and detects device orientation based on accelerometer axes.
///
/// Orientation logic:
/// - If |x| > |y| → landscape
/// - If |y| > |x| → portrait
///
/// Uses Flutter's SystemChrome to change screen orientation.
class SensorUtil {
  StreamSubscription<AccelerometerEvent>? _subscription;
  AppOrientation _currentOrientation = AppOrientation.portrait;
  bool _isSensorAvailable = true;

  /// Current detected orientation.
  AppOrientation get currentOrientation => _currentOrientation;

  /// Whether the accelerometer sensor is available on this device.
  bool get isSensorAvailable => _isSensorAvailable;

  /// Callback invoked when orientation changes.
  void Function(AppOrientation orientation)? onOrientationChanged;

  /// Start listening to accelerometer events and detecting orientation.
  void startListening() {
    try {
      _subscription = accelerometerEventStream().listen(
        _handleAccelerometerEvent,
        onError: (error) {
          _isSensorAvailable = false;
          _subscription?.cancel();
          _subscription = null;
        },
      );
    } on flutter.PlatformException {
      _isSensorAvailable = false;
    } catch (_) {
      _isSensorAvailable = false;
    }
  }

  /// Stop listening to accelerometer events.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Handle incoming accelerometer event and determine orientation.
  void _handleAccelerometerEvent(AccelerometerEvent event) {
    final double x = event.x.abs();
    final double y = event.y.abs();

    AppOrientation newOrientation;

    if (x > y) {
      newOrientation = AppOrientation.landscape;
    } else {
      newOrientation = AppOrientation.portrait;
    }

    if (newOrientation != _currentOrientation) {
      _currentOrientation = newOrientation;
      _applyOrientation(newOrientation);
      onOrientationChanged?.call(newOrientation);
    }
  }

  /// Apply the detected orientation using Flutter's SystemChrome.
  void _applyOrientation(AppOrientation orientation) {
    if (orientation == AppOrientation.landscape) {
      flutter.SystemChrome.setPreferredOrientations([
        flutter.DeviceOrientation.landscapeLeft,
        flutter.DeviceOrientation.landscapeRight,
      ]);
    } else {
      flutter.SystemChrome.setPreferredOrientations([
        flutter.DeviceOrientation.portraitUp,
        flutter.DeviceOrientation.portraitDown,
      ]);
    }
  }

  /// Dispose resources and reset orientation to allow all.
  void dispose() {
    stopListening();
    flutter.SystemChrome.setPreferredOrientations([]);
  }
}
