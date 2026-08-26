import Foundation
import SwiftUI

// MARK: - Auth ViewModel

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var usuario: Usuario?
    @Published var isLoading = false
    @Published var error: String?

    private let api = APIService.shared

    init() {
        Task {
            if await api.isAuthenticated() {
                await cargarPerfil()
            }
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        error = nil
        do {
            let response = try await api.login(email: email, password: password)
            usuario = response.usuario
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func registro(email: String, password: String, nombre: String) async {
        isLoading = true
        error = nil
        do {
            let response = try await api.registro(email: email, password: password, nombre: nombre)
            usuario = response.usuario
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func cargarPerfil() async {
        do {
            let response = try await api.perfil()
            usuario = response.usuario
            isAuthenticated = true
        } catch {
            await api.logout()
            isAuthenticated = false
        }
    }

    func logout() async {
        await api.logout()
        isAuthenticated = false
        usuario = nil
    }
}

// MARK: - Quinchos ViewModel

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

    private let api = APIService.shared

    func buscar() async {
        isLoading = true
        do {
            let response = try await api.buscarQuinchos(
                query: searchQuery.isEmpty ? nil : searchQuery,
                tipo: tipoSeleccionado == "todos" ? nil : tipoSeleccionado
            )
            quinchos = response.data
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
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

// MARK: - Reservas ViewModel

@MainActor
final class ReservasViewModel: ObservableObject {
    @Published var reservas: [Reserva] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var success: String?

    private let api = APIService.shared

    func cargarReservas() async {
        isLoading = true
        do {
            let response = try await api.misReservas()
            reservas = response.data
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func crearReserva(quinchoId: String, fecha: String, horaInicio: String, horaFin: String, personas: Int, notas: String?) async -> Bool {
        isLoading = true
        error = nil
        do {
            _ = try await api.crearReserva(
                quinchoId: quinchoId,
                fecha: fecha,
                horaInicio: horaInicio,
                horaFin: horaFin,
                cantidadPersonas: personas,
                notas: notas
            )
            success = "¡Reserva enviada correctamente!"
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func cancelarReserva(id: String) async {
        do {
            _ = try await api.cancelarReserva(id: id)
            await cargarReservas()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Favoritos ViewModel

@MainActor
final class FavoritosViewModel: ObservableObject {
    @Published var favoritos: [Quincho] = []
    @Published var favoritosIds: Set<String> = []
    @Published var isLoading = false

    private let api = APIService.shared

    func cargarFavoritos() async {
        isLoading = true
        do {
            let response = try await api.misFavoritos()
            favoritos = response.data
            favoritosIds = Set(response.data.map(\.id))
        } catch {
            print("Error cargando favoritos: \(error)")
        }
        isLoading = false
    }

    func toggleFavorito(quinchoId: String) async {
        do {
            let response = try await api.toggleFavorito(quinchoId: quinchoId)
            if response.favorito {
                favoritosIds.insert(quinchoId)
            } else {
                favoritosIds.remove(quinchoId)
                favoritos.removeAll { $0.id == quinchoId }
            }
        } catch {
            print("Error toggle favorito: \(error)")
        }
    }

    func esFavorito(_ id: String) -> Bool {
        favoritosIds.contains(id)
    }
}

// MARK: - Reseñas ViewModel

@MainActor
final class ResenasViewModel: ObservableObject {
    @Published var resenas: [Resena] = []
    @Published var isLoading = false
    @Published var error: String?

    private let api = APIService.shared

    func cargarResenas(quinchoId: String) async {
        isLoading = true
        do {
            let response = try await api.resenasQuincho(quinchoId: quinchoId)
            resenas = response.data
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func crearResena(quinchoId: String, calificacion: Int, comentario: String, reservaId: String? = nil) async -> Bool {
        isLoading = true
        error = nil
        do {
            _ = try await api.crearResena(quinchoId: quinchoId, calificacion: calificacion, comentario: comentario, reservaId: reservaId)
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }
}
