# Unscroll — Resumen técnico para desarrolladores

> Última actualización: mayo 2026  
> Branch activo: `claude/laughing-benz-4ce42d`  
> APK debug: `build/app/outputs/flutter-apk/app-debug.apk`

---

## ¿Qué es Unscroll?

App Android que bloquea redes sociales (Instagram, TikTok, Facebook, etc.) con un mecanismo de responsabilidad social: el usuario elige un "ancla" (amigo o familiar) que es la **única persona autorizada a aprobar un desbloqueo**.

**Premisa de diseño central:** no darle al usuario la opción de salirse solo. Si el propio usuario puede desbloquear, lo hace. El único escape es pedirle a su ancla que lo habilite.

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| App | Flutter 3.x / Dart (solo Android, iOS desactivado) |
| UI | Material 3 + sistema "Sunrise" (`SRTheme.light`) |
| Fuentes | Plus Jakarta Sans (via google_fonts) |
| Persistencia local | shared_preferences |
| Detección de apps | installed_apps, usage_stats |
| Info de dispositivo | device_info_plus (detecta fabricante) |
| Bloqueo nativo | Android AccessibilityService (Kotlin) |
| Deep links | app_links (`changeyourlife://` scheme) |
| Backend | Supabase Edge Functions (unlock-requests, unlock-grants/active) |
| Notificaciones | Email vía Supabase + WhatsApp via Twilio Sandbox |

---

## Arquitectura de archivos clave

```
lib/
├── main.dart                          → Punto de entrada, aplica SRTheme.light
├── screens/
│   ├── home_screen.dart               → ARCHIVO PRINCIPAL (~4500 líneas)
│   │                                    Wizard de configuración (4 pasos)
│   │                                    Dashboard (tabs: Inicio / Ancla / Vos)
│   │                                    Toda la lógica de bloqueo/desbloqueo
│   ├── block_screen.dart              → Pantalla Flutter de pausa (no usada actualmente
│   │                                    como pantalla principal de bloqueo; el bloqueo
│   │                                    real usa BlockActivity nativa)
│   ├── friend_screen.dart             → Configuración del ancla (nombre, email, WhatsApp)
│   ├── stats_screen.dart              → Historial de bloqueos
│   ├── onboarding_screen.dart         → 3 slides de bienvenida + solicitud de permisos
│   ├── pending_requests_screen.dart   → Lista de solicitudes de desbloqueo enviadas
│   └── widgets/
│       ├── wizard_step_shell.dart     → Shell reutilizable para pasos del wizard
│       ├── wizard_bottom_nav.dart     → Navegación inferior del wizard
│       └── selectable_option_card.dart → Tarjeta seleccionable
├── models/
│   └── app_block.dart                 → Modelo AppBlock (packageName, appName, endDate)
├── services/
│   ├── accessibility_service_status.dart → MethodChannel → isEnabled / openSettings
│   ├── unlock_grants_sync_service.dart   → Sincronización de grants desde Supabase
│   └── unlock_request_resender.dart       → Reintento de solicitudes fallidas
└── theme/
    ├── app_theme.dart                 → AppColors (dark) + AppTheme.dark + SRTheme.light
    └── colors.dart                    → SRColors (paleta Sunrise: cream, orange, ink)

android/app/src/main/kotlin/
├── com/example/change_your_life/
│   ├── MainActivity.kt                → MethodChannel: isEnabled, openSettings
│   ├── AppBlockAccessibilityService.kt → NÚCLEO del bloqueo nativo
│   └── UnlockGrantSyncRepository.kt   → Sync de grants desde Supabase (nativo)
└── BlockActivity.kt                   → Pantalla de pausa nativa (se muestra sobre la app bloqueada)

android/app/src/main/res/
├── layout/activity_block.xml          → Layout de la pantalla de pausa (gradiente naranja)
└── drawable/
    ├── bg_block_gradient.xml          → Gradiente naranja: #FF5B3A → #CC3A1A → #7A1200
    ├── bg_icon_card.xml               → Card blanca semitransparente con esquinas 22dp
    ├── bg_hoy_no_pill.xml             → Píldora blanca semitransparente con esquinas 999dp
    ├── bg_quote_card.xml              → Card de cita: #22FFFFFF, esquinas 16dp
    ├── bg_btn_white.xml               → Botón blanco con esquinas 18dp (CTA principal)
    ├── bg_btn_unlock.xml              → Botón oscuro (#33000000) con borde #50FFFFFF
    ├── bg_btn_primary.xml             → Botón naranja (#FF5B3A)
    ├── bg_btn_secondary.xml           → Botón outline verde
    └── bg_timer_badge.xml             → Badge del tiempo restante
```

