import SwiftUI

// MARK: - Quincho Card

struct QuinchoCard: View {
    let quincho: Quincho
    let compact: Bool
    let isFavorito: Bool
    let onFavorito: () -> Void

    init(quincho: Quincho, compact: Bool = false, isFavorito: Bool = false, onFavorito: @escaping () -> Void = {}) {
        self.quincho = quincho
        self.compact = compact
        self.isFavorito = isFavorito
        self.onFavorito = onFavorito
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Imagen
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: quincho.imagenes?.first?.url ?? "")) { fase in
                    switch fase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle().fill(Color.appSurfaceLight)
                            .overlay(Image(systemName: "photo").font(.title2).foregroundColor(.appTextMuted))
                    default:
                        Rectangle().fill(Color.appSurfaceLight)
                            .overlay(ProgressView().tint(.appTextMuted))
                    }
                }
                .frame(height: compact ? 140 : 190)
                .clipped()

                HStack {
                    // Badge tipo
                    Text(quincho.tipo.label)
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Spacer()

                    // Favorito
                    Button(action: onFavorito) {
                        Image(systemName: isFavorito ? "heart.fill" : "heart")
                            .foregroundColor(isFavorito ? .appError : .white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(10)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(quincho.nombre)
                        .font(.headline)
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").foregroundColor(.appStar).font(.caption2)
                        Text(String(format: "%.1f", quincho.calificacionProm))
                            .font(.caption).fontWeight(.bold).foregroundColor(.appStar)
                        Text("(\(quincho.totalResenas))")
                            .font(.caption2).foregroundColor(.appTextMuted)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "location").font(.caption2)
                    Text("\(quincho.ciudad), \(quincho.provincia)").font(.caption)
                }
                .foregroundColor(.appTextSecondary)

                Divider().background(Color.appBorder)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2").font(.caption2)
                        Text("\(quincho.capacidadMin)–\(quincho.capacidadMax)")
                            .font(.caption)
                    }
                    .foregroundColor(.appTextSecondary)

                    Spacer()

                    HStack(spacing: 2) {
                        Text(quincho.precioDia.formattedPrecio)
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(.appPrimary)
                        Text("/ día")
                            .font(.caption2).foregroundColor(.appTextMuted)
                    }
                }
            }
            .padding(12)
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(width: compact ? 260 : nil)
    }
}

// MARK: - Star Rating

struct StarRatingView: View {
    let rating: Int
    let maxRating: Int
    let size: CGFloat
    var editable: Bool = false
    var onChange: ((Int) -> Void)?

    init(rating: Int, maxRating: Int = 5, size: CGFloat = 18, editable: Bool = false, onChange: ((Int) -> Void)? = nil) {
        self.rating = rating
        self.maxRating = maxRating
        self.size = size
        self.editable = editable
        self.onChange = onChange
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(star <= rating ? .appStar : .appTextMuted)
                    .onTapGesture {
                        if editable { onChange?(star) }
                    }
            }
        }
    }
}

// MARK: - Estado Badge

struct EstadoBadge: View {
    let estado: EstadoReserva

    var color: Color {
        switch estado {
        case .PENDIENTE: return .estadoPendiente
        case .CONFIRMADA: return .estadoConfirmada
        case .CANCELADA: return .estadoCancelada
        case .COMPLETADA: return .estadoCompletada
        case .RECHAZADA: return .estadoCancelada
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(estado.label)
                .font(.caption2).fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Search Bar

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Buscar quinchos, salones..."
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.appTextMuted)

            TextField(placeholder, text: $text)
                .foregroundColor(.appTextPrimary)
                .autocorrectionDisabled()
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.appTextMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
}

// MARK: - Filter Chips

struct FilterChipsView: View {
    @Binding var selected: String
    let onChange: () -> Void

    private let options: [(key: String, label: String)] = [
        ("todos", "Todos"),
        ("QUINCHO", "Quincho"),
        ("SALON", "Salón"),
        ("QUINTA", "Quinta"),
        ("TERRAZA", "Terraza"),
        ("JARDIN", "Jardín"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.key) { option in
                    let isActive = selected == option.key
                    Button {
                        selected = option.key
                        onChange()
                    } label: {
                        Text(option.label)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(isActive ? .white : .appTextSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isActive ? Color.appPrimary : Color.appSurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isActive ? Color.clear : Color.appBorder, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Amenidad Chip

struct AmenidadChip: View {
    let amenidad: Amenidad

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption).foregroundColor(.appSuccess)
            Text(amenidad.label)
                .font(.caption).foregroundColor(.appTextPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
