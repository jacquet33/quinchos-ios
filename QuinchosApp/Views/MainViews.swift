import SwiftUI
import MapKit

// MARK: - App Entry

@main
struct QuinchosAppMain: App {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var quinchosVM = QuinchosViewModel()
    @StateObject private var reservasVM = ReservasViewModel()
    @StateObject private var favoritosVM = FavoritosViewModel()
    @StateObject private var pushManager = PushNotificationManager.shared

    init() {
        PushNotificationManager.shared.configure()
    }
    var body: some Scene {
        WindowGroup {
            if authVM.isAuthenticated {
                MainTabView()
                    .environmentObject(authVM)
                    .environmentObject(quinchosVM)
                    .environmentObject(reservasVM)
                    .environmentObject(favoritosVM)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        pushManager.requestPermission()
                        Task { await pushManager.registrarEnBackend() }
                    }
            } else {
                LoginView()
                    .environmentObject(authVM)
                    .preferredColorScheme(.dark)
            }
        }
    }
}

// MARK: - Login

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistro = false
    @State private var nombre = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 60)

                        // Logo
                        Image(systemName: "flame.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.appPrimary)

                        Text("QuinchosApp")
                            .font(.largeTitle).fontWeight(.heavy)
                            .foregroundColor(.appTextPrimary)

                        Text("Encontrá y reservá el lugar perfecto")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)

                        VStack(spacing: 14) {
                            if isRegistro {
                                TextField("Nombre completo", text: $nombre)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color.appSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .foregroundColor(.appTextPrimary)
                            }

                            TextField("Email", text: $email)
                                .textFieldStyle(.plain)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .padding()
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(.appTextPrimary)

                            SecureField("Contraseña", text: $password)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(.appTextPrimary)
                        }

                        if let error = authVM.error {
                            Text(error)
                                .font(.caption).foregroundColor(.appError)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task {
                                if isRegistro {
                                    await authVM.registro(email: email, password: password, nombre: nombre)
                                } else {
                                    await authVM.login(email: email, password: password)
                                }
                            }
                        } label: {
                            Group {
                                if authVM.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isRegistro ? "Crear cuenta" : "Iniciar sesión")
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appPrimary)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(authVM.isLoading)

                        Button {
                            withAnimation { isRegistro.toggle() }
                        } label: {
                            Text(isRegistro ? "¿Ya tenés cuenta? Iniciá sesión" : "¿No tenés cuenta? Registrate")
                                .font(.subheadline)
                                .foregroundColor(.appPrimary)
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var esPropietario: Bool {
        authVM.usuario?.rol == .PROPIETARIO || authVM.usuario?.rol == .ADMIN
    }
    
    var body: some View {
        TabView {
            ExplorarView()
                .tabItem { Label("Explorar", systemImage: "magnifyingglass") }

            MapaView()
                .tabItem { Label("Mapa", systemImage: "map") }

            ReservasView()
                .tabItem { Label("Reservas", systemImage: "calendar") }

            if esPropietario {
                PropietarioView()
                    .tabItem { Label("Mi Panel", systemImage: "briefcase") }
            } else {
                FavoritosView()
                    .tabItem { Label("Favoritos", systemImage: "heart") }
            }

            CuentaView()
                .tabItem { Label("Cuenta", systemImage: "person") }
        }
        .tint(.appPrimary)
    }
}

// MARK: - Explorar

