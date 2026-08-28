import SwiftUI

// MARK: - Modelos

struct ServicioExtra: Codable, Identifiable, Hashable {
    let id: String
    let nombre: String
    let descripcion: String?
    let precio: Int
    let icono: String?
    let disponible: Bool
}

struct AmenidadCatalogo: Codable, Identifiable {
    var id: String { key }
    let key: String
    let label: String
    let icono: String
}

struct CategoriaAmenidades: Codable, Identifiable {
    var id: String { categoria }
    let categoria: String
    let items: [AmenidadCatalogo]
}

struct SugerenciaServicio: Codable, Identifiable {
    var id: String { nombre }
    let nombre: String
    let icono: String
    let precioSugerido: Int
}

// MARK: - Editar Amenidades (propietario)

struct EditarAmenidadesView: View {
    let quinchoId: String
    let amenidadesActuales: [String]
    @StateObject private var vm = ServiciosViewModel()
    @State private var seleccionadas: Set<String> = []
    @State private var guardado = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Marcá todo lo que incluye tu espacio sin costo adicional")
                        .font(.subheadline).foregroundColor(.appTextSecondary)

                    ForEach(vm.catalogo) { cat in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(cat.categoria)
                                .font(.headline).foregroundColor(.appPrimary)

                            FlowLayout(spacing: 8) {
                                ForEach(cat.items) { item in
                                    let activa = seleccionadas.contains(item.key)
                                    Button {
                                        if activa { seleccionadas.remove(item.key) }
                                        else { seleccionadas.insert(item.key) }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: activa ? "checkmark.circle.fill" : item.icono)
                                                .font(.caption)
                                            Text(item.label).font(.caption)
                                        }
                                        .foregroundColor(activa ? .white : .appTextSecondary)
                                        .padding(.horizontal, 12).padding(.vertical, 9)
                                        .background(activa ? Color.appPrimary : Color.appSurface)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        Task {
                            await vm.guardarAmenidades(quinchoId: quinchoId, amenidades: Array(seleccionadas))
                            guardado = true
                        }
                    } label: {
                        Group {
                            if vm.isLoading { ProgressView().tint(.white) }
                            else { Text("Guardar (\(seleccionadas.count) seleccionadas)").fontWeight(.bold) }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.appPrimary).foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(vm.isLoading)
                }
                .padding()
            }
        }
        .navigationTitle("Comodidades")
        .task {
            seleccionadas = Set(amenidadesActuales)
            await vm.cargarCatalogo()
        }
        .alert("Comodidades actualizadas", isPresented: $guardado) {
            Button("OK") { dismiss() }
        }
    }
}

// MARK: - Gestionar Servicios Extra (propietario)

