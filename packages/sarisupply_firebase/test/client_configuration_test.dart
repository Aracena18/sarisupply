import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

void main() {
  test('rejects absent, placeholder, and unsafe backend settings', () {
    for (final value in [
      '',
      'https://dev-api.sarisupply.internal',
      'http://api.example.com',
      'https://user:secret@api.example.com',
      'https://api.example.com/path',
      'https://api.example.com?secret=x'
    ]) {
      expect(() => ClientConfiguration.backendOrigin(value),
          throwsA(isA<ClientConfigurationException>()));
    }
    expect(ClientConfiguration.backendOrigin('https://api.example.com').host,
        'api.example.com');
  });
  test('resolves registered Android OAuth client for each Firebase environment',
      () {
    expect(ClientConfiguration.googleServerClientId('sarisupply-dev-aracena18'),
        startsWith('594903185972-'));
    expect(
        ClientConfiguration.googleServerClientId('sarisupply-prod-aracena18'),
        startsWith('110781011916-'));
    expect(() => ClientConfiguration.googleServerClientId('other-project'),
        throwsA(isA<ClientConfigurationException>()));
  });
}