struct ExplorarView: View {
    @EnvironmentObject var vm: QuinchosViewModel
    @EnvironmentObject var favoritosVM: FavoritosViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var showFiltros = false
    @State private var precioMax: Double = 200000
    @State private var capacidadMin: Double = 1
    @State private var amenidadesSeleccionadas: Set<String> = []
    @State private var ordenarPor: String = "calificacion"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Encontrá tu lugar")
                                    .font(.title).fontWeight(.heavy)
                                    .foregroundColor(.appTextPrimary)
                                if let city = locationManager.cityName {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill").font(.caption2)
                                        Text(city)
                                    }
                                    .font(.subheadline).foregroundColor(.appPrimary)
                                } else {
                                    Text("Quinchos, salones y más en tu zona")
                                        .font(.subheadline).foregroundColor(.appTextSecondary)
                                }
                            }
                            Spacer()
                            Button { showFiltros = true } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.appPrimary)
                                    .padding(10)
                                    .background(Color.appSurface)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)

                        // GPS Banner
                        if !locationManager.isAuthorized || locationManager.isDenied {
                            LocationBanner(locationManager: locationManager)
                                .padding(.horizontal)
                        }

                        // Radio selector (solo si tiene GPS)
                        if locationManager.hasLocation {
                            RadioSelector(radioKm: $vm.radioKm)
                                .onChange(of: vm.radioKm) { newValue in
                                    Task { await buscarConFiltros() }
                                }
                        }

                        // Search
                        SearchBarView(text: $vm.searchQuery) {
                            Task { await buscarConFiltros() }
                        }
                        .padding(.horizontal)

                        // Filters
                        FilterChipsView(selected: $vm.tipoSeleccionado) {
                            Task { await buscarConFiltros() }
                        }

                        // Filtros activos
                        if precioMax < 200000 || capacidadMin > 1 || !amenidadesSeleccionadas.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    if precioMax < 200000 {
                                        ActiveFilterChip(text: "Hasta \(Int(precioMax).formattedPrecio)") { precioMax = 200000; Task { await buscarConFiltros() } }
                                    }
                                    if capacidadMin > 1 {
                                        ActiveFilterChip(text: "+\(Int(capacidadMin)) pers.") { capacidadMin = 1; Task { await buscarConFiltros() } }
                                    }
                                    ForEach(Array(amenidadesSeleccionadas), id: \.self) { a in
                                        if let amenidad = Amenidad(rawValue: a) {
                                            ActiveFilterChip(text: amenidad.label) {
                                                amenidadesSeleccionadas.remove(a)
                                                Task { await buscarConFiltros() }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Destacados
                        if !vm.destacados.isEmpty && vm.searchQuery.isEmpty {
                            Text("⭐ Destacados")
                                .font(.headline).foregroundColor(.appTextPrimary)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(vm.destacados) { q in
                                        NavigationLink(value: q.id) {
                                            QuinchoCard(
                                                quincho: q,
                                                compact: true,
                                                isFavorito: favoritosVM.esFavorito(q.id)
                                            ) {
                                                Task { await favoritosVM.toggleFavorito(quinchoId: q.id) }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Resultados
                        HStack {
                            Text(vm.searchQuery.isEmpty ? "Todos los espacios" : "Resultados")
                                .font(.headline).foregroundColor(.appTextPrimary)
                            Spacer()
                            Text("\(vm.quinchos.count) encontrados")
                                .font(.caption).foregroundColor(.appTextMuted)
                        }
                        .padding(.horizontal)

                        if vm.isLoading {
                            ProgressView().tint(.appPrimary)
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else if vm.quinchos.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass").font(.system(size: 36)).foregroundColor(.appTextMuted)
                                Text("No se encontraron resultados").foregroundColor(.appTextMuted)
                                Text("Probá con otros filtros").font(.caption).foregroundColor(.appTextMuted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 150)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(vm.quinchos) { q in
                                    NavigationLink(value: q.id) {
                                        QuinchoCard(
                                            quincho: q,
                                            isFavorito: favoritosVM.esFavorito(q.id)
                                        ) {
                                            Task { await favoritosVM.toggleFavorito(quinchoId: q.id) }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationDestination(for: String.self) { quinchoId in
                QuinchoDetalleView(quinchoId: quinchoId)
            }
            .task {
                await vm.cargarDestacados()
                locationManager.requestPermission()
                await buscarConFiltros()
                await favoritosVM.cargarFavoritos()
            }
            .sheet(isPresented: $showFiltros) {
                FiltrosAvanzadosView(
                    precioMax: $precioMax,
                    capacidadMin: $capacidadMin,
                    amenidadesSeleccionadas: $amenidadesSeleccionadas,
                    ordenarPor: $ordenarPor,
                    onAplicar: { Task { await buscarConFiltros() } }
                )
                .presentationDetents([.large])
            }
        }
    }
    
    func buscarConFiltros() async {
        vm.ordenarPor = ordenarPor
        vm.precioMax = precioMax < 200000 ? Int(precioMax) : nil
        await vm.buscar(
            lat: locationManager.userLatitude,
            lng: locationManager.userLongitude
        )
    }
}

struct ActiveFilterChip: View {
    let text: String; let onRemove: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(.caption)
            Button(action: onRemove) { Image(systemName: "xmark").font(.system(size: 9)) }
        }
        .foregroundColor(.appPrimary)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.appPrimary.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Quincho Detalle

struct QuinchoDetalleView: View {
    let quinchoId: String
    @EnvironmentObject var quinchosVM: QuinchosViewModel
    @EnvironmentObject var favoritosVM: FavoritosViewModel
    @StateObject private var resenasVM = ResenasViewModel()
    @State private var showReservar = false
    @Environment(\.dismiss) var dismiss

    var q: Quincho? { quinchosVM.quinchoDetalle }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            if quinchosVM.isLoading || q == nil {
                ProgressView().tint(.appPrimary)
            } else if let q = q {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Hero Image
                        TabView {
                            ForEach(q.imagenes ?? [], id: \.id) { img in
                                AsyncImage(url: URL(string: img.url)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(Color.appSurfaceLight)
                                }
                            }
                        }
                        .frame(height: 280)
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .clipShape(RoundedRectangle(cornerRadius: 0))

                        VStack(alignment: .leading, spacing: 16) {
                            // Tipo badge + Nombre
                            Text(q.tipo.label)
                                .font(.caption).fontWeight(.bold)
                                .foregroundColor(.appPrimary)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.appPrimary.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            Text(q.nombre)
                                .font(.title).fontWeight(.heavy)
                                .foregroundColor(.appTextPrimary)

                            HStack(spacing: 5) {
                                Image(systemName: "location").font(.caption)
                                Text(q.direccion)
                            }
                            .foregroundColor(.appTextSecondary).font(.subheadline)

                            HStack(spacing: 5) {
                                Image(systemName: "star.fill").foregroundColor(.appStar)
                                Text(String(format: "%.1f", q.calificacionProm))
                                    .fontWeight(.bold).foregroundColor(.appStar)
                                Text("· \(q.totalResenas) reseñas")
                                    .foregroundColor(.appTextMuted)
                            }
                            .font(.subheadline)

                            // Precios
                            HStack(spacing: 12) {
                                VStack {
                                    Text("Por hora").font(.caption).foregroundColor(.appTextSecondary)
                                    Text(q.precioHora.formattedPrecio).font(.title3).fontWeight(.bold).foregroundColor(.appTextPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding().background(Color.appSurface).clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack {
                                    Text("Por día").font(.caption).foregroundColor(.appTextSecondary)
                                    Text(q.precioDia.formattedPrecio).font(.title3).fontWeight(.bold).foregroundColor(.appPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding().background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appPrimary, lineWidth: 1))
                            }

                            // Capacidad + Horario
                            HStack(spacing: 12) {
                                InfoPill(icon: "person.2", value: "\(q.capacidadMin)–\(q.capacidadMax)", label: "personas")
                                InfoPill(icon: "clock", value: "\(q.horarioApertura)–\(q.horarioCierre)", label: "horario")
                            }

                            // Descripción
                            SectionTitle("Descripción")
                            Text(q.descripcion)
                                .font(.body).foregroundColor(.appTextSecondary)
                                .lineSpacing(4)

                            // Amenidades
                            SectionTitle("Comodidades")
                            FlowLayout(spacing: 8) {
                                ForEach(q.amenidades?.map(\.amenidad) ?? [], id: \.self) { a in
                                    AmenidadChip(amenidad: a)
                                }
                            }

                            // Propietario
                            if let prop = q.propietario {
                                SectionTitle("Propietario")
                                HStack(spacing: 12) {
                                    Circle().fill(Color.appSurface).frame(width: 44, height: 44)
                                        .overlay(Image(systemName: "person").foregroundColor(.appTextMuted))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(prop.nombre).font(.body).fontWeight(.semibold).foregroundColor(.appTextPrimary)
                                        if prop.verificado {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.shield.fill").font(.caption2)
                                                Text("Verificado").font(.caption)
                                            }
                                            .foregroundColor(.appSuccess)
                                        }
                                    }
                                }
                            }

                            // Reseñas
                            SectionTitle("Reseñas (\(resenasVM.resenas.count))")
                            if resenasVM.resenas.isEmpty {
                                Text("Aún no hay reseñas").foregroundColor(.appTextMuted)
                            } else {
                                ForEach(resenasVM.resenas) { resena in
                                    ResenaRow(resena: resena)
                                }
                            }
                        }
                        .padding(.horizontal)

                        Spacer().frame(height: 100)
                    }
                }

                // Footer CTA
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text(q.precioDia.formattedPrecio)
                                .font(.title3).fontWeight(.bold).foregroundColor(.appPrimary)
                            Text("por día").font(.caption).foregroundColor(.appTextSecondary)
                        }
                        Spacer()
                        NavigationLink {
                            ReservarView(quinchoId: q.id, quinchoNombre: q.nombre, precio: q.precioDia)
                        } label: {
                            Text("Reservar")
                                .font(.headline).foregroundColor(.white)
                                .padding(.horizontal, 32).padding(.vertical, 14)
                                .background(Color.appPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding()
                    .background(Color.appSurface)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await favoritosVM.toggleFavorito(quinchoId: quinchoId) }
                } label: {
                    Image(systemName: favoritosVM.esFavorito(quinchoId) ? "heart.fill" : "heart")
                        .foregroundColor(favoritosVM.esFavorito(quinchoId) ? .appError : .appTextPrimary)
                }
            }
        }
        .task {
            await quinchosVM.cargarDetalle(id: quinchoId)
            await resenasVM.cargarResenas(quinchoId: quinchoId)
        }
    }
}

// MARK: - Helper Views

struct InfoPill: View {
    let icon: String; let value: String; let label: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(.appPrimary)
            Text(value).font(.subheadline).fontWeight(.semibold).foregroundColor(.appTextPrimary)
            Text(label).font(.caption2).foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity).padding()
        .background(Color.appSurface).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.headline).foregroundColor(.appTextPrimary).padding(.top, 8)
    }
}

