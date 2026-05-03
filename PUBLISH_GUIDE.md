# Guía completa de publicación en Play Store

Seguí estos pasos en orden. Los que tienen ✅ ya están hechos en el código.

---

## FASE 1 — Keystore (una sola vez, guardalo para siempre)

> ⚠️ Si perdés el keystore no podés actualizar la app nunca más. Guardalo en Google Drive, Dropbox o donde tengas backup.

### Paso 1: Crear la carpeta

```bash
mkdir android/keystore
```

### Paso 2: Generar el keystore

```bash
keytool -genkey -v \
  -keystore android/keystore/release.keystore \
  -alias changeyourlife \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

Te va a pedir:
- Contraseña del keystore (la que quieras, anotala)
- Nombre, organización, ciudad, país → podés poner cualquier cosa
- Contraseña del key (puede ser la misma que el keystore)

### Paso 3: Crear `android/key.properties`

Copiá el template y completalo:

```bash
cp android/key.properties.template android/key.properties
```

Editá `android/key.properties` con tus datos reales:

```
storeFile=keystore/release.keystore
storePassword=TU_CONTRASEÑA
keyAlias=changeyourlife
keyPassword=TU_CONTRASEÑA
```

---

## FASE 2 — GitHub Pages (Privacy Policy)

### Paso 1: Activar GitHub Pages

1. Ir a tu repo en GitHub: https://github.com/estebanbuzzalino-sudo/change_your_life
2. Settings → Pages
3. Source: "Deploy from a branch"
4. Branch: `main` (o la rama principal), carpeta: `/docs`
5. Save

### Paso 2: Mergear la rama de desarrollo a main

```bash
git checkout main
git merge claude/laughing-benz-4ce42d
git push origin main
```

La Privacy Policy va a quedar en:
**https://estebanbuzzalino-sudo.github.io/change_your_life/privacy-policy.html**

---

## FASE 3 — Build de producción

### Paso 1: Asegurate que el keystore está configurado

```bash
cat android/key.properties  # debe existir y tener los datos
```

### Paso 2: Actualizar dependencias

```bash
flutter pub get
```

### Paso 3: Regenerar splash screen (color oscuro)

```bash
dart run flutter_native_splash:create
```

### Paso 4: Regenerar íconos (si cambiaste el logo)

```bash
dart run flutter_launcher_icons
```

### Paso 5: Build del App Bundle

```bash
flutter build appbundle --release
```

El archivo final queda en:
```
build/app/outputs/bundle/release/app-release.aab
```

### Verificar el build

```bash
# Tamaño del bundle
ls -lh build/app/outputs/bundle/release/app-release.aab

# Ver con qué keystore está firmado
java -jar bundletool.jar validate --bundle=build/app/outputs/bundle/release/app-release.aab
```

---

## FASE 4 — Play Console

### Paso 1: Crear cuenta de desarrollador (si no tenés)

- https://play.google.com/console
- Costo único: USD 25
- Verificación de identidad: puede tardar 1-3 días

### Paso 2: Crear la app

1. "Create app"
2. Nombre: `Change Your Life in Community`
3. Idioma por defecto: Español (Latinoamérica)
4. App o juego: App
5. Gratis o pago: Gratis
6. Aceptar políticas

### Paso 3: Completar el Dashboard (sección "Set up your app")

Ir completando en orden:

#### App access
- "All functionality is available without special access"
  (o describí cómo crear una cuenta de prueba si tu revisor lo necesita)

#### Ads
- "My app does not contain ads"

#### Content rating
- Completar el cuestionario IARC (ver PLAY_STORE_LISTING.md para las respuestas)

#### Target audience
- Edad: 18 o 13+ (recomendado 18+)

#### News apps
- "This app is not a news app"

#### COVID-19 apps
- No aplica

#### Data safety (MUY IMPORTANTE)
Declarar qué datos recopila la app:

| Tipo de dato | Recopilado | Compartido | Propósito |
|-------------|-----------|-----------|-----------|
| Nombre | Sí | No | Funcionalidad de la app |
| Dirección de email | Sí | Sí (Supabase/Twilio) | Notificaciones |
| Número de teléfono | Opcional | Sí (Twilio) | Notificaciones WhatsApp |
| Apps instaladas | Sí | No | Funcionalidad de la app |
| Actividad en la app | Sí | No | Funcionalidad de la app |

#### Government apps
- No aplica

### Paso 4: Declaraciones de permisos

En "App content" → "Sensitive app access":

1. **Accessibility Service** → Declarar uso, pegar el texto de PLAY_STORE_LISTING.md
2. **QUERY_ALL_PACKAGES** → Completar el formulario con la justificación del listing

### Paso 5: Store listing

En "Main store listing":
- **App name:** Change Your Life in Community
- **Short description:** Copiar de PLAY_STORE_LISTING.md
- **Full description:** Copiar de PLAY_STORE_LISTING.md
- **App icon:** 512x512 PNG (usar assets/logo/app_icon_android_full.png)
- **Feature graphic:** 1024x500 PNG (crear uno con diseño Vínculo)
- **Screenshots:** Mínimo 2 (ver lista en PLAY_STORE_LISTING.md)
- **Privacy policy URL:** https://estebanbuzzalino-sudo.github.io/change_your_life/privacy-policy.html

### Paso 6: Subir el App Bundle

En "Production" → "Releases" → "Create new release":

1. Subir `app-release.aab`
2. Release notes (qué hay de nuevo):
   ```
   Primera versión de Change Your Life in Community.
   Bloqueá redes sociales con la ayuda de un amigo responsable.
   ```
3. Review y publish

---

## FASE 5 — Revisión de Google

- La primera revisión tarda **3-7 días hábiles**
- Si Google pide más info sobre el Accessibility Service, respondé con el texto de PLAY_STORE_LISTING.md
- Las actualizaciones futuras tardan **1-3 horas** generalmente

---

## ✅ Checklist final antes de subir

- [ ] `android/key.properties` existe y tiene datos reales
- [ ] `android/keystore/release.keystore` existe
- [ ] `flutter build appbundle --release` completó sin errores
- [ ] GitHub Pages activado
- [ ] Privacy Policy accesible en la URL
- [ ] Email de soporte creado
- [ ] Screenshots tomadas (mínimo 2, idealmente 6)
- [ ] Feature graphic creado (1024x500)
- [ ] App icon 512x512 listo
- [ ] Cuenta de Play Console activa y verificada
