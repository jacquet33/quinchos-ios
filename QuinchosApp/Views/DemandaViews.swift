import SwiftUI

// MARK: - Modelos

struct Demanda: Codable {
    let nivel: String          // alta | media | baja | nueva
    let etiqueta: String
    let reservasRecientes: Int
    let proximasReservas: Int

    var color: Color {
        switch nivel {
        case "alta": return .appError
        case "media": return .appWarning
        case "baja": return .appSuccess
        default: return .appTextMuted
        }
    }

    var icono: String {
        switch nivel {
        case "alta": return "flame.fill"
        case "media": return "chart.line.uptrend.xyaxis"
        case "baja": return "checkmark.circle.fill"
        default: return "sparkles"
        }
    }

    /// Solo mostramos el badge cuando aporta información útil
    var valeLaPenaMostrar: Bool { nivel == "alta" || nivel == "nueva" }
}

struct Disponibilidad: Codable {
    let diasLibres: Int
    let diasHabiles: Int
    let porcentajeLibre: Int
    let mensaje: String?

    var urgente: Bool { porcentajeLibre <= 25 }
}

struct DiaDemanda: Codable, Identifiable {
    var id: Int { diaSemana }
    let diaSemana: Int
    let dia: String
    let reservas: Int
    let porcentaje: Int
    let ingresos: Int
    let nivel: String

    var color: Color {
        switch nivel {
        case "alta": return .appError
        case "media": return .appWarning
        case "baja": return .appTextMuted
        default: return .appTextMuted
        }
    }
}

struct AnalisisDemanda: Codable {
    let demanda: Demanda
    let disponibilidad: Disponibilidad
    let totalReservas: Int
    let porDia: [DiaDemanda]
    let sugerencias: [String]
}

// MARK: - Badge de demanda (para las cards)

struct DemandaBadge: View {
    let demanda: Demanda

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: demanda.icono).font(.system(size: 9))
            Text(demanda.etiqueta).font(.caption2).fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(demanda.color)
        .clipShape(Capsule())
    }
}

// MARK: - Aviso de disponibilidad (en el detalle)

struct AvisoDisponibilidad: View {
    let disponibilidad: Disponibilidad

    var body: some View {
        if let mensaje = disponibilidad.mensaje {
            HStack(spacing: 8) {
                Image(systemName: disponibilidad.urgente ? "exclamationmark.circle.fill" : "calendar")
                    .foregroundColor(disponibilidad.urgente ? .appError : .appWarning)
                Text(mensaje)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(.appTextPrimary)
                Spacer()
            }
            .padding(12)
            .background((disponibilidad.urgente ? Color.appError : Color.appWarning).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Panel de demanda del propietario

struct DemandaView: View {
    let quinchoId: String
    let quinchoNombre: String
    @StateObject private var vm = DemandaViewModel()

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if vm.cargando {
                ProgressView().tint(.appPrimary)
            } else if let a = vm.analisis {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // ─── Estado general ───
                        HStack(spacing: 12) {
                            VStack(spacing: 4) {
                                Image(systemName: a.demanda.icono)
                                    .font(.title2).foregroundColor(a.demanda.color)
                                Text(a.demanda.etiqueta)
                                    .font(.caption).fontWeight(.bold).foregroundColor(.appTextPrimary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.appCard).clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(spacing: 4) {
                                Text("\(a.disponibilidad.diasLibres)")
                                    .font(.title2).fontWeight(.bold).foregroundColor(.appPrimary)
                                Text("días libres este mes")
                                    .font(.caption2).foregroundColor(.appTextSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.appCard).clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(spacing: 4) {
                                Text("\(a.totalReservas)")
                                    .font(.title2).fontWeight(.bold).foregroundColor(.appTextPrimary)
                                Text("reservas en 90 días")
                                    .font(.caption2).foregroundColor(.appTextSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.appCard).clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // ─── Demanda por día ───
                        Text("Demanda por día de la semana")
                            .font(.headline).foregroundColor(.appTextPrimary)

                        VStack(spacing: 10) {
                            ForEach(a.porDia) { dia in
                                HStack(spacing: 12) {
                                    Text(String(dia.dia.prefix(3)))
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundColor(.appTextSecondary)
                                        .frame(width: 34, alignment: .leading)

                                    // Barra proporcional
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(Color.appSurface)
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(dia.color)
                                                .frame(width: max(4, geo.size.width * CGFloat(dia.porcentaje) / 100))
                                        }
                                    }
                                    .frame(height: 20)

                                    Text("\(dia.reservas)")
                                        .font(.caption).fontWeight(.bold)
                                        .foregroundColor(.appTextPrimary)
                                        .frame(width: 24, alignment: .trailing)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // ─── Sugerencias ───
                        if !a.sugerencias.isEmpty {
                            Text("Sugerencias").font(.headline).foregroundColor(.appTextPrimary)
                            ForEach(a.sugerencias, id: \.self) { sug in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.appStar).font(.caption)
                                    Text(sug)
                                        .font(.subheadline).foregroundColor(.appTextSecondary)
                                    Spacer()
                                }
                                .padding(14)
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding()
                }
            } else {
                Text("No se pudo cargar el análisis").foregroundColor(.appTextMuted)
            }
        }
        .navigationTitle("Demanda")
        .task { await vm.cargar(quinchoId: quinchoId) }
    }
}

// MARK: - ViewModel

@MainActor
final class DemandaViewModel: ObservableObject {
    @Published var analisis: AnalisisDemanda?
    @Published var cargando = false

    func cargar(quinchoId: String) async {
        cargando = true
        defer { cargando = false }

        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/quinchos/\(quinchoId)/demanda/analisis")
        else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        struct Resp: Codable { let ok: Bool; let data: AnalisisDemanda }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let resp = try? JSONDecoder().decode(Resp.self, from: data)
        else { return }

        analisis = resp.data
    }
}