struct ResenaRow: View {
    let resena: Resena
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(resena.usuario?.nombre ?? "Usuario").font(.subheadline).fontWeight(.semibold).foregroundColor(.appTextPrimary)
                Spacer()
                StarRatingView(rating: resena.calificacion, size: 12)
            }
            Text(resena.comentario).font(.subheadline).foregroundColor(.appTextSecondary).lineSpacing(3)
            if let fecha = resena.fecha {
                Text(fecha).font(.caption2).foregroundColor(.appTextMuted)
            }
        }
        .padding(12).background(Color.appSurface).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    init(spacing: CGFloat = 8) { self.spacing = spacing }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

// MARK: - Reservar

struct ReservarView: View {
    let quinchoId: String
    let quinchoNombre: String
    let precio: Int
    @EnvironmentObject var reservasVM: ReservasViewModel
    @Environment(\.dismiss) var dismiss
    @State private var fechaSeleccionada = Date().addingTimeInterval(86400) // mañana
    @State private var horaInicioDate = Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!
    @State private var horaFinDate = Calendar.current.date(from: DateComponents(hour: 20, minute: 0))!
    @State private var personas = ""
    @State private var notas = ""
    @State private var showSuccess = false

    private var fechaString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: fechaSeleccionada)
    }
    
    private var horaInicioString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: horaInicioDate)
    }
    
    private var horaFinString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: horaFinDate)
    }
    
    private var fechaDisplay: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.dateStyle = .long
        return f.string(from: fechaSeleccionada)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Resumen quincho
                    HStack {
                        Text(quinchoNombre).font(.headline).foregroundColor(.appTextPrimary)
                        Spacer()
                        Text(precio.formattedPrecio + " /día").font(.subheadline).fontWeight(.bold).foregroundColor(.appPrimary)
                    }
                    .padding().background(Color.appSurface).clipShape(RoundedRectangle(cornerRadius: 12))

                    // Fecha con calendario
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fecha del evento").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                        DatePicker("", selection: $fechaSeleccionada, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(.appPrimary)
                            .padding(12)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .environment(\.locale, Locale(identifier: "es_AR"))
                    }

                    // Horarios
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Hora inicio").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                            DatePicker("", selection: $horaInicioDate, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(.appPrimary)
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Hora fin").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                            DatePicker("", selection: $horaFinDate, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(.appPrimary)
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    FormField(label: "Cantidad de personas", placeholder: "25", text: $personas, keyboard: .numberPad)
                    FormField(label: "Notas (opcional)", placeholder: "Tipo de evento...", text: $notas, multiline: true)

                    // Resumen
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resumen").font(.headline).foregroundColor(.appTextPrimary)
                        SummaryRow(label: "Fecha", value: fechaDisplay)
                        SummaryRow(label: "Horario", value: "\(horaInicioString) – \(horaFinString)")
                        Divider().background(Color.appBorder)
                        SummaryRow(label: "Total estimado", value: precio.formattedPrecio, highlight: true)
                    }
                    .padding().background(Color.appSurface).clipShape(RoundedRectangle(cornerRadius: 12))

                    if let error = reservasVM.error {
                        Text(error).font(.caption).foregroundColor(.appError)
                    }

                    Button {
                        Task {
                            let ok = await reservasVM.crearReserva(
                                quinchoId: quinchoId,
                                fecha: fechaString,
                                horaInicio: horaInicioString,
                                horaFin: horaFinString,
                                personas: Int(personas) ?? 1,
                                notas: notas.isEmpty ? nil : notas
                            )
                            if ok { showSuccess = true }
                        }
                    } label: {
                        Group {
                            if reservasVM.isLoading { ProgressView().tint(.white) }
                            else { Text("Confirmar reserva").fontWeight(.bold) }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.appPrimary).foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(reservasVM.isLoading)
                }
                .padding()
            }
        }
        .navigationTitle("Reservar")
        .alert("¡Reserva enviada!", isPresented: $showSuccess) {
            Button("Genial") { dismiss() }
        } message: {
            Text("Tu solicitud fue enviada al propietario.")
        }
    }
}

