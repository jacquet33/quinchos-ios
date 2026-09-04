import SwiftUI

// MARK: - Modelos

enum EstiloInvitacion: String, Codable, CaseIterable {
    case ELEGANTE, FIESTA, INFANTIL, CORPORATIVO, CAMPESTRE

    var nombre: String {
        switch self {
        case .ELEGANTE: return "Elegante"
        case .FIESTA: return "Fiesta"
        case .INFANTIL: return "Infantil"
        case .CORPORATIVO: return "Corporativo"
        case .CAMPESTRE: return "Campestre"
        }
    }

    var descripcion: String {
        switch self {
        case .ELEGANTE: return "Bodas, aniversarios"
        case .FIESTA: return "Cumpleaños, celebraciones"
        case .INFANTIL: return "Cumples de chicos"
        case .CORPORATIVO: return "Eventos de empresa"
        case .CAMPESTRE: return "Asados, encuentros"
        }
    }

    var emoji: String {
        switch self {
        case .ELEGANTE: return "💍"
        case .FIESTA: return "🎉"
        case .INFANTIL: return "🎈"
        case .CORPORATIVO: return "💼"
        case .CAMPESTRE: return "🔥"
        }
    }

    var color: Color {
        switch self {
        case .ELEGANTE: return Color(hex: "c9a227")
        case .FIESTA: return .appPrimary
        case .INFANTIL: return Color(hex: "2ba3d4")
        case .CORPORATIVO: return Color(hex: "33475b")
        case .CAMPESTRE: return Color(hex: "6b8e4e")
        }
    }
}

struct Invitacion: Codable, Identifiable {
    let id: String
    let codigo: String
    let titulo: String
    let mensaje: String
    let estilo: EstiloInvitacion
    let dressCode: String?
    let notas: String?
    let activa: Bool
    let url: String
    let resumen: ResumenInvitados?
    let invitados: [Invitado]?
}

struct ResumenInvitados: Codable {
    let total: Int
    let confirmados: Int
    let rechazados: Int
    let pendientes: Int
    let personasConfirmadas: Int
}

struct Invitado: Codable, Identifiable {
    let id: String
    let nombre: String
    let email: String?
    let telefono: String?
    let estado: String
    let acompanantes: Int
    let mensaje: String?
    let url: String?
    let enviadoEl: String?

    var yaEnviado: Bool { enviadoEl != nil }

    var color: Color {
        switch estado {
        case "CONFIRMADO": return .appSuccess
        case "RECHAZADO": return .appError
        default: return .appWarning
        }
    }

    var etiqueta: String {
        switch estado {
        case "CONFIRMADO": return acompanantes > 0 ? "Viene +\(acompanantes)" : "Viene"
        case "RECHAZADO": return "No viene"
        default: return "Sin responder"
        }
    }
}

// MARK: - Pantalla principal de invitaciones

struct InvitacionView: View {
    let reservaId: String
    let nombreLugar: String

