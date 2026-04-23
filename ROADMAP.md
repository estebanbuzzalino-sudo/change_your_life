# Roadmap de Desarrollo
Change Your Life in Community

Este documento describe el plan de desarrollo del proyecto y los pasos necesarios para completar la aplicación.

Última actualización: 2026-04-23

---

# Fase 1 — Base de la aplicación (COMPLETADA)

- Proyecto Flutter configurado
- Estructura de carpetas modular
- Pantalla principal (wizard multi-paso)
- Selección de duración del bloqueo
- Selección de apps instaladas en Android
- Selección de amigo responsable
- Guardado local con shared_preferences
- Almacenamiento de bloqueos activos
- Detección de app abierta usando Usage Access
- Filtrado de apps del sistema

---

# Fase 2 — Motor de bloqueo de apps (COMPLETADA)

Implementado:

- AppBlockAccessibilityService.kt: servicio que escucha eventos de ventana y detecta cuando el usuario abre una app bloqueada
- BlockActivity.kt: activity nativa que ocupa la pantalla completa bloqueando el acceso
- UsageAccessService.dart: wrapper Dart que consulta los últimos 10 minutos de actividad para detectar app en foreground
- Cooldowns y guards anti-cascada en el servicio de accesibilidad
- Permisos declarados: PACKAGE_USAGE_STATS, QUERY_ALL_PACKAGES, INTERNET

---

# Fase 3 — Pantalla de bloqueo (COMPLETADA)

Implementado:

- BlockActivity.kt con UI completa: nombre de app, fecha de fin, nombre del amigo, botones de acción
- block_screen.dart: pantalla Dart adicional con sugerencias de actividades alternativas
- Botones: "Solicitar desbloqueo" y "Ver reemplazos"
- Sugerencias de reemplazo navegables desde la pantalla de bloqueo

---

# Fase 4 — Sistema de aprobación del amigo (COMPLETADA)

Implementado:

- Edge function unlock-requests (Supabase/Deno): recibe solicitud, genera token, inserta en BD
- Envío de email via Resend API con link de aprobación
- Envío de WhatsApp via Twilio Sandbox con link de aprobación
- Modos de notificación: email_only, whatsapp_only, email_and_whatsapp
- Edge function approvals/{token}: sirve página HTML para que el amigo apruebe desde navegador
- Edge function unlock-grants: endpoint que devuelve grants activos por installation_id
- UnlockGrantSyncRepository.kt: sincroniza grants desde Supabase con throttling de 2s
- UnlockGrantsSyncService.dart: sincroniza grants desde Flutter con throttling de 10s
- Persistencia de grants en SharedPreferences (temporary_unlocked_packages_csv)
- AppBlockAccessibilityService verifica grants activos antes de bloquear

Tablas Supabase:
- unlock_requests: solicitudes pendientes
- unlock_grants: desbloqueos aprobados con unlock_until
- unlock_request_notifications: log de notificaciones enviadas

Limitaciones conocidas:
- WhatsApp funciona solo con Twilio Sandbox (números pre-registrados)
- Aprobación es vía navegador web, no abre la app del amigo
- Migración SQL de unlock_requests no está en el repo (existe en producción)

---

# Deuda técnica identificada (a resolver antes de publicar)

- Dos catch vacíos en usage_access_service.dart (errores de permisos sin log)
- jsonDecode sin try-catch en unlock_grants_sync_service.dart (crash potencial con JSON malformado)
- Variables @Volatile sin lock en BlockActivity.kt (potencial race condition multi-thread)
- Token de aprobación no valida expiración de 24h en el POST de approvals
- Migración SQL faltante para tabla unlock_requests (setup desde cero no funciona)
- block_screen.dart Dart podría eliminarse o integrarse ya que el bloqueo real es nativo

---

# Fase 5 — Producción WhatsApp (PENDIENTE)

Objetivo: reemplazar Twilio Sandbox por cuenta productiva.

Tareas:
- Dar de alta número de WhatsApp Business en Twilio
- Aprobar template de mensaje con Meta
- Actualizar variables de entorno TWILIO_WHATSAPP_FROM
- Probar con números reales sin pre-registro

---

# Fase 6 — Sistema de hábitos (PENDIENTE)

Objetivo: transformar el tiempo liberado en hábitos saludables.

Funcionalidades:
- Lista de hábitos personalizables
- Seguimiento diario
- Recordatorios
- Estadísticas de progreso

---

# Fase 7 — Comunidad (PENDIENTE)

Objetivo: agregar presión social positiva.

Ideas:
- Grupos de amigos
- Desafíos de desintoxicación digital
- Rankings de tiempo recuperado
- Logros compartidos

---

# Fase 8 — Publicación (PENDIENTE)

Objetivo: preparar la app para usuarios reales.

Pasos:
- Resolver deuda técnica listada arriba
- Migrar WhatsApp a cuenta productiva
- Optimización de interfaz y onboarding
- Pruebas en dispositivos reales
- Versión Android estable
- Publicación en Google Play

---

# Estado actual del proyecto

Fases 1-4 completadas.
Trabajando en: definición de próximos pasos (deuda técnica vs nuevas features).