struct FormField: View {
    let label: String; let placeholder: String; @Binding var text: String
    var keyboard: UIKeyboardType = .default; var multiline = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
            if multiline {
                TextEditor(text: $text)
                    .frame(minHeight: 80).foregroundColor(.appTextPrimary).scrollContentBackground(.hidden)
                    .padding(10).background(Color.appSurface).clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard).foregroundColor(.appTextPrimary)
                    .padding(12).background(Color.appSurface).clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
            }
        }
    }
}

struct SummaryRow: View {
    let label: String; let value: String; var highlight = false
    var body: some View {
        HStack { Text(label).foregroundColor(.appTextSecondary); Spacer(); Text(value).fontWeight(highlight ? .bold : .medium).foregroundColor(highlight ? .appPrimary : .appTextPrimary) }.font(.subheadline)
    }
}

// MARK: - Reservas

struct ReservasView: View {
    @EnvironmentObject var vm: ReservasViewModel
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if vm.reservas.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar").font(.system(size: 44)).foregroundColor(.appTextMuted)
                        Text("No tenés reservas todavía").foregroundColor(.appTextMuted)
                    }
                } else {
                    List(vm.reservas) { r in
                        ReservaRow(reserva: r) { Task { await vm.cancelarReserva(id: r.id) } }
                            .listRowBackground(Color.appCard)
                            .listRowSeparatorTint(.appBorder)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Mis Reservas")
            .task { await vm.cargarReservas() }
        }
    }
}