    @StateObject private var vm = InvitacionViewModel()
    @State private var mostrarCrear = false
    @State private var mostrarAgregar = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if vm.cargando {
                ProgressView().tint(.appPrimary)
            } else if let inv = vm.invitacion {
                contenido(inv)
            } else {
                sinInvitacion
            }
        }
        .navigationTitle("Invitación")
        .toolbar {
            if vm.invitacion != nil {
                Button { mostrarAgregar = true } label: {
                    Image(systemName: "person.badge.plus").foregroundColor(.appPrimary)
                }
            }
        }
        .sheet(isPresented: $mostrarCrear) {
            CrearInvitacionView(reservaId: reservaId) {
                Task { await vm.cargar(reservaId: reservaId) }
            }
        }
        .sheet(isPresented: $mostrarAgregar) {
            if let inv = vm.invitacion {
                AgregarInvitadosView(invitacionId: inv.id) {
                    Task { await vm.cargar(reservaId: reservaId) }
                }
            }
        }
        .task { await vm.cargar(reservaId: reservaId) }
    }

    // ─── Sin invitación todavía ───
    private var sinInvitacion: some View {
        VStack(spacing: 16) {
            Text("💌").font(.system(size: 52))
            Text("Invitá a tus invitados")
                .font(.title3).fontWeight(.bold).foregroundColor(.appTextPrimary)
            Text("Creá una invitación con la info del evento y compartila por WhatsApp. Cada invitado confirma con un toque, sin bajar la app.")
                .font(.subheadline).foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            Button { mostrarCrear = true } label: {
                Text("Crear invitación").fontWeight(.bold)
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.appPrimary).foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 8)
        }
        .padding(32)
    }

    // ─── Con invitación ───
    private func contenido(_ inv: Invitacion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Encabezado
                VStack(alignment: .leading, spacing: 6) {
                    Text(inv.estilo.emoji + " " + inv.estilo.nombre)
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(inv.estilo.color)
                    Text(inv.titulo)
                        .font(.title2).fontWeight(.bold).foregroundColor(.appTextPrimary)
                    if !inv.mensaje.isEmpty {
                        Text(inv.mensaje)
                            .font(.subheadline).foregroundColor(.appTextSecondary)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Resumen
                if let r = inv.resumen {
                    HStack(spacing: 10) {
                        contador("\(r.personasConfirmadas)", "personas", .appSuccess)
                        contador("\(r.pendientes)", "sin responder", .appWarning)
                        contador("\(r.rechazados)", "no vienen", .appTextMuted)
                    }
                }

                // Compartir general
                Button {
                    compartir(texto: "\(inv.titulo)\n\n\(inv.url)")
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Compartir invitación general").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.appSurface).foregroundColor(.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Lista de invitados
                HStack {
                    Text("Invitados").font(.headline).foregroundColor(.appTextPrimary)
                    Spacer()
                    Button { mostrarAgregar = true } label: {
                        Text("Agregar").font(.subheadline).foregroundColor(.appPrimary)
                    }
                }

                if let invitados = inv.invitados, !invitados.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(invitados) { invitado in
                            filaInvitado(invitado, titulo: inv.titulo)
                        }
                    }
                } else {
                    Text("Todavía no agregaste invitados")
                        .font(.subheadline).foregroundColor(.appTextMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                }
            }
            .padding()
        }
    }

    private func contador(_ numero: String, _ texto: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(numero).font(.title3).fontWeight(.bold).foregroundColor(color)
            Text(texto).font(.caption2).foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func filaInvitado(_ invitado: Invitado, titulo: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(invitado.color).frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(invitado.nombre)
                    .font(.subheadline).fontWeight(.medium).foregroundColor(.appTextPrimary)
                Text(invitado.etiqueta)
                    .font(.caption2).foregroundColor(invitado.color)
                if let m = invitado.mensaje, !m.isEmpty {
                    Text("“\(m)”")
                        .font(.caption2).foregroundColor(.appTextMuted)
                        .italic().lineLimit(2)
                }
            }

            Spacer()

            if let url = invitado.url {
                Button {
                    compartir(texto: "¡Hola \(invitado.nombre)! Te invito a \(titulo)\n\n\(url)")
                    Task { await vm.marcarEnviado(invitado.id) }
                } label: {
                    Image(systemName: invitado.yaEnviado ? "checkmark.circle.fill" : "square.and.arrow.up")
                        .foregroundColor(invitado.yaEnviado ? .appSuccess : .appPrimary)
                }
            }
        }
        .padding(12)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .swipeActions {
            Button(role: .destructive) {
                Task { await vm.eliminarInvitado(invitado.id, reservaId: reservaId) }
            } label: { Label("Quitar", systemImage: "trash") }
        }
    }

    private func compartir(texto: String) {
        let vc = UIActivityViewController(activityItems: [texto], applicationActivities: nil)
        guard let escena = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = escena.windows.first?.rootViewController else { return }
        // En iPad necesita un punto de origen
        vc.popoverPresentationController?.sourceView = root.view
        vc.popoverPresentationController?.sourceRect = CGRect(
            x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0
        )
        root.present(vc, animated: true)
    }
}

// MARK: - Crear invitación

struct CrearInvitacionView: View {
    let reservaId: String
    let alCrear: () -> Void

