"""Genera env.json a partir de los secretos del repositorio (CI).

Limpia espacios y saltos de línea que suelen colarse al pegar un secreto en
GitHub y corta la compilación si un valor tiene una forma imposible (por
ejemplo, el "secreto del cliente" GOCSPX-... pegado en el campo del "ID de
cliente"). Así nunca se publica una versión con el login roto.

No imprime los valores: solo dice qué campo está mal.
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

KEYS = [
    "GOOGLE_WEB_CLIENT_ID",
    "GOOGLE_DESKTOP_CLIENT_ID",
    "GOOGLE_DESKTOP_CLIENT_SECRET",
    "MICROSOFT_CLIENT_ID",
]

GOOGLE_ID = re.compile(r"^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$")
CHECKS = {
    "GOOGLE_WEB_CLIENT_ID": (
        GOOGLE_ID,
        "debe ser el 'ID de cliente' del cliente tipo 'Aplicación web' "
        "(termina en .apps.googleusercontent.com)",
    ),
    "GOOGLE_DESKTOP_CLIENT_ID": (
        GOOGLE_ID,
        "debe ser el 'ID de cliente' del cliente tipo 'App de escritorio' "
        "(termina en .apps.googleusercontent.com, NO el que empieza con GOCSPX-)",
    ),
    "GOOGLE_DESKTOP_CLIENT_SECRET": (
        re.compile(r"^GOCSPX-[A-Za-z0-9_-]+$"),
        "debe ser el 'Secreto del cliente' del cliente 'App de escritorio' "
        "(empieza con GOCSPX-)",
    ),
    "MICROSOFT_CLIENT_ID": (
        re.compile(r"^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"),
        "debe ser el 'Id. de aplicación (cliente)' de Microsoft Entra",
    ),
}


def check_google_desktop_pair(client_id: str, secret: str) -> str | None:
    """Pregunta a Google si el par ID + secreto existe, con un código falso.

    Con el par correcto Google responde `invalid_grant` (el código es falso);
    con un secreto que no es de ese cliente responde `invalid_client`.
    Devuelve el mensaje de error o None si está bien (o si no hay red).
    """
    data = urllib.parse.urlencode(
        {
            "client_id": client_id,
            "client_secret": secret,
            "grant_type": "authorization_code",
            "code": "verificacion-ci",
            "redirect_uri": "http://localhost",
        }
    ).encode()
    try:
        urllib.request.urlopen(
            "https://oauth2.googleapis.com/token", data=data, timeout=20
        )
        return None
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read().decode("utf-8"))
        except Exception:
            body = {}
        if body.get("error") == "invalid_client":
            return (
                "Google rechaza el par GOOGLE_DESKTOP_CLIENT_ID + "
                "GOOGLE_DESKTOP_CLIENT_SECRET ("
                + str(body.get("error_description", "invalid_client"))
                + "). El secreto tiene que ser el del MISMO cliente "
                "'App de escritorio'."
            )
        return None
    except Exception as e:  # sin red: no bloquear la build
        print(f"::warning::No se pudo verificar el secreto con Google: {e}")
        return None


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    env = {}
    errors = []
    for key in KEYS:
        value = "".join(os.environ.get(key, "").split())
        env[key] = value
        if not value:
            print(f"::warning::Secreto {key} vacío.")
            continue
        pattern, hint = CHECKS[key]
        if not pattern.match(value):
            errors.append(f"::error::Secreto {key} con formato inválido: {hint}.")
    if env["GOOGLE_DESKTOP_CLIENT_ID"] and not env["GOOGLE_DESKTOP_CLIENT_SECRET"]:
        errors.append("::error::Falta GOOGLE_DESKTOP_CLIENT_SECRET.")
    if (
        env["GOOGLE_WEB_CLIENT_ID"]
        and env["GOOGLE_WEB_CLIENT_ID"] == env["GOOGLE_DESKTOP_CLIENT_ID"]
    ):
        errors.append(
            "::error::GOOGLE_WEB_CLIENT_ID y GOOGLE_DESKTOP_CLIENT_ID son iguales: "
            "tienen que ser dos clientes distintos (Aplicación web y App de escritorio)."
        )
    if not errors and env["GOOGLE_DESKTOP_CLIENT_ID"]:
        problem = check_google_desktop_pair(
            env["GOOGLE_DESKTOP_CLIENT_ID"], env["GOOGLE_DESKTOP_CLIENT_SECRET"]
        )
        if problem:
            errors.append(f"::error::{problem}")
    for line in errors:
        print(line)
    if errors:
        return 1
    with open("env.json", "w", encoding="utf-8") as f:
        json.dump(env, f)
    print("env.json generado y validado.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