---

## Flujo principal de uso

### 1. Primera vez (onboarding)
1. `OnboardingScreen` → 3 slides explicativos
2. Solicitud de permiso Usage Stats (`ACTION_USAGE_ACCESS_SETTINGS`)
3. Solicitud de permiso Accessibility (`ACTION_ACCESSIBILITY_SETTINGS`)
4. Usuario llega al `HomeScreen` (wizard)

### 2. Crear un bloqueo (Wizard, 4 pasos)
| Paso | Contenido |
|---|---|
| 1 – Bloqueo | Selección de apps a bloquear (muestra apps instaladas; apps ya bloqueadas aparecen en gris) |
| 2 – Tiempo | Duración: días (1–30) o meses (1–12), via slider |
| 3 – Reemplazo | 4 categorías opcionales: Lectura, Entrenamiento, Música, Concentración |
| 4 – Resumen | Confirmación. Botón "Listo ✓" guarda el bloqueo y activa el servicio |

**Regla importante del paso 1:** El botón "Siguiente" solo se habilita si hay al menos una app seleccionada que NO esté actualmente bloqueada. Si todas las apps seleccionadas ya tienen bloqueo activo, el botón queda deshabilitado (propiedad `_isStep1Ready`).

Al confirmar, `_activateBlock()`:
- Guarda `AppBlock` en `shared_preferences` (key: `activeBlocks`)
- Escribe CSV de packages bloqueados (key: `flutter.blocked_packages_csv`)
- Escribe CSV de fechas de fin (key: `flutter.blocked_end_dates_csv`)
- El `AppBlockAccessibilityService` detecta el cambio vía `OnSharedPreferenceChangeListener`

### 3. Dashboard (post-bloqueo)
Tres tabs:
- **Inicio:** tarjeta de bloqueo activo + tiempo restante + chip "Ideas para reemplazar"
- **Ancla:** datos del amigo responsable (nombre, email, WhatsApp)
- **Vos:** nombre del usuario, estado del servicio de accesibilidad, opción de cambiar ancla (1 vez por bloqueo)

El estado del dashboard se refresca:
- Al abrir la app (resume) → llama directamente `_loadTemporaryUnlockedApps()` + `_loadPendingRequests()` + sync de grants de Supabase
- Al recibir un deep link de aprobación

### 4. Detección y pantalla de bloqueo (BlockActivity)
Cuando el usuario intenta abrir una app bloqueada:
1. `AppBlockAccessibilityService.onAccessibilityEvent` detecta el package
2. Verifica que no esté temporalmente desbloqueado (grants activos en SharedPrefs)
3. Ejecuta `performGlobalAction(GLOBAL_ACTION_HOME)` (manda al inicio)
4. Después de **350ms** lanza `BlockActivity` (pantalla nativa, sin animación suprimida)
5. `BlockActivity` muestra:

#### Diseño de BlockActivity (gradiente naranja)
```
┌──────────────────────────────────┐
│  [ícono real de la app] + 🔒    │  ← PackageManager.getApplicationIcon()
│         [ HOY NO ]               │  ← píldora #33FFFFFF
│                                  │
│   {AppName} está bloqueado.      │  ← 34sp bold blanco
│                                  │
│  Vos lo elegiste. {Ancla} te    │  ← 16sp #CCFFFFFF
│  cuida. Faltan {días, horas}.    │  ← ancla y tiempo en BOLD (SpannableString)
│                                  │
│ ╔══════════════════════════════╗ │
│ ║ "Frase motivacional..."      ║ │  ← cita que rota entre 6 frases
│ ╚══════════════════════════════╝ │
│                                  │
│  [✦  Hacé otra cosa]            │  ← fondo blanco, texto naranja
│  [Pedir desbloqueo a {Ancla}]   │  ← fondo oscuro, borde semitransparente
│                                  │
│  Volvé al home con el botón ↓   │  ← hint ghost
└──────────────────────────────────┘
```

