import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkStatusService {
  static final NetworkStatusService _instance = NetworkStatusService._internal();
  factory NetworkStatusService() => _instance;

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  // Stream para que otros escuchen cambios de conexión
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _connectivity.onConnectivityChanged;

  NetworkStatusService._internal() {
    _init();
  }

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
      
      _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
        _updateStatus(results);
      });
    } catch (e) {
      debugPrint("Error inicializando conectividad: $e");
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      _isOnline = false;
      debugPrint("Red: OFFLINE");
    } else {
      _isOnline = true;
      debugPrint("Red: ONLINE");
    }
  }
  
  Future<bool> checkConnectionNow() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
    return _isOnline;
  }
}
