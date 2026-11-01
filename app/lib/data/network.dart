import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone is on mobile data, for the "Download on Wi-Fi only" setting.
abstract class NetworkInfo {
  /// True when the only connection is mobile data (metered).
  Future<bool> onMobileData();
}

/// Used in tests and where the connection type is unknown: never blocks.
class UnknownNetwork implements NetworkInfo {
  const UnknownNetwork();
  @override
  Future<bool> onMobileData() async => false;
}

class ConnectivityNetwork implements NetworkInfo {
  final _connectivity = Connectivity();

  @override
  Future<bool> onMobileData() async {
    final types = await _connectivity.checkConnectivity();
    final unmetered = types.any(
      (t) => t == ConnectivityResult.wifi || t == ConnectivityResult.ethernet || t == ConnectivityResult.vpn,
    );
    return types.contains(ConnectivityResult.mobile) && !unmetered;
  }
}

/// True when downloads should wait for Wi-Fi.
Future<bool> mustWaitForWifi(NetworkInfo network, {required bool wifiOnly}) async =>
    wifiOnly && await network.onMobileData();