**Fondo:** gradiente lineal vertical `#FF5B3A → #CC3A1A → #7A1200`

**Frases rotativas** (companion object QUOTES en BlockActivity.kt):
1. "Cada vez que cerrás esto, ganás un minuto que era tuyo."
2. "No estás perdiéndote nada. Estás ganando tu atención."
3. "El scroll no te da lo que buscás. Esto sí."
4. "Más tarde lo vas a agradecer."
5. "El aburrimiento es el primer paso a algo real."
6. "Vos elegiste esto. Eso ya es una victoria."

**Lógica dinámica en `bindIntentData()`:**
- Carga nombre del ancla desde SharedPreferences (`friendName`)
- Renderiza subtítulo con `SpannableString` → nombre del ancla y tiempo restantes en bold
- `getTimeRemainingText()` formatea en español: "X días, Y horas"
- Carga ícono real del package con `packageManager.getApplicationIcon(packageName)`
- Selecciona cita rotatoria via `System.currentTimeMillis() % QUOTES.size`

### 5. Flujo de "Hacé otra cosa" (reemplazos)
- Botón "✦ Hacé otra cosa" en BlockActivity → lanza `changeyourlife://unlock/replacements?source=block_activity`
- Deep link capturado en `MainActivity` → flutter side → `_showAlternativesCatalog()`
- `_showAlternativesCatalog()`: DraggableScrollableSheet con 4 categorías
- Tapping en categoría → `_showReplacementIdeas(option)` → bottom sheet con lista de ideas específicas

### 6. Solicitud de desbloqueo
- Botón "Pedir desbloqueo a {AnclaName}" en BlockActivity → POST a `unlock-requests` en Supabase
- Payload incluye: `packageName`, `appName`, `requesterName`, `friendName`, `friendEmail`, `friendWhatsapp`, `requestId` (UUID único del request), `installationId`
- El ancla recibe email o WhatsApp con link de aprobación
- El ancla hace click → `changeyourlife://unlock/approve?package=...&requestId=...&minutes=60`
- La app detecta el deep link → `_applyDeepLinkApproval()` → agrega unlock temporal por 60 min
- El AccessibilityService re-chequea grants antes de bloquear → deja pasar si hay grant activo

**Nota:** el `requestId` en el payload permite al backend deduplicar múltiples solicitudes para distintas apps en la misma sesión.

### 7. Cambio de ancla (máximo 1 vez por bloqueo)
- En tab "Vos", si `_anchorChangesRemaining > 0` aparece botón "Cambiar"
- Al confirmar, llama `_useAnchorChange()` → `_anchorChangesRemaining = 0`
- Cuando se crea un nuevo bloqueo, `_resetAnchorChangeBudget()` lo vuelve a 1

---

## SharedPreferences (claves importantes)

| Clave | Tipo | Descripción |
|---|---|---|
| `activeBlocks` | List\<String\> | JSON array de AppBlock serializados |
| `selectedApps` | List\<String\> | Apps seleccionadas en wizard paso 1 |
| `durationType` | String | `"days"` o `"months"` |
| `durationValue` | Double | Valor del slider (1–30 días / 1–12 meses) |
| `flutter.blocked_packages_csv` | String | CSV de packages actualmente bloqueados |
| `flutter.blocked_end_dates_csv` | String | CSV `package\|millisTimestamp` |
| `flutter.temporary_unlocked_packages_csv` | String | CSV `package\|millisTimestamp` (grants activos) |
| `flutter.pending_unlock_requests_csv` | String | CSV de solicitudes pendientes |
| `friendName` | String | Nombre del ancla |
| `friendEmail` | String | Email del ancla |
| `flutter.friendWhatsappE164` | String | WhatsApp del ancla en formato E.164 |
| `flutter.notificationMode` | String | `"email_only"` o `"whatsapp_only"` |
| `flutter.requester_name` | String | Nombre del usuario |
| `flutter.installation_id` | String | UUID único por instalación |
| `flutter.anchor_changes_remaining` | Int | 0 o 1 (se resetea al crear nuevo bloqueo) |
| `flutter.replacement_choices` | List\<String\> | IDs de categorías de reemplazo elegidas |