    @StateObject private var vm = InvitacionViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var titulo = ""
    @State private var mensaje = ""
    @State private var estilo: EstiloInvitacion = .ELEGANTE
    @State private var dressCode = ""
    @State private var notas = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {

                        // Estilo
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Estilo de la invitación")
                                .font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(EstiloInvitacion.allCases, id: \.self) { e in
                                        Button { estilo = e } label: {
                                            VStack(spacing: 4) {
                                                Text(e.emoji).font(.title2)
                                                Text(e.nombre).font(.caption).fontWeight(.semibold)
                                                Text(e.descripcion).font(.caption2)
                                                    .foregroundColor(.appTextMuted)
                                                    .multilineTextAlignment(.center)
                                            }
                                            .foregroundColor(estilo == e ? .appTextPrimary : .appTextSecondary)
                                            .frame(width: 110).padding(.vertical, 12)
                                            .background(estilo == e ? e.color.opacity(0.15) : Color.appSurface)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(estilo == e ? e.color : Color.appBorder,
                                                            lineWidth: estilo == e ? 2 : 1)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        FormField(label: "Título", placeholder: ejemploTitulo, text: $titulo)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mensaje").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                            TextEditor(text: $mensaje)
                                .frame(minHeight: 110)
                                .foregroundColor(.appTextPrimary)
                                .scrollContentBackground(.hidden)
                                .padding(10).background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))

                            if mensaje.isEmpty {
                                Button("Usar un texto de ejemplo") { mensaje = ejemploMensaje }
                                    .font(.caption).foregroundColor(.appPrimary)
                            }
                        }

                        FormField(label: "Vestimenta (opcional)", placeholder: "Elegante sport", text: $dressCode)
                        FormField(label: "Nota (opcional)", placeholder: "Confirmar antes del 20", text: $notas)

                        if let e = vm.error {
                            Text(e).font(.caption).foregroundColor(.appError)
                        }

                        Button {
                            Task {
                                let ok = await vm.crear(
                                    reservaId: reservaId, titulo: titulo, mensaje: mensaje,
                                    estilo: estilo, dressCode: dressCode, notas: notas
                                )
                                if ok { alCrear(); dismiss() }
                            }
                        } label: {
                            Group {
                                if vm.cargando { ProgressView().tint(.white) }
                                else { Text("Crear invitación").fontWeight(.bold) }
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(titulo.count >= 3 ? Color.appPrimary : Color.appSurfaceLight)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(titulo.count < 3 || vm.cargando)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Nueva invitación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundColor(.appTextSecondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { hideKeyboard() }
                        .fontWeight(.semibold).foregroundColor(.appPrimary)
                }
            }
        }
    }

    private var ejemploTitulo: String {
        switch estilo {
        case .ELEGANTE: return "Boda de Ale y Anto"
        case .FIESTA: return "Los 30 de Martín"
        case .INFANTIL: return "Cumple de Sofi"
        case .CORPORATIVO: return "Cena de fin de año"
        case .CAMPESTRE: return "Asado del sábado"
        }
    }

    private var ejemploMensaje: String {
        switch estilo {
        case .ELEGANTE:
            return "Hay momentos en la vida que son especiales por sí solos, pero compartirlos con las personas que uno quiere los transforma en inolvidables.\n\nNos encantaría que nos acompañes en este día tan importante para nosotros."
        case .FIESTA:
            return "¡Se armó! Te espero para festejar juntos.\n\nVení con ganas de pasarla bien, que la vamos a pasar bárbaro."
        case .INFANTIL:
            return "¡Vamos a festejar!\n\nTe esperamos con juegos, torta y muchas sorpresas. No faltes."
        case .CORPORATIVO:
            return "Nos gustaría contar con tu presencia para celebrar juntos el cierre de este año de trabajo.\n\nTe esperamos."
        case .CAMPESTRE:
            return "Se viene un asado como la gente.\n\nTraé la sed, que del fuego nos encargamos nosotros."
        }
    }
}

// MARK: - Agregar invitados

struct AgregarInvitadosView: View {
    let invitacionId: String
    let alAgregar: () -> Void

    @StateObject private var vm = InvitacionViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var lineas: [NuevoInvitado] = [NuevoInvitado()]

    struct NuevoInvitado: Identifiable {
        let id = UUID()
        var nombre = ""
        var contacto = ""
    }

