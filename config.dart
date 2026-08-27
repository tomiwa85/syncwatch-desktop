/// Single seam for the backend location — the same deployed server the mobile
/// app talks to, so desktop and mobile share rooms.
class Config {
  static const String backendUrl = 'https://syncwatch-server-szu2.onrender.com';

  static String get apiBaseUrl => backendUrl;
  static String get socketUrl => backendUrl;
}
