import Foundation
import SwiftUI
import UserNotifications

// MARK: - Contador global de pendientes

@MainActor
final class BadgeManager: ObservableObject {
    static let shared = BadgeManager()

    /// Reservas pendientes de confirmar (propietario)
    @Published var reservasPendientes = 0

    /// Reservas del usuario que cambiaron de estado y no vio
    @Published var reservasActualizadas = 0

    private var timer: Timer?
    private var estadosConocidos: [String: String] = [:]

    private init() {}

    // ─── Refrescar contadores ───
    func refrescar(esPropietario: Bool) async {
        if esPropietario {
            await contarReservasPendientes()
        }
        await detectarCambiosEnMisReservas()
        actualizarBadgeApp()
    }

    /// Badge en el ícono de la app en el home screen
    private func actualizarBadgeApp() {
        let total = reservasPendientes + reservasActualizadas
        UNUserNotificationCenter.current().setBadgeCount(total) { _ in }
    }

    // ─── Auto-refresh cada 60 segundos ───
    func iniciarAutoRefresh(esPropietario: Bool) {
        detener()
        Task { await refrescar(esPropietario: esPropietario) }

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                await self.refrescar(esPropietario: esPropietario)
            }
        }
    }

    func detener() {
        timer?.invalidate()
        timer = nil
    }

    func limpiarPendientes() {
        reservasPendientes = 0
        actualizarBadgeApp()
    }

    func limpiarActualizadas() {
        reservasActualizadas = 0
        actualizarBadgeApp()
    }

    // ─── Reservas pendientes del propietario ───
    private func contarReservasPendientes() async {
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/reservas/propietario/recibidas?estado=PENDIENTE")
        else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let resp = try? JSONDecoder().decode(ReservasResponse.self, from: data)
        else { return }

        reservasPendientes = resp.data.count
    }

    // ─── Detectar cambios de estado en mis reservas ───
    private func detectarCambiosEnMisReservas() async {
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/reservas/mis-reservas")
        else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let resp = try? JSONDecoder().decode(ReservasResponse.self, from: data)
        else { return }

        // Primera carga: solo guardamos el estado inicial
        if estadosConocidos.isEmpty {
            for r in resp.data { estadosConocidos[r.id] = r.estado.rawValue }
            return
        }

        var cambios = 0
        for r in resp.data {
            let anterior = estadosConocidos[r.id]
            if anterior != nil && anterior != r.estado.rawValue {
                cambios += 1
            }
            estadosConocidos[r.id] = r.estado.rawValue
        }

        if cambios > 0 { reservasActualizadas += cambios }
    }
}

// MARK: - Badge visual reutilizable

struct BadgeCircle: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, count > 9 ? 5 : 0)
                .frame(minWidth: 18, minHeight: 18)
                .background(Color.appError)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Modificador para poner badge en cualquier vista

struct BadgeOverlay: ViewModifier {
    let count: Int

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if count > 0 {
                BadgeCircle(count: count)
                    .offset(x: 8, y: -8)
            }
        }
    }
}

extension View {
    func badge(count: Int) -> some View {
        modifier(BadgeOverlay(count: count))
    }
}