struct ReservaRow: View {
    let reserva: Reserva; let onCancelar: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(reserva.quincho?.nombre ?? "—").font(.headline).foregroundColor(.appTextPrimary); Spacer(); EstadoBadge(estado: reserva.estado) }
            HStack(spacing: 4) { Image(systemName: "calendar"); Text(reserva.fecha) }.font(.caption).foregroundColor(.appTextSecondary)
            HStack(spacing: 4) { Image(systemName: "clock"); Text("\(reserva.horaInicio) – \(reserva.horaFin)") }.font(.caption).foregroundColor(.appTextSecondary)
            HStack(spacing: 4) { Image(systemName: "person.2"); Text("\(reserva.cantidadPersonas) personas") }.font(.caption).foregroundColor(.appTextSecondary)
            Divider().background(Color.appBorder)
            HStack {
                Text(reserva.precioTotal.formattedPrecio).font(.headline).foregroundColor(.appPrimary)
                Spacer()
                if reserva.estado == .PENDIENTE || reserva.estado == .CONFIRMADA {
                    Button("Cancelar") { onCancelar() }
                        .font(.caption).fontWeight(.semibold).foregroundColor(.appError)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().stroke(Color.appError, lineWidth: 1))
                }
                if reserva.estado == .COMPLETADA {
                    NavigationLink {
                        EscribirResenaView(quinchoId: reserva.quincho?.id ?? "", quinchoNombre: reserva.quincho?.nombre ?? "", reservaId: reserva.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").font(.caption2)
                            Text("Valorar").font(.caption).fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.appStar).clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Mapa estilo Booking

struct MapaView: View {
    @EnvironmentObject var vm: QuinchosViewModel
    @EnvironmentObject var favoritosVM: FavoritosViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -32.2230, longitude: -58.1411),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    @State private var quinchoSeleccionado: Quincho?
    @State private var showDetalle = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Mapa
                Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: vm.quinchos) { q in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: q.latitud, longitude: q.longitud)) {
                        Button {
                            withAnimation(.spring()) { quinchoSeleccionado = q }
                        } label: {
                            PriceMarker(
                                precio: q.precioDia,
                                rating: q.calificacionProm,
                                isSelected: quinchoSeleccionado?.id == q.id
                            )
                        }
                    }
                }
                .ignoresSafeArea()
                .onAppear {
                    locationManager.requestPermission()
                    if let lat = locationManager.userLatitude, let lng = locationManager.userLongitude {
                        region.center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    }
                }

                // Tarjeta del quincho seleccionado (estilo Booking)
                if let q = quinchoSeleccionado {
                    VStack(spacing: 0) {
                        // Handle
                        Capsule().fill(Color.appTextMuted).frame(width: 36, height: 4).padding(.top, 8)
                        
                        HStack(spacing: 12) {
                            // Foto
                            AsyncImage(url: URL(string: q.imagenes?.first?.url ?? "")) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Color.appSurfaceLight)
                            }
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            // Info
                            VStack(alignment: .leading, spacing: 6) {
                                // Tipo
                                Text(q.tipo.label)
                                    .font(.caption2).fontWeight(.bold)
                                    .foregroundColor(.appPrimary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.appPrimary.opacity(0.12))
                                    .clipShape(Capsule())
                                
                                Text(q.nombre)
                                    .font(.headline).foregroundColor(.appTextPrimary)
                                    .lineLimit(1)
                                
                                // Rating
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill").font(.caption2).foregroundColor(.appStar)
                                    Text(String(format: "%.1f", q.calificacionProm))
                                        .font(.caption).fontWeight(.bold).foregroundColor(.appStar)
                                    Text("(\(q.totalResenas))").font(.caption2).foregroundColor(.appTextMuted)
                                }
                                
                                // Ubicación
                                HStack(spacing: 3) {
                                    Image(systemName: "location").font(.system(size: 9))
                                    Text(q.ciudad).font(.caption)
                                }
                                .foregroundColor(.appTextSecondary)
                                
                                // Capacidad
                                HStack(spacing: 3) {
                                    Image(systemName: "person.2").font(.system(size: 9))
                                    Text("\(q.capacidadMin)–\(q.capacidadMax) personas").font(.caption)
                                }
                                .foregroundColor(.appTextSecondary)
                                
                                // Precio + botón
                                HStack {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(q.precioDia.formattedPrecio)
                                            .font(.title3).fontWeight(.bold).foregroundColor(.appPrimary)
                                        Text("por día").font(.caption2).foregroundColor(.appTextMuted)
                                    }
                                    
                                    Spacer()
                                    
                                    NavigationLink(value: q.id) {
                                        Text("Ver más")
                                            .font(.caption).fontWeight(.bold).foregroundColor(.white)
                                            .padding(.horizontal, 16).padding(.vertical, 8)
                                            .background(Color.appPrimary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(14)
                    }
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.3), radius: 10)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture {} // Evitar que el tap cierre
                    .gesture(DragGesture().onEnded { g in
                        if g.translation.height > 50 {
                            withAnimation { quinchoSeleccionado = nil }
                        }
                    })
                }
                
                // Botones flotantes
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            // Centrar en mi ubicación
                            Button {
                                if let lat = locationManager.userLatitude, let lng = locationManager.userLongitude {
                                    withAnimation {
                                        region.center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                                        region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                    }
                                }
                            } label: {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.appPrimary)
                                    .padding(12)
                                    .background(.ultraThickMaterial)
                                    .clipShape(Circle())
                            }
                            
                            // Cerrar tarjeta
                            if quinchoSeleccionado != nil {
                                Button {
                                    withAnimation { quinchoSeleccionado = nil }
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundColor(.appTextSecondary)
                                        .padding(12)
                                        .background(.ultraThickMaterial)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .padding(.top, 60)
            }
            .navigationDestination(for: String.self) { id in
                QuinchoDetalleView(quinchoId: id)
            }
            .task {
                await vm.buscar()
                locationManager.requestLocation()
            }
        }
    }
}

