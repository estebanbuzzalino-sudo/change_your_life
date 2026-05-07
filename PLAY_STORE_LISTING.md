# Play Store Listing — Change Your Life in Community

Todo el copy listo para copiar y pegar en Google Play Console.

---

## 📱 Datos básicos

| Campo | Valor |
|-------|-------|
| **Nombre de la app** | Change Your Life in Community |
| **Application ID** | com.changeyourlife.app |
| **Categoría** | Salud y bienestar |
| **Clasificación de contenido** | Para todos |
| **Países** | Argentina (y todos los que quieras) |

---

## 📝 Descripción corta (máx. 80 caracteres)

```
Bloqueá redes sociales con la ayuda de un amigo que te acompañe.
```
*(64 caracteres)*

---

## 📄 Descripción completa (máx. 4000 caracteres)

```
¿Cuántas veces abriste Instagram sin darte cuenta? ¿Pasás horas en TikTok y después te sentís mal? Change Your Life in Community es una app que te ayuda a recuperar el control de tu tiempo, con el respaldo de alguien que te importa.

🔒 BLOQUEÁ LAS APPS QUE TE DISTRAEN
Elegí qué redes sociales querés bloquear: Instagram, TikTok, Facebook, X (Twitter), YouTube, o cualquier otra app instalada en tu celular. Definís la duración del bloqueo, desde días hasta meses.

🤝 EL PODER DEL COMPROMISO SOCIAL
La clave diferencial: un amigo responsable. Cada vez que querés desbloquear una app, tu amigo recibe una notificación (por email o WhatsApp) y es quien decide si aprueba o no. Ese simple mecanismo de rendición de cuentas hace que el compromiso sea real.

✅ SUGERENCIAS DE REEMPLAZO
Cuando intentás abrir una app bloqueada, la app te muestra actividades alternativas personalizadas según lo que elegiste: lectura, ejercicio, meditación, música o juegos mentales. Reemplazás el tiempo perdido con algo que sí te suma.

📊 HISTORIAL Y ESTADÍSTICAS
Seguí tu progreso: cuántos días llevás en modo bloqueo, cuántos bloqueos completaste y cuáles fueron las apps que más bloqueaste.

🛡️ SIN TRUCOS, SIN WORKAROUNDS
El bloqueo funciona mediante el Servicio de Accesibilidad de Android, lo que hace que sea realmente efectivo. No podés simplemente cerrar la app y abrir la red social bloqueada.

---

CÓMO FUNCIONA:
1. Instalá la app y otorgá los permisos necesarios
2. Elegí las apps que querés bloquear y la duración
3. Ingresá los datos de tu amigo responsable (email o WhatsApp)
4. Activá el bloqueo
5. Si querés desbloquear antes de tiempo, tu amigo recibe una notificación y decide

---

PRIVACIDAD:
No vendemos datos. No usamos publicidad. Tus datos se almacenan en tu dispositivo. Las solicitudes de desbloqueo se sincronizan temporalmente con nuestro servidor solo para coordinar con tu amigo.

Política de privacidad completa: https://estebanbuzzalino-sudo.github.io/change_your_life/privacy-policy.html
```

---

## 🏷️ Palabras clave / Tags sugeridos

```
bloqueo de apps, control de tiempo, redes sociales, productividad, 
bienestar digital, hábitos, disciplina, accountability, 
desintoxicación digital, focus, foco, tiempo libre
```

---

## 📸 Capturas de pantalla necesarias

Mínimo 2, recomendado 6. Tamaños aceptados: 16:9 o 9:16.

| Pantalla | Qué mostrar |
|----------|-------------|
| 1 | Wizard Paso 1 — selección de apps (Instagram, TikTok, etc.) |
| 2 | Wizard Paso 2 — duración + configuración del amigo |
| 3 | Wizard Paso 4 — resumen del plan activo (bloqueo activo, verde) |
| 4 | BlockScreen — pantalla de pausa con sugerencias |
| 5 | OnboardingScreen — bienvenida |
| 6 | StatsScreen — estadísticas e historial |

**Tip:** Usá un emulador con datos de ejemplo cargados para que se vea completo.

---

## 🔐 Declaraciones de permisos especiales

### Accessibility Service (Prominent API Declaration)

Google va a pedir que justifiques el uso. Usá este texto:

```
Change Your Life in Community uses the Accessibility Service exclusively to detect
when the user opens a blocked application and to display the block screen.

The Accessibility Service monitors foreground app transitions only. It does not:
- Read screen content or text input from other apps
- Capture screenshots or record screen activity
- Collect or transmit user data from other apps
- Interact with or control other applications

This functionality is the core purpose of the app and cannot be achieved through
alternative, less sensitive APIs. Without this permission, the app cannot fulfill
its primary function of blocking distracting social media applications.
```

### QUERY_ALL_PACKAGES Justification

```
The QUERY_ALL_PACKAGES permission is used to display the list of installed
applications that the user may choose to block. Without this permission, the app
cannot show which social media apps are currently installed on the device,
making it impossible for the user to select apps to block.

This information is displayed only within the app to the user and is never
transmitted to any external server or third party.
```

---

## 📋 Content Rating (IARC Questionnaire)

Respondé así en Play Console → "Clasificación de contenido":

| Pregunta | Respuesta |
|----------|-----------|
| ¿Violencia? | No |
| ¿Contenido sexual? | No |
| ¿Lenguaje ofensivo? | No |
| ¿Sustancias controladas? | No |
| ¿Interacción con usuarios? | Sí (envía notificaciones a un contacto del usuario) |
| ¿Compras en la app? | No |
| ¿Datos de ubicación? | No |

**Resultado esperado:** "Para todos" (Everyone)

---

## 🔗 URLs necesarias en Play Console

| Campo | URL |
|-------|-----|
| Política de privacidad | `https://estebanbuzzalino-sudo.github.io/change_your_life/privacy-policy.html` |
| Sitio web (opcional) | `https://github.com/estebanbuzzalino-sudo/change_your_life` |
| Email de soporte | `changeyourlifecommunity@gmail.com` (crealo o usá el tuyo) |
