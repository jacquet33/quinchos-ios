import Foundation

// MARK: - Usuario

struct Usuario: Codable, Identifiable {
    let id: String
    let email: String
    let nombre: String
    let telefono: String?
    let avatar: String?
    let rol: Rol
    let verificado: Bool?
    let createdAt: String?
    let proveedor: String?
    let tienePassword: Bool?

    /// true si entró con Google o Apple
    var esCuentaSocial: Bool { (proveedor ?? "EMAIL") != "EMAIL" }
    var puedeCambiarPassword: Bool { tienePassword ?? true }

    enum Rol: String, Codable, CaseIterable {
        case USUARIO, PROPIETARIO, ADMIN
    }
    
    var isVerificado: Bool { verificado ?? false }
}

struct AuthResponse: Codable {
    let ok: Bool
    let token: String
    let usuario: Usuario
}

struct PerfilResponse: Codable {
    let ok: Bool
    let usuario: Usuario
}

// MARK: - Quincho

struct Quincho: Codable, Identifiable, Hashable {
    let id: String
    let nombre: String
    let descripcion: String
    let direccion: String
    let ciudad: String
    let provincia: String
    let latitud: Double
    let longitud: Double
    let precioHora: Int
    let precioDia: Int
    let capacidadMin: Int
    let capacidadMax: Int
    let tipo: TipoEspacio
    let disponible: Bool
    let horarioApertura: String
    let horarioCierre: String
    let calificacionProm: Double
    let totalResenas: Int
    let propietario: PropietarioResumen?
    let imagenes: [QuinchoImagen]?
    let amenidades: [QuinchoAmenidadWrapper]?
    let resenas: [Resena]?
    let serviciosExtra: [ServicioExtra]?
    let demanda: Demanda?
    let disponibilidad: Disponibilidad?
    
    static func == (lhs: Quincho, rhs: Quincho) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct PropietarioResumen: Codable {
    let id: String
    let nombre: String
    let avatar: String?
    let verificado: Bool
}

struct QuinchoImagen: Codable, Identifiable {
    let id: String
    let url: String
    let orden: Int
}

struct QuinchoAmenidadWrapper: Codable {
    let amenidad: Amenidad
}

enum TipoEspacio: String, Codable, CaseIterable {
    case QUINCHO, SALON, QUINTA, TERRAZA, JARDIN

    var label: String {
        switch self {
        case .QUINCHO: return "Quincho"
        case .SALON: return "Salón"
        case .QUINTA: return "Quinta"
        case .TERRAZA: return "Terraza"
        case .JARDIN: return "Jardín"
        }
    }

    var icono: String {
        switch self {
        case .QUINCHO: return "flame.fill"
        case .SALON: return "building.2.fill"
        case .QUINTA: return "house.and.flag.fill"
        case .TERRAZA: return "sun.max.fill"
        case .JARDIN: return "leaf.fill"
        }
    }
}

enum Amenidad: String, Codable, CaseIterable {
    case PARRILLA, HORNO_BARRO, COCINA, HELADERA, FREEZER, VAJILLA, MICROONDAS
    case PILETA, PILETA_CLIMATIZADA, TECHADO, JARDIN, QUINCHO_CERRADO, DECK
    case JUEGOS_NINOS, PELOTERO, HAMACAS, TOBOGAN, ARENERO
    case MUSICA, PROYECTOR, METEGOL, PING_PONG, POOL, CANCHA_FUTBOL, CANCHA_TENIS
    case WIFI, AIRE_ACONDICIONADO, CALEFACCION, ESTACIONAMIENTO, SEGURIDAD
    case BANO, DUCHA, VESTUARIO, MESAS_SILLAS, ILUMINACION, ACCESIBLE
    case APTO_MASCOTAS, FOGON, ASADOR_CRIOLLO

    var label: String {
        switch self {
        case .PARRILLA: return "Parrilla"
        case .HORNO_BARRO: return "Horno de barro"
        case .ASADOR_CRIOLLO: return "Asador criollo"
        case .FOGON: return "Fogón"
        case .COCINA: return "Cocina"
        case .HELADERA: return "Heladera"
        case .FREEZER: return "Freezer"
        case .MICROONDAS: return "Microondas"
        case .VAJILLA: return "Vajilla"
        case .PILETA: return "Pileta"
        case .PILETA_CLIMATIZADA: return "Pileta climatizada"
        case .TECHADO: return "Techado"
        case .QUINCHO_CERRADO: return "Quincho cerrado"
        case .JARDIN: return "Jardín"
        case .DECK: return "Deck"
        case .JUEGOS_NINOS: return "Juegos para niños"
        case .PELOTERO: return "Pelotero"
        case .HAMACAS: return "Hamacas"
        case .TOBOGAN: return "Tobogán"
        case .ARENERO: return "Arenero"
        case .MUSICA: return "Equipo de música"
        case .PROYECTOR: return "Proyector"
        case .METEGOL: return "Metegol"
        case .PING_PONG: return "Ping pong"
        case .POOL: return "Pool"
        case .CANCHA_FUTBOL: return "Cancha de fútbol"
        case .CANCHA_TENIS: return "Cancha de tenis"
        case .WIFI: return "Wi-Fi"
        case .AIRE_ACONDICIONADO: return "Aire acondicionado"
        case .CALEFACCION: return "Calefacción"
        case .ESTACIONAMIENTO: return "Estacionamiento"
        case .SEGURIDAD: return "Seguridad"
        case .ILUMINACION: return "Iluminación"
        case .BANO: return "Baño"
        case .DUCHA: return "Ducha"
        case .VESTUARIO: return "Vestuario"
        case .MESAS_SILLAS: return "Mesas y sillas"
        case .ACCESIBLE: return "Accesible"
        case .APTO_MASCOTAS: return "Apto mascotas"
        }
    }

