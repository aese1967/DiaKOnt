/// Configuración de entorno de DiaKont.
///
/// No hay servidor propio: los datos de cada usuario viven en SU Google Drive
/// (carpeta oculta de la app) o en SU OneDrive (carpeta de la app). Solo hace
/// falta registrar la app UNA vez en Google Cloud y en Microsoft Entra (Azure)
/// para obtener los "client id" públicos (ver docs/CONFIGURAR_OAUTH.md).
///
/// Los valores se inyectan al compilar con
///   flutter run --dart-define-from-file=env.json
/// (ver `env.example.json`). Ninguno es secreto en el sentido estricto: las
/// apps instaladas son "clientes públicos" y se protegen con PKCE.
class Env {
  Env._();

  /// Cliente OAuth de Google tipo "Aplicación web". En Android se pasa como
  /// `serverClientId` a Google Sign-In (requisito de Credential Manager).
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Cliente OAuth de Google tipo "App de escritorio" (para Windows).
  static const googleDesktopClientId = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_ID',
  );

  /// Google entrega un "client secret" también para apps de escritorio y lo
  /// exige al canjear el código; su propia documentación aclara que en apps
  /// instaladas NO se considera secreto.
  static const googleDesktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
  );

  /// "Application (client) ID" de la app registrada en Microsoft Entra.
  static const microsoftClientId = String.fromEnvironment(
    'MICROSOFT_CLIENT_ID',
  );

  /// Esquema de retorno del login de Microsoft en Android. Debe coincidir con
  /// AndroidManifest.xml y con la Redirect URI registrada en Azure.
  static const microsoftAndroidRedirectScheme = 'msauth.io.southdevs.diakont';
  static const microsoftAndroidRedirectUri =
      '$microsoftAndroidRedirectScheme://auth';

  static bool get hasGoogle =>
      googleWebClientId.isNotEmpty || googleDesktopClientId.isNotEmpty;
  static bool get hasMicrosoft => microsoftClientId.isNotEmpty;
  static bool get isConfigured => hasGoogle || hasMicrosoft;
}
