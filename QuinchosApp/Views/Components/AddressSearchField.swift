import SwiftUI
import MapKit
import Combine

// MARK: - Dirección normalizada

struct DireccionSeleccionada: Equatable {
    var calle: String = ""
    var ciudad: String = ""
    var provincia: String = "Entre Ríos"
    var latitud: Double = 0
    var longitud: Double = 0

    var esValida: Bool { !calle.isEmpty && latitud != 0 && longitud != 0 }

    var textoCompleto: String {
        [calle, ciudad, provincia].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Buscador de direcciones (MKLocalSearchCompleter)

@MainActor
final class AddressSearchService: NSObject, ObservableObject {
    @Published var sugerencias: [MKLocalSearchCompletion] = []
    @Published var buscando = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        // Direcciones + lugares: en ciudades chicas de Argentina Apple
        // suele tener mejor cobertura de puntos de interés que de alturas
        completer.resultTypes = [.address, .pointOfInterest]

        // Priorizar resultados de la zona de Entre Ríos
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -32.0, longitude: -58.5),
            span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
        )
    }

    func buscar(_ texto: String) {
        guard texto.count >= 3 else {
            sugerencias = []
            return
        }
        buscando = true
        completer.queryFragment = texto
    }

    func limpiar() {
        sugerencias = []
        completer.queryFragment = ""
        resultadosDirectos = []
    }

    /// Búsqueda directa (MKLocalSearch) para cuando el autocompletado no encuentra nada
    @Published var resultadosDirectos: [MKMapItem] = []

    func busquedaDirecta(_ texto: String, ciudad: String = "Colón, Entre Ríos") async {
        guard texto.count >= 3 else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(texto), \(ciudad)"
        request.region = completer.region
        guard let response = try? await MKLocalSearch(request: request).start() else { return }
        resultadosDirectos = Array(response.mapItems.prefix(6))
    }

    /// Convierte un MKMapItem en dirección
    func desdeMapItem(_ item: MKMapItem) -> DireccionSeleccionada {
        let place = item.placemark
        var dir = DireccionSeleccionada()
        let calle = place.thoroughfare ?? item.name ?? ""
        dir.calle = place.subThoroughfare.map { "\(calle) \($0)" } ?? calle
        dir.ciudad = place.locality ?? place.subAdministrativeArea ?? ""
        dir.provincia = place.administrativeArea ?? "Entre Ríos"
        dir.latitud = place.coordinate.latitude
        dir.longitud = place.coordinate.longitude
        return dir
    }

    /// Convierte una sugerencia en dirección con coordenadas reales
    func resolver(_ completion: MKLocalSearchCompletion) async -> DireccionSeleccionada? {
        let request = MKLocalSearch.Request(completion: completion)
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else { return nil }

        let place = item.placemark
        var dir = DireccionSeleccionada()

        // Calle con altura: "12 de Abril 450"
        let calle = place.thoroughfare ?? completion.title
        if let altura = place.subThoroughfare {
            dir.calle = "\(calle) \(altura)"
        } else {
            dir.calle = calle
        }

        dir.ciudad = place.locality ?? place.subAdministrativeArea ?? ""
        dir.provincia = place.administrativeArea ?? "Entre Ríos"
        dir.latitud = place.coordinate.latitude
        dir.longitud = place.coordinate.longitude

        return dir
    }
}

extension AddressSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.sugerencias = Array(completer.results.prefix(8))
            self.buscando = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.sugerencias = []
            self.buscando = false
        }
    }
}

// MARK: - Campo de dirección con autocompletado

struct AddressSearchField: View {
    @Binding var direccion: DireccionSeleccionada
    var label: String = "Dirección"

    @StateObject private var service = AddressSearchService()
    @State private var texto = ""
    @State private var mostrarSugerencias = false
    @State private var mostrarMapa = false
    @FocusState private var enfocado: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(.appTextSecondary)

            // Campo de búsqueda
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(direccion.esValida ? .appSuccess : .appTextMuted)

                TextField("Empezá a escribir la calle...", text: $texto)
                    .foregroundColor(.appTextPrimary)
                    .focused($enfocado)
                    .autocorrectionDisabled()
                    .onChange(of: texto) { _, nuevo in
                        if nuevo != direccion.textoCompleto {
                            direccion.latitud = 0
                            direccion.longitud = 0
                            service.buscar(nuevo)
                            mostrarSugerencias = true
                        }
                    }

