# Change Your Life in Community

Aplicación móvil desarrollada con Flutter para ayudar a las personas a reducir el uso excesivo de redes sociales y otras apps distractoras, transformando ese tiempo en hábitos saludables.

## Objetivo del proyecto

La app permite:

- seleccionar apps a bloquear
- definir duración del bloqueo en días o meses
- asignar un amigo responsable
- detectar qué app está siendo usada en Android
- sentar la base para bloquear apps y pedir autorización a un amigo para desbloquear

## Estado actual del proyecto

Actualmente el proyecto ya tiene implementado:

- Flutter configurado y funcionando
- estructura modular del proyecto
- selección de apps instaladas en Android
- guardado local con `shared_preferences`
- bloqueo lógico con fecha de fin
- almacenamiento de bloqueos activos
- uso de `packageName` para identificar apps
- permiso `Usage Access`
- detección de la app abierta recientemente en Android

## Tecnologías usadas

- Flutter
- Dart
- Android Emulator
- shared_preferences
- installed_apps
- usage_stats

## Estructura del proyecto

```text
lib/
  main.dart
  models/
    app_block.dart
  screens/
    home_screen.dart
    apps_selection_screen.dart
    friend_screen.dart
  services/
    usage_access_service.dart