import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import 'oauth_pkce.dart';

enum CloudProvider {
  google('Google Drive'),
  microsoft('OneDrive');

  const CloudProvider(this.storageName);

  /// Nombre de la nube donde se guardan los datos.
  final String storageName;
}

/// Cuenta con la que el usuario inició sesión. Es a la vez su identidad y
/// su almacenamiento: los datos se guardan en el Drive/OneDrive de esa cuenta.
class CloudAccount {
  const CloudAccount({
    required this.provider,
    required this.id,
    required this.email,
    this.name,
  });

  final CloudProvider provider;

  /// Identificador estable de la cuenta (sub de Google / id de Microsoft).
  final String id;
  final String email;
  final String? name;

  /// Clave única local: separa la base SQLite de cada cuenta.
  String get key =>
      '${provider.name}_${id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}';

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'id': id,
    'email': email,
    'name': name,
  };

  factory CloudAccount.fromJson(Map<String, dynamic> j) => CloudAccount(
    provider: CloudProvider.values.byName(j['provider'] as String),
    id: j['id'] as String,
    email: j['email'] as String,
    name: j['name'] as String?,
  );
}

/// Inicio de sesión con Google o Microsoft, sin servidor propio.
///
/// | Plataforma | Google                                   | Microsoft                   |
/// |------------|------------------------------------------|-----------------------------|
/// | Android    | Google Sign-In nativo (Credential Manager)| PKCE + Custom Tab           |
/// | Windows    | PKCE + navegador + loopback localhost    | PKCE + navegador + loopback |
///
/// La cuenta queda guardada en el almacenamiento seguro del sistema
/// (Keystore en Android, DPAPI en Windows), por lo que la app abre y funciona
/// sin conexión. El token de acceso se pide recién al sincronizar.
class AuthService {
  AuthService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _kAccount = 'dk.account';
  static const _kRefresh = 'dk.refresh_token';

  // Permisos mínimos: solo la carpeta privada de la app, nunca los archivos
  // del usuario.
  static const googleDriveScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const _googleScopes = ['openid', 'email', 'profile', googleDriveScope];
  static const _microsoftScopes = [
    'openid',
    'profile',
    'offline_access',
    'User.Read',
    'Files.ReadWrite.AppFolder',
  ];

  static OAuthConfig get _googleDesktop => const OAuthConfig(
    authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenEndpoint: 'https://oauth2.googleapis.com/token',
    clientId: Env.googleDesktopClientId,
    clientSecret: Env.googleDesktopClientSecret,
    scopes: _googleScopes,
    // offline + consent para recibir refresh token.
    extraAuthParams: {'access_type': 'offline', 'prompt': 'consent'},
  );

  static OAuthConfig get _microsoft => const OAuthConfig(
    // "common" admite cuentas personales (Outlook/Hotmail) y de trabajo.
    authorizationEndpoint:
        'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
    tokenEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
    clientId: Env.microsoftClientId,
    scopes: _microsoftScopes,
    mobileRedirectUri: Env.microsoftAndroidRedirectUri,
    mobileCallbackScheme: Env.microsoftAndroidRedirectScheme,
    extraAuthParams: {'prompt': 'select_account'},
  );

  final _ctrl = StreamController<CloudAccount?>.broadcast();
  CloudAccount? _account;
  OAuthTokens? _tokens;
  bool _googleInitialized = false;

  CloudAccount? get account => _account;

  Stream<CloudAccount?> watch() async* {
    yield _account;
    yield* _ctrl.stream;
  }

  bool get _useNativeGoogle => Platform.isAndroid || Platform.isIOS;

  /// Recupera la cuenta guardada (sin red). Se llama al arrancar la app.
  Future<void> restore() async {
    final raw = await _storage.read(key: _kAccount);
    if (raw == null) return;
    _account = CloudAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _ctrl.add(_account);
  }

