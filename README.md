# 🍎 QuinchosApp iOS

App **100% nativa** en **Swift 5.9 + SwiftUI** para buscar, reservar y valorar quinchos y salones. Target: iOS 16+.

## Stack

- **Swift 5.9** / **SwiftUI**
- **MVVM** con `@MainActor` y `async/await`
- **URLSession** nativa (sin Alamofire)
- **Kingfisher** para cache de imágenes
- **MapKit** para mapa interactivo
- **JWT** almacenado en `UserDefaults` (migrar a Keychain en producción)

## Setup

```bash
git clone https://github.com/jacquet33/quinchos-ios.git
cd quinchos-ios

# Opción A: XcodeGen (recomendado)
brew install xcodegen
xcodegen generate
open QuinchosApp.xcodeproj

# Opción B: Crear proyecto manualmente en Xcode
# y arrastrar la carpeta QuinchosApp/
```

Configurar la URL del backend en `QuinchosApp/Services/APIService.swift`.

## Arquitectura

```
QuinchosApp/
├── App/              # Entry point (@main)
├── Models/           # Codable structs (Usuario, Quincho, Reserva, Resena)
├── Services/         # APIService (URLSession + JWT)
├── ViewModels/       # AuthVM, QuinchosVM, ReservasVM, FavoritosVM, ResenasVM
├── Views/
│   ├── Components/   # QuinchoCard, StarRating, SearchBar, FilterChips
│   └── MainViews     # Login, Explorar, Detalle, Reservar, Mapa, Favoritos, Cuenta
└── Utils/            # Theme (colores, helpers)
```

## Pantallas

| Tab | Descripción |
|---|---|
| Explorar | Búsqueda + filtros + destacados + listado |
| Mapa | MapKit con marcadores y precios |
| Reservas | Mis reservas con estado y cancelación |
| Favoritos | Quinchos guardados |
| Cuenta | Perfil, settings, logout |

## API REST

Conecta con [quinchos-api](https://github.com/jacquet33/quinchos-api) (Express + PostgreSQL).
