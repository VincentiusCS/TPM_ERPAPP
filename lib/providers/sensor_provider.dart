import 'package:flutter/foundation.dart';

import '../utils/sensor_util.dart';

/// SensorProvider manages the state of accelerometer-based screen rotation.
class SensorProvider extends ChangeNotifier {
  final SensorUtil _sensorUtil;

  bool _isActive = false;
  AppOrientation _currentOrientation = AppOrientation.portrait;
  bool _isSensorAvailable = true;

  SensorProvider({SensorUtil? sensorUtil})
      : _sensorUtil = sensorUtil ?? SensorUtil() {
    _sensorUtil.onOrientationChanged = _onOrientationChanged;
  }

  bool get isActive => _isActive;
  AppOrientation get currentOrientation => _currentOrientation;
  bool get isSensorAvailable => _isSensorAvailable;

  void startListening() {
    if (_isActive) return;

    _sensorUtil.startListening();

    if (!_sensorUtil.isSensorAvailable) {
      _isSensorAvailable = false;
      _isActive = false;
      notifyListeners();
      return;
    }

    _isActive = true;
    _isSensorAvailable = true;
    notifyListeners();
  }

  void stopListening() {
    if (!_isActive) return;

    _sensorUtil.stopListening();
    _isActive = false;
    notifyListeners();
  }

  void _onOrientationChanged(AppOrientation orientation) {
    if (orientation != _currentOrientation) {
      _currentOrientation = orientation;
      notifyListeners();
    }

    if (!_sensorUtil.isSensorAvailable) {
      _isSensorAvailable = false;
      _isActive = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sensorUtil.dispose();
    super.dispose();
  }
}
