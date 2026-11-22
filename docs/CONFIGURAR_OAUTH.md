# Configurar el inicio de sesión (una sola vez, la hace SouthDevs)

DiaKont no tiene servidor. Cada usuario guarda sus datos en **su propio** Google Drive (carpeta oculta de la app) o en **su propio** OneDrive (carpeta `Aplicaciones/DiaKont`). Para eso, el desarrollador registra la app **una única vez** en Google y en Microsoft. **Los usuarios no tienen que hacer nada de esto**: solo tocan "Continuar con Google/Microsoft" y aceptan el permiso la primera vez en cada dispositivo.

Al terminar, copiá `env.example.json` a `env.json` y completá los 4 valores.

---

## A. Google (Google Drive)

1. Entrá a https://console.cloud.google.com, creá el proyecto **DiaKont**.
2. **APIs y servicios > Biblioteca**: habilitá **Google Drive API**.
3. **Google Auth Platform > Branding** (pantalla de consentimiento):
   - Tipo de usuario: **Externo**.
   - Nombre "DiaKont", logo, email de soporte, dominio y **URL de política de privacidad** (obligatoria para publicar).
4. **Data Access (Scopes)**: agregá `openid`, `email`, `profile` y `.../auth/drive.appdata`.
   Según la documentación de Google, `drive.appdata` es un permiso **no sensible**, así que solo requiere la **verificación básica de marca** (sin auditoría de seguridad ni pago).
5. **Clients**: creá 3 clientes OAuth:
   | Tipo | Para qué | Dato que va a `env.json` |
   |---|---|---|
   | **Aplicación web** | Lo exige Google Sign-In en Android | `GOOGLE_WEB_CLIENT_ID` |
   | **Android**, paquete `io.southdevs.diakont` + huella **SHA-1** del certificado de firma (`keytool -list -v -keystore ...`). Registrá la SHA-1 de debug y la de release (si publicás en Play, también la de "App signing" de Play Console) | Login nativo en el celular | (no va en env.json) |
   | **App de escritorio** | Login en Windows (loopback `localhost`) | `GOOGLE_DESKTOP_CLIENT_ID` y `GOOGLE_DESKTOP_CLIENT_SECRET` |
6. **Audience**:
   - En modo **Testing** funciona ya para hasta 100 "usuarios de prueba" que agregues por email (los tokens vencen a los 7 días: hay que volver a entrar).
   - Para todos los usuarios: **Publish app** y enviar a verificación de marca (normalmente unos pocos días hábiles). Mientras no esté verificada, Google muestra el aviso "Google no verificó esta app".

## B. Microsoft (OneDrive)

1. Entrá a https://entra.microsoft.com > **Identidad > Aplicaciones > Registros de aplicaciones > Nuevo registro**.
2. Nombre "DiaKont". Tipos de cuenta: **Cuentas de cualquier directorio organizativo y cuentas personales de Microsoft**.
3. **Autenticación > Agregar plataforma > Aplicaciones móviles y de escritorio**, URIs de redirección:
   - `http://localhost` (Windows; el puerto se ignora para localhost)
   - `msauth.io.southdevs.diakont://auth` (Android)
   - Activá **Permitir flujos de cliente público = Sí**.
4. **Permisos de API > Microsoft Graph > Delegados**: `User.Read`, `Files.ReadWrite.AppFolder`, `offline_access`, `openid`, `profile`. No requieren consentimiento de administrador.
5. Copiá el **Id. de aplicación (cliente)** a `MICROSOFT_CLIENT_ID`.
6. Opcional pero recomendado: **Comprobación del publicador** (Branding > Publisher verification), con una cuenta del programa Microsoft AI Cloud Partner (gratis). Sin ella la app funciona igual, pero la pantalla de permisos dice "no comprobado".

---

## Preguntas frecuentes

**¿Cada usuario tiene que verificar algo?** No. La verificación la hace SouthDevs una sola vez por proveedor. El usuario solo inicia sesión y acepta el permiso una vez por dispositivo.

**¿DiaKont puede ver mis otros archivos?** No. Los permisos `drive.appdata` y `Files.ReadWrite.AppFolder` solo dan acceso a la carpeta propia de la app.

**¿Cómo comparto con mi familia?** Exportando a Excel (pestaña Exportar) y enviando el archivo. Cada integrante usa su propia cuenta.

**¿Qué pasa si uso Google en el celular y Microsoft en la PC?** Son dos cuentas distintas con datos separados. Usá la misma cuenta en los dos dispositivos.
