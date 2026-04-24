import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

@riverpod
class ConnectivityNotifier extends _$ConnectivityNotifier {
  @override
  Stream<List<ConnectivityResult>> build() {
    return Connectivity().onConnectivityChanged;
  }

  bool isConnected(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );
  }
}
