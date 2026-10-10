/// Public build settings only. Server credentials never belong in client builds.
final class ClientConfiguration {
  static Uri backendOrigin(String value) {
    final uri = Uri.tryParse(value);
    if (value.trim().isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host.endsWith('.internal') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw Exception(
          "ClientConfigurationException from backendOrigin, value: $value");
    }
    return uri;
  }

  static String googleServerClientId(String projectId, {String supplied = ''}) {
    if (supplied.trim().isNotEmpty) return supplied.trim();
    return switch (projectId) {
      'sarisupply-dev-aracena18' =>
        '594903185972-1dlngb8a6i0j6i87ss6nbaab2u1krdqg.apps.googleusercontent.com',
      'sarisupply-prod-aracena18' =>
        '110781011916-88507t6k0glkskp51460qa6bcm6oti8b.apps.googleusercontent.com',
      _ => throw Exception(
          "ClientConfigurationException from googleServerClientId, projectId: $projectId"),
    };
  }
}

final class ClientConfigurationException implements Exception {
  const ClientConfigurationException();
  @override
  String toString() => 'Application setup is incomplete.';
}
