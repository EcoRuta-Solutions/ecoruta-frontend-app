# EcoRuta Trujillo — app

App Flutter (Riverpod, go_router, dio) para la gestión de la recolección de
residuos en Trujillo.

## Roles

La app tiene dos roles. El rol llega del backend (`GET /auth/me`) después del
login con correo y contraseña:

| Rol | Pantalla de inicio | Qué hace |
|---|---|---|
| `municipalidad` | `/municipalidad` | Panel, mapa, alertas, rutas, contenedores, usuarios y flota, informes |
| `conductor` | `/conductor` | Mi ruta, mapa de ruta, perfil |

No hay registro de cuentas desde la app: las crea la municipalidad. Si una
cuenta tiene otro rol, se cierra la sesión y el login muestra
"Tu cuenta no tiene acceso a esta app".

Las denuncias ciudadanas no forman parte de EcoRuta: se atienden por
**Alerta SEGAT**.

## Cómo correrla

```bash
flutter pub get

# Con datos de ejemplo (por defecto, no necesita backend)
flutter run

# Contra el backend real
flutter run --dart-define=USE_MOCK=false

# En un celular real, apuntando al backend en tu red
flutter run --dart-define=USE_MOCK=false --dart-define=API_URL=http://TU_IP:8000
```

Sin `API_URL`, la app usa `http://10.0.2.2:8000` en el emulador Android y
`http://localhost:8000` en las demás plataformas.

## Pruebas

```bash
flutter analyze
flutter test
```
