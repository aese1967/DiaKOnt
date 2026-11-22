# Publicar DiaKont en Microsoft Store

**Por qué la Store:** Windows (Control inteligente de aplicaciones) bloquea los instaladores que no tienen una firma digital paga. Las apps de la Microsoft Store las firma Microsoft, así que se instalan sin bloqueos, con un clic y se actualizan solas. Para desarrolladores individuales la cuenta es **gratis**.

---

## Paso 1. Crear la cuenta de desarrollador (una vez)
1. Entrá a https://storedeveloper.microsoft.com y tocá **Comenzar / Get started**.
2. Iniciá sesión con tu cuenta Microsoft (la que vas a usar para administrar la app).
3. Elegí **Individual** (desarrollador individual) y país **Uruguay**.
4. Nombre para mostrar del editor: **South Devs** (Microsoft no acepta "SouthDevs" junto; es lo que verá la gente como "editor").
5. Completá la verificación de identidad (documento + selfie desde el celular). Suele aprobarse en minutos u horas.

## Paso 2. Reservar el nombre "DiaKont"
1. En Partner Center: **Aplicaciones y juegos > + Nuevo producto > Aplicación MSIX o PWA**.
2. Nombre: **DiaKont** (si está tomado, probá "DiaKont Gastos del Hogar"). Tocá **Reservar**.

## Paso 3. Pasarme los 3 datos de identidad
En la app recién creada: **Administración de productos > Identidad del producto**. Copiame estos 3 valores:

| En Partner Center | Ejemplo |
|---|---|
| Package/Identity/Name | `12345SouthDevs.DiaKont` |
| Package/Identity/Publisher | `CN=ABCD1234-...` |
| Package/Properties/PublisherDisplayName | `South Devs` |

Con eso actualizo `pubspec.yaml` y GitHub genera el archivo **`DiaKont-1.0.0-store.msix`** en el Release.

## Paso 4. Crear el envío (submission)
En Partner Center, en DiaKont, tocá **Iniciar envío** y completá cada sección:

1. **Precios y disponibilidad**: Gratis. Mercados: todos (o solo Uruguay y Latinoamérica si preferís). Visibilidad: pública.
2. **Propiedades**:
   - Categoría: **Finanzas personales** (Personal finance).
   - URL de política de privacidad: `https://github.com/aese1967/DiaKont/blob/main/docs/PRIVACIDAD.md`
   - Sitio web y contacto de soporte: tu email o la página de GitHub.
3. **Clasificación por edades**: completá el cuestionario (no hay violencia, chat ni compras): queda apta para todo público.
4. **Paquetes**: arrastrá el archivo `DiaKont-1.0.0-store.msix` descargado del Release de GitHub.
   - Si aparece un aviso de la capacidad restringida **runFullTrust**, en "Opciones de envío" explicá: _"Es una aplicación de escritorio Win32 creada con Flutter; necesita confianza total para funcionar como app de escritorio. No accede a archivos del usuario fuera de su carpeta."_
5. **Descripciones de la tienda** (idioma Español): copiá los textos de la sección **"3. Microsoft Store"** del archivo `diakont-marketing/textos/diakont-textos-promocionales.md`:
   - Descripción, descripción breve, características, palabras clave y novedades.
   - **Capturas de escritorio** (mínimo 1366×768): `diakont-marketing/capturas/windows-dashboard-claro.png`, `windows-dashboard-oscuro.png` y `escena-windows-android-claro.png`.
   - Logo de la tienda: `diakont-marketing/logos/png/diakont-isotipo-1024.png`.
   - Mientras el login con Microsoft no esté activado, sacá la frase "o de Microsoft" de la descripción (o avisame y lo activamos).
6. **Enviar a la Store**. La certificación tarda normalmente de unas horas a 3 días hábiles. Te llega un email cuando se publica.

---

## Cómo funcionan las actualizaciones

**Windows (Microsoft Store)**
1. Me pedís un cambio (o lo hacemos juntos) y subo el código a GitHub.
2. Subo el número de versión (por ejemplo 1.0.0 → 1.0.1) y GitHub compila un nuevo `.msix`.
3. Vos entrás a Partner Center > DiaKont > **Actualizar** (crea un envío nuevo copiando todo lo anterior), reemplazás el paquete por el nuevo `.msix` y tocás **Enviar**.
4. Tras la certificación, **la Store actualiza la app sola** en las PCs de todos los usuarios. Ellos no hacen nada.

**Android**
- Hoy: cada versión nueva aparece en GitHub Releases como `.apk`; se instala encima de la anterior y conserva los datos (ya está firmado siempre con la misma clave).
- Cuando la publiques en Google Play: mismo proceso que la Store (subís el nuevo archivo `.aab` en Play Console) y Play actualiza a todos automáticamente.

**Los datos nunca se pierden al actualizar**: viven en el dispositivo y en el Drive/OneDrive de cada usuario.
