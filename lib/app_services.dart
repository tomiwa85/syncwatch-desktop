import 'api.dart';
import 'room_sync.dart';

/// Shared singletons passed down through the screens.
class AppServices {
  final AuthStore auth;
  final ApiClient api;
  final SocketService socket;
  AppServices(this.auth, this.api, this.socket);

  factory AppServices.create() {
    final auth = AuthStore();
    return AppServices(auth, ApiClient(auth), SocketService());
  }
}
