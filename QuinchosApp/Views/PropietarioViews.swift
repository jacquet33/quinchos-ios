import SwiftUI

// MARK: - Panel Propietario (Tab principal)

struct PropietarioView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var dashVM = DashboardViewModel()
    @StateObject private var badges = BadgeManager.shared
    @AppStorage("modoExplorar") private var modoExplorar = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Stats
                        if let d = dashVM.dashboard {
                            HStack(spacing: 12) {
                                StatCard(titulo: "Pendientes", valor: "\(d.reservasPendientes)", color: .appWarning)
                                StatCard(titulo: "Confirmadas", valor: "\(d.reservasConfirmadas)", color: .appSuccess)
                                StatCard(titulo: "Ingresos", valor: d.ingresosMesFormatted, color: .appPrimary)
                            }
                        }
                        
                        // Accesos rápidos
                        VStack(spacing: 10) {
                            NavigationLink { MisQuinchosView() } label: { MenuRow2(icon: "house.fill", label: "Mis Quinchos", color: .appPrimary) }
                            NavigationLink { ReservasRecibidasView() } label: { MenuRow2(icon: "calendar.badge.clock", label: "Reservas Recibidas", color: .appWarning, badge: badges.reservasPendientes) }
                            NavigationLink { ClientesView() } label: { MenuRow2(icon: "person.2.fill", label: "Mis Clientes", color: .appSuccess) }
                            NavigationLink { CrearQuinchoView() } label: { MenuRow2(icon: "plus.circle.fill", label: "Nuevo Quincho", color: .appPrimary) }
                        }
                        
                        // Próximas reservas
                        if let proximas = dashVM.dashboard?.proximasReservas, !proximas.isEmpty {
                            Text("Próximas reservas").font(.headline).foregroundColor(.appTextPrimary)
                            ForEach(proximas) { r in
                                NavigationLink {
                                    ReservaDetalleView(reserva: r, esPropietario: true) {
                                        Task { await dashVM.cargar() }
                                    }
                                } label: {
                                    ReservaRecibidaRow(reserva: r, onConfirmar: { dashVM.confirmar(r.id) }, onRechazar: { dashVM.rechazar(r.id) })
                                        .background(Color.appCard)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Mi Panel")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { modoExplorar = true }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "magnifyingglass").font(.caption)
                            Text("Explorar").font(.caption).fontWeight(.semibold)
                        }
                        .foregroundColor(.appPrimary)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.appPrimary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            .task { await dashVM.cargar() }
        }
    }
}

struct StatCard: View {
    let titulo: String; let valor: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(valor).font(.title3).fontWeight(.bold).foregroundColor(color)
            Text(titulo).font(.caption2).foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity).padding(12)
        .background(Color.appCard).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MenuRow2: View {
    let icon: String
    let label: String
    let color: Color
    var badge: Int = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundColor(color).frame(width: 28)
            Text(label).foregroundColor(.appTextPrimary).font(.body)
            Spacer()
            if badge > 0 {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, badge > 9 ? 7 : 0)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(Color.appError)
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.appTextMuted)
        }
        .padding(14).background(Color.appSurface).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Mis Quinchos (ABM)

struct MisQuinchosView: View {
    @StateObject private var vm = MisQuinchosViewModel()
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if vm.quinchos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "house").font(.system(size: 44)).foregroundColor(.appTextMuted)
                    Text("No tenés quinchos cargados").foregroundColor(.appTextMuted)
                    NavigationLink("Crear mi primer quincho") { CrearQuinchoView() }
                        .foregroundColor(.appPrimary).fontWeight(.bold)
                }
            } else {
                List(vm.quinchos) { q in
                    NavigationLink { EditarQuinchoView(quincho: q) } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: q.imagenes?.first?.url ?? "")) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { Rectangle().fill(Color.appSurfaceLight) }
                                .frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(q.nombre).font(.headline).foregroundColor(.appTextPrimary)
                                Text(q.tipo.label).font(.caption).foregroundColor(.appPrimary)
                                HStack {
                                    Text(q.precioDia.formattedPrecio).font(.subheadline).foregroundColor(.appPrimary)
                                    Text("/día").font(.caption2).foregroundColor(.appTextMuted)
                                    Spacer()
                                    Image(systemName: "star.fill").font(.caption2).foregroundColor(.appStar)
                                    Text(String(format: "%.1f", q.calificacionProm)).font(.caption).foregroundColor(.appStar)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.appCard)
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Mis Quinchos")
        .toolbar {
            NavigationLink { CrearQuinchoView() } label: {
                Image(systemName: "plus").foregroundColor(.appPrimary)
            }
        }
        .task { await vm.cargar() }
    }
}

// MARK: - Crear Quincho

