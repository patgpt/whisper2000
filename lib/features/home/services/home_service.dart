import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_service.g.dart';

@riverpod
HomeService homeService(HomeServiceRef ref) {
  return HomeService();
}

/// Service layer for the Home feature.
/// Potentially manages analytics, session configuration, or specific business logic.
class HomeService {
  Future<void> trackModeSelection(String mode) async {
    // TODO: Implement analytics tracking (e.g., Firebase Analytics)
    print('Analytics: Mode selected - $mode');
  }

  Future<void> configureListeningSession(/* config params */) async {
    // TODO: Configure parameters before starting a listening session
    print('Configuring listening session...');
  }
}