---

## Servicio de accesibilidad (AppBlockAccessibilityService)

**Paquete:** `com.example.change_your_life`  
**Clase:** `AppBlockAccessibilityService`  
**ID en Android Settings:** `com.changeyourlife.app/com.example.change_your_life.AppBlockAccessibilityService`

### Lógica de bloqueo (onAccessibilityEvent)
1. Filtra eventos que no sean `TYPE_WINDOW_STATE_CHANGED`
2. Ignora packages críticos (sistema, launcher, Settings, Google services)
3. Chequea si el package está en `blockedPackagesCache`
4. Hace sync rápido con Supabase (timeout 900ms) para verificar grants activos
5. Si hay grant → deja pasar
6. Si no hay grant → `performGlobalAction(HOME)` + lanza `BlockActivity` después de 350ms

### Protecciones anti-spam
- `relaunchCooldownMillis = 500` ms entre relanzamientos del mismo package
- `transitionGuardMillis = 800` ms de guardia post-lanzamiento
- Verifica `BlockActivity.isVisible` para no relanzar si ya está visible
- Verifica que `lastForegroundPackage` sea el launcher o el app bloqueada antes de lanzar

### Configuración del lanzamiento de BlockActivity
- **Sin** `FLAG_ACTIVITY_NO_ANIMATION` → transición visible (no suprimida)
- Delay de 350ms antes de lanzar (era 120ms) → el `performGlobalAction(HOME)` completa antes de que aparezca BlockActivity
- Primera apertura de Instagram/apps similares puede tardar un ciclo de más en ser capturada

---

## Deep links

Scheme: `changeyourlife://`  
Host: `unlock`

| URL | Acción |
|---|---|
| `changeyourlife://unlock/approve?package=X&requestId=Y&minutes=60&requestedAt=Z&v=1` | Aprueba desbloqueo temporal |
| `changeyourlife://unlock/replacements?source=block_activity` | Abre catálogo de alternativas |

Configurado en `android/app/src/main/AndroidManifest.xml` (intent-filter en MainActivity).

---

## Backend (Supabase)

**URL:** `https://oggqvcjtvfgyagaisvmj.functions.supabase.co`

| Endpoint | Método | Descripción |
|---|---|---|
| `/unlock-requests` | POST | Envía solicitud de desbloqueo al ancla (email + WhatsApp) |
| `/unlock-grants/active` | GET | Consulta grants activos para una instalación |

**Headers requeridos:**
- `X-Installation-Id: {UUID}` (generado y guardado localmente en la primera ejecución)
- `Content-Type: application/json`

**Campo `requestId` en el payload de `/unlock-requests`:** UUID único generado por request. Permite que el backend distinga múltiples solicitudes enviadas en la misma sesión (por ejemplo, bloqueo de Facebook + Instagram por separado).

---

## Instrucciones de accesibilidad por fabricante

El dialog `_showAccessibilityStepsDialog()` detecta el fabricante con `device_info_plus` y muestra instrucciones específicas:

| Fabricante | Nota especial |
|---|---|
| Samsung (Android 13+) | Paso extra: ⋮ → "Permitir ajustes restringidos" antes de Accesibilidad |
| Xiaomi / MIUI | Ruta via "Administrar aplicaciones" → "Otros permisos" |
| Huawei / EMUI | Ruta via "Función de accesibilidad instalada" |
| OnePlus / OPPO / Realme | Ruta via "Ajustes adicionales" → "Accesibilidad" |
| Motorola / Lenovo | Ruta directa a "Accesibilidad" |
| Resto (Pixel, etc.) | Ruta genérica |

---

## Tema visual (Sunrise design system)