struct ServiciosExtraView: View {
    let quinchoId: String
    @StateObject private var vm = ServiciosViewModel()
    @State private var showNuevo = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if vm.servicios.isEmpty && !vm.isLoading {
                VStack(spacing: 14) {
                    Image(systemName: "plus.square.dashed").font(.system(size: 44)).foregroundColor(.appTextMuted)
                    Text("Sin servicios extra").font(.headline).foregroundColor(.appTextPrimary)
                    Text("Agregá servicios opcionales que el cliente puede sumar a su reserva, como pelotero, mozo o equipo de sonido")
                        .font(.caption).foregroundColor(.appTextMuted)
                        .multilineTextAlignment(.center)
                    Button("Agregar servicio") { showNuevo = true }
                        .fontWeight(.bold).foregroundColor(.appPrimary)
                }
                .padding(32)
            } else {
                List {
                    ForEach(vm.servicios) { s in
                        HStack(spacing: 12) {
                            Image(systemName: s.icono ?? "star")
                                .foregroundColor(.appPrimary).frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.nombre).font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(s.disponible ? .appTextPrimary : .appTextMuted)
                                if let d = s.descripcion, !d.isEmpty {
                                    Text(d).font(.caption2).foregroundColor(.appTextSecondary).lineLimit(1)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(s.precio == 0 ? "Sin cargo" : s.precio.formattedPrecio)
                                    .font(.caption).fontWeight(.bold)
                                    .foregroundColor(s.precio == 0 ? .appSuccess : .appPrimary)
                                if !s.disponible {
                                    Text("Inactivo").font(.caption2).foregroundColor(.appTextMuted)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.appCard)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await vm.eliminarServicio(s.id, quinchoId: quinchoId) }
                            } label: { Label("Eliminar", systemImage: "trash") }

                            Button {
                                Task { await vm.toggleDisponible(s, quinchoId: quinchoId) }
                            } label: {
                                Label(s.disponible ? "Ocultar" : "Mostrar", systemImage: "eye")
                            }
                            .tint(.appWarning)
                        }
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Servicios extra")
        .toolbar {
            Button { showNuevo = true } label: {
                Image(systemName: "plus").foregroundColor(.appPrimary)
            }
        }
        .sheet(isPresented: $showNuevo) {
            NuevoServicioView(quinchoId: quinchoId) {
                Task { await vm.cargarServicios(quinchoId: quinchoId, admin: true) }
            }
        }
        .task { await vm.cargarServicios(quinchoId: quinchoId, admin: true) }
    }
}

// MARK: - Nuevo Servicio

struct NuevoServicioView: View {
    let quinchoId: String
    let onCreado: () -> Void
    @StateObject private var vm = ServiciosViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var precio = ""
    @State private var iconoSeleccionado = "star"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {

                        // Sugerencias
                        if !vm.sugerencias.isEmpty && nombre.isEmpty {
                            Text("Sugerencias").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(vm.sugerencias) { s in
                                        Button {
                                            nombre = s.nombre
                                            precio = "\(s.precioSugerido)"
                                            iconoSeleccionado = s.icono
                                        } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: s.icono).font(.caption)
                                                Text(s.nombre).font(.caption)
                                            }
                                            .foregroundColor(.appTextSecondary)
                                            .padding(.horizontal, 12).padding(.vertical, 9)
                                            .background(Color.appSurface)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        FormField(label: "Nombre del servicio", placeholder: "Pelotero inflable", text: $nombre)
                        FormField(label: "Descripción (opcional)", placeholder: "Incluye armado y desarmado", text: $descripcion)
                        FormField(label: "Precio (0 = sin cargo)", placeholder: "25000", text: $precio, keyboard: .numberPad)

                        if let error = vm.error {
                            Text(error).font(.caption).foregroundColor(.appError)
                        }

                        Button {
                            Task {
                                let ok = await vm.crearServicio(
                                    quinchoId: quinchoId,
                                    nombre: nombre,
                                    descripcion: descripcion,
                                    precio: Int(precio) ?? 0,
                                    icono: iconoSeleccionado
                                )
                                if ok { onCreado(); dismiss() }
                            }
                        } label: {
                            Group {
                                if vm.isLoading { ProgressView().tint(.white) }
                                else { Text("Agregar servicio").fontWeight(.bold) }
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(nombre.count >= 2 ? Color.appPrimary : Color.appSurfaceLight)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(nombre.count < 2 || vm.isLoading)
                    }
                    .padding()
                }
            }
            .navigationTitle("Nuevo servicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundColor(.appTextSecondary)
                }
            }
            .task { await vm.cargarSugerencias() }
        }
    }
}

// MARK: - Selector de servicios al reservar (cliente)

struct SelectorServiciosView: View {
    let servicios: [ServicioExtra]
    @Binding var seleccionados: Set<String>

    var total: Int {
        servicios.filter { seleccionados.contains($0.id) }.reduce(0) { $0 + $1.precio }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Servicios adicionales").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                Spacer()
                if total > 0 {
                    Text("+\(total.formattedPrecio)").font(.caption).fontWeight(.bold).foregroundColor(.appPrimary)
                }
            }

