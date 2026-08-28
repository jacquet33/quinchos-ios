import Foundation

// MARK: - Dashboard Data Models

struct DashboardData {
    let reservasPendientes: Int
    let reservasConfirmadas: Int
    let ingresosMes: Int
    let proximasReservas: [Reserva]
    
    var ingresosMesFormatted: String { ingresosMes.formattedPrecio }
}

struct ClienteInfo: Identifiable {
    let id: String
    let nombre: String
    let email: String
    let totalReservas: Int
    let totalGastado: Int
}

struct AgendaDia: Identifiable {
    let id = UUID()
    let diaSemana: Int
    let diaNombre: String
    var habilitado: Bool
    let horaApertura: String
    let horaCierre: String
    let precioEspecial: Int?
}

struct BloqueoInfo: Identifiable {
    let id: String
    let fecha: String
    let motivo: String?
}

// MARK: - Dashboard ViewModel

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var dashboard: DashboardData?
    
    func cargar() async {
        guard let token = await APIService.shared.getToken() else { return }
        guard let url = URL(string: "\(APIConfig.baseURL)/dashboard") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = json["data"] as? [String: Any],
              let resumen = d["resumen"] as? [String: Any],
              let reservas = resumen["reservas"] as? [String: Any],
              let ingresos = resumen["ingresos"] as? [String: Any] else { return }
        
        let proximas = (d["proximasReservas"] as? [[String: Any]])?.compactMap { r -> Reserva? in
            guard let data = try? JSONSerialization.data(withJSONObject: r),
                  let reserva = try? JSONDecoder().decode(Reserva.self, from: data) else { return nil }
            return reserva
        } ?? []
        
        dashboard = DashboardData(
            reservasPendientes: reservas["pendientes"] as? Int ?? 0,
            reservasConfirmadas: reservas["confirmadas"] as? Int ?? 0,
            ingresosMes: ingresos["esteMes"] as? Int ?? 0,
            proximasReservas: proximas
        )
    }
    
    func confirmar(_ id: String) { Task { await accion(id, endpoint: "confirmar"); await cargar() } }
    func rechazar(_ id: String) { Task { await accion(id, endpoint: "rechazar"); await cargar() } }
    
    private func accion(_ id: String, endpoint: String) async {
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/reservas/\(id)/\(endpoint)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = "{}".data(using: .utf8)
        _ = try? await URLSession.shared.data(for: req)
    }
}

// MARK: - Mis Quinchos ViewModel

@MainActor
class MisQuinchosViewModel: ObservableObject {
    @Published var quinchos: [Quincho] = []
    
    func cargar() async {
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/quinchos/usuario/mis-quinchos") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(QuinchosResponse.self, from: data) else { return }
        quinchos = resp.data
    }
}

// MARK: - Reservas Recibidas ViewModel

@MainActor
class ReservasRecibidasViewModel: ObservableObject {
    @Published var reservas: [Reserva] = []
    
    func cargar() async {
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/reservas/propietario/recibidas") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(ReservasResponse.self, from: data) else { return }
        reservas = resp.data
    }
    
    func confirmar(_ id: String) { Task { await accion(id, "confirmar"); await cargar() } }
    func rechazar(_ id: String) { Task { await accion(id, "rechazar"); await cargar() } }
    
    private func accion(_ id: String, _ endpoint: String) async {
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/reservas/\(id)/\(endpoint)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = "{}".data(using: .utf8)
        _ = try? await URLSession.shared.data(for: req)
    }
}

// MARK: - Clientes ViewModel

@MainActor
class ClientesViewModel: ObservableObject {
    @Published var clientes: [ClienteInfo] = []
    
    func cargar() async {
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/dashboard/clientes") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]] else { return }
        
        clientes = items.compactMap { c in
            guard let id = c["id"] as? String,
                  let nombre = c["nombre"] as? String,
                  let email = c["email"] as? String else { return nil }
            return ClienteInfo(
                id: id, nombre: nombre, email: email,
                totalReservas: c["totalReservas"] as? Int ?? 0,
                totalGastado: c["totalGastado"] as? Int ?? 0
            )
        }
    }
}

// MARK: - Agenda ViewModel

@MainActor
class AgendaViewModel: ObservableObject {
    @Published var dias: [AgendaDia] = []
    private let diasNombre = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
    
    func cargar(quinchoId: String) async {
        guard let url = URL(string: "\(APIConfig.baseURL)/agenda/\(quinchoId)/agenda") else { return }
        guard let (data, _) = try? await URLSession.shared.data(for: URLRequest(url: url)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]] else { return }
        
        dias = items.compactMap { d in
            guard let diaSemana = d["diaSemana"] as? Int else { return nil }
            return AgendaDia(
                diaSemana: diaSemana,
                diaNombre: d["diaNombre"] as? String ?? diasNombre[diaSemana],
                habilitado: d["habilitado"] as? Bool ?? true,
                horaApertura: d["horaApertura"] as? String ?? "08:00",
                horaCierre: d["horaCierre"] as? String ?? "00:00",
                precioEspecial: d["precioEspecial"] as? Int
            )
        }
    }
    
    func toggleDia(quinchoId: String, dia: Int, habilitado: Bool) {
        Task {
            guard let token = await APIService.shared.getToken(),
                  let url = URL(string: "\(APIConfig.baseURL)/agenda/\(quinchoId)/agenda/\(dia)") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "PATCH"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["habilitado": habilitado])
            _ = try? await URLSession.shared.data(for: req)
            await cargar(quinchoId: quinchoId)
        }
    }
}

// MARK: - Bloqueo ViewModel

@MainActor
class BloqueoViewModel: ObservableObject {
    @Published var bloqueos: [BloqueoInfo] = []
    
    func cargar(quinchoId: String) async {
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/agenda/\(quinchoId)/bloqueos") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]] else { return }
        
        bloqueos = items.compactMap { b in
            guard let id = b["id"] as? String, let fecha = b["fecha"] as? String else { return nil }
            return BloqueoInfo(id: id, fecha: String(fecha.prefix(10)), motivo: b["motivo"] as? String)
        }
    }
    
    func bloquear(quinchoId: String, fecha: String, motivo: String) async {
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/agenda/\(quinchoId)/bloqueos") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["fechas": [fecha], "motivo": motivo.isEmpty ? nil : motivo])
        _ = try? await URLSession.shared.data(for: req)
        await cargar(quinchoId: quinchoId)
    }
    
    func desbloquear(quinchoId: String, fecha: String) async {
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/agenda/\(quinchoId)/bloqueos/\(fecha)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
        await cargar(quinchoId: quinchoId)
    }
}
