class AppConfig {
  // For physical device development via USB: use adb reverse to map
  //   adb reverse tcp:5000 tcp:5000
  // Then this localhost will point to your PC's port 5000.
  static const String baseUrl = 'https://pertinaciously-ketogenetic-jaqueline.ngrok-free.dev';

  // Optional: backend table/collection name for login
  static String loginTable = 'users';
}
