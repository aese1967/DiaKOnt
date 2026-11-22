# DiaKont by Southdevs

Contabilidad hogareña simple para **Android** y **Windows (.exe)**, con un único código Flutter, sincronización en tiempo real entre dispositivos y funcionamiento completo sin conexión.

> Estado: **Fases 1 y 2** (versión sin servidor: Google Drive / OneDrive) (arquitectura, sincronización, login, gastos con IVA, categorías y grupos, dashboard y exportación a Excel). Las instrucciones detalladas de compilación (Fase 3) y la identidad visual/marketing (Fase 4) vienen después.

---

## 1. Arquitectura elegida (sin servidor)

| Capa | Tecnología | Por qué |
|---|---|---|
| UI multiplataforma | **Flutter** (Material 3) | Un código para Android y Windows nativos, rendimiento real, buen soporte de gráficos. |
| Estado | **Riverpod 3** | Reactivo, testeable, sin generación de código. |
| Base local | **SQLite** (`sqflite` en Android, `sqflite_common_ffi` en Windows) | La app lee y escribe siempre local, así funciona offline igual en ambas plataformas. |
| Nube | **Google Drive** (carpeta oculta `appDataFolder`) u **OneDrive** (carpeta `Aplicaciones/DiaKont`) del propio usuario | Sin servidor que mantener ni pagar; los datos son del usuario. |
| Login | **Google** (nativo en Android, PKCE + loopback en Windows) o **Microsoft** (PKCE en ambos) | La cuenta elegida es la identidad y el almacenamiento. |
| Gráficos | `fl_chart` | Barras y dona interactivas. |
| Excel | `excel` + `file_picker` | .xlsx con formato; diálogo nativo "Guardar como". Sirve para compartir con la familia. |

### Cómo funciona la sincronización
```
 UI ──► Repositorios ──► SQLite local (fuente de verdad, dirty=1)
                              │  ▲
       sube SU archivo        │  │ baja y fusiona los archivos
       dk-device-<id>.json.gz ▼  │ de los otros dispositivos
                Carpeta privada de la app en Drive / OneDrive
```
1. Cada cambio se guarda local (la UI se actualiza al instante) y queda pendiente.
2. Cada dispositivo escribe **solo su propio archivo** con una copia comprimida de sus datos, así dos dispositivos nunca se pisan.
3. Para recibir cambios, lee los archivos de los otros dispositivos y fusiona fila por fila: **gana la edición más reciente** (`updated_at`). Los borrados viajan como marcas (`deleted`).
4. Sincroniza al abrir y al volver a la app, 3 s después de un cambio, al recuperar conexión y cada 60 s mientras está abierta. Sin servidor no hay aviso instantáneo, así que el otro dispositivo ve el cambio en menos de un minuto.
5. Sin conexión todo funciona; al reconectar se sube y baja lo pendiente.
6. Las categorías por defecto usan ids deterministas, así que instalar en dos equipos a la vez no las duplica.

Montos en **centésimos enteros** y tasas en **puntos básicos** (22 % = 2200) para evitar errores de redondeo.

---

## 2. Estructura

```
lib/
  main.dart                 Arranque (cuenta guardada, locale es, prefs)
  app.dart                  MaterialApp, temas, AuthGate → SessionGate → HomeShell
  core/
    config/env.dart         Credenciales vía --dart-define-from-file
    theme/app_theme.dart    Paleta azul profundo/esmeralda, modo claro/oscuro
    utils/vat_calculator.dart   Lógica de IVA (con/sin IVA, redondeo)
    utils/formatters.dart   Formato y parseo de montos es-UY
    utils/icon_catalog.dart Íconos de categorías/grupos
  data/
    models/models.dart      Expense, Category, ExpenseGroup, UserSettings
    local/local_db.dart     Esquema SQLite + streams reactivos
    local/default_data.dart Categorías y grupos por defecto
    sync/sync_service.dart  Sincronización por archivo de dispositivo + fusión
    repositories/           Acceso a datos para la UI
    auth/                   Login Google/Microsoft (OAuth PKCE, sin servidor)
    cloud/cloud_store.dart  APIs REST de Google Drive y OneDrive
    analytics.dart          Agregaciones del dashboard (diario/semanal/mensual/anual)
    export/excel_exporter.dart  Generador .xlsx
  state/providers.dart      Riverpod: sesión, datos, filtros, tema
  features/
    auth/login_screen.dart
    shell/home_shell.dart   Barra inferior (móvil) / riel lateral (PC)
    dashboard/              Tarjetas resumen + gráficos
    expenses/               Formulario rápido con IVA + lista de movimientos
    categories/             Categorías y grupos (crear/editar/eliminar)
    export/                 Exportación a Excel filtrada
    settings/               IVA por defecto, presupuesto, moneda, tema, cuenta
  widgets/                  Componentes compartidos y logo provisorio
docs/CONFIGURAR_OAUTH.md    Registro único en Google Cloud y Microsoft Entra
test/                       Tests de IVA, analítica, Excel y sincronización
```

---

## 3. Puesta en marcha (resumen)

Requisitos: **Flutter stable actual (Dart 3.14 o superior)**, Android Studio (para APK) y/o Visual Studio 2022 con "Desarrollo de escritorio con C++" (para .exe).

1. Registrar la app en Google y/o Microsoft (una sola vez): ver [docs/CONFIGURAR_OAUTH.md](docs/CONFIGURAR_OAUTH.md).
2. Copiar `env.example.json` a `env.json` y completar los client id.
3. Ejecutar:
   ```bash
   flutter pub get
   flutter test
   flutter run --dart-define-from-file=env.json
   flutter build apk --release --dart-define-from-file=env.json
   flutter build windows --release --dart-define-from-file=env.json
   ```
   El .exe queda en `build/windows/x64/runner/Release/` (la Fase 3 agrega el instalador).

En el primer ingreso cada dispositivo crea: IVA 22 %, moneda UYU, grupos "Servicios Fijos" y "Hogar", y las categorías **UTE, Alquiler, OSE, ANTEL, Gas, Supergás, Celulares** (todas editables y eliminables).