            VStack(spacing: 0) {
                ForEach(servicios) { s in
                    let activo = seleccionados.contains(s.id)
                    Button {
                        if activo { seleccionados.remove(s.id) }
                        else { seleccionados.insert(s.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: activo ? "checkmark.square.fill" : "square")
                                .foregroundColor(activo ? .appPrimary : .appTextMuted)

                            Image(systemName: s.icono ?? "star")
                                .foregroundColor(.appTextSecondary).frame(width: 22)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.nombre).font(.subheadline).foregroundColor(.appTextPrimary)
                                if let d = s.descripcion, !d.isEmpty {
                                    Text(d).font(.caption2).foregroundColor(.appTextMuted).lineLimit(1)
                                }
                            }

                            Spacer()

                            Text(s.precio == 0 ? "Gratis" : "+\(s.precio.formattedPrecio)")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(s.precio == 0 ? .appSuccess : .appPrimary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    if s.id != servicios.last?.id {
                        Divider().background(Color.appBorder).padding(.leading, 48)
                    }
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ServiciosViewModel: ObservableObject {
    @Published var catalogo: [CategoriaAmenidades] = []
    @Published var servicios: [ServicioExtra] = []
    @Published var sugerencias: [SugerenciaServicio] = []
    @Published var isLoading = false
    @Published var error: String?

    private func request(_ method: String, _ path: String, body: [String: Any]? = nil, auth: Bool = true) async -> Data? {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth, let token = await APIService.shared.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return try? await URLSession.shared.data(for: req).0
    }

    func cargarCatalogo() async {
        struct Resp: Codable { let ok: Bool; let data: [CategoriaAmenidades] }
        guard let data = await request("GET", "/quinchos/catalogo/amenidades", auth: false),
              let resp = try? JSONDecoder().decode(Resp.self, from: data) else { return }
        catalogo = resp.data
    }

    func cargarSugerencias() async {
        struct Resp: Codable { let ok: Bool; let data: [SugerenciaServicio] }
        guard let data = await request("GET", "/quinchos/catalogo/sugerencias", auth: false),
              let resp = try? JSONDecoder().decode(Resp.self, from: data) else { return }
        sugerencias = resp.data
    }

    func cargarServicios(quinchoId: String, admin: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        struct Resp: Codable { let ok: Bool; let data: [ServicioExtra] }
        let path = admin ? "/quinchos/\(quinchoId)/servicios/admin" : "/quinchos/\(quinchoId)/servicios"
        guard let data = await request("GET", path),
              let resp = try? JSONDecoder().decode(Resp.self, from: data) else { return }
        servicios = resp.data
    }

    func guardarAmenidades(quinchoId: String, amenidades: [String]) async {
        isLoading = true
        defer { isLoading = false }
        _ = await request("PUT", "/quinchos/\(quinchoId)/amenidades", body: ["amenidades": amenidades])
    }

    func crearServicio(quinchoId: String, nombre: String, descripcion: String, precio: Int, icono: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }
        let body: [String: Any] = [
            "nombre": nombre,
            "descripcion": descripcion,
            "precio": precio,
            "icono": icono,
        ]
        guard let data = await request("POST", "/quinchos/\(quinchoId)/servicios", body: body),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            error = "No se pudo crear el servicio"
            return false
        }
        if json["ok"] as? Bool == true { return true }
        error = json["error"] as? String ?? "Error al crear"
        return false
    }

    func eliminarServicio(_ id: String, quinchoId: String) async {
        _ = await request("DELETE", "/quinchos/servicios/\(id)")
        await cargarServicios(quinchoId: quinchoId, admin: true)
    }

    func toggleDisponible(_ servicio: ServicioExtra, quinchoId: String) async {
        _ = await request("PATCH", "/quinchos/servicios/\(servicio.id)", body: ["disponible": !servicio.disponible])
        await cargarServicios(quinchoId: quinchoId, admin: true)
    }
}