                if service.buscando {
                    ProgressView().scaleEffect(0.7).tint(.appTextMuted)
                } else if !texto.isEmpty {
                    Button {
                        texto = ""
                        direccion = DireccionSeleccionada()
                        service.limpiar()
                        mostrarSugerencias = false
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.appTextMuted)
                    }
                }
            }
            .padding(12)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(direccion.esValida ? Color.appSuccess.opacity(0.5) : Color.appBorder)
            )

            // Sugerencias
            if mostrarSugerencias && !service.sugerencias.isEmpty {
                VStack(spacing: 0) {
                    ForEach(service.sugerencias, id: \.self) { sug in
                        Button {
                            Task { await seleccionar(sug) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle")
                                    .foregroundColor(.appPrimary).font(.system(size: 15))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(sug.title)
                                        .font(.subheadline)
                                        .foregroundColor(.appTextPrimary)
                                        .multilineTextAlignment(.leading)
                                    if !sug.subtitle.isEmpty {
                                        Text(sug.subtitle)
                                            .font(.caption2)
                                            .foregroundColor(.appTextMuted)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                        }

                        if sug != service.sugerencias.last {
                            Divider().background(Color.appBorder).padding(.leading, 40)
                        }
                    }
                }
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Confirmación de la dirección elegida
            if direccion.esValida {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption).foregroundColor(.appSuccess)
                    Text("\(direccion.ciudad), \(direccion.provincia)")
                        .font(.caption).foregroundColor(.appTextSecondary)
                }
            }

            // Siempre disponible: ubicar a mano
            Button {
                mostrarMapa = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "map").font(.caption)
                    Text(direccion.esValida ? "Ajustar ubicación en el mapa" : "No la encuentro, ubicar en el mapa")
                        .font(.caption)
                }
                .foregroundColor(.appPrimary)
            }
        }
        .sheet(isPresented: $mostrarMapa) {
            UbicarEnMapaView(direccion: $direccion)
                .onDisappear {
                    if direccion.esValida { texto = direccion.calle }
                }
        }
    }

    private func seleccionar(_ completion: MKLocalSearchCompletion) async {
        guard let dir = await service.resolver(completion) else { return }
        direccion = dir
        texto = dir.calle
        mostrarSugerencias = false
        service.limpiar()
        enfocado = false
    }
}

// MARK: - Mapa de confirmación (muestra dónde quedó ubicado)

struct MiniMapaConfirmacion: View {
    let latitud: Double
    let longitud: Double

    private var posicion: MapCameraPosition {
        .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitud, longitude: longitud),
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        ))
    }

    var body: some View {
        Map(initialPosition: posicion, interactionModes: []) {
            Annotation("", coordinate: CLLocationCoordinate2D(latitude: latitud, longitude: longitud)) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title)
                    .foregroundColor(.appPrimary)
                    .background(Circle().fill(.white).frame(width: 18, height: 18))
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
    }
}

// MARK: - Ubicar manualmente en el mapa

struct UbicarEnMapaView: View {
    @Binding var direccion: DireccionSeleccionada
    @Environment(\.dismiss) var dismiss

    @State private var centro = CLLocationCoordinate2D(latitude: -32.2230, longitude: -58.1411)
    @State private var posicion: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -32.2230, longitude: -58.1411),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )
    @State private var calle: String = ""
    @State private var ciudad: String = ""
    @State private var resolviendo = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Mapa con pin fijo al centro
                    ZStack {
                        Map(position: $posicion)
                            .onMapCameraChange(frequency: .onEnd) { contexto in
                                centro = contexto.region.center
                                Task { await resolverDireccion() }
                            }

                        // Pin fijo en el centro de la pantalla
                        Image(systemName: "mappin")
                            .font(.system(size: 34))
                            .foregroundColor(.appPrimary)
                            .shadow(radius: 3)
                            .offset(y: -17)
                            .allowsHitTesting(false)
                    }
                    .frame(maxHeight: .infinity)

                    // Datos de la ubicación
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse").foregroundColor(.appPrimary)
                            Text("Movés el mapa para ubicar el pin")
                                .font(.caption).foregroundColor(.appTextSecondary)
                            Spacer()
                            if resolviendo { ProgressView().scaleEffect(0.7) }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dirección").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                            TextField("Ej: San Martín 450", text: $calle)
                                .foregroundColor(.appTextPrimary)
                                .padding(12).background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ciudad").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                            TextField("Colón", text: $ciudad)
                                .foregroundColor(.appTextPrimary)
                                .padding(12).background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            direccion = DireccionSeleccionada(
                                calle: calle.trimmingCharacters(in: .whitespaces),
                                ciudad: ciudad.trimmingCharacters(in: .whitespaces),
                                provincia: "Entre Ríos",
                                latitud: centro.latitude,
                                longitud: centro.longitude
                            )
                            dismiss()
                        } label: {
                            Text("Confirmar ubicación").fontWeight(.bold)
                                .frame(maxWidth: .infinity).padding()
                                .background(calle.count >= 3 ? Color.appPrimary : Color.appSurfaceLight)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(calle.count < 3)
                    }
                    .padding()
                    .background(Color.appBackground)
                }
            }
            .navigationTitle("Ubicar en el mapa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundColor(.appTextSecondary)
                }
            }
            .task {
                if direccion.esValida {
                    centro = CLLocationCoordinate2D(latitude: direccion.latitud, longitude: direccion.longitud)
                    posicion = .region(MKCoordinateRegion(center: centro,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
                    calle = direccion.calle
                    ciudad = direccion.ciudad
                } else {
                    await resolverDireccion()
                }
            }
        }
    }

    /// Geocodificación inversa: propone la calle según dónde quedó el pin
    private func resolverDireccion() async {
        resolviendo = true
        defer { resolviendo = false }

        let ubicacion = CLLocation(latitude: centro.latitude, longitude: centro.longitude)
        let geocoder = CLGeocoder()
        guard let places = try? await geocoder.reverseGeocodeLocation(ubicacion, preferredLocale: Locale(identifier: "es_AR")),
              let place = places.first else { return }

        // Solo autocompletar si el usuario todavía no escribió nada
        if calle.isEmpty, let via = place.thoroughfare {
            calle = place.subThoroughfare.map { "\(via) \($0)" } ?? via
        }
        if ciudad.isEmpty {
            ciudad = place.locality ?? place.subAdministrativeArea ?? ""
        }
    }
}