struct CrearQuinchoView: View {
    @Environment(\.dismiss) var dismiss
    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var direccion = DireccionSeleccionada()
    @State private var precioHora = ""
    @State private var precioDia = ""
    @State private var capacidadMin = ""
    @State private var capacidadMax = ""
    @State private var tipo: TipoEspacio = .QUINCHO
    @State private var horaApertura = "08:00"
    @State private var horaCierre = "00:00"
    @State private var isLoading = false
    @State private var error: String?
    @State private var success = false
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormField(label: "Nombre", placeholder: "Quincho Don Asado", text: $nombre)
                    FormField(label: "Descripción", placeholder: "Describe el espacio...", text: $descripcion, multiline: true)

                    AddressSearchField(direccion: $direccion)

                    if direccion.esValida {
                        MiniMapaConfirmacion(latitud: direccion.latitud, longitud: direccion.longitud)
                    }
                    
                    // Tipo
                    Text("Tipo de espacio").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TipoEspacio.allCases, id: \.self) { t in
                                Button { tipo = t } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: t.icono).font(.caption)
                                        Text(t.label).font(.caption)
                                    }
                                    .foregroundColor(tipo == t ? .white : .appTextSecondary)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(tipo == t ? Color.appPrimary : Color.appSurface)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 12) {
                        FormField(label: "Precio/hora", placeholder: "15000", text: $precioHora, keyboard: .numberPad)
                        FormField(label: "Precio/día", placeholder: "85000", text: $precioDia, keyboard: .numberPad)
                    }
                    HStack(spacing: 12) {
                        FormField(label: "Cap. mínima", placeholder: "10", text: $capacidadMin, keyboard: .numberPad)
                        FormField(label: "Cap. máxima", placeholder: "60", text: $capacidadMax, keyboard: .numberPad)
                    }
                    HStack(spacing: 12) {
                        FormField(label: "Hora apertura", placeholder: "08:00", text: $horaApertura)
                        FormField(label: "Hora cierre", placeholder: "00:00", text: $horaCierre)
                    }
                    
                    if let error = error {
                        Text(error).font(.caption).foregroundColor(.appError)
                    }
                    
                    Button {
                        Task { await crear() }
                    } label: {
                        Group {
                            if isLoading { ProgressView().tint(.white) }
                            else { Text("Crear Quincho").fontWeight(.bold) }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.appPrimary).foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isLoading)
                }
                .padding()
            }
        }
        .navigationTitle("Nuevo Quincho")
        .alert("¡Quincho creado!", isPresented: $success) {
            Button("OK") { dismiss() }
        }
    }
    
    func crear() async {
        guard !nombre.isEmpty, !descripcion.isEmpty else {
            error = "Completá el nombre y la descripción"
            return
        }
        guard direccion.esValida else {
            error = "Elegí una dirección de la lista de sugerencias"
            return
        }
        isLoading = true; error = nil
        do {
            let body: [String: Any] = [
                "nombre": nombre, "descripcion": descripcion,
                "direccion": direccion.calle,
                "ciudad": direccion.ciudad, "provincia": direccion.provincia,
                "latitud": direccion.latitud, "longitud": direccion.longitud,
                "precioHora": Int(precioHora) ?? 0, "precioDia": Int(precioDia) ?? 0,
                "capacidadMin": Int(capacidadMin) ?? 1, "capacidadMax": Int(capacidadMax) ?? 10,
                "tipo": tipo.rawValue, "horarioApertura": horaApertura, "horarioCierre": horaCierre
            ]
            let data = try JSONSerialization.data(withJSONObject: body)
            let url = URL(string: "\(APIConfig.baseURL)/quinchos")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = await APIService.shared.getToken() {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            req.httpBody = data
            let (respData, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(MessageResponse.self, from: respData)
            if resp.ok { success = true } else { error = resp.error ?? "Error" }
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }
}

// MARK: - Editar Quincho

struct EditarQuinchoView: View {
    let quincho: Quincho
    @Environment(\.dismiss) var dismiss
    @State private var nombre: String
    @State private var descripcion: String
    @State private var precioDia: String
    @State private var precioHora: String
    @State private var disponible: Bool
    @State private var showDelete = false
    @State private var saved = false
    
    init(quincho: Quincho) {
        self.quincho = quincho
        _nombre = State(initialValue: quincho.nombre)
        _descripcion = State(initialValue: quincho.descripcion)
        _precioDia = State(initialValue: "\(quincho.precioDia)")
        _precioHora = State(initialValue: "\(quincho.precioHora)")
        _disponible = State(initialValue: quincho.disponible)
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormField(label: "Nombre", placeholder: "", text: $nombre)
                    FormField(label: "Descripción", placeholder: "", text: $descripcion, multiline: true)

                    // Dirección
                    if editandoDireccion {
                        AddressSearchField(direccion: $direccion)
                        if direccion.esValida {
                            MiniMapaConfirmacion(latitud: direccion.latitud, longitud: direccion.longitud)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dirección").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                            Button { editandoDireccion = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.and.ellipse").foregroundColor(.appPrimary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(direccion.calle).foregroundColor(.appTextPrimary).font(.subheadline)
                                        Text("\(direccion.ciudad), \(direccion.provincia)")
                                            .font(.caption2).foregroundColor(.appTextMuted)
                                    }
                                    Spacer()
                                    Text("Cambiar").font(.caption).foregroundColor(.appPrimary)
                                }
                                .padding(12).background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        FormField(label: "Precio/hora", placeholder: "", text: $precioHora, keyboard: .numberPad)
                        FormField(label: "Precio/día", placeholder: "", text: $precioDia, keyboard: .numberPad)
                    }
                    
                    Toggle("Disponible", isOn: $disponible)
                        .foregroundColor(.appTextPrimary).tint(.appPrimary)
                        .padding().background(Color.appSurface).clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Subir fotos
                    Text("Fotos").font(.headline).foregroundColor(.appTextPrimary)
                    ImageUploadButton(quinchoId: quincho.id)
                    
                    // Accesos
                    NavigationLink {
                        EditarAmenidadesView(quinchoId: quincho.id, amenidadesActuales: quincho.amenidades?.map { $0.amenidad.rawValue } ?? [])
                    } label: {
                        MenuRow2(icon: "checklist", label: "Comodidades incluidas", color: .appSuccess)
                    }
                    NavigationLink { ServiciosExtraView(quinchoId: quincho.id) } label: {
                        MenuRow2(icon: "plus.square.on.square", label: "Servicios extra con costo", color: .appStar)
                    }
                    NavigationLink { AgendaView(quinchoId: quincho.id, quinchoNombre: quincho.nombre) } label: {
                        MenuRow2(icon: "calendar", label: "Agenda y Horarios", color: .appPrimary)
                    }
                    NavigationLink { BloqueoView(quinchoId: quincho.id) } label: {
                        MenuRow2(icon: "xmark.circle", label: "Bloquear Fechas", color: .appWarning)
                    }
                    
                    Button("Guardar Cambios") { Task { await guardar() } }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.appPrimary).foregroundColor(.white).fontWeight(.bold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    Button("Eliminar Quincho") { showDelete = true }
                        .frame(maxWidth: .infinity).padding()
                        .foregroundColor(.appError).fontWeight(.semibold)
                }
                .padding()
            }
        }
        .navigationTitle("Editar")
        .alert("¿Eliminar quincho?", isPresented: $showDelete) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) { Task { await eliminar() } }
        }
        .alert("Cambios guardados", isPresented: $saved) { Button("OK") {} }
    }
    
    func guardar() async {
        var body: [String: Any] = ["nombre": nombre, "descripcion": descripcion, "precioDia": Int(precioDia) ?? 0, "precioHora": Int(precioHora) ?? 0, "disponible": disponible]
        if direccion.esValida {
            body["direccion"] = direccion.calle
            body["ciudad"] = direccion.ciudad
            body["provincia"] = direccion.provincia
            body["latitud"] = direccion.latitud
            body["longitud"] = direccion.longitud
        }
        let data = try? JSONSerialization.data(withJSONObject: body)
        let url = URL(string: "\(APIConfig.baseURL)/quinchos/\(quincho.id)")!
        var req = URLRequest(url: url); req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await APIService.shared.getToken() { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = data
        _ = try? await URLSession.shared.data(for: req)
        saved = true
    }
    
    func eliminar() async {
        let url = URL(string: "\(APIConfig.baseURL)/quinchos/\(quincho.id)")!
        var req = URLRequest(url: url); req.httpMethod = "DELETE"
        if let token = await APIService.shared.getToken() { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        _ = try? await URLSession.shared.data(for: req)
        dismiss()
    }
}

// MARK: - Reservas Recibidas

struct ReservasRecibidasView: View {
    @StateObject private var vm = ReservasRecibidasViewModel()
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if vm.reservas.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar").font(.system(size: 44)).foregroundColor(.appTextMuted)
                    Text("No tenés reservas recibidas").foregroundColor(.appTextMuted)
                }
            } else {
                List(vm.reservas) { r in
                    NavigationLink {
                        ReservaDetalleView(reserva: r, esPropietario: true) {
                            Task { await vm.cargar() }
                        }
                    } label: {
                        ReservaRecibidaRow(reserva: r, onConfirmar: { vm.confirmar(r.id) }, onRechazar: { vm.rechazar(r.id) })
                    }
                    .listRowBackground(Color.appCard)
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Reservas Recibidas")
        .task {
            await vm.cargar()
            await BadgeManager.shared.refrescar(esPropietario: true)
        }
    }
}

