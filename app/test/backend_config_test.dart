import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/services/backend_config.dart';

void main() {
  test('Google sign-in uses the production Web OAuth client by default', () {
    expect(
      BackendConfig.googleServerClientId,
      '729072124482-a5mn4a6alj6ielikioqrjgfp1v1mvg66.apps.googleusercontent.com',
    );
    expect(BackendConfig.hasGoogleSignIn, isTrue);
  });
}