    var validos: [NuevoInvitado] {
        lineas.filter { $0.nombre.trimmingCharacters(in: .whitespaces).count >= 2 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Agregá los nombres. A cada uno le vas a poder mandar su link personal por WhatsApp.")
                            .font(.subheadline).foregroundColor(.appTextSecondary)

                        ForEach($lineas) { $linea in
                            HStack(spacing: 10) {
                                VStack(spacing: 8) {
                                    TextField("Nombre", text: $linea.nombre)
                                        .foregroundColor(.appTextPrimary)
                                        .padding(11).background(Color.appSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    TextField("Email o teléfono (opcional)", text: $linea.contacto)
                                        .foregroundColor(.appTextPrimary)
                                        .textInputAutocapitalization(.never)
                                        .padding(11).background(Color.appSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                if lineas.count > 1 {
                                    Button {
                                        lineas.removeAll { $0.id == linea.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.appError)
                                    }
                                }
                            }
                        }

                        Button {
                            lineas.append(NuevoInvitado())
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                Text("Agregar otro")
                            }
                            .font(.subheadline).foregroundColor(.appPrimary)
                        }

                        if let e = vm.error {
                            Text(e).font(.caption).foregroundColor(.appError)
                        }

                        Button {
                            Task {
                                let ok = await vm.agregarInvitados(
                                    invitacionId: invitacionId,
                                    invitados: validos.map {
                                        (nombre: $0.nombre, contacto: $0.contacto)
                                    }
                                )
                                if ok { alAgregar(); dismiss() }
                            }
                        } label: {
                            Group {
                                if vm.cargando { ProgressView().tint(.white) }
                                else { Text("Agregar \(validos.count) invitado\(validos.count == 1 ? "" : "s")").fontWeight(.bold) }
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(validos.isEmpty ? Color.appSurfaceLight : Color.appPrimary)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(validos.isEmpty || vm.cargando)
                        .padding(.top, 6)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Agregar invitados")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundColor(.appTextSecondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { hideKeyboard() }
                        .fontWeight(.semibold).foregroundColor(.appPrimary)
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class InvitacionViewModel: ObservableObject {
    @Published var invitacion: Invitacion?
    @Published var cargando = false
    @Published var error: String?

    private func pedir(_ metodo: String, _ ruta: String, cuerpo: [String: Any]? = nil) async -> Data? {
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)\(ruta)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = metodo
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let cuerpo { request.httpBody = try? JSONSerialization.data(withJSONObject: cuerpo) }

        guard let (data, respuesta) = try? await URLSession.shared.data(for: request),
              let http = respuesta as? HTTPURLResponse else {
            error = "No se pudo conectar"
            return nil
        }

        if http.statusCode >= 400 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                error = json["error"] as? String ?? "Ocurrió un error"
            }
            return nil
        }
        return data
    }

    func cargar(reservaId: String) async {
        cargando = true
        defer { cargando = false }
        struct Resp: Codable { let ok: Bool; let data: Invitacion? }
        guard let data = await pedir("GET", "/invitaciones/reserva/\(reservaId)"),
              let resp = try? JSONDecoder().decode(Resp.self, from: data) else { return }
        invitacion = resp.data
    }

    func crear(reservaId: String, titulo: String, mensaje: String,
               estilo: EstiloInvitacion, dressCode: String, notas: String) async -> Bool {
        cargando = true
        error = nil
        defer { cargando = false }

        let cuerpo: [String: Any] = [
            "titulo": titulo,
            "mensaje": mensaje,
            "estilo": estilo.rawValue,
            "dressCode": dressCode,
            "notas": notas,
        ]
        return await pedir("POST", "/invitaciones/reserva/\(reservaId)", cuerpo: cuerpo) != nil
    }

    func agregarInvitados(invitacionId: String,
                          invitados: [(nombre: String, contacto: String)]) async -> Bool {
        cargando = true
        error = nil
        defer { cargando = false }

        let lista = invitados.map { inv -> [String: Any] in
            var dic: [String: Any] = ["nombre": inv.nombre]
            let contacto = inv.contacto.trimmingCharacters(in: .whitespaces)
            if contacto.contains("@") { dic["email"] = contacto }
            else if !contacto.isEmpty { dic["telefono"] = contacto }
            return dic
        }

        return await pedir("POST", "/invitaciones/\(invitacionId)/invitados",
                           cuerpo: ["invitados": lista]) != nil
    }

    func eliminarInvitado(_ invitadoId: String, reservaId: String) async {
        _ = await pedir("DELETE", "/invitaciones/invitados/\(invitadoId)")
        await cargar(reservaId: reservaId)
    }

    func marcarEnviado(_ invitadoId: String) async {
        _ = await pedir("POST", "/invitaciones/invitados/\(invitadoId)/enviado")
    }
}