struct ReservaRecibidaRow: View {
    let reserva: Reserva
    let onConfirmar: () -> Void
    let onRechazar: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reserva.usuario?.nombre ?? "Cliente").font(.headline).foregroundColor(.appTextPrimary)
                    Text(reserva.quincho?.nombre ?? "").font(.caption).foregroundColor(.appTextSecondary)
                }
                Spacer()
                EstadoBadge(estado: reserva.estado)            }
            
            HStack(spacing: 16) {
                Label(reserva.fecha.prefix(10).description, systemImage: "calendar").font(.caption)
                Label("\(reserva.horaInicio)–\(reserva.horaFin)", systemImage: "clock").font(.caption)
                Label("\(reserva.cantidadPersonas)", systemImage: "person.2").font(.caption)
            }
            .foregroundColor(.appTextSecondary)
            
            HStack {
                Text(reserva.precioTotal.formattedPrecio).font(.headline).foregroundColor(.appPrimary)
                Spacer()
                if reserva.estado == .PENDIENTE {
                    Button { onRechazar() } label: {
                        Text("Rechazar").font(.caption).fontWeight(.semibold).foregroundColor(.appError)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .overlay(Capsule().stroke(Color.appError))
                    }
                    Button { onConfirmar() } label: {
                        Text("Confirmar").font(.caption).fontWeight(.semibold).foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.appSuccess).clipShape(Capsule())
                    }
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Clientes

struct ClientesView: View {
    @StateObject private var vm = ClientesViewModel()
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if vm.clientes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2").font(.system(size: 44)).foregroundColor(.appTextMuted)
                    Text("Aún no tenés clientes").foregroundColor(.appTextMuted)
                }
            } else {
                List(vm.clientes) { c in
                    HStack(spacing: 12) {
                        Circle().fill(Color.appSurface).frame(width: 40, height: 40)
                            .overlay(Image(systemName: "person").foregroundColor(.appTextMuted))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.nombre).font(.subheadline).fontWeight(.semibold).foregroundColor(.appTextPrimary)
                            Text(c.email).font(.caption).foregroundColor(.appTextSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(c.totalReservas) reservas").font(.caption2).foregroundColor(.appTextSecondary)
                            Text(c.totalGastado.formattedPrecio).font(.caption).fontWeight(.bold).foregroundColor(.appPrimary)
                        }
                    }
                    .listRowBackground(Color.appCard)
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Mis Clientes")
        .task { await vm.cargar() }
    }
}

