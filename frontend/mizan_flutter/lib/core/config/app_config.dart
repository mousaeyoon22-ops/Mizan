class AppConfig {
  /// Base HTTPS URL pointing to Nginx TLS 1.3 reverse proxy in front of Mizan .NET 8 API.
  static const String apiBaseUrl = String.fromEnvironment(
    'MIZAN_API_BASE_URL',
    defaultValue: 'https://api.mizan.local',
  );

  static const String signalRHubUrl = '$apiBaseUrl/hubs/mizan';
  static const int perishableDisputeWindowMinutes = 30;
  static const int standardDisputeWindowMinutes = 1440;
  static const int blindRatingRevealDays = 7;
}
