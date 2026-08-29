import SwiftUI

// MARK: - Modelos

enum TipoServicio: String, Codable {
    case ADICIONAL, INCLUIDO

    var titulo: String {
        self == .INCLUIDO ? "Incluido" : "Adicional"
    }
    var explicacion: String {
        self == .INCLUIDO
            ? "Viene en el precio. Si el cliente no lo quiere, paga menos."
            : "No viene incluido. Si el cliente lo quiere, paga más."
    }
    var color: Color { self == .INCLUIDO ? .appSuccess : .appPrimary }
}

struct ServicioExtra: Codable, Identifiable, Hashable {
    let id: String
    let nombre: String
    let descripcion: String?
    let precio: Int
    let icono: String?
    let disponible: Bool
    var tipo: TipoServicio = .ADICIONAL

    /// Cómo se muestra el impacto en el precio
    var etiquetaPrecio: String {
        if precio == 0 { return tipo == .INCLUIDO ? "Incluido" : "Sin cargo" }
        return tipo == .INCLUIDO ? "-\(precio.formattedPrecio) si lo quitás" : "+\(precio.formattedPrecio)"
    }
}

struct SugerenciasResponse: Codable {
    let incluidos: [SugerenciaServicio]
    let adicionales: [SugerenciaServicio]
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