// MARK: - Agenda

struct AgendaView: View {
    let quinchoId: String
    let quinchoNombre: String
    @StateObject private var vm = AgendaViewModel()
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            List(vm.dias) { dia in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dia.diaNombre).font(.headline).foregroundColor(.appTextPrimary)
                        if dia.habilitado {
                            Text("\(dia.horaApertura) – \(dia.horaCierre)").font(.caption).foregroundColor(.appTextSecondary)
                            if let precio = dia.precioEspecial {
                                Text(precio.formattedPrecio + " /día").font(.caption).foregroundColor(.appPrimary)
                            }
                        }
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { dia.habilitado },
                        set: { vm.toggleDia(quinchoId: quinchoId, dia: dia.diaSemana, habilitado: $0) }
                    ))
                    .tint(.appPrimary)
                }
                .listRowBackground(Color.appCard)
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
        }
        .navigationTitle("Agenda")
        .task { await vm.cargar(quinchoId: quinchoId) }
    }
}

// MARK: - Bloqueo de Fechas

struct BloqueoView: View {
    let quinchoId: String
    @State private var fecha = ""
    @State private var motivo = ""
    @StateObject private var vm = BloqueoViewModel()
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    FormField(label: "Fecha (AAAA-MM-DD)", placeholder: "2026-09-20", text: $fecha)
                    Button {
                        Task { await vm.bloquear(quinchoId: quinchoId, fecha: fecha, motivo: motivo); fecha = ""; motivo = "" }
                    } label: {
                        Image(systemName: "plus").foregroundColor(.white)
                            .padding(12).background(Color.appPrimary).clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                
                FormField(label: "Motivo (opcional)", placeholder: "Mantenimiento", text: $motivo)
                    .padding(.horizontal)
                
                List(vm.bloqueos) { b in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(b.fecha).font(.subheadline).foregroundColor(.appTextPrimary)
                            if let m = b.motivo { Text(m).font(.caption).foregroundColor(.appTextSecondary) }
                        }
                        Spacer()
                        Button { Task { await vm.desbloquear(quinchoId: quinchoId, fecha: b.fecha) } } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.appError)
                        }
                    }
                    .listRowBackground(Color.appCard)
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Bloquear Fechas")
        .task { await vm.cargar(quinchoId: quinchoId) }
    }
}
