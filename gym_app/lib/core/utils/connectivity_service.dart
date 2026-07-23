import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Serviço de monitorização de conectividade.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  Stream<bool> get onConnectivityChanged => _controller.stream;

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((result) => result != ConnectivityResult.none);
      _controller.add(isConnected);
    });
  }

  /// Verifica se o dispositivo está atualmente ligado à internet.
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// Fecha o stream quando não for mais necessário.
  void dispose() {
    _controller.close();
  }
}
