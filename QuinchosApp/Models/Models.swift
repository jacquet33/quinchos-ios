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
    case PARRILLA, PILETA, ESTACIONAMIENTO, WIFI, AIRE_ACONDICIONADO
    case COCINA, BANO, JUEGOS_NINOS, MUSICA, VAJILLA
    case MESAS_SILLAS, SEGURIDAD, TECHADO

    var label: String {
        switch self {
        case .PARRILLA: return "Parrilla"
        case .PILETA: return "Pileta"
        case .ESTACIONAMIENTO: return "Estacionamiento"
        case .WIFI: return "Wi-Fi"
        case .AIRE_ACONDICIONADO: return "Aire Acondicionado"
        case .COCINA: return "Cocina"
        case .BANO: return "Baño"
        case .JUEGOS_NINOS: return "Juegos Niños"
        case .MUSICA: return "Música"
        case .VAJILLA: return "Vajilla"
        case .MESAS_SILLAS: return "Mesas y Sillas"
        case .SEGURIDAD: return "Seguridad"
        case .TECHADO: return "Techado"
        }
    }

    var icono: String {
        switch self {
        case .PARRILLA: return "flame"
        case .PILETA: return "drop.fill"
        case .ESTACIONAMIENTO: return "car.fill"
        case .WIFI: return "wifi"
        case .AIRE_ACONDICIONADO: return "snowflake"
        case .COCINA: return "fork.knife"
        case .BANO: return "shower.fill"
        case .JUEGOS_NINOS: return "figure.play"
        case .MUSICA: return "music.note"
        case .VAJILLA: return "wineglass.fill"
        case .MESAS_SILLAS: return "tablecells"
        case .SEGURIDAD: return "shield.checkered"
        case .TECHADO: return "house.fill"
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
