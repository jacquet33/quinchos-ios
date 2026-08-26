import Foundation

@MainActor
final class QuinchosViewModel: ObservableObject {
    @Published var quinchos: [Quincho] = []
    @Published var destacados: [Quincho] = []
    @Published var quinchoDetalle: Quincho?
    @Published var isLoading = false
    @Published var error: String?

    // Filtros
    @Published var searchQuery = ""
    @Published var tipoSeleccionado: String = "todos"
    @Published var radioKm: Double = 20
    @Published var precioMax: Int?
    @Published var ordenarPor: String = "calificacion"

    // Resultados con distancia (del endpoint /mapa)
    @Published var quinchosMapa: [QuinchoMapa] = []

    private let api = APIService.shared

    // ─── Búsqueda con GPS ───
    func buscar(lat: Double? = nil, lng: Double? = nil) async {
        isLoading = true
        do {
            let response = try await api.buscarQuinchos(
                query: searchQuery.isEmpty ? nil : searchQuery,
                tipo: tipoSeleccionado == "todos" ? nil : tipoSeleccionado,
                precioMax: precioMax,
                ordenarPor: (lat != nil) ? "distancia" : ordenarPor,
                lat: lat,
                lng: lng,
                radio: (lat != nil) ? radioKm : nil
            )
            quinchos = response.data
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // ─── Quinchos para el mapa (con distancia) ───
    func cargarMapa(lat: Double, lng: Double, radio: Double = 50) async {
        do {
            let response = try await api.quinchosParaMapa(lat: lat, lng: lng, radio: radio)
            quinchosMapa = response.data
        } catch {
            print("Error cargando mapa: \(error)")
        }
    }

    func cargarDestacados() async {
        do {
            let response = try await api.destacados()
            destacados = response.data
        } catch {
            print("Error cargando destacados: \(error)")
        }
    }

    func cargarDetalle(id: String) async {
        isLoading = true
        do {
            let response = try await api.quincho(id: id)
            quinchoDetalle = response.data
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Modelo para respuesta de mapa

struct QuinchoMapa: Codable, Identifiable {
    let id: String
    let nombre: String
    let tipo: TipoEspacio
    let latitud: Double
    let longitud: Double
    let precioDia: Int
    let precioHora: Int
    let calificacionProm: Double
    let totalResenas: Int
    let direccion: String
    let ciudad: String
    let capacidadMax: Int
    let imagenes: [QuinchoImagen]?
    let distanciaKm: Double?
}

struct QuinchosMapaResponse: Codable {
    let ok: Bool
    let total: Int
    let data: [QuinchoMapa]
}