    var icono: String {
        switch self {
        case .PARRILLA, .FOGON: return "flame"
        case .HORNO_BARRO: return "flame.circle"
        case .ASADOR_CRIOLLO: return "flame.fill"
        case .COCINA: return "fork.knife"
        case .HELADERA: return "refrigerator"
        case .FREEZER, .AIRE_ACONDICIONADO: return "snowflake"
        case .MICROONDAS: return "microwave"
        case .VAJILLA: return "wineglass"
        case .PILETA: return "drop.fill"
        case .PILETA_CLIMATIZADA: return "drop.circle.fill"
        case .TECHADO: return "house.fill"
        case .QUINCHO_CERRADO: return "building.2"
        case .JARDIN: return "leaf.fill"
        case .DECK: return "square.split.bottomrightquarter"
        case .JUEGOS_NINOS: return "figure.play"
        case .PELOTERO: return "circle.grid.3x3.fill"
        case .HAMACAS: return "figure.and.child.holdinghands"
        case .TOBOGAN: return "arrow.down.right"
        case .ARENERO: return "square.grid.3x3.fill"
        case .MUSICA: return "music.note"
        case .PROYECTOR: return "tv"
        case .METEGOL: return "sportscourt"
        case .PING_PONG: return "figure.table.tennis"
        case .POOL: return "circle.circle"
        case .CANCHA_FUTBOL: return "sportscourt.fill"
        case .CANCHA_TENIS: return "figure.tennis"
        case .WIFI: return "wifi"
        case .CALEFACCION: return "heater.vertical"
        case .ESTACIONAMIENTO: return "car.fill"
        case .SEGURIDAD: return "shield.checkered"
        case .ILUMINACION: return "lightbulb.fill"
        case .BANO: return "toilet"
        case .DUCHA: return "shower.fill"
        case .VESTUARIO: return "door.left.hand.open"
        case .MESAS_SILLAS: return "tablecells"
        case .ACCESIBLE: return "figure.roll"
        case .APTO_MASCOTAS: return "pawprint.fill"
        }
    }
}

// MARK: - Reserva

struct Reserva: Codable, Identifiable {
    let id: String
    let fecha: String
    let horaInicio: String
    let horaFin: String
    let cantidadPersonas: Int
    let precioTotal: Int
    let estado: EstadoReserva
    let notas: String?
    let motivoCancelacion: String?
    let quincho: QuinchoResumen?
    let usuario: UsuarioResumen?
}

struct QuinchoResumen: Codable {
    let id: String
    let nombre: String
    let direccion: String
    let ciudad: String
    let tipo: TipoEspacio
    let precioDia: Int
    let imagenes: [QuinchoImagen]?
}

struct UsuarioResumen: Codable {
    let id: String
    let nombre: String
    let email: String?
    let telefono: String?
}

enum EstadoReserva: String, Codable {
    case PENDIENTE, CONFIRMADA, CANCELADA, COMPLETADA, RECHAZADA

    var label: String {
        switch self {
        case .PENDIENTE: return "Pendiente"
        case .CONFIRMADA: return "Confirmada"
        case .CANCELADA: return "Cancelada"
        case .COMPLETADA: return "Completada"
        case .RECHAZADA: return "Rechazada"
        }
    }

    var color: String {
        switch self {
        case .PENDIENTE: return "estadoPendiente"
        case .CONFIRMADA: return "estadoConfirmada"
        case .CANCELADA: return "estadoCancelada"
        case .COMPLETADA: return "estadoCompletada"
        case .RECHAZADA: return "estadoCancelada"
        }
    }
}

// MARK: - Reseña

struct Resena: Codable, Identifiable {
    let id: String
    let calificacion: Int
    let comentario: String
    let fecha: String?
    let usuario: ResenaUsuario?
    let respuestaPropietario: String?
}

struct ResenaUsuario: Codable {
    let id: String
    let nombre: String
    let avatar: String?
}

// MARK: - API Responses

struct QuinchosResponse: Codable {
    let ok: Bool
    let data: [Quincho]
    let paginacion: Paginacion?
}

struct QuinchoResponse: Codable {
    let ok: Bool
    let data: Quincho
}

struct ReservasResponse: Codable {
    let ok: Bool
    let data: [Reserva]
}

struct ReservaResponse: Codable {
    let ok: Bool
    let data: Reserva
}

struct ResenasResponse: Codable {
    let ok: Bool
    let data: [Resena]
    let paginacion: Paginacion?
}

struct ResenaResponse: Codable {
    let ok: Bool
    let data: Resena
}

struct FavoritoResponse: Codable {
    let ok: Bool
    let favorito: Bool
}

struct MessageResponse: Codable {
    let ok: Bool
    let message: String?
    let error: String?
}

struct Paginacion: Codable {
    let total: Int
    let pagina: Int
    let porPagina: Int
    let totalPaginas: Int
}
