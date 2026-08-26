import Foundation

// MARK: - API Configuration

enum APIConfig {
    #if DEBUG
    static let baseURL = "http://localhost:3000/api"
    #else
    static let baseURL = "https://tu-backend.com/api"
    #endif
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed
    case serverError(String)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL inválida"
        case .noData: return "Sin datos"
        case .decodingFailed: return "Error al procesar respuesta"
        case .serverError(let msg): return msg
        case .unauthorized: return "Sesión expirada"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

// MARK: - API Service

actor APIService {
    static let shared = APIService()
    private init() {}

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()

    // MARK: - Token Management

    private var token: String? {
        get { UserDefaults.standard.string(forKey: "jwt_token") }
        set { UserDefaults.standard.set(newValue, forKey: "jwt_token") }
    }

    func setToken(_ token: String?) {
        self.token = token
    }

    func getToken() -> String? {
        return token
    }

    func isAuthenticated() -> Bool {
        return token != nil
    }

    func logout() {
        self.token = nil
        UserDefaults.standard.removeObject(forKey: "jwt_token")
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        method: String,
        path: String,
        body: Encodable? = nil,
        requireAuth: Bool = false
    ) async throws -> T {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        if requireAuth, let token = self.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? decoder.decode(MessageResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error ?? "Error desconocido")
            }
            throw APIError.serverError("Error \(httpResponse.statusCode)")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("❌ Decoding error: \(error)")
            throw APIError.decodingFailed
        }
    }

    // MARK: - Auth

    func registro(email: String, password: String, nombre: String, rol: String = "USUARIO") async throws -> AuthResponse {
        struct Body: Encodable { let email, password, nombre, rol: String }
        let response: AuthResponse = try await request(
            method: "POST",
            path: "/auth/registro",
            body: Body(email: email, password: password, nombre: nombre, rol: rol)
        )
        self.token = response.token
        return response
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { let email, password: String }
        let response: AuthResponse = try await request(
            method: "POST",
            path: "/auth/login",
            body: Body(email: email, password: password)
        )
        self.token = response.token
        return response
    }

    func perfil() async throws -> PerfilResponse {
        try await request(method: "GET", path: "/auth/perfil", requireAuth: true)
    }

    // MARK: - Quinchos

    func buscarQuinchos(
        query: String? = nil,
        tipo: String? = nil,
        precioMax: Int? = nil,
        capacidadMin: Int? = nil,
        amenidades: [String]? = nil,
        ordenarPor: String? = nil,
        ciudad: String? = nil,
        page: Int = 1
    ) async throws -> QuinchosResponse {
        var params: [String] = ["page=\(page)"]
        if let q = query, !q.isEmpty { params.append("q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)") }
        if let t = tipo, t != "todos" { params.append("tipo=\(t)") }
        if let p = precioMax { params.append("precioMax=\(p)") }
        if let c = capacidadMin { params.append("capacidadMin=\(c)") }
        if let a = amenidades, !a.isEmpty { params.append("amenidades=\(a.joined(separator: ","))") }
        if let o = ordenarPor { params.append("ordenarPor=\(o)") }
        if let ci = ciudad { params.append("ciudad=\(ci.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ci)") }
        let qs = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        return try await request(method: "GET", path: "/quinchos\(qs)")
    }

    func destacados() async throws -> QuinchosResponse {
        try await request(method: "GET", path: "/quinchos/destacados")
    }

    func quincho(id: String) async throws -> QuinchoResponse {
        try await request(method: "GET", path: "/quinchos/\(id)")
    }

    func toggleFavorito(quinchoId: String) async throws -> FavoritoResponse {
        try await request(method: "POST", path: "/quinchos/\(quinchoId)/favorito", requireAuth: true)
    }

    func misFavoritos() async throws -> QuinchosResponse {
        try await request(method: "GET", path: "/quinchos/usuario/favoritos", requireAuth: true)
    }

    // MARK: - Reservas

    func crearReserva(
        quinchoId: String,
        fecha: String,
        horaInicio: String,
        horaFin: String,
        cantidadPersonas: Int,
        notas: String?
    ) async throws -> ReservaResponse {
        struct Body: Encodable {
            let quinchoId, fecha, horaInicio, horaFin: String
            let cantidadPersonas: Int
            let notas: String?
        }
        return try await request(
            method: "POST",
            path: "/reservas",
            body: Body(quinchoId: quinchoId, fecha: fecha, horaInicio: horaInicio, horaFin: horaFin, cantidadPersonas: cantidadPersonas, notas: notas),
            requireAuth: true
        )
    }

    func misReservas() async throws -> ReservasResponse {
        try await request(method: "GET", path: "/reservas/mis-reservas", requireAuth: true)
    }

    func cancelarReserva(id: String) async throws -> ReservaResponse {
        try await request(method: "POST", path: "/reservas/\(id)/cancelar", requireAuth: true)
    }

    // MARK: - Reseñas

    func resenasQuincho(quinchoId: String, page: Int = 1) async throws -> ResenasResponse {
        try await request(method: "GET", path: "/resenas/quincho/\(quinchoId)?page=\(page)")
    }

    func crearResena(quinchoId: String, calificacion: Int, comentario: String, reservaId: String? = nil) async throws -> ResenaResponse {
        struct Body: Encodable { let quinchoId: String; let calificacion: Int; let comentario: String; let reservaId: String? }
        return try await request(
            method: "POST",
            path: "/resenas",
            body: Body(quinchoId: quinchoId, calificacion: calificacion, comentario: comentario, reservaId: reservaId),
            requireAuth: true
        )
    }
}