    var incluidos: [ServicioExtra] { vm.servicios.filter { $0.tipo == .INCLUIDO } }
    var adicionales: [ServicioExtra] { vm.servicios.filter { $0.tipo == .ADICIONAL } }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if vm.servicios.isEmpty && !vm.isLoading {
                VStack(spacing: 14) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 44)).foregroundColor(.appTextMuted)
                    Text("Sin servicios configurados").font(.headline).foregroundColor(.appTextPrimary)
                    Text("Definí qué viene incluido y qué se puede sumar, con su impacto en el precio")
                        .font(.caption).foregroundColor(.appTextMuted)
                        .multilineTextAlignment(.center)
                    Button("Agregar servicio") { showNuevo = true }
                        .fontWeight(.bold).foregroundColor(.appPrimary)
                }
                .padding(32)
            } else {
                List {
                    if !incluidos.isEmpty {
                        Section {
                            ForEach(incluidos) { s in
                                FilaServicio(servicio: s)
                                    .listRowBackground(Color.appCard)
                                    .swipeActions { accionesSwipe(s) }
                            }
                        } header: {
                            Text("Incluidos en el precio")
                                .foregroundColor(.appSuccess).font(.caption).fontWeight(.bold)
                        } footer: {
                            Text("El cliente los puede quitar y paga menos")
                                .font(.caption2).foregroundColor(.appTextMuted)
                        }
                    }

                    if !adicionales.isEmpty {
                        Section {
                            ForEach(adicionales) { s in
                                FilaServicio(servicio: s)
                                    .listRowBackground(Color.appCard)
                                    .swipeActions { accionesSwipe(s) }
                            }
                        } header: {
                            Text("Adicionales con costo")
                                .foregroundColor(.appPrimary).font(.caption).fontWeight(.bold)
                        } footer: {
                            Text("El cliente los puede sumar y paga más")
                                .font(.caption2).foregroundColor(.appTextMuted)
                        }
                    }
                }
                .listStyle(.insetGrouped).scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Servicios")
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

    @ViewBuilder
    func accionesSwipe(_ s: ServicioExtra) -> some View {
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

struct FilaServicio: View {
    let servicio: ServicioExtra

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: servicio.icono ?? "star")
                .foregroundColor(servicio.tipo.color).frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(servicio.nombre)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(servicio.disponible ? .appTextPrimary : .appTextMuted)
                if let d = servicio.descripcion, !d.isEmpty {
                    Text(d).font(.caption2).foregroundColor(.appTextSecondary).lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if servicio.precio > 0 {
                    Text(servicio.tipo == .INCLUIDO ? "-\(servicio.precio.formattedPrecio)" : "+\(servicio.precio.formattedPrecio)")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(servicio.tipo.color)
                } else {
                    Text("Sin cargo").font(.caption).foregroundColor(.appSuccess)
                }
                if !servicio.disponible {
                    Text("Inactivo").font(.caption2).foregroundColor(.appTextMuted)
                }
            }
        }
        .padding(.vertical, 4)
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
    @State private var tipo: TipoServicio = .ADICIONAL

    var sugerenciasDelTipo: [SugerenciaServicio] {
        tipo == .INCLUIDO ? vm.sugerenciasIncluidos : vm.sugerenciasAdicionales
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {

                        // ─── Tipo de servicio ───
                        VStack(alignment: .leading, spacing: 8) {
                            Text("¿Viene incluido en el precio?")
                                .font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)

                            HStack(spacing: 10) {
                                TipoServicioCard(
                                    titulo: "Sí, incluido",
                                    subtitulo: "Si lo quitan, pagan menos",
                                    icono: "checkmark.seal.fill",
                                    color: .appSuccess,
                                    seleccionado: tipo == .INCLUIDO
                                ) { tipo = .INCLUIDO }

                                TipoServicioCard(
                                    titulo: "No, adicional",
                                    subtitulo: "Si lo suman, pagan más",
                                    icono: "plus.circle.fill",
                                    color: .appPrimary,
                                    seleccionado: tipo == .ADICIONAL
                                ) { tipo = .ADICIONAL }
                            }
                        }

                        // ─── Sugerencias del tipo elegido ───
                        if !sugerenciasDelTipo.isEmpty && nombre.isEmpty {
                            Text("Sugerencias").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(sugerenciasDelTipo) { sug in
                                        Button {
                                            nombre = sug.nombre
                                            precio = "\(sug.precioSugerido)"
                                            iconoSeleccionado = sug.icono
                                        } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: sug.icono).font(.caption)
                                                Text(sug.nombre).font(.caption)
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

                        FormField(label: "Nombre del servicio", placeholder: tipo == .INCLUIDO ? "Pileta" : "Pelotero inflable", text: $nombre)
                        FormField(label: "Descripción (opcional)", placeholder: "Detalles del servicio", text: $descripcion)
                        FormField(
                            label: tipo == .INCLUIDO ? "Descuento si lo quitan" : "Costo adicional",
                            placeholder: tipo == .INCLUIDO ? "10000" : "25000",
                            text: $precio,
                            keyboard: .numberPad
                        )

                        // ─── Ejemplo en vivo ───
                        if let p = Int(precio), p > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill").foregroundColor(tipo.color).font(.caption)
                                Text(tipo == .INCLUIDO
                                     ? "El cliente que no quiera \(nombre.isEmpty ? "este servicio" : nombre.lowercased()) paga \(p.formattedPrecio) menos"
                                     : "El cliente que quiera \(nombre.isEmpty ? "este servicio" : nombre.lowercased()) paga \(p.formattedPrecio) más")
                                    .font(.caption).foregroundColor(.appTextSecondary)
                            }
                            .padding(12)
                            .background(tipo.color.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

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
                                    icono: iconoSeleccionado,
                                    tipo: tipo
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

struct TipoServicioCard: View {
    let titulo: String
    let subtitulo: String
    let icono: String
    let color: Color
    let seleccionado: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: icono).font(.title3)
                    .foregroundColor(seleccionado ? color : .appTextMuted)
                Text(titulo).font(.caption).fontWeight(.bold)
                    .foregroundColor(seleccionado ? .appTextPrimary : .appTextSecondary)
                Text(subtitulo).font(.caption2).foregroundColor(.appTextMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(12)
            .background(seleccionado ? color.opacity(0.12) : Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(seleccionado ? color : Color.appBorder, lineWidth: seleccionado ? 2 : 1)
            )
        }
    }
}

// MARK: - Selector de servicios al reservar (cliente)

struct SelectorServiciosView: View {
    let servicios: [ServicioExtra]
    @Binding var seleccionados: Set<String>

    var incluidos: [ServicioExtra] { servicios.filter { $0.tipo == .INCLUIDO } }
    var adicionales: [ServicioExtra] { servicios.filter { $0.tipo == .ADICIONAL } }

    /// Suma de adicionales elegidos menos incluidos rechazados
    var ajuste: Int {
        let suma = adicionales.filter { seleccionados.contains($0.id) }.reduce(0) { $0 + $1.precio }
        let resta = incluidos.filter { !seleccionados.contains($0.id) }.reduce(0) { $0 + $1.precio }
        return suma - resta
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ─── Incluidos (destildar para descontar) ───
            if !incluidos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Incluido en el precio")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                    Text("Destildá lo que no necesites y te lo descontamos")
                        .font(.caption2).foregroundColor(.appTextMuted)

                    VStack(spacing: 0) {
                        ForEach(incluidos) { s in
                            filaServicio(s, activo: seleccionados.contains(s.id), esIncluido: true)
                            if s.id != incluidos.last?.id {
                                Divider().background(Color.appBorder).padding(.leading, 48)
                            }
                        }
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // ─── Adicionales (tildar para sumar) ───
            if !adicionales.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Servicios adicionales")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)

                    VStack(spacing: 0) {
                        ForEach(adicionales) { s in
                            filaServicio(s, activo: seleccionados.contains(s.id), esIncluido: false)
                            if s.id != adicionales.last?.id {
                                Divider().background(Color.appBorder).padding(.leading, 48)
                            }
                        }
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .onAppear {
            // Los incluidos arrancan tildados
            for s in incluidos { seleccionados.insert(s.id) }
        }
    }

    @ViewBuilder
    func filaServicio(_ s: ServicioExtra, activo: Bool, esIncluido: Bool) -> some View {
        Button {
            if activo { seleccionados.remove(s.id) } else { seleccionados.insert(s.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: activo ? "checkmark.square.fill" : "square")
                    .foregroundColor(activo ? (esIncluido ? .appSuccess : .appPrimary) : .appTextMuted)

                Image(systemName: s.icono ?? "star")
                    .foregroundColor(.appTextSecondary).frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(s.nombre)
                        .font(.subheadline)
                        .foregroundColor(activo ? .appTextPrimary : .appTextMuted)
                        .strikethrough(esIncluido && !activo)
                    if let d = s.descripcion, !d.isEmpty {
                        Text(d).font(.caption2).foregroundColor(.appTextMuted).lineLimit(1)
                    }
                }

                Spacer()

                if s.precio == 0 {
                    Text("Sin cargo").font(.caption).foregroundColor(.appSuccess)
                } else if esIncluido {
                    Text(activo ? "Incluido" : "-\(s.precio.formattedPrecio)")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(activo ? .appTextMuted : .appSuccess)
                } else {
                    Text("+\(s.precio.formattedPrecio)")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(activo ? .appPrimary : .appTextMuted)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ServiciosViewModel: ObservableObject {
    @Published var catalogo: [CategoriaAmenidades] = []
    @Published var servicios: [ServicioExtra] = []
    @Published var sugerenciasIncluidos: [SugerenciaServicio] = []
    @Published var sugerenciasAdicionales: [SugerenciaServicio] = []
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
        struct Resp: Codable { let ok: Bool; let data: SugerenciasResponse }
        guard let data = await request("GET", "/quinchos/catalogo/sugerencias", auth: false),
              let resp = try? JSONDecoder().decode(Resp.self, from: data) else { return }
        sugerenciasIncluidos = resp.data.incluidos
        sugerenciasAdicionales = resp.data.adicionales
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

    func crearServicio(quinchoId: String, nombre: String, descripcion: String, precio: Int, icono: String, tipo: TipoServicio = .ADICIONAL) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }
        let body: [String: Any] = [
            "nombre": nombre,
            "descripcion": descripcion,
            "precio": precio,
            "icono": icono,
            "tipo": tipo.rawValue,
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