**Paleta principal (wizard y UI de Flutter):**
| Color | Hex | Uso |
|---|---|---|
| Naranja primario | `#FF5B3A` | CTAs, acentos, íconos activos |
| Naranja claro | `#FF7A55` | Estados hover |
| Fondo cream | `#FDF6EC` | Background del wizard y scaffold |
| Card | `#FFFBF5` | Tarjetas en modo claro |
| Ink (texto) | `#1F1410` | Texto principal |
| Ink2 | `#4A3728` | Texto secundario |
| Ink3 | `#8A7060` | Texto muted |

**El dashboard usa `AppTheme.dark` (fondo `#080B14`), el wizard usa `SRTheme.light` (cream).**

**Paleta de BlockActivity (nativa Android):**
| Color | Hex | Uso |
|---|---|---|
| Naranja primario | `#FF5B3A` | Gradiente inicio, badge de bloqueo |
| Naranja oscuro | `#CC3A1A` | Gradiente medio |
| Rojo oscuro | `#7A1200` | Gradiente final |
| Blanco puro | `#FFFFFF` | Texto título, botón CTA |
| Blanco 80% | `#CCFFFFFF` | Texto subtítulo |
| Blanco 33% | `#33FFFFFF` | Tarjetas, íconos |
| Negro 20% | `#33000000` | Fondo botón desbloqueo |

---

## Reset de datos (testing)

En la tab "Vos" hay un botón "Reiniciar app (debug)" que llama a `_clearAllData()`. Este método:
1. Borra todas las claves de SharedPreferences listadas arriba
2. Resetea todo el estado en memoria
3. Vuelve al wizard como primera vez
4. Mensaje: "Todo reseteado. La app quedó como nueva."

---

## Estado actual y deuda técnica conocida

### Funciona hoy ✅
- Bloqueo real de apps vía AccessibilityService ✅
- Wizard de configuración 4 pasos ✅
- Validación en paso 1: solo habilita "Siguiente" si hay app nueva sin bloqueo activo ✅
- Notificaciones email y WhatsApp al ancla ✅
- Desbloqueo temporal via deep link (ancla aprueba desde email) ✅
- Instrucciones de accesibilidad por fabricante (Samsung, Xiaomi, Huawei, OnePlus, Motorola, Generic) ✅
- Pantalla de pausa nativa con diseño gradiente naranja ✅
  - Ícono real de la app bloqueada (PackageManager) ✅
  - Píldora "HOY NO" ✅
  - Subtítulo dinámico con nombre del ancla + tiempo restante en bold (SpannableString) ✅
  - Frases rotativas motivacionales (6 frases) ✅
- Catálogo de alternativas (bottom sheet con 4 categorías + sugerencias) desde BlockActivity ✅
- Estado del dashboard se refresca al retomar la app (incluye estado de desbloqueo temporal) ✅
- `requestId` en solicitudes de desbloqueo para deduplicación en backend ✅
- Cambio de ancla máximo 1 vez por sesión de bloqueo ✅
- Reset completo para testing ✅

### Pendiente / mejoras futuras
- **iOS:** completamente desactivado. Requeriría Screen Time API + considerable trabajo nativo.
- **Notificaciones push:** el ancla recibe email/WhatsApp pero no push nativa. Si el ancla no tiene email activo, el desbloqueo falla silenciosamente.
- **Multi-ancla:** actualmente 1 solo ancla. Podría ampliarse a "grupo de responsabilidad".
- **Estadísticas:** `StatsScreen` existe pero está básica. Falta gráfica de uso diario.
- **Sincronización background:** la app no corre en background para detectar expiración de bloqueos; se procesa al abrir la app.
- **Accesibilidad en MIUI 14:** el path de permisos cambia nuevamente en MIUI 14 vs MIUI 12/13. Requiere testing específico.
- **WhatsApp Twilio:** actualmente en Sandbox (requiere que el ancla haya aceptado el número de Twilio). Para producción se necesita un número aprobado de WhatsApp Business.
- **Primera apertura de app bloqueada:** hay un ciclo de detección que puede demorar en el primer intento de acceso (especialmente Instagram). El delay de 350ms mitiga pero no elimina el problema.
- **iOS App Clips / Share Extension:** no implementado.
- **Tests automatizados:** no hay tests unitarios ni de integración.
