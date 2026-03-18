# Roadmap de Desarrollo
Change Your Life in Community

Este documento describe el plan de desarrollo del proyecto y los pasos necesarios para completar la aplicación.

---

# Fase 1 — Base de la aplicación (COMPLETADA)

Implementado:

- proyecto Flutter configurado
- estructura de carpetas modular
- pantalla principal
- selección de duración del bloqueo
- selección de apps instaladas en Android
- selección de amigo responsable
- guardado local con shared_preferences
- almacenamiento de bloqueos activos
- detección de app abierta usando Usage Access
- filtrado de apps del sistema

Estado: COMPLETADO

---

# Fase 2 — Motor de bloqueo de apps

Objetivo: bloquear automáticamente una app cuando el usuario intenta abrirla.

Tareas:

- ejecutar verificación de app abierta cada pocos segundos
- comparar app detectada con lista de bloqueos activos
- crear pantalla de bloqueo
- mostrar mensaje de bloqueo
- impedir acceso a la app bloqueada

Resultado esperado:

Si el usuario abre una app bloqueada, aparece una pantalla de bloqueo.

---

# Fase 3 — Pantalla de bloqueo

Objetivo: crear la interfaz que aparece cuando una app bloqueada se abre.

Contenido de la pantalla:

- nombre de la app bloqueada
- fecha en la que termina el bloqueo
- mensaje motivacional
- botón para solicitar desbloqueo

---

# Fase 4 — Sistema de aprobación del amigo

Objetivo: permitir que un amigo autorice el desbloqueo.

Tareas:

- generar solicitud de desbloqueo
- enviar email al amigo responsable
- incluir link de autorización
- permitir aprobación del desbloqueo

Opciones técnicas:

- Firebase
- backend simple
- email con token

---

# Fase 5 — Backend

Objetivo: gestionar solicitudes de desbloqueo.

Funcionalidad:

- registrar usuarios
- registrar amigos responsables
- guardar bloqueos activos
- recibir aprobación del amigo

Tecnologías posibles:

- Firebase
- Supabase
- Node.js

---

# Fase 6 — Sistema de hábitos

Objetivo: transformar el tiempo liberado en hábitos saludables.

Funcionalidades posibles:

- lista de hábitos
- seguimiento diario
- recordatorios
- estadísticas de progreso

---

# Fase 7 — Comunidad

Objetivo: agregar presión social positiva.

Ideas:

- grupos de amigos
- desafíos de desintoxicación digital
- rankings de tiempo recuperado
- logros compartidos

---

# Fase 8 — Publicación

Objetivo: preparar la app para usuarios reales.

Pasos:

- optimización de interfaz
- pruebas en dispositivos reales
- versión Android estable
- publicación en Google Play
- diseño de onboarding

---

# Estado actual del proyecto

Estamos trabajando en:

Fase 2 — Motor de bloqueo de apps

---

# Próximo objetivo inmediato

Implementar:

verificación automática continua de la app abierta