// MARK: - Price Marker (estilo Booking)

struct PriceMarker: View {
    let precio: Int
    let rating: Double
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                if rating >= 4.5 {
                    Image(systemName: "star.fill").font(.system(size: 7)).foregroundColor(.appStar)
                }
                Text(precio.formattedPrecio)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(isSelected ? .white : .appTextPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.appPrimary : Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.appPrimaryDark : Color.appBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            
            // Flecha
            Triangle()
                .fill(isSelected ? Color.appPrimary : Color.appCard)
                .frame(width: 10, height: 6)
                .offset(y: -1)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Favoritos

struct FavoritosView: View {
    @EnvironmentObject var favoritosVM: FavoritosViewModel
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if favoritosVM.favoritos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart").font(.system(size: 44)).foregroundColor(.appTextMuted)
                        Text("Guardá tus quinchos favoritos").foregroundColor(.appTextMuted).multilineTextAlignment(.center)
                    }.padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(favoritosVM.favoritos) { q in
                                NavigationLink(value: q.id) {
                                    QuinchoCard(quincho: q, isFavorito: true) {
                                        Task { await favoritosVM.toggleFavorito(quinchoId: q.id) }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Favoritos")
            .navigationDestination(for: String.self) { id in QuinchoDetalleView(quinchoId: id) }
            .task { await favoritosVM.cargarFavoritos() }
        }
    }
}

// MARK: - Cuenta

struct CuentaView: View {
    @EnvironmentObject var authVM: AuthViewModel
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar
                        VStack(spacing: 8) {
                            Circle().fill(Color.appSurface).frame(width: 80, height: 80)
                                .overlay(Image(systemName: "person").font(.title).foregroundColor(.appTextMuted))
                            Text(authVM.usuario?.nombre ?? "Usuario").font(.title3).fontWeight(.bold).foregroundColor(.appTextPrimary)
                            Text(authVM.usuario?.email ?? "").font(.caption).foregroundColor(.appTextSecondary)
                            if let rol = authVM.usuario?.rol {
                                Text(rol == .PROPIETARIO ? "Propietario" : rol == .ADMIN ? "Admin" : "Usuario")
                                    .font(.caption2).fontWeight(.bold)
                                    .foregroundColor(.appPrimary)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.appPrimary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        // Menu items
                        VStack(spacing: 0) {
                            NavigationLink { EditarPerfilView() } label: { MenuRowLink(icon: "person", label: "Editar perfil") }
                            NavigationLink { FavoritosView() } label: { MenuRowLink(icon: "heart", label: "Mis favoritos") }
                            MenuRowLink(icon: "bell", label: "Notificaciones")
                            MenuRowLink(icon: "questionmark.circle", label: "Ayuda")
                            MenuRowLink(icon: "doc.text", label: "Términos y condiciones")
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        Button {
                            Task { await authVM.logout() }
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.forward")
                                Text("Cerrar sesión")
                            }
                            .foregroundColor(.appError).fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Text("QuinchosApp v1.0.0").font(.caption2).foregroundColor(.appTextMuted)
                    }
                    .padding()
                }
            }
            .navigationTitle("Cuenta")
        }
    }
}

struct MenuRowLink: View {
    let icon: String; let label: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundColor(.appTextSecondary).frame(width: 22)
            Text(label).foregroundColor(.appTextPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.appTextMuted)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        Divider().background(Color.appBorder).padding(.leading, 52)
    }
}