  Future<void> _initGoogle() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: Env.googleWebClientId,
    );
    _googleInitialized = true;
  }

  // ------------------------------------------------------------ Google
  Future<void> signInWithGoogle() async {
    if (_useNativeGoogle) {
      await _initGoogle();
      try {
        final user = await GoogleSignIn.instance.authenticate(
          scopeHint: _googleScopes,
        );
        // Pide (una vez) el permiso de la carpeta de la app en Drive.
        final authz = await user.authorizationClient.authorizeScopes(const [
          googleDriveScope,
        ]);
        _tokens = OAuthTokens(
          accessToken: authz.accessToken,
          expiresAt: DateTime.now().add(const Duration(minutes: 50)),
        );
        await _setAccount(
          CloudAccount(
            provider: CloudProvider.google,
            id: user.id,
            email: user.email,
            name: user.displayName,
          ),
        );
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          throw const AuthFailure('Inicio de sesión cancelado.');
        }
        throw AuthFailure('Google: ${e.description ?? e.code.name}');
      }
      return;
    }

    final tokens = await PkceOAuth.authorize(_googleDesktop);
    AuthLog.mark('Leyendo los datos de la cuenta de Google');
    final claims = OAuthTokens.decodeJwtPayload(tokens.idToken ?? '');
    final sub = claims['sub'] as String?;
    if (sub == null) {
      throw const AuthFailure('Google no devolvió los datos de la cuenta.');
    }
    _tokens = tokens;
    await _save(_kRefresh, tokens.refreshToken);
    await _setAccount(
      CloudAccount(
        provider: CloudProvider.google,
        id: sub,
        email: (claims['email'] as String?) ?? '',
        name: claims['name'] as String?,
      ),
    );
    AuthLog.mark('Sesión iniciada');
  }

  /// Guarda en el almacenamiento seguro sin poder trabar el login: si el
  /// almacén no responde, la sesión sigue en memoria (habrá que volver a
  /// entrar la próxima vez) y queda registrado.
  Future<void> _save(String key, String? value) async {
    AuthLog.mark('Guardando la sesión en el equipo ($key)');
    try {
      await _storage
          .write(key: key, value: value)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      AuthLog.error(e);
    }
  }

  // ------------------------------------------------------------ Microsoft
  Future<void> signInWithMicrosoft() async {
    final tokens = await PkceOAuth.authorize(_microsoft);
    final me = await http.get(
      Uri.parse(
        'https://graph.microsoft.com/v1.0/me?\$select=id,displayName,mail,userPrincipalName',
      ),
      headers: {'Authorization': 'Bearer ${tokens.accessToken}'},
    );
    if (me.statusCode != 200) {
      throw const AuthFailure('No se pudo leer el perfil de Microsoft.');
    }
    final j = jsonDecode(me.body) as Map<String, dynamic>;
    _tokens = tokens;
    await _save(_kRefresh, tokens.refreshToken);
    await _setAccount(
      CloudAccount(
        provider: CloudProvider.microsoft,
        id: j['id'] as String,
        email:
            (j['mail'] as String?) ?? (j['userPrincipalName'] as String? ?? ''),
        name: j['displayName'] as String?,
      ),
    );
  }

  /// Token de acceso vigente para Drive/OneDrive (lo renueva si venció).
  /// Lanza [AuthFailure] si hay que volver a iniciar sesión.
  Future<String> accessToken({bool forceRefresh = false}) async {
    final acc = _account;
    if (acc == null) throw const AuthFailure('Sin sesión.');
    if (!forceRefresh && _tokens != null && !_tokens!.isExpired) {
      return _tokens!.accessToken;
    }

    if (acc.provider == CloudProvider.google && _useNativeGoogle) {
      await _initGoogle();
      // Silencioso: no muestra pantallas durante la sincronización.
      final authz = await GoogleSignIn.instance.authorizationClient
          .authorizationForScopes(const [googleDriveScope]);
      if (authz == null) {
        throw const AuthFailure(
          'Volvé a iniciar sesión con Google para sincronizar.',
        );
      }
      _tokens = OAuthTokens(
        accessToken: authz.accessToken,
        expiresAt: DateTime.now().add(const Duration(minutes: 50)),
      );
      return authz.accessToken;
    }

    final refresh = await _storage.read(key: _kRefresh);
    if (refresh == null) throw const AuthFailure('Volvé a iniciar sesión.');
    final cfg = acc.provider == CloudProvider.google
        ? _googleDesktop
        : _microsoft;
    final tokens = await PkceOAuth.refresh(cfg, refresh);
    _tokens = tokens;
    if (tokens.refreshToken != null && tokens.refreshToken != refresh) {
      await _storage.write(key: _kRefresh, value: tokens.refreshToken);
    }
    return tokens.accessToken;
  }

  Future<void> signOut() async {
    if (_account?.provider == CloudProvider.google && _useNativeGoogle) {
      try {
        await _initGoogle();
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        /* sin red: igual se cierra localmente */
      }
    }
    _tokens = null;
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kAccount);
    _account = null;
    _ctrl.add(null);
  }

  Future<void> _setAccount(CloudAccount a) async {
    await _save(_kAccount, jsonEncode(a.toJson()));
    _account = a;
    _ctrl.add(a);
  }
}
