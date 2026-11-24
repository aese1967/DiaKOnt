import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diakont/data/auth/oauth_pkce.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simula al navegador volviendo al servidor local (loopback) de Windows.
Future<(int, String)> _get(int port, String pathAndQuery) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port$pathAndQuery'),
    );
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    return (res.statusCode, body);
  } finally {
    client.close(force: true);
  }
}

void main() {
  test('recibe el código, responde la página y termina sin trabarse', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final wait = PkceOAuth.waitForLoopbackCallback(
      server,
      timeout: const Duration(seconds: 10),
    );
    // El navegador suele pedir antes el favicon.
    final favicon = await _get(server.port, '/favicon.ico');
    expect(favicon.$1, HttpStatus.noContent);

    final page = await _get(server.port, '/?code=abc123&state=xyz');
    expect(page.$1, 200);
    expect(page.$2, contains('Listo'));

    final uri = await wait.timeout(const Duration(seconds: 10));
    expect(uri.queryParameters['code'], 'abc123');
    expect(uri.queryParameters['state'], 'xyz');
    await server.close(force: true);
  });

  test('devuelve el error que manda el proveedor', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final wait = PkceOAuth.waitForLoopbackCallback(
      server,
      timeout: const Duration(seconds: 10),
    );
    final page = await _get(server.port, '/?error=access_denied');
    expect(page.$2, contains('No se pudo'));
    final uri = await wait.timeout(const Duration(seconds: 10));
    expect(uri.queryParameters['error'], 'access_denied');
    await server.close(force: true);
  });

  test('Cancelar corta la espera con un error claro', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final cancel = Completer<void>();
    final wait = PkceOAuth.waitForLoopbackCallback(
      server,
      cancel: cancel.future,
      timeout: const Duration(seconds: 10),
    );
    cancel.complete();
    await expectLater(
      wait.timeout(const Duration(seconds: 5)),
      throwsA(isA<AuthFailure>()),
    );
    await server.close(force: true);
  });

  test('si el navegador nunca vuelve, se agota el tiempo', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    await expectLater(
      PkceOAuth.waitForLoopbackCallback(
        server,
        timeout: const Duration(milliseconds: 300),
      ).timeout(const Duration(seconds: 5)),
      throwsA(isA<TimeoutException>()),
    );
    await server.close(force: true);
  });
}
