import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String baseUrl = "https://elearningapp-lgx3.onrender.com/";

  static const int apiTimeoutSeconds = 15;

  static const int searchDebounceMs = 600;

  static String get clientId => dotenv.env['CLIENT_ID'] ?? '';
  static String get clientSecret => dotenv.env['CLIENT_SECRET'] ?? '';
}
